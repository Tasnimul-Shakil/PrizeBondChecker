import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/digit_normalizer.dart';
import '../../models/bond.dart';
import '../../services/locale_service.dart';
import '../../services/wallet_service.dart';

class ManualAddModal extends StatefulWidget {
  final WalletService walletService;
  final VoidCallback? onOpenScanner;

  const ManualAddModal({
    super.key,
    required this.walletService,
    this.onOpenScanner,
  });

  @override
  State<ManualAddModal> createState() => _ManualAddModalState();
}

class _ManualAddModalState extends State<ManualAddModal> {
  final TextEditingController _controller = TextEditingController();
  String? _errorMessage;
  bool _isSubmitting = false;
  final LocaleService _locale = LocaleService();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_validateInput);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validateInput() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      if (_errorMessage != null) {
        setState(() => _errorMessage = null);
      }
      return;
    }

    final normalized = DigitNormalizer.normalizeSerial(text);
    if (normalized != null && widget.walletService.containsSerial(normalized)) {
      setState(() {
        _errorMessage = _locale.t('duplicate_bond_msg');
      });
    } else if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    final normalized = DigitNormalizer.normalizeSerial(text);

    if (normalized == null || normalized.length != 7) {
      setState(() {
        _errorMessage = _locale.t('invalid_serial_msg');
      });
      return;
    }

    if (widget.walletService.containsSerial(normalized)) {
      setState(() {
        _errorMessage = _locale.t('duplicate_bond_msg');
      });
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final addedBond = await widget.walletService.addBond(
        serialNumber: normalized,
      );
      if (mounted) {
        Navigator.of(context).pop(addedBond);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _locale,
      builder: (context, _) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF131D2A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF006A4E).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_circle, color: Color(0xFF00FF66), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _locale.t('manual_add_title'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (widget.onOpenScanner != null)
                      InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onOpenScanner?.call();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF006A4E).withOpacity(0.35),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF00FF66).withOpacity(0.6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.camera_alt, color: Color(0xFF00FF66), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                _locale.isBangla ? 'স্ক্যান' : 'Scan',
                                style: const TextStyle(
                                  color: Color(0xFF00FF66),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(7),
                  ],
                  decoration: InputDecoration(
                    hintText: _locale.t('manual_add_hint'),
                    hintStyle: const TextStyle(
                      color: Colors.white30,
                      fontSize: 15,
                      letterSpacing: 0,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF0B192C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF006A4E), width: 2),
                    ),
                    prefixIcon: const Icon(Icons.confirmation_number, color: Color(0xFFD4AF37)),
                    suffixIcon: widget.onOpenScanner != null
                        ? IconButton(
                            icon: const Icon(Icons.camera_alt, color: Color(0xFF00FF66), size: 24),
                            tooltip: _locale.isBangla ? 'ক্যামেরা দিয়ে স্ক্যান' : 'Scan with Camera',
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onOpenScanner?.call();
                            },
                          )
                        : null,
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFFF5252), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFFFF5252), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          _locale.t('cancel'),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFF006A4E),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                _locale.t('manual_add_btn'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }
}
