import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/tab_index_provider.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../widgets/app_logo_image.dart';
import '../widgets/session_notice_banner.dart';

const _teal = Color(0xFF0F8F83);
const _ink = Color(0xFF13213A);

class PinLoginScreen extends StatefulWidget {
  final bool presentedAsRoute;

  const PinLoginScreen({super.key, this.presentedAsRoute = false});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  String _pin = '';
  String? _error;
  bool _busy = false;
  int _attempts = 0;

  Future<void> _digit(String digit) async {
    if (_busy || _pin.length == 6) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == 6) await _verify();
  }

  void _delete() {
    if (_busy || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _verify() async {
    final auth = context.read<AuthService>();
    setState(() => _busy = true);
    final success = auth.isLoggedIn
        ? auth.unlockWithPin(_pin)
        : await auth.loginWithPin(_pin);
    if (!mounted) return;

    if (success) {
      HapticFeedback.mediumImpact();
      context.read<TabIndexProvider>().go(0);
      if (widget.presentedAsRoute && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    }

    final quickLoginError = auth.quickLoginError;
    if (quickLoginError != null) {
      setState(() {
        _pin = '';
        _busy = false;
        _error = quickLoginError;
      });
      return;
    }

    _attempts++;
    if (_attempts >= 5) {
      await auth.usePasswordInsteadOfPin();
      if (!mounted) return;
      if (widget.presentedAsRoute && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    } else {
      _error = 'PIN salah. Tersisa ${5 - _attempts} percobaan.';
    }
    HapticFeedback.heavyImpact();
    setState(() {
      _pin = '';
      _busy = false;
    });
  }

  Future<void> _biometric() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthService>();
    final result = auth.isLoggedIn
        ? await auth.unlockWithBiometrics()
        : await auth.loginWithBiometrics();
    if (!mounted) return;
    if (result == BiometricAuthResult.success) {
      context.read<TabIndexProvider>().go(0);
      if (widget.presentedAsRoute && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    }
    setState(() {
      _busy = false;
      _error = result == BiometricAuthResult.lockedOut
          ? 'Sidik jari terkunci sementara.'
          : 'Sidik jari dibatalkan atau tidak cocok.';
    });
  }

  Future<void> _usePassword() async {
    await context.read<AuthService>().usePasswordInsteadOfPin();
    if (!mounted) return;
    if (widget.presentedAsRoute && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final canUseBiometric =
        auth.biometricEnabled && (auth.isLoggedIn || auth.canUseBiometricLogin);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 40,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 72,
                        height: 72,
                        child: AppLogoImage(),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Masukkan PIN Anda',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Gunakan 6 digit PIN untuk masuk ke akun',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF7A869A),
                        ),
                      ),
                      if (auth.sessionNotice != null) ...[
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: SessionNoticeBanner(
                            message: auth.sessionNotice!,
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          6,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 18,
                            height: 18,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index < _pin.length
                                  ? _teal
                                  : Colors.transparent,
                              border: Border.all(
                                color: index < _pin.length
                                    ? _teal
                                    : const Color(0xFFD9DEE7),
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 38,
                        child: Center(
                          child: _error == null
                              ? null
                              : Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 11.5,
                                  ),
                                ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Column(
                          children: [
                            _NumberPad(
                              onDigit: _digit,
                              onDelete: _delete,
                              onBiometric: canUseBiometric ? _biometric : null,
                              busy: _busy,
                            ),
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.shield_outlined,
                                        size: 16,
                                        color: _teal,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'PIN terlindungi',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF7A869A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton(
                                    onPressed: _busy ? null : _usePassword,
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(0, 36),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                    ),
                                    child: const Text('Gunakan Password'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _NumberPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onBiometric;
  final bool busy;

  const _NumberPad({
    required this.onDigit,
    required this.onDelete,
    required this.onBiometric,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    final keys = <_PadButton>[
      for (final digit in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
        _PadButton(label: digit, onTap: () => onDigit(digit)),
      _PadButton(
        icon: Icons.fingerprint_rounded,
        highlighted: true,
        onTap: onBiometric,
      ),
      _PadButton(label: '0', onTap: () => onDigit('0')),
      _PadButton(icon: Icons.backspace_outlined, onTap: onDelete),
    ];

    return AbsorbPointer(
      absorbing: busy,
      child: Column(
        children: List.generate(4, (rowIndex) {
          final start = rowIndex * 3;
          return Padding(
            padding: EdgeInsets.only(bottom: rowIndex == 3 ? 0 : 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: keys.sublist(start, start + 3),
            ),
          );
        }),
      ),
    );
  }
}

class _PadButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool highlighted;

  const _PadButton({
    this.label,
    this.icon,
    this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: highlighted && onTap != null
            ? const Color(0xFFEAF8F6)
            : Colors.white,
        shape: CircleBorder(
          side: BorderSide(
            color: onTap == null ? Colors.transparent : const Color(0xFFE3E7ED),
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: icon != null
                ? Icon(icon, color: _teal, size: 25)
                : Text(
                    label!,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
