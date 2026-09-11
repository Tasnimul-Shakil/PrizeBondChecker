import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/digit_normalizer.dart';
import '../../models/draw.dart';
import '../../services/draw_service.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _searchWinningNumber() {
    final query = DigitNormalizer.normalizeSerial(_searchController.text);
    if (query == null) {
      setState(() {
        _searchResultFeedback = 'Enter a valid 7-digit number to search.';
      });
      return;
    }

    final matches = widget.drawService.matchingEngine.checkSerialString(query);
    setState(() {
      if (matches.isNotEmpty) {
        final m = matches.first;
        _searchResultFeedback =
            '🎉 WINNER! $query won ${m.tierName} (${DigitNormalizer.formatCurrencyBDT(m.prizeAmount)}) in Draw #${m.drawNumber} (${DateFormat('d MMM yyyy').format(m.drawDate)})!';
      } else {
        _searchResultFeedback =
            '❌ $query was not drawn in any of the active 8 draws (2-year window).';
      }
    });
  }

  Future<void> _syncDraws({bool forceRefresh = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF1E2D40),
        duration: Duration(seconds: 1),
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Checking remote draw endpoint...'),
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
        title: const Row(
          children: [
            Icon(Icons.settings_suggest, color: Color(0xFFD4AF37)),
            SizedBox(width: 8),
            Text('Draw Sync Endpoint', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configure the remote JSON endpoint used to fetch official Bangladesh Bank draw updates:',
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
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
            child: const Text('Reset Default', style: TextStyle(color: Colors.white60)),
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
            child: const Text('Save & Sync'),
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
        : 'Bundled Database (Offline)';

    final latestDrawNo = widget.drawService.latestDrawNo ?? (draws.isNotEmpty ? draws.first.drawNumber : 119);
    final totalNumbers = widget.drawService.totalWinningNumbers;

    return Scaffold(
      backgroundColor: const Color(0xFF0B192C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B192C),
        elevation: 0,
        title: const Text(
          'Official Draws Archive',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white70),
            tooltip: 'Endpoint Settings',
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
            tooltip: 'Sync Latest Draws',
            onPressed: () => _syncDraws(forceRefresh: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFFD4AF37),
        backgroundColor: const Color(0xFF131D2A),
        onRefresh: () => _syncDraws(forceRefresh: true),
        child: draws.isEmpty
            ? const Center(
                child: Text(
                  'No draw data available. Pull down to sync.',
                  style: TextStyle(color: Colors.white60),
                ),
              )
            : CustomScrollView(
                slivers: [
                  // 1. Sync & Database Status Header Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF131D2A), Color(0xFF1E2D40)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: widget.drawService.isOfflineFallback
                                        ? Colors.amber.withOpacity(0.2)
                                        : const Color(0xFF006A4E).withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: widget.drawService.isOfflineFallback
                                          ? Colors.amber
                                          : const Color(0xFF00FF66),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        widget.drawService.isOfflineFallback
                                            ? Icons.offline_bolt
                                            : Icons.cloud_done,
                                        size: 13,
                                        color: widget.drawService.isOfflineFallback
                                            ? Colors.amber
                                            : const Color(0xFF00FF66),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.drawService.isOfflineFallback
                                            ? 'Offline Cache'
                                            : 'Online Synced',
                                        style: TextStyle(
                                          color: widget.drawService.isOfflineFallback
                                              ? Colors.amber
                                              : const Color(0xFF00FF66),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Last Synced: $lastSyncText',
                                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Latest Draw',
                                        style: TextStyle(color: Colors.white54, fontSize: 11)),
                                    Text(
                                      'Draw #$latestDrawNo',
                                      style: const TextStyle(
                                        color: Color(0xFFD4AF37),
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Eligible Draws (2 Yrs)',
                                        style: TextStyle(color: Colors.white54, fontSize: 11)),
                                    Text(
                                      '${draws.length} Draws ($totalNumbers Winning Serials)',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. Quick Number Search Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              keyboardType: TextInputType.number,
                              maxLength: 7,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: 'Verify any 7-digit number (e.g. 0782341)...',
                                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                                prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                                filled: true,
                                fillColor: const Color(0xFF1E2D40),
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
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
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _searchWinningNumber,
                            child: const Text('Verify'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_searchResultFeedback != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _searchResultFeedback!.contains('WINNER')
                                ? const Color(0xFF006A4E).withOpacity(0.4)
                                : Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _searchResultFeedback!,
                            style: TextStyle(
                              color: _searchResultFeedback!.contains('WINNER')
                                  ? const Color(0xFF00FF66)
                                  : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 3. Horizontal Draw Picker Tabs (Draw 119, 118, 117...)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        height: 44,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: draws.length,
                          itemBuilder: (context, index) {
                            final draw = draws[index];
                            final isSelected = _selectedDrawIndex == index;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Text('Draw #${draw.drawNumber}'),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedDrawIndex = index;
                                    });
                                  }
                                },
                                selectedColor: const Color(0xFF006A4E),
                                backgroundColor: const Color(0xFF1E2D40),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // 4. Selected Draw Summary Banner
                  if (activeDraw != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131D2A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Draw #${activeDraw.drawNumber} Results',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Conducted on: ${DateFormat('d MMMM yyyy').format(activeDraw.drawDate)}',
                                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD4AF37).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${activeDraw.totalWinnersCount} Prizes',
                                  style: const TextStyle(
                                    color: Color(0xFFD4AF37),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // 5. Prize Tiers Breakdown (1st to 5th)
                  if (activeDraw != null)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final tier = activeDraw.prizes[index];
                            return _buildPrizeTierCard(tier);
                          },
                          childCount: activeDraw.prizes.length,
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 30)),
                ],
              ),
      ),
    );
  }

  Widget _buildPrizeTierCard(PrizeTier tier) {
    Color badgeColor;
    switch (tier.tier) {
      case 1:
        badgeColor = const Color(0xFFD4AF37); // Gold
        break;
      case 2:
        badgeColor = const Color(0xFFC0C0C0); // Silver
        break;
      case 3:
        badgeColor = const Color(0xFFCD7F32); // Bronze
        break;
      default:
        badgeColor = const Color(0xFF006A4E); // Emerald
    }

    return Card(
      color: const Color(0xFF131D2A),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: badgeColor, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      '${tier.tier}',
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tier.name} (${tier.nameBn})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${DigitNormalizer.formatCurrencyBDT(tier.amount)} each',
                      style: const TextStyle(color: Color(0xFF00FF66), fontSize: 12),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '${tier.winningNumbers.length} Winners',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
            const Divider(color: Colors.white10, height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: tier.winningNumbers.map((winningNum) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    winningNum,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
