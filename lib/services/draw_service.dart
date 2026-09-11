import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/matching_engine.dart';
import '../models/draw.dart';

/// Service responsible for managing draw history data, bundled offline assets,
/// remote sync from official/hosted endpoints, and coordinating with [MatchingEngine].
class DrawService {
  static const String _prefsKeyCachedDraws = 'cached_draws_json';
  static const String _prefsKeyLastSyncTime = 'last_sync_timestamp';
  static const String _prefsKeyLatestDrawNo = 'latest_draw_no';
  static const String _prefsKeyLastUpdated = 'last_updated_date';
  static const String _prefsKeySyncUrl = 'remote_draws_sync_url';

  /// Default remote hosted endpoint URL
  /// Hosted directly in the user's GitHub repository
  static const String defaultRemoteUrl =
      'https://raw.githubusercontent.com/Tasnimul-Shakil/PriceBondChecker/main/data/draws_endpoint.json';

  final MatchingEngine matchingEngine;
  List<Draw> _draws = [];
  DateTime? _lastSyncTime;
  String? _lastUpdatedDate;
  int? _latestDrawNo;
  bool _isLoading = false;
  bool _isOfflineFallback = false;
  String _syncUrl = defaultRemoteUrl;

  DrawService({MatchingEngine? engine})
      : matchingEngine = engine ?? MatchingEngine();

  List<Draw> get draws => List.unmodifiable(_draws);
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastUpdatedDate => _lastUpdatedDate;
  int? get latestDrawNo => _latestDrawNo ?? latestDraw?.drawNumber;
  bool get isLoading => _isLoading;
  bool get isOfflineFallback => _isOfflineFallback;
  String get currentSyncUrl => _syncUrl;
  int get totalWinningNumbers => matchingEngine.winningNumbersSet.length;

