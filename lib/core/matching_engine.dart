import '../models/bond.dart';
import '../models/draw.dart';

/// Inverted entry pointing a 7-digit serial to its specific draw and tier.
class _WinningEntry {
  final int drawNumber;
  final DateTime drawDate;
  final int tier;
  final String tierName;
  final String tierNameBn;
  final double amount;
  final bool isClaimable;

  _WinningEntry({
    required this.drawNumber,
    required this.drawDate,
    required this.tier,
    required this.tierName,
    required this.tierNameBn,
    required this.amount,
    required this.isClaimable,
  });
}

/// High-performance O(1) matching engine for Bangladesh Prize Bonds.
///
/// Under Bangladesh Bank rules:
/// 1. Draws are strictly series-agnostic (the 7-digit number alone decides the winner).
/// 2. Claims are valid for 2 years (last 8 quarterly draws).
///
/// This engine pre-indexes all winning numbers into a hash map so any bond
/// or batch of bonds can be checked instantaneously in O(1) time per bond.
class MatchingEngine {
  final Map<String, List<_WinningEntry>> _invertedIndex = {};
  List<Draw> _activeDraws = [];
  DateTime? _referenceDate;

  MatchingEngine([List<Draw>? draws, DateTime? referenceDate]) {
    _referenceDate = referenceDate;
    if (draws != null) {
      loadDraws(draws, referenceDate: referenceDate);
    }
  }

  /// Rebuilds the inverted hash table index from the list of [draws].
  /// By default, filters for draws within the 2-year legal window.
  void loadDraws(List<Draw> draws, {DateTime? referenceDate, bool filterExpired = true}) {
    _referenceDate = referenceDate ?? _referenceDate ?? DateTime.now();
    _invertedIndex.clear();
    _activeDraws = List.from(draws);

    final twoYearsAgo = DateTime(
      _referenceDate!.year - 2,
      _referenceDate!.month,
      _referenceDate!.day,
    );

    for (final draw in draws) {
      final isClaimable = !draw.drawDate.isBefore(twoYearsAgo);

      if (filterExpired && !isClaimable) {
        // Skip draws older than 2 years if filtering expired draws
        continue;
      }

      for (final prize in draw.prizes) {
        for (final number in prize.winningNumbers) {
          final cleanNumber = number.trim().padLeft(7, '0');

          final entry = _WinningEntry(
            drawNumber: draw.drawNumber,
            drawDate: draw.drawDate,
            tier: prize.tier,
            tierName: prize.name,
            tierNameBn: prize.nameBn,
            amount: prize.amount,
            isClaimable: isClaimable,
          );

          _invertedIndex.putIfAbsent(cleanNumber, () => []).add(entry);
        }
      }
    }
  }

  /// Returns the flattened HashSet of all active winning 7-digit numbers for instant O(1) set membership.
  Set<String> get winningNumbersSet => _invertedIndex.keys.toSet();

  /// Instant O(1) boolean check if a serial is present in any active draw.
  bool isWinningNumber(String serialNumber) {
    final clean = serialNumber.trim().padLeft(7, '0');
    return _invertedIndex.containsKey(clean);
  }

  /// O(1) lookup to check if a specific [bond] is a winner in any loaded draw.
  /// Returns a list of matches (a bond might theoretically win in multiple draws across 2 years).
  List<PrizeMatchResult> checkBond(Bond bond) {
    final cleanSerial = bond.serialNumber.trim().padLeft(7, '0');
    final entries = _invertedIndex[cleanSerial];

    if (entries == null || entries.isEmpty) {
      return [];
    }

    return entries.map((entry) {
      return PrizeMatchResult(
        bond: bond,
        drawNumber: entry.drawNumber,
        drawDate: entry.drawDate,
        tier: entry.tier,
        tierName: entry.tierName,
        tierNameBn: entry.tierNameBn,
        prizeAmount: entry.amount,
        isClaimable: entry.isClaimable,
      );
    }).toList();
  }

  /// O(1) lookup by raw 7-digit serial number string.
  List<PrizeMatchResult> checkSerialString(String serialNumber, {String? series}) {
    final tempBond = Bond(
      serialNumber: serialNumber.trim().padLeft(7, '0'),
      seriesPrefix: series,
    );
    return checkBond(tempBond);
  }

  /// O(N) batch checker across [bonds].
  /// Returns a [WalletMatchSummary] with aggregated winning statistics.
  WalletMatchSummary checkAllBonds(List<Bond> bonds) {
    final winningBonds = <Bond>[];
    final allMatches = <PrizeMatchResult>[];
    double totalWonAmount = 0;

    for (final bond in bonds) {
      final matches = checkBond(bond);
      if (matches.isNotEmpty) {
        winningBonds.add(bond);
        allMatches.addAll(matches);
        for (final m in matches) {
          totalWonAmount += m.prizeAmount;
        }
      }
    }

    return WalletMatchSummary(
      totalBondsCount: bonds.length,
      winningBondsCount: winningBonds.length,
      totalPrizeAmount: totalWonAmount,
      winningMatches: allMatches,
      winningBonds: winningBonds,
      checkedDrawsCount: _activeDraws.length,
    );
  }

  /// Total unique winning numbers indexed.
  int get indexedNumbersCount => _invertedIndex.length;

  /// Returns true if the index has been built with draws.
  bool get isReady => _invertedIndex.isNotEmpty;
}

/// Summary report returned when evaluating an entire user bond collection.
class WalletMatchSummary {
  final int totalBondsCount;
  final int winningBondsCount;
  final double totalPrizeAmount;
  final List<PrizeMatchResult> winningMatches;
  final List<Bond> winningBonds;
  final int checkedDrawsCount;

  WalletMatchSummary({
    required this.totalBondsCount,
    required this.winningBondsCount,
    required this.totalPrizeAmount,
    required this.winningMatches,
    required this.winningBonds,
    required this.checkedDrawsCount,
  });

  /// Total portfolio investment (৳100 per bond)
  int get totalInvestmentValue => totalBondsCount * 100;

  /// Net prize money after 20% Bangladesh NBR tax
  double get netPrizeAmount => totalPrizeAmount * 0.80;

  /// Return on investment percentage
  double get roiPercentage => totalInvestmentValue > 0
      ? (totalPrizeAmount / totalInvestmentValue) * 100
      : 0.0;
}
