import 'package:flutter_test/flutter_test.dart';
import 'package:prize_bond_checker/core/digit_normalizer.dart';

void main() {
  group('DigitNormalizer Tests', () {
    test('Converts Bengali numerals to English digits', () {
      expect(DigitNormalizer.toEnglishDigits('০১২৩৪৫৬৭৮৯'), equals('0123456789'));
      expect(DigitNormalizer.toEnglishDigits('সিরিজ কখ ০৭৮২৩৪১'), equals('সিরিজ কখ 0782341'));
      expect(DigitNormalizer.toEnglishDigits('৳ ১০০ টাকা'), equals('৳ 100 টাকা'));
    });

    test('Converts English numerals to Bengali digits', () {
      expect(DigitNormalizer.toBengaliDigits('0123456789'), equals('০১২৩৪৫৬৭৮৯'));
      expect(DigitNormalizer.toBengaliDigits('0782341'), equals('০৭৮২৩৪১'));
    });

    test('Validates and normalizes 7-digit serial numbers', () {
      expect(DigitNormalizer.normalizeSerial('0782341'), equals('0782341'));
      expect(DigitNormalizer.normalizeSerial('০৭৮২৩৪১'), equals('0782341'));
      expect(DigitNormalizer.normalizeSerial('  0782341  '), equals('0782341'));
      // Zero-padding for serials missing leading zeros
      expect(DigitNormalizer.normalizeSerial('782341'), equals('0782341'));
      expect(DigitNormalizer.normalizeSerial('1234'), equals('0001234'));
      // Invalid lengths (e.g. 8 digits or empty)
      expect(DigitNormalizer.normalizeSerial('12345678'), isNull);
      expect(DigitNormalizer.normalizeSerial(''), isNull);
    });

    test('Extracts primary bond serial and series prefix from OCR text', () {
      const sampleOcrBengali = 'বাংলাদেশ ব্যাংক\nপ্রাইজবন্ড ১০০ টাকা\nসিরিজ কখ ০৭৮২৩৪১';
      final result1 = DigitNormalizer.extractPrimaryBond(sampleOcrBengali);
      expect(result1.isValid, isTrue);
      expect(result1.serial, equals('0782341'));
      expect(result1.series, equals('কখ'));

      const sampleOcrEnglish = 'BANGLADESH BANK\nPRIZE BOND TK 100\nSERIES KA 0421890';
      final result2 = DigitNormalizer.extractPrimaryBond(sampleOcrEnglish);
      expect(result2.isValid, isTrue);
      expect(result2.serial, equals('0421890'));
      expect(result2.series, equals('KA'));

      // Real user prize bond sample:
      const sampleUserBond = 'গণপ্রজাতন্ত্রী বাংলাদেশ সরকার\nসুদ-মুক্ত জাতীয় প্রাইজ বন্ড\nএকশত টাকা\nখ শ ০১২৮৭৪৪\nবিভাগ খ শ';
      final result3 = DigitNormalizer.extractPrimaryBond(sampleUserBond);
      expect(result3.isValid, isTrue);
      expect(result3.serial, equals('0128744'));
      expect(result3.series, equals('খ শ'));
    });

    test('Formats BDT currency with Lakh/Crore grouping', () {
      expect(DigitNormalizer.formatCurrencyBDT(600000), equals('৳ 6,00,000'));
      expect(DigitNormalizer.formatCurrencyBDT(325000), equals('৳ 3,25,000'));
      expect(DigitNormalizer.formatCurrencyBDT(10000), equals('৳ 10,000'));
      expect(DigitNormalizer.formatCurrencyBDT(100), equals('৳ 100'));
      expect(DigitNormalizer.formatCurrencyBDT(600000, bengali: true), equals('৳ ৬,০০,০০০'));
    });
  });
}
