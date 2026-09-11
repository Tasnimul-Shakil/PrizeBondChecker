import 'dart:math';

/// Represents a physical ৳100 Bangladesh Prize Bond stored in the user's wallet.
class Bond {
  static final Random _random = Random();

  final String id;
  final String serialNumber; // 7-digit string (e.g. "0123456")
  final String? seriesPrefix; // e.g. "কখ", "ঘঙ", "KA"
  final String? imagePath; // Local path to photo/scanned image of the bond
  final DateTime createdAt;
  final String? batchId;
  final List<String> tags;
  final String? notes;

  Bond({
    String? id,
    required this.serialNumber,
    this.seriesPrefix,
    this.imagePath,
    DateTime? createdAt,
    this.batchId,
    List<String>? tags,
    this.notes,
  })  : id = id ??
            'bond_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(100000)}',
        createdAt = createdAt ?? DateTime.now(),
        tags = tags ?? [];

  /// Full display string e.g. "0123456" or "কখ 0123456"
  String get displayName {
    if (seriesPrefix != null && seriesPrefix!.trim().isNotEmpty) {
      return '${seriesPrefix!.trim()} $serialNumber';
    }
    return serialNumber;
  }

  /// Denomination of Bangladesh Prize Bonds is always ৳100
  int get denomination => 100;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serialNumber': serialNumber,
      'seriesPrefix': seriesPrefix,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
      'batchId': batchId,
      'tags': tags,
      'notes': notes,
    };
  }

  factory Bond.fromJson(Map<String, dynamic> json) {
    return Bond(
      id: json['id'] as String?,
      serialNumber: json['serialNumber'] as String,
      seriesPrefix: json['seriesPrefix'] as String?,
      imagePath: json['imagePath'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      batchId: json['batchId'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      notes: json['notes'] as String?,
    );
  }

  Bond copyWith({
    String? id,
    String? serialNumber,
    String? seriesPrefix,
    String? imagePath,
    DateTime? createdAt,
    String? batchId,
    List<String>? tags,
    String? notes,
  }) {
    return Bond(
      id: id ?? this.id,
      serialNumber: serialNumber ?? this.serialNumber,
      seriesPrefix: seriesPrefix ?? this.seriesPrefix,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      batchId: batchId ?? this.batchId,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bond &&
          runtimeType == other.runtimeType &&
          serialNumber == other.serialNumber &&
          seriesPrefix == other.seriesPrefix;

  @override
  int get hashCode => serialNumber.hashCode ^ (seriesPrefix?.hashCode ?? 0);
}
