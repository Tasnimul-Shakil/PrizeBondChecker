import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/digit_normalizer.dart';
import '../../core/matching_engine.dart';
import '../../models/bond.dart';
import '../../services/locale_service.dart';
import '../../services/wallet_service.dart';
import 'batch_scanner_tray.dart';
import 'preview_edit_modal.dart';

enum ScanMode { single, batch }

/// Real-time camera scanner with guided bounding box overlay,
/// Google ML Kit OCR text recognition (Devanagari & Latin),
/// high-resolution photo capture, gallery image upload, and digit normalization.
class ScannerScreen extends StatefulWidget {
  final WalletService widgetWalletService;
  final MatchingEngine matchingEngine;

  const ScannerScreen({
    super.key,
    required WalletService walletService,
    required this.matchingEngine,
  }) : widgetWalletService = walletService;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isTorchOn = false;
  bool _isCameraInitialized = false;
  bool _isProcessingFrame = false;
  bool _isAnalyzingImage = false;
  bool _isPickingImage = false;
  String? _cameraErrorMessage;

  ScanMode _currentMode = ScanMode.single;
  late final TextRecognizer _devanagariRecognizer;
  late final TextRecognizer _latinRecognizer;
  final ImagePicker _imagePicker = ImagePicker();
  final LocaleService _locale = LocaleService();

  // Batch Mode state
  final List<Bond> _batchCapturedBonds = [];
  final Set<String> _batchCapturedSerials = {};

