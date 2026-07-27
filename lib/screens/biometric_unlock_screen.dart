import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/tab_index_provider.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../widgets/auth_brand_header.dart';

const _teal = Color(0xFF0F766E);

class BiometricUnlockScreen extends StatefulWidget {
  const BiometricUnlockScreen({super.key});

  @override
  State<BiometricUnlockScreen> createState() => _BiometricUnlockScreenState();
}

class _BiometricUnlockScreenState extends State<BiometricUnlockScreen> {
  bool _checking = false;
  String? _error;
  bool _showPasswordFallback = false;

  @override
  void initState() {
    super.initState();
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
        context.read<TabIndexProvider>().go(0);
        break;
      case BiometricAuthResult.notSupported:
      case BiometricAuthResult.notEnrolled:
        setState(() {
          _error =
              'Sidik jari tidak tersedia. Silakan masuk dengan kata sandi.';
          _showPasswordFallback = true;
        });
      case BiometricAuthResult.lockedOut:
        setState(() {
          _error =
              'Terlalu banyak percobaan. Coba lagi nanti atau gunakan kata sandi.';
          _showPasswordFallback = true;
        });
      case BiometricAuthResult.failedOrCancelled:
        setState(() => _error = 'Verifikasi dibatalkan atau tidak cocok.');
    }
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final nama = context.watch<AuthService>().user?.name.split(' ').first;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 50,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthBrandHeader(),
                    const SizedBox(height: 54),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 24,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                        children: [
                          const TextSpan(text: 'Selamat datang kembali'),
                          if (nama != null) ...[
                            const TextSpan(text: ',\n'),
                            TextSpan(
                              text: nama,
                              style: const TextStyle(color: _teal),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Verifikasi sidik jari untuk membuka akun Anda.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 42),
                    Center(
                      child: GestureDetector(
                        onTap: _checking ? null : _unlock,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: 132,
                          height: 132,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5F3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _teal.withValues(
                                alpha: _checking ? 0.5 : 0.18,
                              ),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: _teal,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: _checking
                                ? const SizedBox(
                                    width: 27,
                                    height: 27,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.fingerprint_rounded,
                                    color: Colors.white,
                                    size: 50,
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      _checking ? 'Memeriksa...' : 'Sentuh untuk masuk',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Gunakan sidik jari yang terdaftar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12.5,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDECEC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0x33B91C1C)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFB91C1C),
                              size: 19,
                            ),
                            const SizedBox(width: 9),
                            Flexible(
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
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _checking ? null : _unlock,
                        icon: const Icon(Icons.fingerprint_rounded, size: 22),
                        label: const Text(
                          'Coba Lagi',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => context.read<AuthService>().logout(),
                        icon: const Icon(Icons.lock_outline_rounded, size: 20),
                        label: Text(
                          _showPasswordFallback
                              ? 'Gunakan Kata Sandi'
                              : 'Masuk dengan Kata Sandi',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () =>
                          context.read<AuthService>().switchAccount(),
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12.5,
                          ),
                          children: [
                            if (nama != null) TextSpan(text: 'Bukan $nama?  '),
                            const TextSpan(
                              text: 'Gunakan akun lain',
                              style: TextStyle(
                                color: _teal,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
