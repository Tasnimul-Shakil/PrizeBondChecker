import 'package:flutter/material.dart';
import '../../core/digit_normalizer.dart';
import '../../core/matching_engine.dart';
import '../../models/bond.dart';
import '../../services/draw_service.dart';
import '../../services/locale_service.dart';
import '../../services/wallet_service.dart';
import '../wallet/manual_add_modal.dart';

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
  final LocaleService _locale = LocaleService();

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

  void _openManualAdd() async {
    final res = await showModalBottomSheet<Bond>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ManualAddModal(
        walletService: widget.walletService,
        onOpenScanner: widget.onOpenScanner,
      ),
    );

    if (res != null) {
      _recalculateSummary();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF006A4E),
            content: Text(_locale.t('bond_added_msg')),
          ),
        );
      }
    }
  }

  void _showAllResultsModal() {
    _recalculateSummary();
    final summary = _summary;
    final winningBonds = summary?.winningBonds ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131D2A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        winningBonds.isNotEmpty ? Icons.emoji_events : Icons.verified,
                        color: winningBonds.isNotEmpty ? const Color(0xFFFFF176) : const Color(0xFF00FF66),
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          winningBonds.isNotEmpty
                              ? _locale.t('modal_winning_title')
                              : _locale.t('modal_no_win_title'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B192C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildModalStat(
                          _locale.t('total_bonds'),
                          _locale.formatNumber(widget.walletService.count),
                        ),
                        Container(width: 1, height: 28, color: Colors.white12),
                        _buildModalStat(
                          _locale.t('winning_bonds'),
                          _locale.formatNumber(winningBonds.length),
                          valueColor: const Color(0xFF00FF66),
                        ),
                        Container(width: 1, height: 28, color: Colors.white12),
                        _buildModalStat(
                          _locale.t('total_won'),
                          _locale.formatCurrency(summary?.totalPrizeAmount ?? 0.0),
                          valueColor: const Color(0xFFFFF176),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (winningBonds.isEmpty) ...[
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sentiment_satisfied_alt, color: Colors.white30, size: 54),
                            const SizedBox(height: 12),
                            Text(
                              _locale.t('modal_checked_msg'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _locale.t('modal_better_luck'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: winningBonds.length,
                        itemBuilder: (ctx, i) {
                          final bond = winningBonds[i];
                          final matches = widget.matchingEngine.checkBond(bond);
                          if (matches.isEmpty) return const SizedBox();
                          final firstMatch = matches.first;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF006A4E).withOpacity(0.35),
                                  const Color(0xFF131D2A),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF006A4E)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF006A4E),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _locale.isBangla
                                            ? DigitNormalizer.toBengaliDigits(bond.displayName)
                                            : bond.displayName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _locale.formatCurrency(firstMatch.prizeAmount),
                                      style: const TextStyle(
                                        color: Color(0xFFFFF176),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${_locale.isBangla ? firstMatch.tierNameBn : firstMatch.tierName} • ${_locale.t('draw_no')}${_locale.formatNumber(firstMatch.drawNumber)}',
                                  style: const TextStyle(color: Color(0xFF00FF66), fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${_locale.t('net_receivable')}: ${_locale.formatCurrency(firstMatch.netPrizeAmount)} (${_locale.t('tax_20')})',
                                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF006A4E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(_locale.t('close'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalStat(String label, String value, {Color valueColor = Colors.white}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bondsCount = widget.walletService.count;
    final totalInvestment = widget.walletService.totalPortfolioValue;
    final winningAmount = _summary?.totalPrizeAmount ?? 0.0;
    final winningCount = _summary?.winningBondsCount ?? 0;
    final latestDraw = widget.drawService.latestDraw;

    return AnimatedBuilder(
      animation: _locale,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0B192C),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0B192C),
            elevation: 0,
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF006A4E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.stars, color: Color(0xFFD4AF37), size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _locale.t('app_name'),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              const LanguageToggleButton(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                tooltip: _locale.isBangla ? 'রিফ্রেশ' : 'Refresh',
                onPressed: () {
                  _recalculateSummary();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 1),
                      backgroundColor: const Color(0xFF006A4E),
                      content: Text(
                        _locale.isBangla
                            ? 'সবগুলো ড্রয়ের সাথে ফলাফল যাচাই করা হয়েছে!'
                            : 'Results re-checked across all 8 draws!',
                      ),
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

                // 2. Check All Results Action Button
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD4AF37), Color(0xFFAA820A)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _showAllResultsModal,
                    icon: const Icon(Icons.verified, color: Color(0xFF0B192C), size: 22),
                    label: Text(
                      _locale.t('check_all_bonds'),
                      style: const TextStyle(
                        color: Color(0xFF0B192C),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Quick Actions Grid (Clean, Range-free)
                Text(
                  _locale.t('quick_actions'),
                  style: const TextStyle(
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
                    Text(
                      _locale.t('recent_bonds'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: widget.onOpenWallet,
                      child: Text(
                        _locale.t('see_all'),
                        style: const TextStyle(color: Color(0xFFD4AF37)),
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
      },
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
        border: Border.all(color: const Color(0xFF006A4E).withOpacity(0.6)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _locale.t('total_investment'),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _locale.formatCurrency(totalInvestment.toDouble()),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.confirmation_number, color: Color(0xFFFFF176), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${_locale.formatNumber(bondsCount)} ${_locale.isBangla ? 'টি বন্ড' : 'Bonds'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniMetric(
                label: _locale.t('winning_bonds'),
                value: _locale.formatNumber(winningCount),
                color: winningCount > 0 ? const Color(0xFF00FF66) : Colors.white70,
              ),
              _buildMiniMetric(
                label: _locale.t('total_won'),
                value: _locale.formatCurrency(winningAmount),
                color: const Color(0xFFFFF176),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildActionTile(
            icon: Icons.camera_alt,
            title: _locale.t('scan_bonds_action'),
            subtitle: _locale.t('scan_bonds_sub'),
            color: const Color(0xFF006A4E),
            onTap: widget.onOpenScanner,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionTile(
            icon: Icons.add_circle_outline,
            title: _locale.t('add_bond_action'),
            subtitle: _locale.t('add_bond_sub'),
            color: const Color(0xFF1E3E62),
            onTap: _openManualAdd,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionTile(
            icon: Icons.emoji_events_outlined,
            title: _locale.t('draw_results_action'),
            subtitle: _locale.t('draw_results_sub'),
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
        color: const Color(0xFF131D2A),
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
                  '${_locale.t('latest_draw')}: ${_locale.t('draw_no')}${_locale.formatNumber(draw.drawNumber)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_locale.t('draw_date')}: ${draw.drawDate.toIso8601String().substring(0, 10)} • ${_locale.isBangla ? "১ম পুরস্কার ১৬ লাখ" : "1st Prize 16L"}',
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
          color: const Color(0xFF131D2A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Center(
          child: Text(
            '${_locale.t('no_bonds_dash')}\n${_locale.t('no_bonds_dash_sub')}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
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
              : const Color(0xFF131D2A),
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
              _locale.isBangla ? DigitNormalizer.toBengaliDigits(bond.displayName) : bond.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              isWinner
                  ? '${_locale.isBangla ? "বিজয়ী" : "Won"} ${_locale.formatCurrency(matches.first.prizeAmount)} • ${_locale.t("draw_no")}${_locale.formatNumber(matches.first.drawNumber)}'
                  : (_locale.isBangla ? '১০০ টাকা প্রাইজ বন্ড' : '৳100 Prize Bond'),
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
