import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/flat_card.dart';
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
  final _confirmationFocus = FocusNode();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirmation.dispose();
    _confirmationFocus.dispose();
    super.dispose();
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
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF17212B),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FlatCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.lock_person_outlined,
                    color: _teal,
                    size: 34,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    enabled ? 'Buat PIN login baru' : 'Masuk lebih cepat',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF17212B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'PIN ini hanya berlaku pada perangkat ini dan tidak menggantikan kata sandi akun.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'PIN 6 digit',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  PinBoxField(
                    controller: _pin,
                    autofocus: true,
                    onCompleted: (_) => _confirmationFocus.requestFocus(),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Ulangi PIN',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  PinBoxField(
                    controller: _confirmation,
                    focusNode: _confirmationFocus,
                    onCompleted: (_) => _save(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(
                        _saving ? 'Menyimpan...' : 'Simpan PIN Login',
                      ),
                    ),
                  ),
                ],
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
        ),
      ),
    );
  }
}
