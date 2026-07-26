import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../widgets/app_logo_image.dart';
import '../widgets/flat_card.dart';

const _bg = Colors.transparent;
const _teal = Color(0xFF0F766E);

/// Shown by AuthGate whenever AuthService.needsBiometricUnlock is true -
/// either at a cold start with biometric login enabled, or after
/// SessionActivityGuard soft-locks the app for inactivity. The token stays
/// valid throughout; this is purely a local gate in front of it.
class BiometricUnlockScreen extends StatefulWidget {
  const BiometricUnlockScreen({super.key});

  @override
  State<BiometricUnlockScreen> createState() => _BiometricUnlockScreenState();
}

class _BiometricUnlockScreenState extends State<BiometricUnlockScreen> {
  bool _checking = false;
  String? _error;
  bool _showGantiPassword = false;

  @override
  void initState() {
    super.initState();
    // Prompt immediately on arrival - the tap-to-retry circle below covers
    // cancellation/failure, so the wali doesn't have to tap twice on the
    // common path.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_checking) return;

    setState(() {
      _checking = true;
      _error = null;
    });

    final result = await context.read<AuthService>().unlockWithBiometrics();

    if (!mounted) return;

    switch (result) {
      case BiometricAuthResult.success:
        break; // AuthGate rebuilds automatically.
      case BiometricAuthResult.notSupported:
      case BiometricAuthResult.notEnrolled:
        setState(() {
          _error =
              'Sidik jari tidak tersedia lagi di perangkat ini. Silakan masuk dengan kata sandi.';
          _showGantiPassword = true;
        });
      case BiometricAuthResult.lockedOut:
        setState(() {
          _error =
              'Terlalu banyak percobaan. Coba lagi nanti, atau masuk dengan kata sandi.';
          _showGantiPassword = true;
        });
      case BiometricAuthResult.failedOrCancelled:
        setState(() => _error = 'Verifikasi dibatalkan atau tidak cocok.');
    }

    setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final nama = context.watch<AuthService>().user?.name.split(' ').first;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 44,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xDCF4F9F8),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xCCFFFFFF),
                              ),
                            ),
                            child: const AppLogoImage(),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'E-Mall Annuqayah',
                            style: TextStyle(
                              color: Color(0xFF17212B),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      FlatCard(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                        child: Column(
                          children: [
                            Text.rich(
                              TextSpan(
                                style: GoogleFonts.newsreader(
                                  fontSize: 25,
                                  height: 1.25,
                                  color: const Color(0xFF17212B),
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Selamat datang kembali,\n',
                                  ),
                                  TextSpan(
                                    text: nama != null ? '$nama.' : 'Anda.',
                                    style: GoogleFonts.newsreader(
                                      fontSize: 26,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w600,
                                      color: _teal,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Verifikasi sidik jari untuk membuka akun Anda.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF667085),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 28),
                            GestureDetector(
                              onTap: _checking ? null : _unlock,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                width: 106,
                                height: 106,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(32),
                                  color: _teal.withValues(alpha: 0.07),
                                  border: Border.all(
                                    color: _teal.withValues(
                                      alpha: _checking ? 0.4 : 0.16,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _teal.withValues(alpha: 0.12),
                                      blurRadius: 22,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _teal.withValues(alpha: 0.14),
                                        _teal.withValues(alpha: 0.06),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  alignment: Alignment.center,
                                  child: _checking
                                      ? const SizedBox(
                                          width: 25,
                                          height: 25,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: _teal,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.fingerprint_rounded,
                                          color: _teal,
                                          size: 42,
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _checking ? 'Memeriksa...' : 'Sentuh untuk masuk',
                              style: const TextStyle(
                                color: Color(0xFF667085),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: const Color(0xCCFDECEC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0x33B91C1C),
                                  ),
                                ),
                                child: Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFB91C1C),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    context.read<AuthService>().logout(),
                                icon: const Icon(
                                  Icons.lock_open_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Gunakan Kata Sandi',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0x80FFFFFF),
                                  side: BorderSide(
                                    color: _showGantiPassword
                                        ? _teal
                                        : _teal.withValues(alpha: 0.2),
                                    width: _showGantiPassword ? 1.4 : 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () =>
                            context.read<AuthService>().switchAccount(),
                        child: Text(
                          nama != null
                              ? 'Bukan $nama? Gunakan akun lain'
                              : 'Gunakan akun lain',
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
