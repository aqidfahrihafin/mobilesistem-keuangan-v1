import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../widgets/app_logo_image.dart';

const _teal = Color(0xFF0F766E);
const _bg = Colors.transparent;

class _Slide {
  final IconData icon;
  final String title;
  final String description;

  const _Slide({
    required this.icon,
    required this.title,
    required this.description,
  });
}

const _slides = [
  _Slide(
    icon: Icons.account_balance_wallet_rounded,
    title: 'Pantau Saldo Real-Time',
    description:
        'Cek saldo santri kapan saja, di mana saja, langsung dari genggaman Anda.',
  ),
  _Slide(
    icon: Icons.receipt_long_rounded,
    title: 'Bayar Tagihan Lebih Mudah',
    description:
        'Bayar tagihan pondok dari saldo atau langsung via transfer/QRIS, tanpa antre.',
  ),
  _Slide(
    icon: Icons.bar_chart_rounded,
    title: 'Laporan yang Transparan',
    description:
        'Semua transaksi tercatat rapi, lengkap dengan laporan yang bisa diunduh sebagai evaluasi.',
  ),
  _Slide(
    icon: Icons.fingerprint_rounded,
    title: 'Aman dengan Sidik Jari',
    description:
        'Lindungi akun Anda dengan kunci sidik jari dan sesi otomatis logout saat tidak aktif.',
  ),
];

/// Shown once, on the first launch of a fresh install (before any login) -
/// [AuthGate] gates this on `!isLoggedIn && !hasOnboarded`, and an already-
/// logged-in device (e.g. upgrading from a build before this existed) is
/// marked onboarded automatically so it never interrupts an existing user.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() => context.read<AuthService>().completeOnboarding();

  void _next() {
    if (_page == _slides.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 12, 0),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xDCF4F9F8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xCCFFFFFF)),
                    ),
                    child: const AppLogoImage(),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'E-Mall Annuqayah',
                      style: TextStyle(
                        color: Color(0xFF17212B),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Visibility(
                    visible: !isLast,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: TextButton(
                      onPressed: _finish,
                      child: Text(
                        'Lewati',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, index) =>
                    _SlideView(slide: _slides[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: active ? _teal : const Color(0xFFD8DBE2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(
                        isLast ? 'Mulai' : 'Lanjut',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

class _SlideView extends StatelessWidget {
  final _Slide slide;

  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 126,
              height: 126,
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _teal.withValues(alpha: 0.1)),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF169A8E), _teal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: _teal.withValues(alpha: 0.2),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(slide.icon, color: Colors.white, size: 34),
              ),
            ),
            const SizedBox(height: 34),
            Text(
              slide.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF17212B),
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              slide.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF667085),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
