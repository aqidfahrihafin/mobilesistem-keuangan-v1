import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_info_provider.dart';
import '../providers/tab_index_provider.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../widgets/app_logo_image.dart';
import '../widgets/geometric_pattern.dart';

const _bg = Colors.transparent;
const _teal = Color(0xFF0F766E);
const _tealDark = Color(0xFF115E59);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _biometricLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  ServerStatus? _serverStatus;

  @override
  void initState() {
    super.initState();
    _checkServerStatus();
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkServerStatus() async {
    final status = await context.read<ApiClient>().checkServerStatus();
    if (!mounted) return;
    setState(() => _serverStatus = status);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await context.read<AuthService>().login(
        _loginController.text.trim(),
        _passwordController.text,
      );
      // No navigation call needed - AuthGate rebuilds automatically once
      // AuthService notifies listeners after a successful login. A fresh
      // login always starts on Home, regardless of which tab a previous
      // session happened to end on (e.g. logging out from Profil).
      if (mounted) context.read<TabIndexProvider>().go(0);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.errorFor('login') ?? e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitWithBiometrics() async {
    if (_biometricLoading) return;

    setState(() {
      _biometricLoading = true;
      _errorMessage = null;
    });

    final result = await context.read<AuthService>().loginWithBiometrics();

    if (!mounted) return;

    switch (result) {
      case BiometricAuthResult.success:
        // Same "always starts on Home" rule as a password login - this is
        // a fresh login from this screen too, just via fingerprint.
        context.read<TabIndexProvider>().go(0);
      case BiometricAuthResult.notSupported:
      case BiometricAuthResult.notEnrolled:
        setState(
          () => _errorMessage =
              'Sidik jari tidak tersedia lagi di perangkat ini. Silakan masuk dengan kata sandi.',
        );
      case BiometricAuthResult.lockedOut:
        setState(
          () => _errorMessage =
              'Terlalu banyak percobaan. Coba lagi nanti, atau masuk dengan kata sandi.',
        );
      case BiometricAuthResult.failedOrCancelled:
        setState(
          () => _errorMessage =
              'Verifikasi sidik jari dibatalkan atau tidak cocok.',
        );
    }

    if (mounted) setState(() => _biometricLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final heroHeight = MediaQuery.sizeOf(context).height * 0.31;

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: heroHeight,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_teal, _tealDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Positioned.fill(
                      child: GeometricPatternBackground(opacity: 0.07),
                    ),
                    Positioned(
                      right: -34,
                      top: -20,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -28,
                      bottom: -10,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 66,
                              height: 66,
                              decoration: BoxDecoration(
                                color: const Color(0xECFAFDFC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: const AppLogoImage(),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              context.watch<AppInfoProvider>().namaAplikasi ??
                                  'E-Mall Annuqayah',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.watch<AppInfoProvider>().namaPondok ??
                                  'Pondok Pesantren Latee',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -22),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                decoration: BoxDecoration(
                  color: const Color(0xE6F1F8F6),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xE6FFFFFF),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _teal.withValues(alpha: 0.13),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                28,
                                30,
                                28,
                                28,
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Masuk ke Akun Anda',
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Kelola saldo, tagihan, dan aktivitas santri dengan aman.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    if (_serverStatus ==
                                            ServerStatus.maintenance ||
                                        _serverStatus ==
                                            ServerStatus.unreachable) ...[
                                      _ServerStatusBanner(
                                        status: _serverStatus!,
                                        onRetry: _checkServerStatus,
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    if (_errorMessage != null) ...[
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFDECEC),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Text(
                                          _errorMessage!,
                                          style: const TextStyle(
                                            color: Color(0xFFB91C1C),
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    const _FieldLabel('Email atau No. KK'),
                                    TextFormField(
                                      controller: _loginController,
                                      autocorrect: false,
                                      decoration: const InputDecoration(
                                        hintText: 'nama@email.com atau No. KK',
                                        prefixIcon: Icon(
                                          Icons.person_outline_rounded,
                                          size: 20,
                                        ),
                                      ),
                                      validator: (value) =>
                                          (value == null ||
                                              value.trim().isEmpty)
                                          ? 'Wajib diisi'
                                          : null,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Wali baru bisa login pakai No. KK',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const _FieldLabel('Kata Sandi'),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      decoration: InputDecoration(
                                        hintText: '••••••••',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline_rounded,
                                          size: 20,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: Colors.grey[500],
                                            size: 20,
                                          ),
                                          onPressed: () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                        ),
                                      ),
                                      validator: (value) =>
                                          (value == null || value.isEmpty)
                                          ? 'Wajib diisi'
                                          : null,
                                      onFieldSubmitted: (_) => _submit(),
                                    ),
                                    const SizedBox(height: 30),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SizedBox(
                                            height: 54,
                                            child: FilledButton(
                                              onPressed: _loading
                                                  ? null
                                                  : _submit,
                                              child: _loading
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Colors.white,
                                                          ),
                                                    )
                                                  : const Text(
                                                      'Masuk',
                                                      style: TextStyle(
                                                        fontSize: 15.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                        if (context
                                            .watch<AuthService>()
                                            .canUseBiometricLogin) ...[
                                          const SizedBox(width: 12),
                                          SizedBox(
                                            width: 54,
                                            height: 54,
                                            child: OutlinedButton(
                                              onPressed: _biometricLoading
                                                  ? null
                                                  : _submitWithBiometrics,
                                              style: OutlinedButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                side: const BorderSide(
                                                  color: _teal,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                              ),
                                              child: _biometricLoading
                                                  ? const SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: _teal,
                                                          ),
                                                    )
                                                  : const Icon(
                                                      Icons.fingerprint_rounded,
                                                      color: _teal,
                                                      size: 26,
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.info_outline_rounded,
                                          size: 14,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'Belum punya akun? Hubungi pengurus pondok.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ),
                                      ],
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
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ServerStatusBanner extends StatelessWidget {
  final ServerStatus status;
  final VoidCallback onRetry;

  const _ServerStatusBanner({required this.status, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isMaintenance = status == ServerStatus.maintenance;
    final bg = isMaintenance
        ? const Color(0xFFFFF3E0)
        : const Color(0xFFFDECEC);
    final fg = isMaintenance
        ? const Color(0xFF9A6700)
        : const Color(0xFFB91C1C);
    final message = isMaintenance
        ? 'Server sedang dalam pemeliharaan. Silakan coba lagi beberapa saat lagi.'
        : 'Tidak bisa terhubung ke server. Periksa koneksi internet Anda.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isMaintenance ? Icons.build_rounded : Icons.wifi_off_rounded,
            color: fg,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: fg, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              'Coba lagi',
              style: TextStyle(
                color: fg,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
