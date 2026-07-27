import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/tab_index_provider.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../widgets/auth_brand_header.dart';

const _teal = Color(0xFF0F766E);

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
    if (mounted) setState(() => _serverStatus = status);
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
      if (mounted) context.read<TabIndexProvider>().go(0);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.errorFor('login') ?? e.message);
      }
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
        context.read<TabIndexProvider>().go(0);
      case BiometricAuthResult.notSupported:
      case BiometricAuthResult.notEnrolled:
        setState(
          () => _errorMessage =
              'Sidik jari tidak tersedia. Silakan masuk dengan kata sandi.',
        );
      case BiometricAuthResult.lockedOut:
        setState(
          () => _errorMessage =
              'Terlalu banyak percobaan. Coba lagi nanti atau gunakan kata sandi.',
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
    final canUseBiometric = context.watch<AuthService>().canUseBiometricLogin;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 50,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AuthBrandHeader(),
                      const SizedBox(height: 42),
                      const Text(
                        'Selamat datang',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Gunakan akun wali Anda.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 30),
                      if (_serverStatus == ServerStatus.maintenance ||
                          _serverStatus == ServerStatus.unreachable) ...[
                        _ServerStatusBanner(
                          status: _serverStatus!,
                          onRetry: _checkServerStatus,
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_errorMessage != null) ...[
                        _ErrorBanner(message: _errorMessage!),
                        const SizedBox(height: 14),
                      ],
                      const _FieldLabel('Email atau No. KK'),
                      TextFormField(
                        controller: _loginController,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'Masukkan email atau No. KK',
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
                            size: 21,
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      const _FieldLabel('Kata Sandi'),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            size: 21,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: _teal,
                              size: 21,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Wajib diisi'
                            : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _submit,
                          icon: _loading
                              ? const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 19,
                                ),
                          label: Text(
                            _loading ? 'Memproses...' : 'Masuk',
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (canUseBiometric) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _biometricLoading
                                ? null
                                : _submitWithBiometrics,
                            icon: _biometricLoading
                                ? const SizedBox(
                                    width: 19,
                                    height: 19,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _teal,
                                    ),
                                  )
                                : const Icon(
                                    Icons.fingerprint_rounded,
                                    size: 22,
                                  ),
                            label: const Text(
                              'Masuk dengan Sidik Jari',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Text(
                        'Butuh bantuan? Hubungi pengurus pondok.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12.5,
                        ),
                      ),
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

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7, left: 1),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x33B91C1C)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12.5),
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
    final maintenance = status == ServerStatus.maintenance;
    final bg = maintenance ? const Color(0xFFFFF3E0) : const Color(0xFFFDECEC);
    final fg = maintenance ? const Color(0xFF9A6700) : const Color(0xFFB91C1C);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            maintenance ? Icons.build_rounded : Icons.wifi_off_rounded,
            color: fg,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              maintenance
                  ? 'Server sedang dalam pemeliharaan.'
                  : 'Tidak bisa terhubung ke server.',
              style: TextStyle(color: fg, fontSize: 12.5),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text('Coba lagi', style: TextStyle(color: fg)),
          ),
        ],
      ),
    );
  }
}
