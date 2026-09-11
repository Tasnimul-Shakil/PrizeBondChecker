import 'package:flutter/material.dart';
import '../../core/digit_normalizer.dart';
import '../../models/bond.dart';
import '../../services/wallet_service.dart';

/// Modal dialog for entering a sequential range of prize bonds at once.
class RangeInputModal extends StatefulWidget {
  final WalletService walletService;

  const RangeInputModal({super.key, required this.walletService});

  @override
  State<RangeInputModal> createState() => _RangeInputModalState();
}

class _RangeInputModalState extends State<RangeInputModal> {
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _tagController = TextEditingController();

  int _calculatedCount = 0;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _startController.addListener(_calculateCount);
    _endController.addListener(_calculateCount);
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _calculateCount() {
    final start = DigitNormalizer.normalizeSerial(_startController.text);
    final end = DigitNormalizer.normalizeSerial(_endController.text);

    if (start != null && end != null) {
      final s = int.tryParse(start);
      final e = int.tryParse(end);
      if (s != null && e != null && e >= s) {
        setState(() {
          _calculatedCount = e - s + 1;
          _errorMessage = _calculatedCount > 500
              ? 'Maximum 500 bonds per batch allowed.'
              : null;
        });
        return;
      }
    }

    setState(() {
      _calculatedCount = 0;
      _errorMessage = null;
    });
  }

  Future<void> _submitRange() async {
    final start = DigitNormalizer.normalizeSerial(_startController.text);
    final end = DigitNormalizer.normalizeSerial(_endController.text);

    if (start == null || end == null) {
      setState(() {
        _errorMessage = 'Please enter valid 7-digit numbers for both start and end.';
      });
      return;
    }

    if (_calculatedCount <= 0 || _calculatedCount > 500) {
      setState(() {
        _errorMessage = 'Invalid range count (1 to 500 bonds allowed).';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final List<Bond> generated = await widget.walletService.addBondRange(
        startSerial: start,
        endSerial: end,
        tag: _tagController.text.trim().isNotEmpty
            ? _tagController.text.trim()
            : null,
      );

      if (mounted) {
        Navigator.pop(context, generated);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Row(
              children: [
                const Icon(Icons.format_list_numbered, color: Color(0xFFD4AF37), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Add Sequential Bond Range',
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

            // Start & End inputs
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startController,
                    keyboardType: TextInputType.number,
                    maxLength: 7,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: 'Start Serial',
                      hintText: '0154201',
                      hintStyle: const TextStyle(color: Colors.white24),
                      labelStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, color: Colors.white38),
                ),
                Expanded(
                  child: TextField(
                    controller: _endController,
                    keyboardType: TextInputType.number,
                    maxLength: 7,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: 'End Serial',
                      hintText: '0154250',
                      hintStyle: const TextStyle(color: Colors.white24),
                      labelStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tag input
            TextField(
              controller: _tagController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Batch Tag (Optional, e.g. Sonali Bank Purchase)',
                labelStyle: const TextStyle(color: Colors.white60),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Calculation preview banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _calculatedCount > 0 ? const Color(0xFFD4AF37) : Colors.white12,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFD4AF37), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _calculatedCount > 0
                          ? 'Total: $_calculatedCount bonds (${DigitNormalizer.formatCurrencyBDT(_calculatedCount * 100)})'
                          : 'Enter start and end 7-digit numbers to preview',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],

            const SizedBox(height: 20),

            // Add Range Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006A4E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _calculatedCount > 0 && !_isSubmitting ? _submitRange : null,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Add $_calculatedCount Bonds to Wallet',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
