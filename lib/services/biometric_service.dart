import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

enum BiometricAuthResult {
  success,
  notSupported,
  notEnrolled,
  lockedOut,
  failedOrCancelled,
}

/// The only file in the app that talks to `local_auth` directly - every
/// other file (AuthService, login quick action, ProfilTab's toggle) goes
/// through this instead. `local_auth` is Pigeon-based, not a plain
/// MethodChannel, so it can't be mocked the lightweight way
/// flutter_secure_storage is mocked in widget_test.dart; keeping it behind
/// one interface means any future test only needs to fake this class.
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// True only when the device both supports biometric auth AND has at
  /// least one biometric actually enrolled - isDeviceSupported() alone
  /// would be true on hardware capable of it even with nothing enrolled,
  /// which would show a toggle that fails the moment it's tapped.
  Future<bool> isSupported() async {
    try {
      final deviceSupported = await _auth.isDeviceSupported();
      if (!deviceSupported) return false;

      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      // A hardware/support check should never itself crash the caller -
      // treat any unexpected platform error as "not supported" rather
      // than letting it bubble up as an unhandled exception.
      return false;
    }
  }

  Future<BiometricAuthResult> authenticate() async {
    if (!await isSupported()) {
      return BiometricAuthResult.notSupported;
    }

    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Verifikasi identitas Anda untuk melanjutkan',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      return ok
          ? BiometricAuthResult.success
          : BiometricAuthResult.failedOrCancelled;
    } on PlatformException catch (e) {
      switch (e.code) {
        case auth_error.notEnrolled:
          return BiometricAuthResult.notEnrolled;
        case auth_error.lockedOut:
        case auth_error.permanentlyLockedOut:
          return BiometricAuthResult.lockedOut;
        default:
          return BiometricAuthResult.failedOrCancelled;
      }
    }
  }
}
