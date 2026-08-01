import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/tab_index_provider.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../widgets/app_logo_image.dart';
import '../widgets/session_notice_banner.dart';
import 'pin_login_screen.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthService>();
      // When fingerprint is the only enabled quick-login method, prompt it
      // immediately on app start/resume. If PIN is also enabled AuthGate
      // routes to PinLoginScreen instead, where both choices remain visible.
      if (auth.canUseBiometricLogin && !auth.canUsePinLogin) {
        _submitWithBiometrics();
      }
    });
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
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = error.errorFor('login') ?? error.message,
        );
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

    final auth = context.read<AuthService>();
    final result = auth.isLoggedIn
        ? await auth.unlockWithBiometrics()
        : await auth.loginWithBiometrics();
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
    final auth = context.watch<AuthService>();
    final canUseBiometric = auth.canUseBiometricLogin;
    final canUsePin = auth.canUsePinLogin;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 40,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: SizedBox(
                            width: 78,
                            height: 78,
                            child: AppLogoImage(),
                          ),
                        ),
                        const SizedBox(height: 26),
                        const Text(
                          'Selamat datang kembali',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF13213A),
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Masuk untuk melanjutkan aktivitas Anda',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF7A869A),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 30),
                        if (auth.sessionNotice != null) ...[
                          SessionNoticeBanner(message: auth.sessionNotice!),
                          const SizedBox(height: 12),
                        ],
                        if (_serverStatus == ServerStatus.maintenance ||
                            _serverStatus == ServerStatus.unreachable) ...[
                          _ServerStatusBanner(
                            status: _serverStatus!,
                            onRetry: _checkServerStatus,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_errorMessage != null) ...[
                          _ErrorBanner(message: _errorMessage!),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _loginController,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: 'Email atau No. KK',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Email atau No. KK wajib diisi'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            hintText: 'Kata sandi',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 21,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Kata sandi wajib diisi'
                              : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 50,
                          child: FilledButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(
                                    width: 19,
                                    height: 19,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Masuk',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        if (canUsePin || canUseBiometric) ...[
                          const SizedBox(height: 22),
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'Masuk cepat',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF7A869A),
                                  ),
                                ),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (canUsePin)
                                _QuickLoginButton(
                                  icon: Icons.pin_outlined,
                                  label: 'PIN',
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const PinLoginScreen(
                                        presentedAsRoute: true,
                                      ),
                                    ),
                                  ),
                                ),
                              if (canUsePin && canUseBiometric)
                                const SizedBox(width: 14),
                              if (canUseBiometric)
                                _QuickLoginButton(
                                  icon: Icons.fingerprint_rounded,
                                  label: 'Sidik Jari',
                                  loading: _biometricLoading,
                                  onTap: _submitWithBiometrics,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickLoginButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool loading;

  const _QuickLoginButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: loading ? null : onTap,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 21),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(112, 44),
        padding: const EdgeInsets.symmetric(horizontal: 13),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        backgroundColor: Colors.white,
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
