import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/digit_normalizer.dart';
import '../../models/draw.dart';
import '../../services/draw_service.dart';
import '../../services/locale_service.dart';

class DrawsScreen extends StatefulWidget {
  final DrawService drawService;

  const DrawsScreen({super.key, required this.drawService});

  @override
  State<DrawsScreen> createState() => _DrawsScreenState();
}

class _DrawsScreenState extends State<DrawsScreen> {
  int _selectedDrawIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String? _searchResultFeedback;
  final LocaleService _locale = LocaleService();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _searchWinningNumber() {
    final query = DigitNormalizer.normalizeSerial(_searchController.text);
    if (query == null) {
      setState(() {
        _searchResultFeedback = _locale.isBangla
            ? 'খুঁজতে সঠিক ৭-সংখ্যার নম্বর দিন।'
            : 'Enter a valid 7-digit number to search.';
      });
      return;
    }

    final matches = widget.drawService.matchingEngine.checkSerialString(query);
    setState(() {
      if (matches.isNotEmpty) {
        final m = matches.first;
        final displaySerial = _locale.isBangla ? DigitNormalizer.toBengaliDigits(query) : query;
        final tier = _locale.isBangla ? m.tierNameBn : m.tierName;
        final prize = _locale.formatCurrency(m.prizeAmount);
        final drawNum = _locale.formatNumber(m.drawNumber);

        _searchResultFeedback = _locale.isBangla
            ? '🎉 অভিনন্দন! $displaySerial নম্বরটি $drawNum নম্বর ড্রয়ে $tier ($prize) জিতেছে!'
            : '🎉 WINNER! $query won $tier ($prize) in Draw #$drawNum!';
      } else {
        final displaySerial = _locale.isBangla ? DigitNormalizer.toBengaliDigits(query) : query;
        _searchResultFeedback = _locale.isBangla
            ? '❌ $displaySerial নম্বরটি সাম্প্রতিক ৮টি ড্রয়ের কোনোটিতে বিজয়ী হয়নি।'
            : '❌ $query was not drawn in any of the active 8 draws (2-year window).';
      }
    });
  }

