import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final logoFile = File('assets/images/app_logo.png');
  if (!logoFile.existsSync()) {
    print('Logo file not found!');
    return;
  }

  final croppedLogo = img.decodeImage(logoFile.readAsBytesSync())!;
  print('Cropped logo size: ${croppedLogo.width}x${croppedLogo.height}');

  final sizes = {
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  };

  // Gradient colors for background:
  // Top: #147A76 -> r=20, g=122, b=118
  // Bottom: #175475 -> r=23, g=84, b=117
  const topR = 20, topG = 122, topB = 118;
  const botR = 23, botG = 84, botB = 117;

  for (final entry in sizes.entries) {
    final size = entry.value;
    final square = img.Image(width: size, height: size, numChannels: 4);

    // 1. Fill square with vertical gradient
    for (int y = 0; y < size; y++) {
      final t = y / size;
      final r = (topR + (botR - topR) * t).round();
      final g = (topG + (botG - topG) * t).round();
      final b = (topB + (botB - topB) * t).round();
      for (int x = 0; x < size; x++) {
        square.setPixelRgba(x, y, r, g, b, 255);
      }
    }

    // 2. Scale logo to fit nicely with small margin (about 88% of icon size)
    final targetContentSize = (size * 0.88).round();
    final scale = targetContentSize / (croppedLogo.width > croppedLogo.height ? croppedLogo.width : croppedLogo.height);
    final scaledW = (croppedLogo.width * scale).round();
    final scaledH = (croppedLogo.height * scale).round();

    final resizedLogo = img.copyResize(
      croppedLogo,
      width: scaledW,
      height: scaledH,
      interpolation: img.Interpolation.linear,
    );

    // 3. Center composite onto gradient square
    final offsetX = (size - scaledW) ~/ 2;
    final offsetY = (size - scaledH) ~/ 2;

    img.compositeImage(
      square,
      resizedLogo,
      dstX: offsetX,
      dstY: offsetY,
    );

    // 4. Save to destination
    final outFile = File(entry.key);
    outFile.parent.createSync(recursive: true);
    outFile.writeAsBytesSync(img.encodePng(square));
    print('Generated full-bleed icon ${entry.key} (${size}x$size)');
  }

  // Also create foreground icon for adaptive icons (432x432 for xxxhdpi)
  final adaptiveForeground = img.Image(width: 432, height: 432, numChannels: 4);
  // Clear transparent
  for (int y = 0; y < 432; y++) {
    for (int x = 0; x < 432; x++) {
      adaptiveForeground.setPixelRgba(x, y, 0, 0, 0, 0);
    }
  }
  // Adaptive icon safe zone is 264x264 in center of 432x432
  final adaptScale = 270 / (croppedLogo.width > croppedLogo.height ? croppedLogo.width : croppedLogo.height);
  final adaptW = (croppedLogo.width * adaptScale).round();
  final adaptH = (croppedLogo.height * adaptScale).round();
  final resizedAdapt = img.copyResize(croppedLogo, width: adaptW, height: adaptH, interpolation: img.Interpolation.linear);
  img.compositeImage(
    adaptiveForeground,
    resizedAdapt,
    dstX: (432 - adaptW) ~/ 2,
    dstY: (432 - adaptH) ~/ 2,
  );

  final fgFile = File('android/app/src/main/res/drawable/ic_launcher_foreground.png');
  fgFile.parent.createSync(recursive: true);
  fgFile.writeAsBytesSync(img.encodePng(adaptiveForeground));
  print('Generated adaptive foreground icon (432x432)');

  print('All full-bleed app icons generated successfully!');
}