  // Detection feedback throttle
  DateTime? _lastDetectionTime;
  String? _lastDetectedSerial;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize ML Kit Text Recognizers:
    // Devanagiri model handles Bengali/Indic script and digits (০-৯)
    // Latin model handles English digits (0-9) and series prefixes (KA, KH)
    _devanagariRecognizer = TextRecognizer(script: TextRecognitionScript.devanagiri);
    _latinRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _devanagariRecognizer.close();
    _latinRecognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the user is currently picking a photo from the gallery, don't interfere with camera
    if (_isPickingImage) return;

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopImageStream();
    } else if (state == AppLifecycleState.resumed) {
      if (!_isAnalyzingImage && !controller.value.isStreamingImages) {
        _startImageStream();
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _cameraErrorMessage = 'No camera found on this device.';
        });
        return;
      }

      final camera = _cameras![_selectedCameraIndex];
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
        _cameraErrorMessage = null;
      });

      // Start live image stream for OCR
      _startImageStream();
    } catch (e) {
      setState(() {
        _cameraErrorMessage = 'Camera permission or initialization error: $e';
      });
    }
  }

  Future<void> _stopImageStream() async {
    try {
      final controller = _cameraController;
      if (controller != null &&
          controller.value.isInitialized &&
          controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {}
  }

  void _startImageStream() {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isStreamingImages) return;

    try {
      controller.startImageStream((CameraImage image) {
        if (_isProcessingFrame || _isAnalyzingImage || _isPickingImage) return;

        // Throttle processing: allow 2 to 3 frames per second to save battery
        final now = DateTime.now();
        if (_lastDetectionTime != null &&
            now.difference(_lastDetectionTime!).inMilliseconds < 400) {
          return;
        }

        _processCameraStreamImage(image);
      });
    } catch (_) {
      // If streaming fails on some hardware, manual capture & upload remain 100% active
    }
  }

  Future<void> _processCameraStreamImage(CameraImage image) async {
    _isProcessingFrame = true;
    try {
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage == null) return;

      await _runOcrPipeline(inputImage, isLiveStream: true);
    } catch (_) {
      // Ignore transient frame recognition errors
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    if (_cameraController == null) return null;
    final camera = _cameras![_selectedCameraIndex];
    final sensorOrientation = camera.sensorOrientation;

    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
        InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;

    Uint8List allBytes;
    if (image.planes.length > 1) {
      final WriteBuffer allBytesBuffer = WriteBuffer();
      for (final plane in image.planes) {
        allBytesBuffer.putUint8List(plane.bytes);
      }
      allBytes = allBytesBuffer.done().buffer.asUint8List();
    } else {
      allBytes = image.planes.first.bytes;
    }

    return InputImage.fromBytes(
      bytes: allBytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  /// Master OCR pipeline: runs Devanagari first (Bengali digits/text),
  /// then Latin (English digits/series), or combines both for best extraction.
  Future<void> _runOcrPipeline(InputImage inputImage, {required bool isLiveStream, String? imagePath}) async {
    String rawTextDevanagari = '';
    String rawTextLatin = '';

    try {
      // 1. Process with Devanagari model (primary for Bengali numerals ০-৯)
      final devanagariResult = await _devanagariRecognizer.processImage(inputImage);
      rawTextDevanagari = devanagariResult.text;
      var scanned = DigitNormalizer.extractPrimaryBond(rawTextDevanagari);

      // 2. If no valid 7-digit serial, also try Latin model
      if (!scanned.isValid) {
        final latinResult = await _latinRecognizer.processImage(inputImage);
        rawTextLatin = latinResult.text;
        final latinScanned = DigitNormalizer.extractPrimaryBond(rawTextLatin);

        if (latinScanned.isValid) {
          scanned = latinScanned;
        } else {
          // Combine both OCR texts
          final combined = '$rawTextDevanagari\n$rawTextLatin';
          scanned = DigitNormalizer.extractPrimaryBond(combined);
        }
      }

      if (scanned.isValid && scanned.serial != null) {
        _handleDetectedBond(scanned.serial!, scanned.series, imagePath: imagePath);
      } else if (!isLiveStream) {
        // User explicitly tapped Capture or Picked from Gallery and no serial was found
        if (mounted) {
          _showNoSerialDetectedDialog(
            rawTextDevanagari.isNotEmpty ? rawTextDevanagari : rawTextLatin,
          );
        }
      }
    } catch (e) {
      if (!isLiveStream && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('OCR Recognition error: $e'),
          ),
        );
      }
    }
  }

  void _handleDetectedBond(String serial, String? series, {String? imagePath}) {
    _lastDetectionTime = DateTime.now();

    // Prevent duplicate scan if bond is already in the user's wallet
    if (widget.widgetWalletService.containsSerial(serial)) {
      if (mounted && _lastDetectedSerial != serial) {
        _lastDetectedSerial = serial;
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD4AF37),
            duration: const Duration(seconds: 2),
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.black),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bond $serial is already in your wallet!',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return;
    }

    if (_currentMode == ScanMode.single) {
      // Pause stream temporarily to show preview confirmation modal
      _stopImageStream();
      HapticFeedback.mediumImpact();

      _showSinglePreviewModal(serial: serial, series: series, imagePath: imagePath);
    } else {
      // Batch Mode: continuous rapid capture (ignore duplicates)
      if (!_batchCapturedSerials.contains(serial) && !widget.widgetWalletService.containsSerial(serial)) {
        HapticFeedback.lightImpact();
        SystemSound.play(SystemSoundType.click);

        final bond = Bond(
          serialNumber: serial,
          seriesPrefix: series,
          imagePath: imagePath,
          batchId: 'BATCH_${DateTime.now().millisecondsSinceEpoch}',
        );

        setState(() {
          _batchCapturedSerials.add(serial);
          _batchCapturedBonds.add(bond);
          _lastDetectedSerial = serial;
        });
      }
    }
  }

  /// Helper to extract 7-digit serial number from an image file
  Future<String?> _extractSerialFromImage(InputImage inputImage) async {
    try {
      final devanagariResult = await _devanagariRecognizer.processImage(inputImage);
      var scanned = DigitNormalizer.extractPrimaryBond(devanagariResult.text);
      if (scanned.isValid && scanned.serial != null) {
        return scanned.serial;
      }
      final latinResult = await _latinRecognizer.processImage(inputImage);
      scanned = DigitNormalizer.extractPrimaryBond(latinResult.text);
      if (scanned.isValid && scanned.serial != null) {
        return scanned.serial;
      }
      final combined = '${devanagariResult.text}\n${latinResult.text}';
      scanned = DigitNormalizer.extractPrimaryBond(combined);
      if (scanned.isValid && scanned.serial != null) {
        return scanned.serial;
      }
    } catch (_) {}
    return null;
  }

  /// Takes a high-resolution focused photo and runs OCR via InputImage.fromFilePath
  Future<void> _captureAndScanPhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isAnalyzingImage || _isPickingImage) return;

    try {
      setState(() {
        _isAnalyzingImage = true;
      });

      HapticFeedback.mediumImpact();
      await _stopImageStream();

      final photo = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(photo.path);
      await _runOcrPipeline(inputImage, isLiveStream: false, imagePath: photo.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('Capture error: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzingImage = false;
        });
      }
    }
  }

  /// Lets the user pick single or multiple prize bond photos from Gallery / Storage
  Future<void> _pickImageFromGallery() async {
    if (_isPickingImage) return;

    setState(() {
      _isPickingImage = true;
      _isAnalyzingImage = true;
    });

    // 1. Stop camera image stream first so camera hardware is idle while gallery is open
    await _stopImageStream();

    try {
      final pickedList = await _imagePicker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (pickedList.isEmpty) {
        // User cancelled gallery selection without picking any image
        if (mounted) {
          setState(() {
            _isPickingImage = false;
            _isAnalyzingImage = false;
          });
          _startImageStream();
        }
        return;
      }

      if (pickedList.length == 1) {
        // Single image selected: run OCR and show preview modal with photo preview
        final file = pickedList.first;
        final inputImage = InputImage.fromFilePath(file.path);
        await _runOcrPipeline(inputImage, isLiveStream: false, imagePath: file.path);
      } else {
        // Multiple images selected: process each and add to wallet
        int addedCount = 0;
        int duplicateCount = 0;
        int failedOcrCount = 0;
        final newBonds = <Bond>[];

        for (int i = 0; i < pickedList.length; i++) {
          final file = pickedList[i];
          final inputImage = InputImage.fromFilePath(file.path);
          final serial = await _extractSerialFromImage(inputImage);

          if (serial != null) {
            if (widget.widgetWalletService.containsSerial(serial) ||
                newBonds.any((b) => b.serialNumber == serial)) {
              duplicateCount++;
            } else {
              newBonds.add(Bond(
                serialNumber: serial,
                imagePath: file.path,
                batchId: 'MULTI_GALLERY_${DateTime.now().millisecondsSinceEpoch}',
                tags: ['Gallery Upload'],
              ));
            }
          } else {
            failedOcrCount++;
          }
        }

        if (newBonds.isNotEmpty) {
          addedCount = await widget.widgetWalletService.addBatch(newBonds);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF006A4E),
              duration: const Duration(seconds: 4),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Added $addedCount bonds from ${pickedList.length} photos!',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (duplicateCount > 0 || failedOcrCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 28),
                      child: Text(
                        '${duplicateCount > 0 ? "$duplicateCount duplicate(s) skipped. " : ""}${failedOcrCount > 0 ? "$failedOcrCount photo(s) had no readable number." : ""}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('Could not open images: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
          _isAnalyzingImage = false;
        });
      }
    }
  }

  void _showNoSerialDetectedDialog(String rawOcrText) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.search_off, color: Color(0xFFD4AF37), size: 28),
            SizedBox(width: 10),
            Text('Number Not Detected', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Could not clearly isolate the 7-digit serial number.\n\nTips for a successful scan:\n• Align the serial line (e.g. খ শ ০১২৮৭৪৪)\n• Ensure good lighting without flash glare\n• Keep the bond flat and in focus',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            if (rawOcrText.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Text Detected:', style: TextStyle(color: Colors.white54, fontSize: 11)),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  rawOcrText.length > 100 ? '${rawOcrText.substring(0, 100)}...' : rawOcrText,
                  style: const TextStyle(color: Colors.white60, fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openManualEntry();
            },
            child: const Text('Type Manually', style: TextStyle(color: Color(0xFF00FF66))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006A4E),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _pickImageFromGallery();
            },
            child: const Text('Pick Image'),
          ),
        ],
      ),
    );
  }

  void _showSinglePreviewModal({required String serial, String? series, String? imagePath}) async {
    await _stopImageStream();

    final result = await showModalBottomSheet<Bond>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PreviewEditModal(
        initialSerial: serial,
        imagePath: imagePath,
        matchingEngine: widget.matchingEngine,
        walletService: widget.widgetWalletService,
      ),
    );

    if (result != null) {
      final added = await widget.widgetWalletService.addBond(
        serialNumber: result.serialNumber,
        seriesPrefix: result.seriesPrefix,
        imagePath: result.imagePath,
        tags: result.tags,
        notes: result.notes,
      );

      if (mounted) {
        if (added != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF006A4E),
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Bond ${result.displayName} saved to wallet!'),
                ],
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFD4AF37),
              content: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.black),
                  const SizedBox(width: 8),
                  Text(
                    'Bond ${result.displayName} is already in your wallet!',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }

    // Resume camera stream if needed
    if (mounted && _cameraController != null && _cameraController!.value.isInitialized) {
      _startImageStream();
    }
  }

  Future<void> _toggleTorch() async {
    if (_cameraController == null) return;
    try {
      _isTorchOn = !_isTorchOn;
      await _cameraController!.setFlashMode(
        _isTorchOn ? FlashMode.torch : FlashMode.off,
      );
      setState(() {});
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    await _cameraController?.dispose();
    setState(() {
      _isCameraInitialized = false;
    });
    await _initializeCamera();
  }

  void _openManualEntry() {
    _showSinglePreviewModal(serial: '', series: null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Viewfinder or Placeholder / Error
          if (_isCameraInitialized && _cameraController != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? 1,
                  height: _cameraController!.value.previewSize?.width ?? 1,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            _buildFallbackCameraView(),

          // 2. Guided Overlay with Golden Bounding Box
          _buildGuidedBoundingBoxOverlay(),

          // 3. Top Control Bar (Back, Flash, Switch, Single/Batch toggle)
          _buildTopBar(),

          // 4. Bottom Controls / Batch Tray
          if (_currentMode == ScanMode.batch)
            Align(
              alignment: Alignment.bottomCenter,
              child: BatchScannerTray(
                capturedBonds: _batchCapturedBonds,
                onRemoveBond: (index) {
                  setState(() {
                    final removed = _batchCapturedBonds.removeAt(index);
                    _batchCapturedSerials.remove(removed.serialNumber);
                  });
                },
                onSaveAll: () async {
                  if (_batchCapturedBonds.isEmpty) return;
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  final count = await widget.widgetWalletService.addBatch(_batchCapturedBonds);
                  if (mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF006A4E),
                        content: Text('🎉 Successfully added $count bonds to your wallet!'),
                      ),
                    );
                  }
                },
              ),
            )
          else
            _buildSingleModeBottomBar(),

          // 5. Analyzing Spinner Overlay
          if (_isAnalyzingImage)
            Container(
              color: Colors.black.withOpacity(0.75),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Analyzing Prize Bond Serial...\nChecking Winning Draws',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFallbackCameraView() {
    return Container(
      color: const Color(0xFF0B192C),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.document_scanner, size: 72, color: Color(0xFFD4AF37)),
              const SizedBox(height: 16),
              Text(
                _cameraErrorMessage ?? 'Initializing Camera...',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006A4E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: _pickImageFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Upload Prize Bond Image'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuidedBoundingBoxOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.maxWidth * 0.88;
        const boxHeight = 115.0;
        final topOffset = constraints.maxHeight * 0.28;

        return Stack(
          children: [
            // Darkened scrim around target area
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.55),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    child: Container(color: Colors.black),
                  ),
                  Positioned(
                    top: topOffset,
                    left: (constraints.maxWidth - boxWidth) / 2,
                    width: boxWidth,
                    height: boxHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Golden Bounding Box Frame
            Positioned(
              top: topOffset,
              left: (constraints.maxWidth - boxWidth) / 2,
              width: boxWidth,
              height: boxHeight,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFD4AF37),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    _buildCornerAccent(top: 0, left: 0),
                    _buildCornerAccent(top: 0, right: 0),
                    _buildCornerAccent(bottom: 0, left: 0),
                    _buildCornerAccent(bottom: 0, right: 0),
                    Center(
                      child: Text(
                        _lastDetectedSerial != null
                            ? (_locale.isBangla
                                ? 'শনাক্ত হয়েছে: ${DigitNormalizer.toBengaliDigits(_lastDetectedSerial!)}'
                                : 'Detected: $_lastDetectedSerial')
                            : (_locale.isBangla
                                ? 'এখানে বন্ডের ৭ ডিজিট নম্বরটি রাখুন\n(যেমন: ০১২৮৭৪৪)'
                                : 'Align Serial Number Here\n(e.g. 0128744)'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _lastDetectedSerial != null
                              ? const Color(0xFF00FF66)
                              : Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          shadows: const [
                            Shadow(blurRadius: 4, color: Colors.black),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Instructional banner
            Positioned(
              top: topOffset - 50,
              left: 20,
              right: 20,
              child: const Text(
                'Hold camera steady or tap Capture / Upload below',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCornerAccent({
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: const Color(0xFFD4AF37),
          borderRadius: BorderRadius.only(
            topLeft: top != null && left != null ? const Radius.circular(14) : Radius.zero,
            topRight: top != null && right != null ? const Radius.circular(14) : Radius.zero,
            bottomLeft: bottom != null && left != null ? const Radius.circular(14) : Radius.zero,
            bottomRight: bottom != null && right != null ? const Radius.circular(14) : Radius.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
            const Spacer(),
            // Single / Batch Mode Selector
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  _modeButton(title: _locale.isBangla ? 'একক' : 'Single', mode: ScanMode.single),
                  _modeButton(title: _locale.isBangla ? 'একাধিক' : 'Batch', mode: ScanMode.batch),
                ],
              ),
            ),
            const Spacer(),
            const LanguageToggleButton(),
            IconButton(
              icon: Icon(
                _isTorchOn ? Icons.flash_on : Icons.flash_off,
                color: _isTorchOn ? const Color(0xFFD4AF37) : Colors.white,
              ),
              onPressed: _toggleTorch,
            ),
            IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
              onPressed: _switchCamera,
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeButton({required String title, required ScanMode mode}) {
    final isSelected = _currentMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF006A4E) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSingleModeBottomBar() {
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF131D2A).withOpacity(0.88),
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // 1. Upload from Gallery
            _bottomActionIcon(
              icon: Icons.photo_library,
              label: _locale.isBangla ? 'ছবি বাছাই' : 'Gallery',
              onTap: _pickImageFromGallery,
            ),

            // 2. Large High-Res Capture Shutter Button
            GestureDetector(
              onTap: _captureAndScanPhoto,
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD4AF37), width: 3.5),
                  color: Colors.white.withOpacity(0.15),
                ),
                padding: const EdgeInsets.all(4),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: const Center(
                    child: Icon(Icons.camera_alt, color: Color(0xFF006A4E), size: 30),
                  ),
                ),
              ),
            ),

            // 3. Manual Entry
            _bottomActionIcon(
              icon: Icons.keyboard,
              label: _locale.isBangla ? 'নম্বর লিখুন' : 'Type Serial',
              onTap: _openManualEntry,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomActionIcon({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
