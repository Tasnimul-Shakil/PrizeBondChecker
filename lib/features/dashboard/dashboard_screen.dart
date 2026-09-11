import 'package:flutter/material.dart';
import '../../core/digit_normalizer.dart';
import '../../core/matching_engine.dart';
import '../../models/bond.dart';
import '../../services/draw_service.dart';
import '../../services/wallet_service.dart';
import '../wallet/range_input_modal.dart';

class DashboardScreen extends StatefulWidget {
  final WalletService walletService;
  final DrawService drawService;
  final MatchingEngine matchingEngine;
  final VoidCallback onOpenScanner;
  final VoidCallback onOpenWallet;
  final VoidCallback onOpenDraws;

  const DashboardScreen({
    super.key,
    required this.walletService,
    required this.drawService,
    required this.matchingEngine,
    required this.onOpenScanner,
    required this.onOpenWallet,
    required this.onOpenDraws,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  WalletMatchSummary? _summary;

  @override
  void initState() {
    super.initState();
    _recalculateSummary();
  }

  void _recalculateSummary() {
    final summary = widget.matchingEngine.checkAllBonds(widget.walletService.bonds);
    setState(() {
      _summary = summary;
    });
  }

  void _openRangeModal() async {
    final res = await showModalBottomSheet<List<Bond>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RangeInputModal(walletService: widget.walletService),
    );

    if (res != null) {
      _recalculateSummary();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF006A4E),
            content: Text('Added ${res.length} bonds to your collection!'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bondsCount = widget.walletService.count;
    final totalInvestment = widget.walletService.totalPortfolioValue;
    final winningAmount = _summary?.totalPrizeAmount ?? 0.0;
    final winningCount = _summary?.winningBondsCount ?? 0;
    final latestDraw = widget.drawService.latestDraw;

    return Scaffold(
      backgroundColor: const Color(0xFF0B192C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B192C),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF006A4E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.stars, color: Color(0xFFD4AF37), size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Prize Bond Scanner',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Re-check Results',
            onPressed: () {
              _recalculateSummary();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  duration: Duration(seconds: 1),
                  backgroundColor: Color(0xFF006A4E),
                  content: Text('Verification refreshed across all 8 draws!'),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _recalculateSummary();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Hero Portfolio & Winning Card
            _buildHeroCard(
              totalInvestment: totalInvestment,
              bondsCount: bondsCount,
              winningAmount: winningAmount,
              winningCount: winningCount,
            ),
            const SizedBox(height: 16),

            // 2. Winning Celebration Banner if any bond won
            if (winningCount > 0) ...[
              _buildWinnerCelebrationBanner(),
              const SizedBox(height: 16),
            ],

            // 3. Quick Action Grid
            const Text(
              'Quick Actions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildQuickActionsGrid(),
            const SizedBox(height: 20),

            // 4. Latest Official Draw Status
            if (latestDraw != null) ...[
              _buildLatestDrawCard(latestDraw),
              const SizedBox(height: 20),
            ],

            // 5. Recent Bonds Header & List
            Row(
              children: [
                const Text(
                  'Recent Bonds',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.onOpenWallet,
                  child: const Text(
                    'View All',
                    style: TextStyle(color: Color(0xFFD4AF37)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildRecentBondsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard({
    required int totalInvestment,
    required int bondsCount,
    required double winningAmount,
    required int winningCount,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF006A4E), Color(0xFF0E4C3A), Color(0xFF133E33)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF006A4E).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Total Prize Money Won',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$bondsCount Bonds Tracked',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            DigitNormalizer.formatCurrencyBDT(winningAmount),
            style: const TextStyle(
              color: Color(0xFFFFF176),
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          if (winningAmount > 0)
            Text(
              'Net: ${DigitNormalizer.formatCurrencyBDT(winningAmount * 0.80)} (after 20% source tax)',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Value', style: TextStyle(color: Colors.white60, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    DigitNormalizer.formatCurrencyBDT(totalInvestment),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Winning Bonds', style: TextStyle(color: Colors.white60, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    '$winningCount / $bondsCount',
                    style: TextStyle(
                      color: winningCount > 0 ? const Color(0xFF00FF66) : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWinnerCelebrationBanner() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37).withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4AF37)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CONGRATULATIONS!',
                  style: TextStyle(
                    color: Color(0xFFFFF176),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You have ${_summary?.winningBondsCount} winning bond(s) in active draws!',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006A4E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: widget.onOpenWallet,
            child: const Text('View', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildActionTile(
            icon: Icons.camera_alt,
            title: 'Scan Bond',
            subtitle: 'Camera OCR',
            color: const Color(0xFF006A4E),
            onTap: widget.onOpenScanner,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionTile(
            icon: Icons.format_list_numbered,
            title: 'Add Range',
            subtitle: 'Serial Series',
            color: const Color(0xFF1E3E62),
            onTap: _openRangeModal,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionTile(
            icon: Icons.history_edu,
            title: 'Draw Results',
            subtitle: '8 Quarters',
            color: const Color(0xFF4A3E1A),
            onTap: widget.onOpenDraws,
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.8)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestDrawCard(dynamic draw) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF172333),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF006A4E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.campaign, color: Color(0xFFD4AF37), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Latest Draw #${draw.drawNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Held on ${draw.drawDate.toIso8601String().substring(0, 10)} • 1st Prize ৳6,00,000',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
            onPressed: widget.onOpenDraws,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentBondsList() {
    final recent = widget.walletService.bonds.take(4).toList();

    if (recent.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF172333),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text(
            'No prize bonds added yet.\nTap "Scan Bond" to start adding.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: recent.map((bond) {
        final matches = widget.matchingEngine.checkBond(bond);
        final isWinner = matches.isNotEmpty;

        return Card(
          color: isWinner
              ? const Color(0xFF006A4E).withOpacity(0.25)
              : const Color(0xFF172333),
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isWinner ? const Color(0xFF00FF66) : Colors.white10,
            ),
          ),
          child: ListTile(
            dense: true,
            leading: Icon(
              isWinner ? Icons.emoji_events : Icons.confirmation_number,
              color: isWinner ? const Color(0xFFFFF176) : const Color(0xFFD4AF37),
            ),
            title: Text(
              bond.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              isWinner
                  ? 'Won ${DigitNormalizer.formatCurrencyBDT(matches.first.prizeAmount)} in Draw #${matches.first.drawNumber}'
                  : '৳100 Prize Bond',
              style: TextStyle(
                color: isWinner ? const Color(0xFF00FF66) : Colors.white54,
                fontSize: 11,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
