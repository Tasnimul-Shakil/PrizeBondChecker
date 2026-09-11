import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/digit_normalizer.dart';
import '../../core/matching_engine.dart';
import '../../models/bond.dart';
import '../../models/draw.dart';
import '../../services/wallet_service.dart';
import 'range_input_modal.dart';

enum BondFilter { all, winningOnly }

class WalletScreen extends StatefulWidget {
  final WalletService walletService;
  final MatchingEngine matchingEngine;
  final VoidCallback onOpenScanner;

  const WalletScreen({
    super.key,
    required this.walletService,
    required this.matchingEngine,
    required this.onOpenScanner,
  });

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final TextEditingController _searchController = TextEditingController();
  BondFilter _activeFilter = BondFilter.all;
  String? _selectedSeriesFilter;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Bond> _getFilteredBonds() {
    final query = _searchController.text.trim().toLowerCase();
    final allBonds = widget.walletService.bonds;

    return allBonds.where((bond) {
      // 1. Search Query
      if (query.isNotEmpty) {
        final matchesSerial = bond.serialNumber.contains(query);
        final matchesSeries = bond.seriesPrefix?.toLowerCase().contains(query) ?? false;
        final matchesTags = bond.tags.any((t) => t.toLowerCase().contains(query));
        if (!matchesSerial && !matchesSeries && !matchesTags) return false;
      }

      // 2. Series Filter
      if (_selectedSeriesFilter != null) {
        if (bond.seriesPrefix != _selectedSeriesFilter) return false;
      }

      // 3. Winning Filter
      if (_activeFilter == BondFilter.winningOnly) {
        final matches = widget.matchingEngine.checkBond(bond);
        if (matches.isEmpty) return false;
      }

      return true;
    }).toList();
  }

  void _showFullImageDialog(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBondDetails(Bond bond, List<PrizeMatchResult> matches) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131D2A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final hasImage = bond.imagePath != null && File(bond.imagePath!).existsSync();

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (hasImage) ...[
                GestureDetector(
                  onTap: () => _showFullImageDialog(context, bond.imagePath!),
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(bond.imagePath!),
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.zoom_in, color: Color(0xFFFFF176), size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Tap to Enlarge Photo',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              Row(
                children: [
                  Text(
                    bond.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await widget.walletService.deleteBond(bond.id);
                      setState(() {});
                    },
                  ),
                ],
              ),
              Text(
                'Bengali: ${DigitNormalizer.toBengaliDigits(bond.displayName)}',
                style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (matches.isNotEmpty) ...[
                const Text(
                  'Winning Draw Details:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...matches.map((m) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF006A4E).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF006A4E)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${m.tierName} (${m.tierNameBn})',
                              style: const TextStyle(
                                color: Color(0xFF00FF66),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DigitNormalizer.formatCurrencyBDT(m.prizeAmount),
                              style: const TextStyle(
                                color: Color(0xFFFFF176),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Draw #${m.drawNumber} • ${m.drawDate.toIso8601String().substring(0, 10)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          'Net after 20% tax: ${DigitNormalizer.formatCurrencyBDT(m.netPrizeAmount)}',
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  );
                }),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white54, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'No winning matches in recent 8 draws (2 years).',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (bond.tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  children: bond.tags.map((t) {
                    return Chip(
                      label: Text(t, style: const TextStyle(fontSize: 11, color: Colors.white)),
                      backgroundColor: Colors.white12,
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openRangeInput() async {
    final result = await showModalBottomSheet<List<Bond>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RangeInputModal(walletService: widget.walletService),
    );

    if (result != null) {
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF006A4E),
            content: Text('Added ${result.length} bonds to your collection!'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredBonds();

    // Calculate unique series for filter chips
    final allSeries = widget.walletService.bonds
        .map((b) => b.seriesPrefix)
        .where((s) => s != null && s.isNotEmpty)
        .toSet()
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B192C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B192C),
        elevation: 0,
        title: const Text(
          'My Prize Bonds',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_to_photos, color: Color(0xFFD4AF37)),
            tooltip: 'Add Range',
            onPressed: _openRangeInput,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF00FF66)),
            tooltip: 'Scan Camera',
            onPressed: widget.onOpenScanner,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filters Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search serial, series, or tag...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E2D40),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Filter row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Bonds'),
                  selected: _activeFilter == BondFilter.all && _selectedSeriesFilter == null,
                  onSelected: (_) {
                    setState(() {
                      _activeFilter = BondFilter.all;
                      _selectedSeriesFilter = null;
                    });
                  },
                  selectedColor: const Color(0xFF006A4E),
                  labelStyle: TextStyle(
                    color: _activeFilter == BondFilter.all && _selectedSeriesFilter == null
                        ? Colors.white
                        : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.emoji_events, size: 16, color: Color(0xFFFFF176)),
                  label: const Text('Winners Only'),
                  selected: _activeFilter == BondFilter.winningOnly,
                  onSelected: (selected) {
                    setState(() {
                      _activeFilter = selected ? BondFilter.winningOnly : BondFilter.all;
                    });
                  },
                  selectedColor: const Color(0xFF006A4E),
                  labelStyle: TextStyle(
                    color: _activeFilter == BondFilter.winningOnly ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (allSeries.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ...allSeries.map((series) {
                    final isSelected = _selectedSeriesFilter == series;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text('Series $series'),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedSeriesFilter = selected ? series : null;
                          });
                        },
                        selectedColor: const Color(0xFFD4AF37),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Bonds List or Empty state
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final bond = filtered[index];
                      final matches = widget.matchingEngine.checkBond(bond);
                      final isWinner = matches.isNotEmpty;

                      return Card(
                        color: isWinner
                            ? const Color(0xFF006A4E).withOpacity(0.25)
                            : const Color(0xFF172333),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isWinner ? const Color(0xFF00FF66) : Colors.white12,
                            width: isWinner ? 1.5 : 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          onTap: () => _showBondDetails(bond, matches),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: (bond.imagePath != null && File(bond.imagePath!).existsSync())
                                  ? GestureDetector(
                                      onTap: () => _showFullImageDialog(context, bond.imagePath!),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.file(
                                            File(bond.imagePath!),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => _buildDefaultAvatar(isWinner),
                                          ),
                                          Positioned(
                                            bottom: 2,
                                            right: 2,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: Colors.black87,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Icon(Icons.zoom_in, color: Colors.white70, size: 10),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : _buildDefaultAvatar(isWinner),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                bond.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DigitNormalizer.toBengaliDigits(bond.serialNumber),
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          subtitle: isWinner
                              ? Text(
                                  '🎉 Won ${DigitNormalizer.formatCurrencyBDT(matches.first.prizeAmount)} (${matches.first.tierName})',
                                  style: const TextStyle(
                                    color: Color(0xFF00FF66),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                )
                              : Text(
                                  bond.tags.isNotEmpty ? bond.tags.join(', ') : '৳100 Prize Bond',
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'No Prize Bonds Found',
              style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan physical bonds with your camera or add a sequential serial range.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006A4E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: widget.onOpenScanner,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Scan Bonds'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD4AF37),
                    side: const BorderSide(color: Color(0xFFD4AF37)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: _openRangeInput,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Range'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(bool isWinner) {
    return CircleAvatar(
      backgroundColor: isWinner
          ? const Color(0xFF006A4E)
          : Colors.white.withOpacity(0.08),
      child: Icon(
        isWinner ? Icons.emoji_events : Icons.confirmation_number,
        color: isWinner ? const Color(0xFFFFF176) : const Color(0xFFD4AF37),
      ),
    );
  }
}
