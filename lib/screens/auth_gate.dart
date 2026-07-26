import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import 'biometric_unlock_screen.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'onboarding_screen.dart';
import 'splash_screen.dart';

/// Root of the widget tree, below MaterialApp: decides which screen to show
/// based on session state, and re-decides automatically whenever AuthService
/// notifies (login/logout/password change) - no manual navigation needed
/// from those actions.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // A real network restore can finish in well under this, which would make
  // the splash just flash on screen - held open for at least this long so
  // the brand actually registers, independent of how fast restoreSession()
  // happens to be.
  static const _minSplashDuration = Duration(milliseconds: 1300);
  bool _minSplashElapsed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(_minSplashDuration, () {
      if (mounted) setState(() => _minSplashElapsed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        if (auth.restoring || !_minSplashElapsed) {
          return const SplashScreen();
        }

        if (!auth.isLoggedIn && !auth.hasOnboarded) {
          return const OnboardingScreen();
        }

        if (!auth.isLoggedIn) {
          return const LoginScreen();
        }

        // Checked before mustChangePassword - a soft-locked wali who also
        // happens to need a password change should see the lock screen
        // first, not skip straight past it.
        if (auth.needsBiometricUnlock) {
          return const BiometricUnlockScreen();
        }

        if (auth.mustChangePassword) {
          return const ChangePasswordScreen(wajib: true);
        }

        return const MainScreen();
      },
    );
  }
}
