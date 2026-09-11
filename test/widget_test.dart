import 'package:flutter_test/flutter_test.dart';
import 'package:prize_bond_checker/core/digit_normalizer.dart';
import 'package:prize_bond_checker/models/bond.dart';

void main() {
  test('DigitNormalizer converts Bengali digits and normalizes 7-digit numbers', () {
    expect(DigitNormalizer.toEnglishDigits('০৭৮৬৩৪৫'), '0786345');
    expect(DigitNormalizer.normalizeSerial('০৭৮৬৩৪৫'), '0786345');
    expect(DigitNormalizer.toBengaliDigits('0786345'), '০৭৮৬৩৪৫');
    expect(DigitNormalizer.isValidSerial('0786345'), isTrue);
    expect(DigitNormalizer.isValidSerial('12345'), isFalse);
  });

  test('Bond model displays 7-digit serial number', () {
    final bond = Bond(serialNumber: '0786345');
    expect(bond.displayName, '0786345');
    expect(bond.denomination, 100);
  });
}
