import 'bond.dart';

/// Details of an individual prize category in a draw (1st through 5th).
class PrizeTier {
  final int tier; // 1 to 5
  final String name; // e.g. "1st Prize"
  final String nameBn; // e.g. "১ম পুরস্কার"
  final double amount; // e.g. 600000
  final int count; // 1, 1, 2, 2, or 40
  final List<String> winningNumbers; // 7-digit formatted strings

  PrizeTier({
    required this.tier,
    required this.name,
    required this.nameBn,
    required this.amount,
    required this.count,
    required this.winningNumbers,
  });

  factory PrizeTier.fromJson(Map<String, dynamic> json) {
    return PrizeTier(
      tier: json['tier'] as int,
      name: json['name'] as String,
      nameBn: json['nameBn'] as String? ?? '',
      amount: (json['amount'] as num).toDouble(),
      count: json['count'] as int? ?? 1,
      winningNumbers: (json['winningNumbers'] as List<dynamic>)
          .map((e) => e.toString().trim().padLeft(7, '0'))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tier': tier,
      'name': name,
      'nameBn': nameBn,
      'amount': amount,
      'count': count,
      'winningNumbers': winningNumbers,
    };
  }
}

/// Represents one official quarterly draw conducted by Bangladesh Bank.
class Draw {
  final int drawNumber; // e.g. 119
  final DateTime drawDate; // e.g. 2026-07-31
  final List<PrizeTier> prizes;

  Draw({
    required this.drawNumber,
    required this.drawDate,
    required this.prizes,
  });

  factory Draw.fromJson(Map<String, dynamic> json) {
    final drawNum = (json['draw_no'] ?? json['drawNumber']) as int;
    final dateStr = (json['draw_date'] ?? json['drawDate']) as String;
    final parsedDate = DateTime.parse(dateStr);

    List<PrizeTier> parsedPrizes = [];

    final rawPrizes = json['prizes'];
    if (rawPrizes is Map) {
      final prizesMap = Map<String, dynamic>.from(rawPrizes);

      void addTier(int tier, String key, String name, String nameBn, double amount, int count) {
        if (prizesMap.containsKey(key)) {
          final list = (prizesMap[key] as List<dynamic>)
              .map((e) => e.toString().trim().padLeft(7, '0'))
              .toList();
          parsedPrizes.add(PrizeTier(
            tier: tier,
            name: name,
            nameBn: nameBn,
            amount: amount,
            count: count,
            winningNumbers: list,
          ));
        }
      }

      addTier(1, '1st', '1st Prize', '১ম পুরস্কার', 600000.0, 1);
      addTier(2, '2nd', '2nd Prize', '২য় পুরস্কার', 325000.0, 1);
      addTier(3, '3rd', '3rd Prize', '৩য় পুরস্কার', 100000.0, 2);
      addTier(4, '4th', '4th Prize', '৪র্থ পুরস্কার', 50000.0, 2);
      addTier(5, '5th', '5th Prize', '৫ম পুরস্কার', 10000.0, 40);
    } else if (rawPrizes is List) {
      parsedPrizes = rawPrizes
          .map((p) => PrizeTier.fromJson(p as Map<String, dynamic>))
          .toList();
    }

    return Draw(
      drawNumber: drawNum,
      drawDate: parsedDate,
      prizes: parsedPrizes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'draw_no': drawNumber,
      'draw_date': drawDate.toIso8601String().substring(0, 10),
      'prizes': {
        for (var tier in prizes)
          _tierKey(tier.tier): tier.winningNumbers,
      },
    };
  }

  static String _tierKey(int tier) {
    switch (tier) {
      case 1:
        return '1st';
      case 2:
        return '2nd';
      case 3:
        return '3rd';
      case 4:
        return '4th';
      case 5:
        return '5th';
      default:
        return '${tier}th';
    }
  }

  /// Total number of winning numbers in this draw (standard: 46)
  int get totalWinnersCount =>
      prizes.fold(0, (sum, tier) => sum + tier.winningNumbers.length);

  /// Checks if this draw is within the legal 2-year claim window from [referenceDate].
  bool isWithinLegalWindow([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final twoYearsAgo = DateTime(now.year - 2, now.month, now.day);
    return drawDate.isAfter(twoYearsAgo);
  }
}

/// Represents a winning match between a user's bond and an official draw.
class PrizeMatchResult {
  final Bond bond;
  final int drawNumber;
  final DateTime drawDate;
  final int tier;
  final String tierName;
  final String tierNameBn;
  final double prizeAmount;
  final bool isClaimable;

  PrizeMatchResult({
    required this.bond,
    required this.drawNumber,
    required this.drawDate,
    required this.tier,
    required this.tierName,
    required this.tierNameBn,
    required this.prizeAmount,
    required this.isClaimable,
  });

  /// 20% source tax deducted under Bangladesh National Board of Revenue (NBR) rules
  double get taxDeduction => prizeAmount * 0.20;

  /// Net amount payable to the winner after 20% tax
  double get netPrizeAmount => prizeAmount - taxDeduction;

  @override
  String toString() =>
      'PrizeMatchResult(bond: ${bond.serialNumber}, tier: $tierName, amount: ৳$prizeAmount, draw: #$drawNumber)';
}

/// Root data model representing the remote JSON payload from the draw API.
class DrawsPayload {
  final String lastUpdated;
  final int latestDrawNo;
  final List<Draw> draws;

  DrawsPayload({
    required this.lastUpdated,
    required this.latestDrawNo,
    required this.draws,
  });

  factory DrawsPayload.fromJson(Map<String, dynamic> json) {
    final rawDraws = (json['draws'] as List<dynamic>? ?? []);
    final parsedDraws = rawDraws
        .map((e) => Draw.fromJson(e as Map<String, dynamic>))
        .toList();

    parsedDraws.sort((a, b) => b.drawNumber.compareTo(a.drawNumber));

    final latestNo = json['latest_draw_no'] as int? ??
        (parsedDraws.isNotEmpty ? parsedDraws.first.drawNumber : 0);

    final updated = json['last_updated'] as String? ??
        json['updatedAt'] as String? ??
        DateTime.now().toIso8601String().substring(0, 10);

    return DrawsPayload(
      lastUpdated: updated,
      latestDrawNo: latestNo,
      draws: parsedDraws,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'last_updated': lastUpdated,
      'latest_draw_no': latestDrawNo,
      'draws': draws.map((d) => d.toJson()).toList(),
    };
  }
}
