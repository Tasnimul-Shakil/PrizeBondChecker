import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/digit_normalizer.dart';
import '../../core/matching_engine.dart';
import '../../models/bond.dart';
import '../../models/draw.dart';
import '../../services/document_cropper_service.dart';
import '../../services/wallet_service.dart';

/// Bottom modal sheet shown after a single bond is scanned to allow manual verification,
/// instant prize match checking, photo preview, and duplicate-safe saving.
class PreviewEditModal extends StatefulWidget {
  final String initialSerial;
  final String? imagePath;
  final MatchingEngine matchingEngine;
  final WalletService walletService;

  const PreviewEditModal({
    super.key,
    required this.initialSerial,
    this.imagePath,
    required this.matchingEngine,
    required this.walletService,
  });

  @override
  State<PreviewEditModal> createState() => _PreviewEditModalState();
}

class _PreviewEditModalState extends State<PreviewEditModal> {
  late final TextEditingController _serialController;
  late final TextEditingController _tagController;
  String? _currentImagePath;
  int _imageKeyIndex = 0;

  List<PrizeMatchResult> _instantMatches = [];

  @override
  void initState() {
    super.initState();
    _currentImagePath = widget.imagePath;
    _serialController = TextEditingController(text: widget.initialSerial);
    _tagController = TextEditingController();

    _runInstantCheck();
    _serialController.addListener(_runInstantCheck);
  }

  Future<void> _rotateImage() async {
    if (_currentImagePath == null) return;
    final rotated = await DocumentCropperService().rotateImageFile(_currentImagePath!, 90);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    setState(() {
      _currentImagePath = rotated;
      _imageKeyIndex++;
    });
  }

  @override
  void dispose() {
    _serialController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _runInstantCheck() {
    final serial = DigitNormalizer.normalizeSerial(_serialController.text);
    if (serial != null && serial.length == 7) {
      final matches = widget.matchingEngine.checkSerialString(serial);
      setState(() {
        _instantMatches = matches;
      });
    } else {
      setState(() {
        _instantMatches = [];
      });
    }
  }

  bool get _isAlreadyInWallet {
    final serial = DigitNormalizer.normalizeSerial(_serialController.text);
    if (serial == null) return false;
    return widget.walletService.containsSerial(serial);
  }

  @override
  Widget build(BuildContext context) {
    final isWinner = _instantMatches.isNotEmpty;
    final currentSerial = _serialController.text.trim();
    final bengaliPreview = DigitNormalizer.toBengaliDigits(currentSerial);
    final isAlreadySaved = _isAlreadyInWallet;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF131D2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                const Icon(Icons.verified, color: Color(0xFFD4AF37), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Verify Bond Number',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Instant Winner Alert Banner
            if (isWinner) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF006A4E), Color(0xFF0F9D58)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F9D58).withOpacity(0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'WINNING BOND DETECTED!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_instantMatches.first.tierName} (${_instantMatches.first.tierNameBn}) - ${DigitNormalizer.formatCurrencyBDT(_instantMatches.first.prizeAmount)}',
                            style: const TextStyle(
                              color: Color(0xFFFFF176),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Draw #${_instantMatches.first.drawNumber}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Duplicate Warning Banner
            if (isAlreadySaved) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFD4AF37), size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This bond number is already in your wallet. Each number can only be added once.',
                        style: TextStyle(
                          color: Color(0xFFFFF176),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Full Prize Bond Document Preview with Rotate & Zoom
            if (_currentImagePath != null && File(_currentImagePath!).existsSync()) ...[
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5), width: 1.5),
                ),
                padding: const EdgeInsets.all(6),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 3.5,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Image.file(
                          File(_currentImagePath!),
                          key: ValueKey('preview_img_$_imageKeyIndex'),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _rotateImage,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.rotate_right, size: 14, color: Color(0xFFFFF176)),
                                SizedBox(width: 4),
                                Text(
                                  'Rotate',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.document_scanner, size: 12, color: Color(0xFFFFF176)),
                            SizedBox(width: 4),
                            Text(
                              'Full Document',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 7-Digit Serial Input (Full Width, Number-only, Large & Prominent)
            TextField(
              controller: _serialController,
              keyboardType: TextInputType.number,
              maxLength: 7,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
              decoration: InputDecoration(
                counterText: '',
                labelText: '7-Digit Bond Number',
                hintText: '0786345',
                hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 4),
                labelStyle: const TextStyle(color: Colors.white60),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF00FF66), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Bengali Numeral preview
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Text(
                    'বাংলা সংখ্যা: ',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  Text(
                    bengaliPreview.isNotEmpty ? bengaliPreview : '-------',
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    '৳১০০ প্রাইজবন্ড',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Optional Tag input
            TextField(
              controller: _tagController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Tag / Label (Optional, e.g. Gift, Personal)',
                labelStyle: const TextStyle(color: Colors.white60),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 22),

            // Confirm & Save Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isAlreadySaved ? Colors.white24 : const Color(0xFF006A4E),
                foregroundColor: isAlreadySaved ? Colors.white54 : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: isAlreadySaved
                  ? null
                  : () {
                      final serial = DigitNormalizer.normalizeSerial(_serialController.text);
                      if (serial == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Colors.redAccent,
                            content: Text('Please enter a valid 7-digit bond serial number.'),
                          ),
                        );
                        return;
                      }

                      if (widget.walletService.containsSerial(serial)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFFD4AF37),
                            content: Text('This bond is already in your wallet!'),
                          ),
                        );
                        return;
                      }

                      final confirmedBond = Bond(
                        serialNumber: serial,
                        imagePath: _currentImagePath,
                        tags: _tagController.text.trim().isNotEmpty
                            ? [_tagController.text.trim()]
                            : [],
                      );

                      Navigator.pop(context, confirmedBond);
                    },
              child: Text(
                isAlreadySaved ? 'Already in Wallet' : 'Confirm & Save to Wallet',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
