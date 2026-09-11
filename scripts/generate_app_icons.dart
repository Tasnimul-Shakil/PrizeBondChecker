import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final logoFile = File('assets/images/app_logo.png');
  if (!logoFile.existsSync()) {
    print('Logo file not found!');
    return;
  }

  final image = img.decodeImage(logoFile.readAsBytesSync());
  if (image == null) {
    print('Failed to decode image');
    return;
  }

  final sizes = {
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  };

  for (final entry in sizes.entries) {
    final resized = img.copyResize(image, width: entry.value, height: entry.value, interpolation: img.Interpolation.linear);
    final outFile = File(entry.key);
    outFile.parent.createSync(recursive: true);
    outFile.writeAsBytesSync(img.encodePng(resized));
    print('Generated ${entry.key} (${entry.value}x${entry.value})');
  }

  print('All Android mipmap icons successfully updated!');
}
