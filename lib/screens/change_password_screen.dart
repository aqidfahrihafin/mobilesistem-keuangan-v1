import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';

/// Shown either as a forced gate right after login (wajib=true, when the
/// account's password is still the temporary one issued by admin - see
/// WaliAccountService on the server) or later as a voluntary action from a
/// settings screen (wajib=false, not wired up yet).
class ChangePasswordScreen extends StatefulWidget {
  final bool wajib;

  const ChangePasswordScreen({super.key, this.wajib = false});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  String? _currentError;
  String? _passwordError;
  String? _generalError;

  @override
  void dispose() {
    _currentController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _currentError = null;
      _passwordError = null;
      _generalError = null;
    });

    try {
      await context.read<AuthService>().changePassword(
        currentPassword: _currentController.text,
        password: _passwordController.text,
        passwordConfirmation: _confirmController.text,
      );
      // AuthGate rebuilds to the home screen automatically once
      // must_change_password flips to false.
    } on ApiException catch (e) {
      setState(() {
        _currentError = e.errorFor('current_password');
        _passwordError = e.errorFor('password');
        if (_currentError == null && _passwordError == null) {
          _generalError = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F7),
      appBar: AppBar(
        title: const Text('Ganti Kata Sandi'),
        automaticallyImplyLeading: !widget.wajib,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.wajib)
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF6E7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFFB45309),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Akun Anda dibuat dengan kata sandi awal berupa No. KK. '
                            'Silakan ganti kata sandi sebelum melanjutkan.',
                            style: TextStyle(
                              color: Colors.amber[900],
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_generalError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDECEC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _generalError!,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Kata Sandi Saat Ini',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _currentController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: widget.wajib ? 'No. KK Anda' : '••••••••',
                    errorText: _currentError,
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Kata Sandi Baru',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Minimal 8 karakter',
                    errorText: _passwordError,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Wajib diisi';
                    if (v.length < 8) return 'Minimal 8 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                const Text(
                  'Konfirmasi Kata Sandi Baru',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: '••••••••'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Wajib diisi';
                    if (v != _passwordController.text) return 'Tidak cocok';
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Ubah Kata Sandi',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
