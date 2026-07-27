import 'package:flutter/material.dart';

import 'pin_box_field.dart';
import 'glass_modal_surface.dart';

const _teal = Color(0xFF0F766E);

/// Asks for the 6-digit transaction PIN before a sensitive action (kantin
/// payment, tagihan-from-saldo, transfer antar santri) proceeds. Returns the
/// entered PIN once all 6 digits are in, or null if the sheet is dismissed/
/// cancelled. The PIN itself is only ever verified server-side - this sheet
/// just collects it; the caller is responsible for surfacing a wrong-PIN or
/// locked-out error the same way it already surfaces other API errors.
Future<String?> showPinEntrySheet(
  BuildContext context, {
  String title = 'Masukkan PIN Transaksi',
  String? subtitle,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x520F172A),
    builder: (_) => GlassModalSurface(
      child: _PinEntrySheet(title: title, subtitle: subtitle),
    ),
  );
}

class _PinEntrySheet extends StatefulWidget {
  final String title;
  final String? subtitle;

  const _PinEntrySheet({required this.title, this.subtitle});

  @override
  State<_PinEntrySheet> createState() => _PinEntrySheetState();
}

class _PinEntrySheetState extends State<_PinEntrySheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.lock_rounded, color: _teal, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              PinBoxField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                onCompleted: (pin) => Navigator.of(context).pop(pin),
              ),
              const SizedBox(height: 18),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Batal',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
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