  Future<void> _syncDraws({bool forceRefresh = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF131D2A),
        duration: const Duration(seconds: 1),
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(_locale.isBangla ? 'অনলাইন সার্ভার থেকে তথ্য সংগ্রহ করা হচ্ছে...' : 'Checking remote draw endpoint...'),
          ],
        ),
      ),
    );

    final res = await widget.drawService.syncRemoteDraws(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {});
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: res.success ? const Color(0xFF006A4E) : Colors.amber.shade800,
          content: Row(
            children: [
              Icon(
                res.success ? Icons.check_circle : Icons.cloud_off,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(res.message)),
            ],
          ),
        ),
      );
    }
  }

  void _openSyncSettingsDialog() {
    final urlController = TextEditingController(text: widget.drawService.currentSyncUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.settings_suggest, color: Color(0xFFD4AF37)),
            const SizedBox(width: 8),
            Text(
              _locale.isBangla ? 'ড্র সিঙ্ক সেটিংস' : 'Draw Sync Endpoint',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _locale.isBangla
                  ? 'বাংলাদেশ ব্যাংকের সর্বশেষ ড্র ফলাফল স্বয়ংক্রিয়ভাবে পেতে রিমোট JSON লিঙ্ক:'
                  : 'Configure the remote JSON endpoint used to fetch official Bangladesh Bank draw updates:',
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Remote JSON URL',
                labelStyle: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12),
                hintText: 'https://...',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.drawService.resetDefaultSyncUrl();
              if (mounted) {
                _syncDraws(forceRefresh: true);
              }
            },
            child: Text(_locale.isBangla ? 'ডিফল্ট রিসেট' : 'Reset Default', style: const TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006A4E),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newUrl = urlController.text.trim();
              if (newUrl.isNotEmpty) {
                Navigator.pop(ctx);
                await widget.drawService.setRemoteSyncUrl(newUrl);
                if (mounted) {
                  _syncDraws(forceRefresh: true);
                }
              }
            },
            child: Text(_locale.isBangla ? 'সংরক্ষণ ও সিঙ্ক' : 'Save & Sync'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draws = widget.drawService.draws;
    final activeDraw =
        draws.isNotEmpty && _selectedDrawIndex < draws.length ? draws[_selectedDrawIndex] : null;

    final lastSync = widget.drawService.lastSyncTime;
    final lastSyncText = lastSync != null
        ? DateFormat('d MMM, h:mm a').format(lastSync)
        : (_locale.isBangla ? 'অফলাইন ডেটাবেস' : 'Bundled Database (Offline)');

    final totalNumbers = widget.drawService.totalWinningNumbers;

    return AnimatedBuilder(
      animation: _locale,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0B192C),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0B192C),
            elevation: 0,
            title: Text(
              _locale.t('draws_title'),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            actions: [
              const LanguageToggleButton(),
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.white70),
                tooltip: _locale.isBangla ? 'সেটিংস' : 'Endpoint Settings',
                onPressed: _openSyncSettingsDialog,
              ),
              IconButton(
                icon: widget.drawService.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FF66)),
                      )
                    : const Icon(Icons.sync, color: Color(0xFF00FF66)),
                tooltip: _locale.isBangla ? 'সিঙ্ক ড্র' : 'Sync Latest Draws',
                onPressed: () => _syncDraws(forceRefresh: true),
              ),
            ],
          ),
          body: draws.isEmpty
              ? Center(
                  child: Text(
                    _locale.isBangla ? 'কোনো ড্র তথ্য পাওয়া যায়নি।' : 'No official draws loaded.',
                    style: const TextStyle(color: Colors.white60),
                  ),
                )
              : Column(
                  children: [
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: _locale.isBangla
                                    ? '৭-সংখ্যার নম্বর লিখে ফলাফল খুঁজুন...'
                                    : 'Search 7-digit number in active draws...',
                                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, color: Colors.white54),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchResultFeedback = null);
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: const Color(0xFF131D2A),
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Colors.white10),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFF006A4E)),
                                ),
                              ),
                              onSubmitted: (_) => _searchWinningNumber(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF006A4E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _searchWinningNumber,
                            child: Text(_locale.isBangla ? 'যাচাই' : 'Check'),
                          ),
                        ],
                      ),
                    ),

                    if (_searchResultFeedback != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _searchResultFeedback!.contains('🎉')
                              ? const Color(0xFF006A4E).withOpacity(0.3)
                              : Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _searchResultFeedback!.contains('🎉')
                                ? const Color(0xFF00FF66)
                                : Colors.red.shade400,
                          ),
                        ),
                        child: Text(
                          _searchResultFeedback!,
                          style: TextStyle(
                            color: _searchResultFeedback!.contains('🎉')
                                ? Colors.white
                                : Colors.red.shade200,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    // Draw Horizontal Selector Chips
                    Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: draws.length,
                        itemBuilder: (ctx, i) {
                          final d = draws[i];
                          final isSelected = i == _selectedDrawIndex;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(
                                '${_locale.t('draw_no')}${_locale.formatNumber(d.drawNumber)}',
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: const Color(0xFF006A4E),
                              backgroundColor: const Color(0xFF131D2A),
                              onSelected: (_) => setState(() => _selectedDrawIndex = i),
                            ),
                          );
                        },
                      ),
                    ),

                    // Active Draw Summary Header
                    if (activeDraw != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131D2A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_locale.t('draw_no')}${_locale.formatNumber(activeDraw.drawNumber)} • ${DateFormat('d MMMM yyyy').format(activeDraw.drawDate)}',
                                    style: const TextStyle(
                                      color: Color(0xFFD4AF37),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_locale.isBangla ? "মোট বিজয়ী সংখ্যা:" : "Winning numbers:"} ${_locale.formatNumber(totalNumbers)}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                lastSyncText,
                                style: const TextStyle(color: Colors.white38, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Prize Numbers Expansion List
                    Expanded(
                      child: activeDraw == null
                          ? const SizedBox()
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                _buildPrizeCard(
                                  tierName: _locale.t('prize_1st'),
                                  amount: '৳১৬,০০,০০০' == '৳১৬,০০,০০০' && _locale.isBangla ? '৳১৬,০০,০০০' : '৳16,00,000',
                                  numbers: activeDraw.firstPrize,
                                  cardColor: const Color(0xFFD4AF37).withOpacity(0.15),
                                  accentColor: const Color(0xFFFFF176),
                                ),
                                const SizedBox(height: 12),
                                _buildPrizeCard(
                                  tierName: _locale.t('prize_2nd'),
                                  amount: _locale.isBangla ? '৳৩,২৫,০০০' : '৳3,25,000',
                                  numbers: activeDraw.secondPrize,
                                  cardColor: const Color(0xFF006A4E).withOpacity(0.2),
                                  accentColor: const Color(0xFF00FF66),
                                ),
                                const SizedBox(height: 12),
                                _buildPrizeCard(
                                  tierName: _locale.t('prize_3rd'),
                                  amount: _locale.isBangla ? '৳১,০০,০০০' : '৳1,00,000',
                                  numbers: activeDraw.thirdPrize,
                                  cardColor: const Color(0xFF131D2A),
                                  accentColor: const Color(0xFF81D4FA),
                                ),
                                const SizedBox(height: 12),
                                _buildPrizeCard(
                                  tierName: _locale.t('prize_4th'),
                                  amount: _locale.isBangla ? '৳৫০,০০০' : '৳50,000',
                                  numbers: activeDraw.fourthPrize,
                                  cardColor: const Color(0xFF131D2A),
                                  accentColor: const Color(0xFFFFB74D),
                                ),
                                const SizedBox(height: 12),
                                _buildPrizeCard(
                                  tierName: _locale.t('prize_5th'),
                                  amount: _locale.isBangla ? '৳১০,০০০' : '৳10,000',
                                  numbers: activeDraw.fifthPrize,
                                  cardColor: const Color(0xFF131D2A),
                                  accentColor: Colors.white70,
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildPrizeCard({
    required String tierName,
    required String amount,
    required List<String> numbers,
    required Color cardColor,
    required Color accentColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withOpacity(0.4)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tierName,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  amount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: numbers.map((n) {
              final display = _locale.isBangla ? DigitNormalizer.toBengaliDigits(n) : n;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B192C),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  display,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
