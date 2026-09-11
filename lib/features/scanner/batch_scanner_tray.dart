import 'package:flutter/material.dart';
import '../../core/digit_normalizer.dart';
import '../../models/bond.dart';

/// Bottom tray displayed during Batch Scanning Mode.
/// Displays live count, recent captures, and "Save All" action.
class BatchScannerTray extends StatefulWidget {
  final List<Bond> capturedBonds;
  final ValueChanged<int> onRemoveBond;
  final VoidCallback onSaveAll;

  const BatchScannerTray({
    super.key,
    required this.capturedBonds,
    required this.onRemoveBond,
    required this.onSaveAll,
  });

  @override
  State<BatchScannerTray> createState() => _BatchScannerTrayState();
}

class _BatchScannerTrayState extends State<BatchScannerTray> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final count = widget.capturedBonds.length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0B192C).withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle / expand toggle
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Summary bar
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF006A4E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.layers, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Batch Mode: $count Bonds',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        count == 0
                            ? 'Point camera at bonds sequentially'
                            : 'Investment: ${DigitNormalizer.formatCurrencyBDT(count * 100)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                  ),
                ],
              ),

              // Expanded horizontal list of captured bonds
              if (_isExpanded && count > 0) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: count,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final bond = widget.capturedBonds[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (bond.seriesPrefix != null)
                                  Text(
                                    bond.seriesPrefix!,
                                    style: const TextStyle(
                                      color: Color(0xFFD4AF37),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                Text(
                                  bond.serialNumber,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => widget.onRemoveBond(index),
                              child: const Icon(Icons.close, color: Colors.white54, size: 16),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Save All button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: count > 0 ? const Color(0xFF006A4E) : Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: count > 0 ? widget.onSaveAll : null,
                  icon: const Icon(Icons.save_alt),
                  label: Text(
                    count > 0 ? 'Save $count Bonds to Wallet' : 'Scan Bonds to Begin',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
