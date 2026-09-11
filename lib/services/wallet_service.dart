import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/digit_normalizer.dart';
import '../models/bond.dart';

/// Service responsible for persistent local storage and CRUD operations for the user's bond wallet.
class WalletService {
  static const String _prefsKeyBondsList = 'user_saved_bonds_v1';

  final List<Bond> _bonds = [];
  bool _isInitialized = false;

  List<Bond> get bonds => List.unmodifiable(_bonds);
  bool get isInitialized => _isInitialized;

  /// Loads stored bonds from persistent local storage.
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_prefsKeyBondsList);

      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _bonds.clear();
        for (final item in decoded) {
          _bonds.add(Bond.fromJson(item as Map<String, dynamic>));
        }
      }
    } catch (_) {
      // In case of parsing error, start with empty wallet
      _bonds.clear();
    } finally {
      _isInitialized = true;
    }
  }

  /// Saves the current list of bonds to persistent storage.
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(_bonds.map((b) => b.toJson()).toList());
      await prefs.setString(_prefsKeyBondsList, jsonString);
    } catch (e) {
      // Handle storage exception
    }
  }

  /// Adds a single bond to the wallet.
  /// Automatically validates and normalizes the 7-digit serial number.
  /// Returns the created [Bond], or null if the serial is invalid.
  Future<Bond?> addBond({
    required String serialNumber,
    String? seriesPrefix,
    String? batchId,
    List<String>? tags,
    String? notes,
  }) async {
    final normalized = DigitNormalizer.normalizeSerial(serialNumber);
    if (normalized == null) return null;

    final bond = Bond(
      serialNumber: normalized,
      seriesPrefix: seriesPrefix?.trim().toUpperCase(),
      batchId: batchId,
      tags: tags,
      notes: notes,
    );

    // Check if identical bond (same serial & series) already exists
    final existsIndex = _bonds.indexWhere(
      (b) => b.serialNumber == bond.serialNumber && b.seriesPrefix == bond.seriesPrefix,
    );

    if (existsIndex >= 0) {
      // Update existing bond's metadata if needed
      _bonds[existsIndex] = bond;
    } else {
      _bonds.insert(0, bond); // Latest added first
    }

    await _persist();
    return bond;
  }

  /// Adds a batch of bonds at once (e.g. from batch camera scanning).
  /// Deduplicates items within the batch and skips existing ones if requested.
  Future<int> addBatch(List<Bond> newBonds) async {
    int addedCount = 0;
    for (final bond in newBonds) {
      final exists = _bonds.any(
        (b) => b.serialNumber == bond.serialNumber && b.seriesPrefix == bond.seriesPrefix,
      );
      if (!exists) {
        _bonds.insert(0, bond);
        addedCount++;
      }
    }

    if (addedCount > 0) {
      await _persist();
    }
    return addedCount;
  }

  /// Generates and adds a continuous sequential range of bonds.
  /// E.g. Series: "কখ", Start: "0154201", End: "0154250" -> 50 bonds created.
  Future<List<Bond>> addBondRange({
    required String startSerial,
    required String endSerial,
    String? seriesPrefix,
    String? tag,
  }) async {
    final startNorm = DigitNormalizer.normalizeSerial(startSerial);
    final endNorm = DigitNormalizer.normalizeSerial(endSerial);

    if (startNorm == null || endNorm == null) {
      throw ArgumentError('Start or end serial is not a valid 7-digit number');
    }

    final startInt = int.parse(startNorm);
    final endInt = int.parse(endNorm);

    if (startInt > endInt) {
      throw ArgumentError('Start serial must be less than or equal to end serial');
    }

    final count = endInt - startInt + 1;
    if (count > 500) {
      throw ArgumentError('Range exceeds the maximum allowed limit of 500 bonds per batch');
    }

    final batchId = 'RANGE_${DateTime.now().millisecondsSinceEpoch}';
    final generatedBonds = <Bond>[];

    for (int i = startInt; i <= endInt; i++) {
      final serialString = i.toString().padLeft(7, '0');
      generatedBonds.add(
        Bond(
          serialNumber: serialString,
          seriesPrefix: seriesPrefix?.trim(),
          batchId: batchId,
          tags: tag != null && tag.isNotEmpty ? [tag] : ['Sequential Range'],
        ),
      );
    }

    await addBatch(generatedBonds);
    return generatedBonds;
  }

  /// Updates an existing bond.
  Future<bool> updateBond(Bond updatedBond) async {
    final index = _bonds.indexWhere((b) => b.id == updatedBond.id);
    if (index >= 0) {
      _bonds[index] = updatedBond;
      await _persist();
      return true;
    }
    return false;
  }

  /// Deletes a bond by its unique ID.
  Future<bool> deleteBond(String id) async {
    final initialLength = _bonds.length;
    _bonds.removeWhere((b) => b.id == id);
    if (_bonds.length < initialLength) {
      await _persist();
      return true;
    }
    return false;
  }

  /// Deletes an entire batch of bonds by batchId.
  Future<int> deleteBatch(String batchId) async {
    final initialLength = _bonds.length;
    _bonds.removeWhere((b) => b.batchId == batchId);
    final deletedCount = initialLength - _bonds.length;
    if (deletedCount > 0) {
      await _persist();
    }
    return deletedCount;
  }

  /// Clears the entire wallet.
  Future<void> clearAll() async {
    _bonds.clear();
    await _persist();
  }

  /// Exports all saved bonds as a formatted JSON string for backup.
  String exportBackupJson() {
    return jsonEncode({
      'app': 'PrizeBondChecker',
      'version': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'bondsCount': _bonds.length,
      'bonds': _bonds.map((b) => b.toJson()).toList(),
    });
  }

  /// Imports bonds from a backup JSON string.
  Future<int> importBackupJson(String backupJson) async {
    final Map<String, dynamic> data = jsonDecode(backupJson);
    final List<dynamic> importedList = data['bonds'] as List<dynamic>;

    int importedCount = 0;
    for (final item in importedList) {
      final bond = Bond.fromJson(item as Map<String, dynamic>);
      final exists = _bonds.any((b) => b.serialNumber == bond.serialNumber && b.seriesPrefix == bond.seriesPrefix);
      if (!exists) {
        _bonds.add(bond);
        importedCount++;
      }
    }

    if (importedCount > 0) {
      await _persist();
    }
    return importedCount;
  }

  /// Total count of saved bonds.
  int get count => _bonds.length;

  /// Total portfolio valuation (৳100 per bond).
  int get totalPortfolioValue => _bonds.length * 100;
}
