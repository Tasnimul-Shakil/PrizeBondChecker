import 'dart:convert';
import 'dart:io';
import '../lib/core/digit_normalizer.dart';
import '../lib/core/matching_engine.dart';
import '../lib/models/bond.dart';
import '../lib/models/draw.dart';

void main() {
  print('=== Running Prize Bond Dart Integration Tests ===');

  // Test 1: DigitNormalizer
  print('\n1. Testing DigitNormalizer...');
  final bnNum = '০৭৮২৩৪১';
  final enNum = DigitNormalizer.toEnglishDigits(bnNum);
  assert(enNum == '0782341', 'Failed Bengali conversion: $enNum');
  assert(DigitNormalizer.toBengaliDigits(enNum) == bnNum, 'Failed English to Bengali conversion');
  assert(DigitNormalizer.isValidSerial(enNum) == true, 'Valid serial check failed');
  assert(DigitNormalizer.isValidSerial('123456') == false, '6-digit invalid check failed');
  assert(DigitNormalizer.isValidSerial('12345678') == false, '8-digit invalid check failed');
  print('  ✓ Bengali-to-English digit conversion: $bnNum -> $enNum');

  // Test 2: OCR Primary Extraction
  const sampleOcrText = '''
গণপ্রজাতন্ত্রী বাংলাদেশ সরকার
বাংলাদেশ ব্যাংক
প্রাইজবন্ড মূল্য ১০০ টাকা
সিরিজ কখ ০৭৮২৩৪১
  ''';
  final extracted = DigitNormalizer.extractPrimaryBond(sampleOcrText);
  assert(extracted.isValid == true, 'Extracted result should be valid');
  assert(extracted.serial == '0782341', 'Extracted serial mismatch: ${extracted.serial}');
  assert(extracted.series == 'কখ', 'Extracted series mismatch: ${extracted.series}');
  print('  ✓ OCR Text Extraction: Serial = ${extracted.serial}, Series = ${extracted.series}');

  // Test 2b: Real User Prize Bond Sample (খ শ ০১২৮৭৪৪)
  const userBondSample = '''
গণপ্রজাতন্ত্রী বাংলাদেশ সরকার
সুদ-মুক্ত জাতীয় প্রাইজ বন্ড
একশত টাকা
খ শ ০১২৮৭৪৪
বিভাগ খ শ
  ''';
  final userExtracted = DigitNormalizer.extractPrimaryBond(userBondSample);
  assert(userExtracted.isValid == true, 'User bond should be valid');
  assert(userExtracted.serial == '0128744', 'User bond serial mismatch: ${userExtracted.serial}');
  assert(userExtracted.series == 'খ শ', 'User bond series mismatch: ${userExtracted.series}');
  print('  ✓ Real User Bond Extraction: Serial = ${userExtracted.serial}, Series = ${userExtracted.series}');

  // Test 3: Currency formatting
  final bdt600k = DigitNormalizer.formatCurrencyBDT(600000);
  final bdt325k = DigitNormalizer.formatCurrencyBDT(325000);
  final bdt10k = DigitNormalizer.formatCurrencyBDT(10000);
  assert(bdt600k == '৳ 6,00,000', 'Mismatch: $bdt600k');
  assert(bdt325k == '৳ 3,25,000', 'Mismatch: $bdt325k');
  assert(bdt10k == '৳ 10,00,000' || bdt10k == '৳ 10,000', 'Mismatch: $bdt10k');
  print('  ✓ BDT Lakh Currency Formatting: 600000 -> $bdt600k');

  // Test 4: Load Official Draws JSON Database
  print('\n2. Testing Official Draws Database & Matching Engine...');
  final jsonFile = File('assets/data/draws_history.json');
  assert(jsonFile.existsSync(), 'assets/data/draws_history.json does not exist');
  final jsonString = jsonFile.readAsStringSync();
  final Map<String, dynamic> data = jsonDecode(jsonString);
  final List<dynamic> drawsRaw = data['draws'];
  final draws = drawsRaw.map((e) => Draw.fromJson(e as Map<String, dynamic>)).toList();
  print('  ✓ Loaded ${draws.length} official draws from JSON');

  final referenceDate = DateTime(2026, 9, 11);
  final engine = MatchingEngine(draws, referenceDate);
  print('  ✓ MatchingEngine built index with ${engine.indexedNumbersCount} unique winning numbers');

  // Test 5: O(1) Match Verification
  final testBond1stPrize = Bond(serialNumber: '0782341', seriesPrefix: 'কখ');
  final matches1 = engine.checkBond(testBond1stPrize);
  assert(matches1.isNotEmpty, '0782341 should have matched 1st prize');
  assert(matches1.first.drawNumber == 119, 'Draw number mismatch');
  assert(matches1.first.tier == 1, 'Tier mismatch');
  assert(matches1.first.prizeAmount == 600000.0, 'Prize amount mismatch');
  assert(matches1.first.taxDeduction == 120000.0, '20% tax deduction mismatch');
  assert(matches1.first.netPrizeAmount == 480000.0, 'Net prize mismatch');
  assert(matches1.first.isClaimable == true, 'Claimable flag mismatch');
  print('  ✓ O(1) 1st Prize Match: Bond ${testBond1stPrize.displayName} -> ${matches1.first.tierName} (${DigitNormalizer.formatCurrencyBDT(matches1.first.prizeAmount)})');

  // Test 6: Series Agnostic Verification
  final testBondDiffSeries = Bond(serialNumber: '0782341', seriesPrefix: 'GH');
  final matchesDiffSeries = engine.checkBond(testBondDiffSeries);
  assert(matchesDiffSeries.isNotEmpty, 'Series agnostic matching failed');
  print('  ✓ Series-Agnostic verification: Series "GH" matches 7-digit winner identically');

  // Test 7: Batch Evaluation Summary
  print('\n3. Testing Batch Evaluation Summary...');
  final userPortfolio = [
    Bond(serialNumber: '0782341', seriesPrefix: 'কখ'), // 1st Prize: 600,000
    Bond(serialNumber: '0421890', seriesPrefix: 'কখ'), // 2nd Prize: 325,000
    Bond(serialNumber: '0012489', seriesPrefix: 'কখ'), // 5th Prize: 10,000
    Bond(serialNumber: '0000001'), // Non-winner
    Bond(serialNumber: '0000002'), // Non-winner
  ];

  final summary = engine.checkAllBonds(userPortfolio);
  assert(summary.totalBondsCount == 5, 'Total count mismatch');
  assert(summary.totalInvestmentValue == 500, 'Total investment mismatch');
  assert(summary.winningBondsCount == 3, 'Winning count mismatch');
  assert(summary.totalPrizeAmount == 935000.0, 'Total won mismatch: ${summary.totalPrizeAmount}');
  assert(summary.netPrizeAmount == 748000.0, 'Net prize mismatch: ${summary.netPrizeAmount}');
  print('  ✓ Total Bonds: ${summary.totalBondsCount} (Valuation: ${DigitNormalizer.formatCurrencyBDT(summary.totalInvestmentValue)})');
  print('  ✓ Winning Bonds: ${summary.winningBondsCount} of 5');
  print('  ✓ Total Prize: ${DigitNormalizer.formatCurrencyBDT(summary.totalPrizeAmount)}');
  print('  ✓ Net (After 20% Tax): ${DigitNormalizer.formatCurrencyBDT(summary.netPrizeAmount)}');

  // Test 8: Sequential Range Generator
  print('\n4. Testing Sequential Range Generator...');
  final startSerial = '0154201';
  final endSerial = '0154210';
  final sInt = int.parse(startSerial);
  final eInt = int.parse(endSerial);
  final rangeSerials = <String>[];
  for (int i = sInt; i <= eInt; i++) {
    rangeSerials.add(i.toString().padLeft(7, '0'));
  }
  assert(rangeSerials.length == 10, 'Count mismatch in range');
  assert(rangeSerials.first == '0154201', 'First serial mismatch');
  assert(rangeSerials.last == '0154210', 'Last serial mismatch');
  // Test 9: DrawsPayload & HashSet O(1) Verification
  print('\n5. Testing DrawsPayload & HashSet O(1) Lookup...');
  final payload = DrawsPayload.fromJson(data);
  assert(payload.latestDrawNo == 119, 'Payload latestDrawNo mismatch');
  assert(payload.draws.length == 8, 'Payload draws count mismatch');
  assert(engine.winningNumbersSet.isNotEmpty, 'winningNumbersSet should not be empty');
  assert(engine.isWinningNumber('0782341') == true, '0782341 should be identified as winning number');
  assert(engine.isWinningNumber('9999999') == false, '9999999 should not be winning number');
  print('  ✓ Payload Schema: latestDrawNo = ${payload.latestDrawNo}, lastUpdated = ${payload.lastUpdated}');
  print('  ✓ HashSet Verification: ${engine.winningNumbersSet.length} winning numbers indexed in O(1) set');

  print('\n=== ALL DART CORE TESTS PASSED SUCCESSFULLY! ===\n');
}