  /// Initializes the service:
  /// 1. Tries to load from locally cached SharedPreferences.
  /// 2. If no cache exists, loads bundled asset `assets/data/draws_history.json`.
  /// 3. Builds the inverted index in [matchingEngine].
  /// 4. Silently schedules a background sync check.
  Future<void> initialize() async {
    _isLoading = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _syncUrl = prefs.getString(_prefsKeySyncUrl) ?? defaultRemoteUrl;
      final cachedJson = prefs.getString(_prefsKeyCachedDraws);
      final lastSyncIso = prefs.getString(_prefsKeyLastSyncTime);
      _latestDrawNo = prefs.getInt(_prefsKeyLatestDrawNo);
      _lastUpdatedDate = prefs.getString(_prefsKeyLastUpdated);

      if (lastSyncIso != null) {
        _lastSyncTime = DateTime.tryParse(lastSyncIso);
      }

      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          _parseAndLoadJson(cachedJson);
        } catch (_) {
          // If cached data is corrupted, fall back to bundled asset
          await _loadFromAssetBundle();
        }
      } else {
        await _loadFromAssetBundle();
      }
    } catch (e) {
      await _loadFromAssetBundle();
    } finally {
      _isLoading = false;
    }

    // Trigger non-blocking background sync if connected
    _scheduleBackgroundSync();
  }

  void _scheduleBackgroundSync() {
    Future.delayed(const Duration(seconds: 2), () {
      syncRemoteDraws(silent: true);
    });
  }

  /// Loads bundled official draw history from asset bundle.
  Future<void> _loadFromAssetBundle() async {
    try {
      final assetString =
          await rootBundle.loadString('assets/data/draws_history.json');
      _parseAndLoadJson(assetString);
      _isOfflineFallback = true;
    } catch (e) {
      // If running in test mode without Flutter bundle or asset loading fails
      _draws = [];
    }
  }

  /// Parses JSON string into [Draw] objects and loads into [matchingEngine].
  void _parseAndLoadJson(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    final payload = DrawsPayload.fromJson(data);

    _draws = payload.draws;
    _latestDrawNo = payload.latestDrawNo;
    _lastUpdatedDate = payload.lastUpdated;

    // Sort descending by drawNumber (latest draw first)
    _draws.sort((a, b) => b.drawNumber.compareTo(a.drawNumber));

    // Rebuild O(1) matching engine inverted index & HashSet
    matchingEngine.loadDraws(_draws);
  }

  /// Manually loads a raw JSON string (useful for testing or direct file import).
  void loadRawJson(String jsonString) {
    _parseAndLoadJson(jsonString);
  }

  /// Updates the remote sync URL (e.g. user-hosted Supabase, Firebase, or GitHub repo).
  Future<void> setRemoteSyncUrl(String url) async {
    _syncUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeySyncUrl, _syncUrl);
  }

  /// Resets remote sync URL to default.
  Future<void> resetDefaultSyncUrl() async {
    await setRemoteSyncUrl(defaultRemoteUrl);
  }

  /// Syncs with remote server or GitHub raw endpoint.
  /// 1. Sends lightweight GET request with 10s timeout.
  /// 2. Compares `latest_draw_no` between remote and local cache.
  /// 3. If remote > local, downloads and persists into local storage.
  /// 4. Rebuilds inverted index / HashSet for O(1) lookup.
  /// 5. Silently falls back to local cache if offline or error occurs.
  Future<SyncResult> syncRemoteDraws({
    bool silent = false,
    bool forceRefresh = false,
    String? customUrl,
  }) async {
    if (_isLoading) {
      return SyncResult(
        success: false,
        newDrawsFound: false,
        drawsCount: _draws.length,
        message: 'Sync already in progress...',
      );
    }

    _isLoading = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final targetUrl = customUrl ?? _syncUrl;

      final response = await http
          .get(Uri.parse(targetUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> data = jsonDecode(body);
        final remotePayload = DrawsPayload.fromJson(data);

        final remoteLatestNo = remotePayload.latestDrawNo;
        final localLatestNo = _latestDrawNo ?? 0;

        _lastSyncTime = DateTime.now();
        _isOfflineFallback = false;

        // Check if there is a new draw or user requested forced refresh
        if (remoteLatestNo > localLatestNo || forceRefresh || _draws.isEmpty) {
          _parseAndLoadJson(body);

          await prefs.setString(_prefsKeyCachedDraws, body);
          await prefs.setInt(_prefsKeyLatestDrawNo, remoteLatestNo);
          await prefs.setString(
            _prefsKeyLastUpdated,
            remotePayload.lastUpdated,
          );
          await prefs.setString(
            _prefsKeyLastSyncTime,
            _lastSyncTime!.toIso8601String(),
          );

          return SyncResult(
            success: true,
            newDrawsFound: true,
            latestDrawNo: remoteLatestNo,
            drawsCount: _draws.length,
            message: '🎉 Updated to Draw #$remoteLatestNo! (${_draws.length} active draws synchronized)',
          );
        } else {
          // Already up to date
          await prefs.setString(
            _prefsKeyLastSyncTime,
            _lastSyncTime!.toIso8601String(),
          );

          return SyncResult(
            success: true,
            newDrawsFound: false,
            latestDrawNo: localLatestNo,
            drawsCount: _draws.length,
            message: 'Draw results are already up to date (Latest: Draw #$localLatestNo).',
          );
        }
      } else {
        _isOfflineFallback = true;
        return SyncResult(
          success: false,
          newDrawsFound: false,
          isOffline: false,
          drawsCount: _draws.length,
          message: 'Remote server returned HTTP ${response.statusCode}. Using cached draws.',
        );
      }
    } catch (e) {
      // Offline fallback: Network failure, timeout, or DNS lookup failure
      _isOfflineFallback = true;
      return SyncResult(
        success: false,
        newDrawsFound: false,
        isOffline: true,
        drawsCount: _draws.length,
        message: 'Offline mode: using locally cached draw results.',
      );
    } finally {
      _isLoading = false;
    }
  }

  /// Returns the latest draw in the system.
  Draw? get latestDraw => _draws.isNotEmpty ? _draws.first : null;
}

class SyncResult {
  final bool success;
  final bool newDrawsFound;
  final bool isOffline;
  final int? latestDrawNo;
  final int drawsCount;
  final String message;

  SyncResult({
    required this.success,
    this.newDrawsFound = false,
    this.isOffline = false,
    this.latestDrawNo,
    required this.drawsCount,
    required this.message,
  });
}
