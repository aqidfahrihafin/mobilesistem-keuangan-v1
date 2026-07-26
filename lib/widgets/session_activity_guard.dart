import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';

/// Default "beberapa menit tidak ada aktivitas" threshold - named here so
/// it's trivially tunable in one place.
const kInactivityTimeout = Duration(minutes: 5);

/// Wraps the whole app (below MaterialApp, above AuthGate) and locks the
/// session on two independent triggers:
///
/// 1. A single debounced Timer, reset on every tap anywhere in the app via
///    a translucent Listener - catches "left the app open on a screen and
///    walked away" (locks after [kInactivityTimeout] of no interaction
///    while still in the foreground).
/// 2. AppLifecycleState tracking - locks the *instant* the app is
///    backgrounded (switched away from, not just "gone N minutes"), no
///    grace period at all. This is deliberate for a financial app: someone
///    glancing at the phone over a wali's shoulder shouldn't be able to
///    switch back into an unlocked session just because it's been under 5
///    minutes. A wali who wants the app to feel instant again always still
///    has the fingerprint prompt right there - this doesn't add a real
///    step, just removes the window where backgrounding briefly skipped it.
///
/// Known accepted trade-off: the software keyboard is a native overlay
/// outside the Flutter view, so typing alone (no intervening taps on the
/// canvas) doesn't reset the foreground timer. Given this app's forms are
/// short (amounts, name/phone), that's acceptable.
class SessionActivityGuard extends StatefulWidget {
  final Widget child;

  const SessionActivityGuard({super.key, required this.child});

  @override
  State<SessionActivityGuard> createState() => _SessionActivityGuardState();
}

class _SessionActivityGuardState extends State<SessionActivityGuard>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // No grace period, no elapsed-time check - see the class doc comment
      // for why "just switched away for a few seconds" locks too, not only
      // "gone for 5+ minutes".
      _lock();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _resetTimer();
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(kInactivityTimeout, _lock);
  }

  void _lock() {
    _timer?.cancel();

    final auth = context.read<AuthService>();
    if (auth.isLoggedIn && !auth.needsBiometricUnlock) {
      auth.lockForInactivity();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
