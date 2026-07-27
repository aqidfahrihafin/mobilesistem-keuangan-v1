import 'package:flutter/material.dart';

import 'glass_modal_surface.dart';

const _teal = Color(0xFF0F766E);

/// A short-lived "berhasil" dialog shown right after a money-moving action
/// completes (bayar tagihan, top up dst.) - not just a checkmark for its own
/// sake: [sinkronkan], if given, is kicked off *immediately* (not awaited
/// first) so it runs in the background *while* this dialog is on screen.
/// The "Selesai" button stays disabled/spinning until it finishes (with a
/// short minimum display time so it never looks like a flash even when the
/// refresh is instant). By the time a wali dismisses this and lands back on
/// the list/dashboard behind it, that screen's data is already fresh -
/// nothing visibly updates a moment later, which is what makes the whole
/// thing read as "realtime" rather than a lucky-timed refresh.
Future<void> showSuccessDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  List<(String label, String value)> rincian = const [],
  Future<void> Function()? sinkronkan,
}) async {
  final syncFuture = Future.wait([
    if (sinkronkan != null)
      sinkronkan().catchError((_) {
        // A background refresh failing shouldn't block the wali from
        // dismissing a dialog telling them their action already succeeded -
        // the next natural screen visit/poll retries it anyway.
      }),
    // Minimum display time so the dialog reads as a deliberate confirmation
    // even when the sync above resolves near-instantly, not a flash.
    Future.delayed(const Duration(milliseconds: 700)),
  ]);

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SuccessDialog(
      title: title,
      subtitle: subtitle,
      rincian: rincian,
      syncFuture: syncFuture,
    ),
  );
}

class _SuccessDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<(String, String)> rincian;
  final Future<void> syncFuture;

  const _SuccessDialog({
    required this.title,
    required this.subtitle,
    required this.rincian,
    required this.syncFuture,
  });

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog> {
  bool _syncing = true;

  @override
  void initState() {
    super.initState();
    widget.syncFuture.whenComplete(() {
      if (mounted) setState(() => _syncing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Deliberately not dismissible by tapping outside or the system back
      // gesture while syncing - popping this early is exactly the "leaves
      // before the refresh lands" case the whole dialog exists to prevent.
      canPop: !_syncing,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: GlassModalSurface(
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 32, 26, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF15803D),
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                if (widget.rincian.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < widget.rincian.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.rincian[i].$1,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                widget.rincian[i].$2,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _teal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _syncing
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: _syncing
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text('Menyinkronkan...'),
                            ],
                          )
                        : const Text(
                            'Selesai',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
