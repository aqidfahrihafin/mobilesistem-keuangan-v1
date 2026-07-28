import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/wali_api.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/pin_box_field.dart';

const _bg = Color(0xFFF3F8F7);
const _teal = Color(0xFF0F766E);

class LoginPinSetupScreen extends StatefulWidget {
  const LoginPinSetupScreen({super.key});

  @override
  State<LoginPinSetupScreen> createState() => _LoginPinSetupScreenState();
}

class _LoginPinSetupScreenState extends State<LoginPinSetupScreen> {
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();
  final _password = TextEditingController();
  final _confirmationFocus = FocusNode();
  bool _saving = false;
  bool _passwordVerified = false;
  bool _verifyingPassword = false;
  String? _passwordError;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirmation.dispose();
    _password.dispose();
    _confirmationFocus.dispose();
    super.dispose();
  }

  Future<void> _verifyPassword() async {
    if (_password.text.isEmpty || _verifyingPassword) {
      setState(() => _passwordError = 'Kata sandi wajib diisi.');
      return;
    }
    setState(() {
      _verifyingPassword = true;
      _passwordError = null;
    });
    try {
      await context.read<WaliApi>().confirmPassword(_password.text);
      if (mounted) setState(() => _passwordVerified = true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _passwordError = error.errorFor('password') ?? error.message,
        );
      }
    } finally {
      if (mounted) setState(() => _verifyingPassword = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_pin.text.length != 6 || _confirmation.text.length != 6) {
      setState(() => _error = 'Masukkan dan ulangi PIN 6 digit.');
      return;
    }
    if (_pin.text != _confirmation.text) {
      setState(() => _error = 'Konfirmasi PIN tidak sama.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    await context.read<AuthService>().setLoginPin(_pin.text);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN login berhasil diaktifkan.')),
    );
  }

  Future<void> _disable() async {
    final confirmed = await ConfirmDialog.show(
      context,
      icon: Icons.pin_outlined,
      iconColor: Colors.red,
      title: 'Nonaktifkan PIN login?',
      message:
          'Setelah dinonaktifkan, masuk cepat tetap dapat menggunakan sidik jari jika fitur tersebut aktif.',
      confirmText: 'Nonaktifkan',
      confirmColor: Colors.red,
    );
    if (confirmed != true || !mounted) return;
    await context.read<AuthService>().disableLoginPin();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = context.watch<AuthService>().loginPinEnabled;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(enabled ? 'Ubah PIN Login' : 'Aktifkan PIN Login'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8E4)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _teal.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.shield_outlined,
                        color: _teal,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      enabled && !_passwordVerified
                          ? 'Verifikasi kata sandi'
                          : (enabled ? 'PIN login baru' : 'Buat PIN login'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      enabled && !_passwordVerified
                          ? 'Masukkan kata sandi akun sebelum mengganti PIN login.'
                          : 'PIN 6 digit ini hanya membuka sesi akun yang tersimpan pada perangkat ini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (enabled && !_passwordVerified)
                _PasswordVerificationCard(
                  controller: _password,
                  error: _passwordError,
                  loading: _verifyingPassword,
                  onSubmit: _verifyPassword,
                )
              else ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _error != null
                          ? Colors.red[200]!
                          : const Color(0xFFE2E8E4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _PinLabel(
                        text: 'PIN Baru',
                        icon: Icons.pin_outlined,
                      ),
                      const SizedBox(height: 12),
                      PinBoxField(
                        controller: _pin,
                        autofocus: true,
                        hasError: _error != null,
                        onCompleted: (_) => _confirmationFocus.requestFocus(),
                      ),
                      const SizedBox(height: 24),
                      const _PinLabel(
                        text: 'Konfirmasi PIN Baru',
                        icon: Icons.check_circle_outline_rounded,
                      ),
                      const SizedBox(height: 12),
                      PinBoxField(
                        controller: _confirmation,
                        focusNode: _confirmationFocus,
                        hasError: _error != null,
                        onCompleted: (_) => _save(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const _SecurityTip(),
                const SizedBox(height: 26),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Simpan PIN',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                if (enabled) ...[
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: _disable,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Nonaktifkan PIN Login'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordVerificationCard extends StatefulWidget {
  final TextEditingController controller;
  final String? error;
  final bool loading;
  final VoidCallback onSubmit;

  const _PasswordVerificationCard({
    required this.controller,
    required this.error,
    required this.loading,
    required this.onSubmit,
  });

  @override
  State<_PasswordVerificationCard> createState() =>
      _PasswordVerificationCardState();
}

class _PasswordVerificationCardState extends State<_PasswordVerificationCard> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PinLabel(
            text: 'Kata Sandi Akun',
            icon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.controller,
            autofocus: true,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => widget.onSubmit(),
            decoration: InputDecoration(
              hintText: 'Kata sandi',
              errorText: widget.error,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: widget.loading ? null : widget.onSubmit,
              child: widget.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Verifikasi & Lanjutkan',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinLabel extends StatelessWidget {
  final String text;
  final IconData icon;

  const _PinLabel({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _teal),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _SecurityTip extends StatelessWidget {
  const _SecurityTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _teal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _teal.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.privacy_tip_outlined, size: 18, color: _teal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Hindari tanggal lahir atau angka berurutan. Jangan bagikan PIN ini kepada siapa pun.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
