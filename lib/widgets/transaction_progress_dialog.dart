import 'dart:async';

import 'package:flutter/material.dart';

Future<T> runWithTransactionProgress<T>(
  BuildContext context, {
  required String message,
  required Future<T> Function() action,
}) async {
  final dialogReady = Completer<BuildContext>();

  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        if (!dialogReady.isCompleted) dialogReady.complete(context);
        return _TransactionProgressDialog(message: message);
      },
    ),
  );
  final dialogContext = await dialogReady.future;

  try {
    return await action();
  } finally {
    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
  }
}

class _TransactionProgressDialog extends StatefulWidget {
  final String message;

  const _TransactionProgressDialog({required this.message});

  @override
  State<_TransactionProgressDialog> createState() =>
      _TransactionProgressDialogState();
}

class _TransactionProgressDialogState extends State<_TransactionProgressDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 30),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 104,
                  height: 104,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEAF5F3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      RotationTransition(
                        turns: _controller,
                        child: const SizedBox(
                          width: 100,
                          height: 100,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            backgroundColor: Color(0xFFDDEDEA),
                            color: Color(0xFF0F766E),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 39,
                        color: Color(0xFF0F766E),
                      ),
                      const Positioned(
                        right: 3,
                        bottom: 8,
                        child: CircleAvatar(
                          radius: 13,
                          backgroundColor: Color(0xFF0F766E),
                          child: Icon(
                            Icons.shield_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Transaksi sedang diproses',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17212B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAF9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8E4)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 15,
                        color: Color(0xFF0F766E),
                      ),
                      SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'Terhubung aman · Mohon tunggu',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
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
