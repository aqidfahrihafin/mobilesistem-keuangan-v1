import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Loading layar penuh yang ringan dan konsisten.
///
/// Dibangun hanya dengan widget Flutter sehingga tidak menambah aset gambar,
/// dependensi, atau pekerjaan decoding bitmap ketika data sedang dimuat.
class LoadingStateView extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;

  const LoadingStateView({
    super.key,
    this.title = 'Menyiapkan data',
    this.message = 'Mohon tunggu sebentar.',
    this.icon = Icons.hourglass_top_rounded,
  });

  @override
  State<LoadingStateView> createState() => _LoadingStateViewState();
}

class _LoadingStateViewState extends State<LoadingStateView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Center(
      child: Semantics(
        liveRegion: true,
        label: '${widget.title}. ${widget.message}',
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 86,
                height: 86,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFFEAF5F3),
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.expand(),
                    ),
                    if (!reduceMotion)
                      RotationTransition(
                        turns: _controller,
                        child: const SizedBox(
                          width: 82,
                          height: 82,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            backgroundColor: Color(0xFFD9ECE8),
                          ),
                        ),
                      ),
                    Icon(widget.icon, size: 34, color: AppColors.primary),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
