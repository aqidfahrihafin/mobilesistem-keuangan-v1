import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/wali_api.dart';
import '../widgets/pin_box_field.dart';

const _bg = Color(0xFFF3F8F7);
const _teal = Color(0xFF0F766E);

/// Creates or replaces the wali's 6-digit transaction PIN - the second
/// factor gating kantin payment, tagihan-from-saldo, and transfer antar
/// santri (see PinService on the server). A two-step wizard rather than one
/// long form: step 1 verifies the account password for real (a round trip
/// to the server, not just a non-empty check) before step 2 even appears,
/// so a wrong password is caught immediately instead of after also typing
/// a PIN twice.
///
/// [forced] is true when a sensitive action routed here because the wali
/// has no PIN yet (has_pin == false) - shows an explanatory banner and pops
/// with `true` on success so the caller can resume the action that sent the
/// wali here, instead of leaving them stranded on Profil.
class PinSetupScreen extends StatefulWidget {
  final bool forced;

  const PinSetupScreen({super.key, this.forced = false});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinConfirmController = TextEditingController();
  final _pinFocusNode = FocusNode();
  final _pinConfirmFocusNode = FocusNode();

  int _step = 0;
  bool _loading = false;
  String? _passwordError;
  String? _pinError;

  @override
  void dispose() {
    _passwordController.dispose();
    _pinController.dispose();
    _pinConfirmController.dispose();
    _pinFocusNode.dispose();
    _pinConfirmFocusNode.dispose();
    super.dispose();
  }

