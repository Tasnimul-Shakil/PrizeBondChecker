import 'package:flutter_test/flutter_test.dart';
import 'package:prize_bond_checker/core/matching_engine.dart';
import 'package:prize_bond_checker/models/bond.dart';
import 'package:prize_bond_checker/models/draw.dart';

void main() {
  group('MatchingEngine Tests', () {
    late MatchingEngine engine;
    late List<Draw> mockDraws;
    final referenceDate = DateTime(2026, 9, 11);

    setUp(() {
      mockDraws = [
        // Draw 119 (Eligible, recent)
        Draw(
          drawNumber: 119,
          drawDate: DateTime(2026, 7, 31),
          prizes: [
            PrizeTier(
              tier: 1,
              name: '1st Prize',
              nameBn: '১ম পুরস্কার',
              amount: 600000,
              count: 1,
              winningNumbers: ['0782341'],
            ),
            PrizeTier(
              tier: 2,
              name: '2nd Prize',
              nameBn: '২য় পুরস্কার',
              amount: 325000,
              count: 1,
              winningNumbers: ['0421890'],
            ),
            PrizeTier(
              tier: 5,
              name: '5th Prize',
              nameBn: '৫ম পুরস্কার',
              amount: 10000,
              count: 2,
              winningNumbers: ['0012489', '0034821'],
            ),
          ],
        ),
        // Draw 105 (Expired, > 2 years ago)
        Draw(
          drawNumber: 105,
          drawDate: DateTime(2023, 1, 31),
          prizes: [
            PrizeTier(
              tier: 1,
              name: '1st Prize',
              nameBn: '১ম পুরস্কার',
              amount: 600000,
              count: 1,
              winningNumbers: ['0999999'],
            ),
          ],
        ),
      ];

      engine = MatchingEngine(mockDraws, referenceDate);
    });

    test('Indexes eligible winning numbers and filters expired draws', () {
      // 0782341 (1st), 0421890 (2nd), 0012489, 0034821 (5th) should be indexed
      expect(engine.indexedNumbersCount, equals(4));

      // Expired draw number 0999999 should NOT be indexed when filterExpired is true
      final expiredMatches = engine.checkSerialString('0999999');
      expect(expiredMatches, isEmpty);
    });

    test('Matches 1st Prize in O(1) time and verifies series-agnostic property', () {
      // Series-agnostic: Any series with '0782341' wins
      final bondBengaliSeries = Bond(serialNumber: '0782341', seriesPrefix: 'কখ');
      final bondEnglishSeries = Bond(serialNumber: '0782341', seriesPrefix: 'KA');
      final bondNoSeries = Bond(serialNumber: '0782341');

      final matches1 = engine.checkBond(bondBengaliSeries);
      final matches2 = engine.checkBond(bondEnglishSeries);
      final matches3 = engine.checkBond(bondNoSeries);

      expect(matches1.length, equals(1));
      expect(matches2.length, equals(1));
      expect(matches3.length, equals(1));

      final match = matches1.first;
      expect(match.drawNumber, equals(119));
      expect(match.tier, equals(1));
      expect(match.prizeAmount, equals(600000));
      expect(match.taxDeduction, equals(120000)); // 20%
      expect(match.netPrizeAmount, equals(480000));
      expect(match.isClaimable, isTrue);
    });

    test('Batch verification calculates total investment, wins, and tax', () {
      final userBonds = [
        Bond(serialNumber: '0782341'), // 1st Prize: 600,000
        Bond(serialNumber: '0012489'), // 5th Prize: 10,000
        Bond(serialNumber: '0000001'), // Non-winner
        Bond(serialNumber: '0000002'), // Non-winner
      ];

      final summary = engine.checkAllBonds(userBonds);
      expect(summary.totalBondsCount, equals(4));
      expect(summary.totalInvestmentValue, equals(400)); // 4 * ৳100
      expect(summary.winningBondsCount, equals(2));
      expect(summary.totalPrizeAmount, equals(610000));
      expect(summary.netPrizeAmount, equals(488000)); // after 20% NBR tax
    });
  });
}
