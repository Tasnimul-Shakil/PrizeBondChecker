import 'package:flutter_test/flutter_test.dart';
import 'package:prize_bond_checker/core/digit_normalizer.dart';

void main() {
  group('Range Generator Logic Tests', () {
    test('Generates sequential serial numbers with zero-padding', () {
      const start = '0000008';
      const end = '0000012';

      final startInt = int.parse(DigitNormalizer.normalizeSerial(start)!);
      final endInt = int.parse(DigitNormalizer.normalizeSerial(end)!);

      final generated = <String>[];
      for (int i = startInt; i <= endInt; i++) {
        generated.add(i.toString().padLeft(7, '0'));
      }

      expect(generated.length, equals(5));
      expect(generated, equals(['0000008', '0000009', '0000010', '0000011', '0000012']));
    });

    test('Validates sequential range bounds', () {
      final start = DigitNormalizer.normalizeSerial('0154250');
      final end = DigitNormalizer.normalizeSerial('0154200');

      final startInt = int.parse(start!);
      final endInt = int.parse(end!);

      // Start is greater than end -> should be invalid
      expect(startInt > endInt, isTrue);
    });
  });
}
