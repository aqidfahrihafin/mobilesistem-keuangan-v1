import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass_modal_surface.dart';

const _teal = Color(0xFF0F766E);

/// A rounded, icon-led confirmation dialog matching the app's flat visual
/// language - used in place of the default Material AlertDialog wherever a
/// "are you sure" moment needs a real confirmation, not just a plain
/// system-styled box. Pass either [message] (simple text) or [content] (a
/// richer widget, e.g. a breakdown box) - not both.
class ConfirmDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? message;
  final Widget? content;
  final String confirmText;
  final String cancelText;
  final Color confirmColor;

  const ConfirmDialog({
    super.key,
    required this.icon,
    this.iconColor = _teal,
    required this.title,
    this.message,
    this.content,
    this.confirmText = 'Ya, Lanjutkan',
    this.cancelText = 'Batal',
    this.confirmColor = _teal,
  });

  /// Shows the dialog and resolves to true (confirmed), false (cancelled
  /// via button), or null (dismissed by tapping outside/back button).
  static Future<bool?> show(
    BuildContext context, {
    required IconData icon,
    Color iconColor = _teal,
    required String title,
    String? message,
    Widget? content,
    String confirmText = 'Ya, Lanjutkan',
    String cancelText = 'Batal',
    Color confirmColor = _teal,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        icon: icon,
        iconColor: iconColor,
        title: title,
        message: message,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: confirmColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: GlassModalSurface(
        borderRadius: AppRadius.borderRadius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              ],
              if (content != null) ...[const SizedBox(height: 14), content!],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(
                          cancelText,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: confirmColor,
                          elevation: 0,
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.borderRadius,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(
                          confirmText,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
