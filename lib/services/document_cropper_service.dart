import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Service to detect and isolate the full Bangladesh Prize Bond banknote document
/// from camera captures and gallery uploads, removing table/background clutter.
class DocumentCropperService {
  static final DocumentCropperService _instance = DocumentCropperService._internal();
  factory DocumentCropperService() => _instance;
  DocumentCropperService._internal();

  /// Crops and isolates the full prize bond document from [originalImagePath].
  /// Uses [textBlocks] to identify the bounding box of the banknote, or falls back
  /// to the viewfinder area if provided.
  Future<String> cropFullBondDocument({
    required String originalImagePath,
    List<TextBlock>? textBlocks,
    double? viewfinderWidthFraction, // e.g. 0.90
    double? viewfinderHeightFraction, // e.g. 0.35
  }) async {
    try {
      final file = File(originalImagePath);
      if (!await file.exists()) return originalImagePath;

      // Decode the image using compute or directly
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return originalImagePath;

      int cropX = 0;
      int cropY = 0;
      int cropW = image.width;
      int cropH = image.height;

      bool foundDocumentRegion = false;

      // 1. Text-guided document detection with prize bond cluster anchoring
      if (textBlocks != null && textBlocks.isNotEmpty) {
        // Find anchor blocks that are definitely part of the Prize Bond:
        // (7-digit numbers, Bengali characters, or bond keywords)
        TextBlock? anchorBlock;
        for (final block in textBlocks) {
          final t = block.text;
          // Check for serial number (English or Bengali digits) or prize bond keywords
          if (RegExp(r'[0-9০-৯]{5,7}').hasMatch(t) ||
              t.contains('একশত') ||
              t.contains('বাংলাদেশ') ||
              t.contains('টাকা') ||
              t.contains('বন্ড')) {
            anchorBlock = block;
            break;
          }
        }

        // If an anchor was found, filter blocks belonging to the bond cluster
        // (a banknote is ~1.75:1 aspect ratio, so height is roughly 0.55-0.65 of width)
        final bondBlocks = <TextBlock>[];
        if (anchorBlock != null) {
          final anchorCenterY = anchorBlock.boundingBox.center.dy;
          final anchorCenterX = anchorBlock.boundingBox.center.dx;

          // Bangladesh banknote in a standard photo spans at most ~60% of image height
          final maxVerticalDist = image.height * 0.40;
          final maxHorizontalDist = image.width * 0.55;

          for (final block in textBlocks) {
            final box = block.boundingBox;
            if ((box.center.dy - anchorCenterY).abs() <= maxVerticalDist &&
                (box.center.dx - anchorCenterX).abs() <= maxHorizontalDist) {
              bondBlocks.add(block);
            }
          }
        } else {
          bondBlocks.addAll(textBlocks);
        }

        double minX = double.infinity;
        double minY = double.infinity;
        double maxX = 0;
        double maxY = 0;

        int validBlockCount = 0;
        for (final block in bondBlocks) {
          final box = block.boundingBox;
          if (box.width > 0 && box.height > 0) {
            validBlockCount++;
            if (box.left < minX) minX = box.left;
            if (box.top < minY) minY = box.top;
            if (box.right > maxX) maxX = box.right;
            if (box.bottom > maxY) maxY = box.bottom;
          }
        }

        if (validBlockCount >= 1 && maxX > minX && maxY > minY) {
          final textW = maxX - minX;
          final textH = maxY - minY;

          // Prize bonds have text spanning the entire surface (government header at top,
          // 7-digit serial numbers at top-left and bottom-right, denomination in center, signatures at bottom).
          // We add a modest 8-10% margin around the text union to capture the complete banknote with borders
          // without pulling in external keyboards or desks.
          final padX = textW * 0.08;
          final padY = textH * 0.10;

          final docLeft = max(0.0, minX - padX);
          final docTop = max(0.0, minY - padY);
          final docRight = min(image.width.toDouble(), maxX + padX);
          final docBottom = min(image.height.toDouble(), maxY + padY);

          final docW = docRight - docLeft;
          final docH = docBottom - docTop;

          // Only apply if the document region represents a valid banknote region
          if (docW > image.width * 0.20 && docH > image.height * 0.10) {
            cropX = docLeft.round();
            cropY = docTop.round();
            cropW = docW.round();
            cropH = docH.round();
            foundDocumentRegion = true;
          }
        }
      }

      // 2. Viewfinder-guided fallback (if from camera)
      if (!foundDocumentRegion && viewfinderWidthFraction != null && viewfinderHeightFraction != null) {
        final targetW = (image.width * viewfinderWidthFraction).round();
        final targetH = (image.height * viewfinderHeightFraction).round();

        cropX = max(0, (image.width - targetW) ~/ 2);
        cropY = max(0, (image.height - targetH) ~/ 2);
        cropW = min(image.width - cropX, targetW);
        cropH = min(image.height - cropY, targetH);
        foundDocumentRegion = true;
      }

      // 3. Fallback for portrait camera captures containing a horizontal banknote in the center
      if (!foundDocumentRegion) {
        if (image.height > image.width * 1.2) {
          // Portrait phone capture: banknote is horizontally centered
          cropX = (image.width * 0.05).round();
          cropW = (image.width * 0.90).round();
          cropH = (cropW / 1.75).round(); // standard ~1.75:1 banknote ratio
          cropY = max(0, (image.height - cropH) ~/ 2);
          foundDocumentRegion = true;
        }
      }

      // If document region matches almost entire image, return original
      if (cropW >= image.width * 0.96 && cropH >= image.height * 0.96) {
        return originalImagePath;
      }

      // Perform crop
      final cropped = img.copyCrop(
        image,
        x: max(0, cropX),
        y: max(0, cropY),
        width: min(image.width - max(0, cropX), cropW),
        height: min(image.height - max(0, cropY), cropH),
      );

      // Save cropped document image
      final appDir = await getApplicationDocumentsDirectory();
      final bondsDir = Directory('${appDir.path}/bonds');
      if (!await bondsDir.exists()) {
        await bondsDir.create(recursive: true);
      }

      final outPath = '${bondsDir.path}/bond_doc_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outFile = File(outPath);
      await outFile.writeAsBytes(img.encodeJpg(cropped, quality: 88));

      return outPath;
    } catch (e) {
      debugPrint('DocumentCropperService error: $e');
      return originalImagePath;
    }
  }
}
