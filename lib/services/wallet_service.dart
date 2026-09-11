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
        final seenSerials = <String>{};
        for (final item in decoded) {
          final b = Bond.fromJson(item as Map<String, dynamic>);
          final norm = DigitNormalizer.normalizeSerial(b.serialNumber);
          if (norm != null && !seenSerials.contains(norm)) {
            seenSerials.add(norm);
            _bonds.add(b);
          }
        }
      }
    } catch (_) {
      // In case of parsing error, start with empty wallet
      _bonds.clear();
    } finally {
      _isInitialized = true;
    }
  }

  /// Checks if a 7-digit bond serial number already exists in the wallet.
  bool containsSerial(String serialNumber) {
    final normalized = DigitNormalizer.normalizeSerial(serialNumber);
    if (normalized == null) return false;
    return _bonds.any((b) => b.serialNumber == normalized);
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
  /// Strictly prevents duplicate bond numbers: each number can only be added once!
  /// Returns the created [Bond], or null if invalid or already exists.
  Future<Bond?> addBond({
    required String serialNumber,
    String? seriesPrefix,
    String? imagePath,
    String? batchId,
    List<String>? tags,
    String? notes,
  }) async {
    final normalized = DigitNormalizer.normalizeSerial(serialNumber);
    if (normalized == null) return null;

    // Reject duplicate: bond number can only be added once!
    if (containsSerial(normalized)) {
      return null;
    }

    final bond = Bond(
      serialNumber: normalized,
      seriesPrefix: seriesPrefix?.trim().isNotEmpty == true
          ? seriesPrefix!.trim().toUpperCase()
          : null,
      imagePath: imagePath,
      batchId: batchId,
      tags: tags,
      notes: notes,
    );

    _bonds.insert(0, bond); // Latest added first
    await _persist();
    return bond;
  }

  /// Adds a batch of bonds at once (e.g. from batch camera scanning).
  /// Strictly deduplicates so each 7-digit serial number exists only once in the wallet.
  Future<int> addBatch(List<Bond> newBonds) async {
    int addedCount = 0;
    final seenInBatch = <String>{};
    for (final bond in newBonds) {
      final norm = DigitNormalizer.normalizeSerial(bond.serialNumber);
      if (norm == null) continue;
      if (seenInBatch.contains(norm)) continue;
      seenInBatch.add(norm);

      final exists = _bonds.any((b) => b.serialNumber == norm);
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
  /// E.g. Start: "0154201", End: "0154250" -> 50 bonds created.
  /// Skips any serial numbers that are already in the wallet.
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
      // Only include if not already in wallet
      if (!containsSerial(serialString)) {
        generatedBonds.add(
          Bond(
            serialNumber: serialString,
            seriesPrefix: seriesPrefix?.trim().isNotEmpty == true
                ? seriesPrefix!.trim()
                : null,
            batchId: batchId,
            tags: tag != null && tag.isNotEmpty ? [tag] : ['Sequential Range'],
          ),
        );
      }
    }

    if (generatedBonds.isNotEmpty) {
      await addBatch(generatedBonds);
    }
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
