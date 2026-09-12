import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/digit_normalizer.dart';
import '../../core/matching_engine.dart';
import '../../models/bond.dart';
import '../../models/draw.dart';
import '../../services/document_cropper_service.dart';
import '../../services/locale_service.dart';
import '../../services/wallet_service.dart';
import 'manual_add_modal.dart';

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
  final LocaleService _locale = LocaleService();

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
      if (query.isNotEmpty) {
        final matchesSerial = bond.serialNumber.contains(query);
        final matchesSeries = bond.seriesPrefix?.toLowerCase().contains(query) ?? false;
        final matchesTags = bond.tags.any((t) => t.toLowerCase().contains(query));
        if (!matchesSerial && !matchesSeries && !matchesTags) return false;
      }

      if (_selectedSeriesFilter != null) {
        if (bond.seriesPrefix != _selectedSeriesFilter) return false;
      }

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
      builder: (ctx) {
        String currentPath = imagePath;
        int imgKey = 0;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              backgroundColor: const Color(0xFF131D2A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top bar with Rotate and Close
                    Row(
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFFFF176),
                            backgroundColor: Colors.white.withOpacity(0.08),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.rotate_right, size: 18),
                          label: Text(_locale.isBangla ? 'ঘোরান' : 'Rotate'),
                          onPressed: () async {
                            final rotated = await DocumentCropperService().rotateImageFile(currentPath, 90);
                            PaintingBinding.instance.imageCache.clear();
                            PaintingBinding.instance.imageCache.clearLiveImages();
                            setDialogState(() {
                              currentPath = rotated;
                              imgKey++;
                            });
                            setState(() {});
                          },
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 26),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Uncropped Full Document with InteractiveViewer
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(dialogCtx).size.height * 0.65,
                      ),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Image.file(
                          File(currentPath),
                          key: ValueKey('full_dialog_img_$imgKey'),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _locale.isBangla
                          ? 'জুম করতে পিঞ্চ করুন • প্রয়োজন হলে ঘোরান'
                          : 'Pinch to zoom • Tap Rotate if needed',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
                  child: AspectRatio(
                    aspectRatio: 1.75, // Bangladesh banknote aspect ratio
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.black45,
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
                              fit: BoxFit.contain,
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
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      _locale.t('tap_to_view_photo'),
                                      style: const TextStyle(color: Colors.white, fontSize: 11),
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
                ),
              ],
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _locale.isBangla
                              ? DigitNormalizer.toBengaliDigits(bond.displayName)
                              : bond.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        if (hasImage)
                          Row(
                            children: [
                              const Icon(Icons.photo, color: Color(0xFF00FF66), size: 13),
                              const SizedBox(width: 4),
                              Text(
                                _locale.t('attached_photo'),
                                style: const TextStyle(color: Color(0xFF00FF66), fontSize: 11),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFFF5252)),
                    tooltip: _locale.t('delete'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final confirm = await _showDeleteConfirmDialog(bond);
                      if (confirm == true) {
                        await widget.walletService.deleteBond(bond.id);
                        setState(() {});
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (matches.isNotEmpty) ...[
                Text(
                  _locale.t('winning_draw_info'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                              _locale.isBangla ? m.tierNameBn : m.tierName,
                              style: const TextStyle(
                                color: Color(0xFF00FF66),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _locale.formatCurrency(m.prizeAmount),
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
                          '${_locale.t("draw_no")}${_locale.formatNumber(m.drawNumber)} • ${m.drawDate.toIso8601String().substring(0, 10)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          '${_locale.t("net_receivable")}: ${_locale.formatCurrency(m.netPrizeAmount)} (${_locale.t("tax_20")})',
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
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white54, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _locale.t('no_win_in_8'),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _showDeleteConfirmDialog(Bond bond) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _locale.t('delete_confirm_title'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '${_locale.t('delete_confirm_msg')} ${_locale.isBangla ? DigitNormalizer.toBengaliDigits(bond.displayName) : bond.displayName}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_locale.t('cancel'), style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_locale.t('delete')),
          ),
        ],
      ),
    );
  }

  void _openManualAdd() async {
    final result = await showModalBottomSheet<Bond>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ManualAddModal(
        walletService: widget.walletService,
        onOpenScanner: widget.onOpenScanner,
      ),
    );

    if (result != null) {
      setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredBonds();

    return AnimatedBuilder(
      animation: _locale,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0B192C),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0B192C),
            elevation: 0,
            title: Text(
              _locale.t('my_bonds'),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            actions: [
              const LanguageToggleButton(),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00FF66)),
                tooltip: _locale.t('add_bond_action'),
                onPressed: _openManualAdd,
              ),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner, color: Color(0xFFD4AF37)),
                tooltip: _locale.t('scan_bonds_action'),
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
                    hintText: _locale.t('search_bonds'),
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54),
                            onPressed: () => _searchController.clear(),
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
                ),
              ),

              // Filter row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    FilterChip(
                      label: Text(_locale.t('filter_all')),
                      selected: _activeFilter == BondFilter.all,
                      onSelected: (_) {
                        setState(() {
                          _activeFilter = BondFilter.all;
                        });
                      },
                      selectedColor: const Color(0xFF006A4E),
                      labelStyle: TextStyle(
                        color: _activeFilter == BondFilter.all ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: const Icon(Icons.emoji_events, size: 16, color: Color(0xFFFFF176)),
                      label: Text(_locale.t('filter_winning')),
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
                        itemBuilder: (ctx, i) {
                          final bond = filtered[i];
                          final matches = widget.matchingEngine.checkBond(bond);
                          final isWinner = matches.isNotEmpty;
                          final hasImage = bond.imagePath != null && File(bond.imagePath!).existsSync();

                          return Container(
                            decoration: BoxDecoration(
                              color: isWinner
                                  ? const Color(0xFF006A4E).withOpacity(0.2)
                                  : const Color(0xFF131D2A),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isWinner
                                    ? const Color(0xFF00FF66).withOpacity(0.8)
                                    : Colors.white10,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              leading: hasImage
                                  ? GestureDetector(
                                      onTap: () => _showFullImageDialog(context, bond.imagePath!),
                                      child: Container(
                                        width: 56,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5)),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(5),
                                          child: Stack(
                                            alignment: Alignment.bottomRight,
                                            children: [
                                              Image.file(
                                                File(bond.imagePath!),
                                                width: 56,
                                                height: 36,
                                                fit: BoxFit.cover,
                                              ),
                                              Container(
                                                color: Colors.black54,
                                                padding: const EdgeInsets.all(1.5),
                                                child: const Icon(Icons.zoom_in, color: Colors.white, size: 10),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                  : _buildDefaultAvatar(isWinner),
                              title: Row(
                                children: [
                                  Text(
                                    _locale.isBangla
                                        ? DigitNormalizer.toBengaliDigits(bond.displayName)
                                        : bond.displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  if (isWinner) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF006A4E),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _locale.isBangla ? 'বিজয়ী' : 'WINNER',
                                        style: const TextStyle(
                                          color: Color(0xFFFFF176),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                isWinner
                                    ? '${_locale.isBangla ? "বিজয়ী" : "Won"} ${_locale.formatCurrency(matches.first.prizeAmount)} (${_locale.t("draw_no")}${_locale.formatNumber(matches.first.drawNumber)})'
                                    : (_locale.isBangla ? '১০০ টাকা প্রাইজ বন্ড' : '৳100 Prize Bond'),
                                style: TextStyle(
                                  color: isWinner ? const Color(0xFF00FF66) : Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.chevron_right, color: Colors.white38),
                                onPressed: () => _showBondDetails(bond, matches),
                              ),
                              onTap: () => _showBondDetails(bond, matches),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wallet, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              _locale.t('empty_wallet_title'),
              style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _locale.t('empty_wallet_sub'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: widget.onOpenScanner,
                  icon: const Icon(Icons.camera_alt),
                  label: Text(_locale.t('scan_bonds_action')),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD4AF37),
                    side: const BorderSide(color: Color(0xFFD4AF37)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _openManualAdd,
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(_locale.t('add_bond_action')),
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
