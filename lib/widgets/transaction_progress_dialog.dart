import 'dart:async';

import 'package:flutter/material.dart';

Future<T> runWithTransactionProgress<T>(
  BuildContext context, {
  required String message,
  required Future<T> Function() action,
}) async {
  final dialogReady = Completer<BuildContext>();

  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      if (!dialogReady.isCompleted) dialogReady.complete(context);
      return PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  ));
  final dialogContext = await dialogReady.future;

  try {
    return await action();
  } finally {
    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
  }
}
