import 'package:flutter/material.dart';
import '../../core/digit_normalizer.dart';
import '../../core/matching_engine.dart';
import '../../models/bond.dart';
import '../../models/draw.dart';

/// Bottom modal sheet shown after a single bond is scanned to allow manual verification,
/// instant prize match checking, and saving.
class PreviewEditModal extends StatefulWidget {
  final String initialSerial;
  final String? initialSeries;
  final MatchingEngine matchingEngine;

  const PreviewEditModal({
    super.key,
    required this.initialSerial,
    this.initialSeries,
    required this.matchingEngine,
  });

  @override
  State<PreviewEditModal> createState() => _PreviewEditModalState();
}

class _PreviewEditModalState extends State<PreviewEditModal> {
  late final TextEditingController _serialController;
  late final TextEditingController _seriesController;
  late final TextEditingController _tagController;

  List<PrizeMatchResult> _instantMatches = [];

  @override
  void initState() {
    super.initState();
    _serialController = TextEditingController(text: widget.initialSerial);
    _seriesController = TextEditingController(text: widget.initialSeries ?? '');
    _tagController = TextEditingController();

    _runInstantCheck();
    _serialController.addListener(_runInstantCheck);
  }

  @override
  void dispose() {
    _serialController.dispose();
    _seriesController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _runInstantCheck() {
    final serial = DigitNormalizer.normalizeSerial(_serialController.text);
    if (serial != null && serial.length == 7) {
      final matches = widget.matchingEngine.checkSerialString(
        serial,
        series: _seriesController.text.trim(),
      );
      setState(() {
        _instantMatches = matches;
      });
    } else {
      setState(() {
        _instantMatches = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWinner = _instantMatches.isNotEmpty;
    final currentSerial = _serialController.text;
    final bengaliPreview = DigitNormalizer.toBengaliDigits(currentSerial);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF131D2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
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

            // Header
            Row(
              children: [
                const Icon(Icons.verified, color: Color(0xFFD4AF37), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Verify Scanned Bond',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Instant Winner Alert Banner
            if (isWinner) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF006A4E), Color(0xFF0F9D58)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F9D58).withOpacity(0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'WINNING BOND DETECTED!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_instantMatches.first.tierName} (${_instantMatches.first.tierNameBn}) - ${DigitNormalizer.formatCurrencyBDT(_instantMatches.first.prizeAmount)}',
                            style: const TextStyle(
                              color: Color(0xFFFFF176),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Draw #${_instantMatches.first.drawNumber}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Input Fields
            Row(
              children: [
                // Series input
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _seriesController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Series',
                      labelStyle: const TextStyle(color: Colors.white60),
                      hintText: 'কখ',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 7-digit Serial input
                Expanded(
                  child: TextField(
                    controller: _serialController,
                    keyboardType: TextInputType.number,
                    maxLength: 7,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: '7-Digit Serial',
                      labelStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Bengali Numeral preview
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Text(
                    'Bengali Digits: ',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    bengaliPreview,
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    '৳100 Prize Bond',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Optional Tag input
            TextField(
              controller: _tagController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Tag / Note (Optional, e.g. Gift, Family)',
                labelStyle: const TextStyle(color: Colors.white60),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // Confirm & Save Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006A4E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                final serial = DigitNormalizer.normalizeSerial(_serialController.text);
                if (serial == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Colors.redAccent,
                      content: Text('Please enter a valid 7-digit bond serial number.'),
                    ),
                  );
                  return;
                }

                final confirmedBond = Bond(
                  serialNumber: serial,
                  seriesPrefix: _seriesController.text.trim().isNotEmpty
                      ? _seriesController.text.trim()
                      : null,
                  tags: _tagController.text.trim().isNotEmpty
                      ? [_tagController.text.trim()]
                      : [],
                );

                Navigator.pop(context, confirmedBond);
              },
              child: const Text(
                'Confirm & Save to Wallet',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