  Future<void> _confirmPassword() async {
    if (_passwordController.text.isEmpty || _loading) return;

    setState(() {
      _loading = true;
      _passwordError = null;
    });

    try {
      await context.read<WaliApi>().confirmPassword(_passwordController.text);
      if (!mounted) return;
      setState(() => _step = 1);
    } on ApiException catch (e) {
      setState(() => _passwordError = e.errorFor('password') ?? e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _simpanPin() async {
    if (_pinController.text.length != 6 ||
        _pinConfirmController.text.length != 6 ||
        _loading) {
      return;
    }

    setState(() {
      _loading = true;
      _pinError = null;
    });

    try {
      // Already verified once above - reused here (instead of asking the
      // wali to retype it) since PinController::store re-checks it anyway
      // as its own authorization guard, not just a formality.
      await context.read<WaliApi>().setPin(
        currentPassword: _passwordController.text,
        pin: _pinController.text,
        pinConfirmation: _pinConfirmController.text,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN transaksi berhasil disimpan.')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _pinError = e.errorFor('pin') ?? e.message;
        // Password was accepted a moment ago - the only realistic way
        // store() rejects it now is the account password having changed in
        // between, an edge case not worth a dedicated message for. Bounce
        // back to step 1 so the wali can re-verify rather than getting
        // stuck on a step whose only field (PIN) isn't actually the issue.
        if (e.errorFor('current_password') != null) {
          _step = 0;
          _passwordError = e.errorFor('current_password');
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(widget.forced ? 'Buat PIN Transaksi' : 'PIN Transaksi'),
        automaticallyImplyLeading: !widget.forced,
        leading: (!widget.forced && _step == 1)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _step = 0),
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(step: _step, forced: widget.forced),
              const SizedBox(height: 22),
              _StepDots(step: _step),
              const SizedBox(height: 22),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(_step == 0 ? -0.06 : 0.06, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: _step == 0
                    ? _PasswordStep(
                        key: const ValueKey('password'),
                        controller: _passwordController,
                        error: _passwordError,
                        loading: _loading,
                        onSubmit: _confirmPassword,
                      )
                    : _PinStep(
                        key: const ValueKey('pin'),
                        pinController: _pinController,
                        pinConfirmController: _pinConfirmController,
                        pinFocusNode: _pinFocusNode,
                        pinConfirmFocusNode: _pinConfirmFocusNode,
                        error: _pinError,
                        loading: _loading,
                        onSubmit: _simpanPin,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int step;
  final bool forced;

  const _Header({required this.step, required this.forced});

  @override
  Widget build(BuildContext context) {
    final title = step == 0
        ? 'Verifikasi kata sandi'
        : (forced ? 'Buat PIN transaksi' : 'PIN transaksi baru');
    final subtitle = step == 0
        ? 'Masukkan kata sandi akun Anda untuk melanjutkan.'
        : 'PIN 6 digit ini akan diminta setiap kali membayar kantin, membayar tagihan dari saldo, atau transfer saldo ke santri lain.';

    return Container(
      width: double.infinity,
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
            child: Icon(
              step == 0 ? Icons.lock_outline_rounded : Icons.shield_outlined,
              color: _teal,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two dots showing "langkah 1 dari 2 / 2 dari 2" - a small, honest signal
/// that there's one more short step coming, not just decoration.
class _StepDots extends StatelessWidget {
  final int step;

  const _StepDots({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (i) {
        final active = i == step;
        final done = i < step;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: (active || done) ? _teal : const Color(0xFFE1E4E9),
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }
}

class _PasswordStep extends StatelessWidget {
  final TextEditingController controller;
  final String? error;
  final bool loading;
  final VoidCallback onSubmit;

  const _PasswordStep({
    super.key,
    required this.controller,
    required this.error,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Kata Sandi Akun',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          onSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(hintText: '••••••••', errorText: error),
        ),
        const SizedBox(height: 26),
        SizedBox(
          height: 54,
          child: FilledButton(
            onPressed: loading ? null : onSubmit,
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Lanjutkan',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _PinStep extends StatelessWidget {
  final TextEditingController pinController;
  final TextEditingController pinConfirmController;
  final FocusNode pinFocusNode;
  final FocusNode pinConfirmFocusNode;
  final String? error;
  final bool loading;
  final VoidCallback onSubmit;

  const _PinStep({
    super.key,
    required this.pinController,
    required this.pinConfirmController,
    required this.pinFocusNode,
    required this.pinConfirmFocusNode,
    required this.error,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A bordered white card (matching _Header below it) instead of
        // labels floating directly on the grey background - groups the two
        // PIN fields into one clear unit and reads as far less bare than
        // plain text labels above each box row.
        Container(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: error != null ? Colors.red[200]! : const Color(0xFFE2E8E4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PinFieldLabel(text: 'PIN Baru', icon: Icons.pin_outlined),
              const SizedBox(height: 12),
              PinBoxField(
                controller: pinController,
                focusNode: pinFocusNode,
                autofocus: true,
                hasError: error != null,
                onCompleted: (_) => pinConfirmFocusNode.requestFocus(),
              ),
              const SizedBox(height: 24),
              _PinFieldLabel(
                text: 'Konfirmasi PIN Baru',
                icon: Icons.check_circle_outline_rounded,
              ),
              const SizedBox(height: 12),
              PinBoxField(
                controller: pinConfirmController,
                focusNode: pinConfirmFocusNode,
                hasError: error != null,
                onCompleted: (_) => onSubmit(),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red[700], fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _PinSecurityTip(),
        const SizedBox(height: 26),
        SizedBox(
          height: 54,
          child: FilledButton(
            onPressed: loading ? null : onSubmit,
            child: loading
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
      ],
    );
  }
}

class _PinFieldLabel extends StatelessWidget {
  final String text;
  final IconData icon;

  const _PinFieldLabel({required this.text, required this.icon});

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

/// A short, tinted reminder card - fills the space below the PIN card with
/// something genuinely useful instead of bare grey background, and reminds
/// a wali of real PIN-hygiene practice at the exact moment they're setting
/// one.
class _PinSecurityTip extends StatelessWidget {
  const _PinSecurityTip();

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
              'Hindari tanggal lahir atau angka berurutan. Jangan bagikan PIN ini kepada siapa pun, termasuk pihak pondok.',
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
