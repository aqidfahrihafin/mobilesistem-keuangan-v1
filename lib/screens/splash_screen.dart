import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_info_provider.dart';
import '../widgets/app_logo_image.dart';
import '../widgets/geometric_pattern.dart';

const _teal = Color(0xFF0F766E);
const _tealDark = Color(0xFF115E59);

/// Shown while [AuthService] restores the previous session, held for a
/// minimum visible duration by [AuthGate] so it never just flashes on a
/// fast restore - a real app leaves its brand on screen long enough to
/// register, not for exactly as long as a network call happens to take.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_teal, _tealDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: GeometricPatternBackground(opacity: 0.07),
            ),
            Center(
              child: _SplashMark(reduceMotion: reduceMotion),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: Column(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation(
                        Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.watch<AppInfoProvider>().namaPondok ?? 'Pondok Pesantren Latee',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashMark extends StatelessWidget {
  final bool reduceMotion;

  const _SplashMark({required this.reduceMotion});

  @override
  Widget build(BuildContext context) {
    final logo = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(18),
          child: const AppLogoImage(),
        ),
        const SizedBox(height: 20),
        Text(
          context.watch<AppInfoProvider>().namaAplikasi ?? 'E-Mall Annuqayah',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Keuangan Santri, dalam Genggaman',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 13,
          ),
        ),
      ],
    );

    if (reduceMotion) return logo;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.scale(scale: 0.85 + (0.15 * value), child: child),
        );
      },
      child: logo,
    );
  }
}
