import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/wali_user.dart';
import 'api_client.dart';
import 'biometric_service.dart';
import 'push_notification_service.dart';

/// Owns the session: token persistence (secure storage, survives app
/// restarts), the currently logged-in wali, and the three auth actions
/// (login, change password, logout) - plus the optional biometric lock
/// layered on top of that session (see `needsBiometricUnlock`). Screens
/// read `isLoggedIn` / `mustChangePassword` / `needsBiometricUnlock` off
/// this via Provider to decide what to show.
class AuthService extends ChangeNotifier {
  final ApiClient _api;
  final BiometricService _biometric;
  final PushNotificationService _push;
  final _storage = const FlutterSecureStorage();

  static const _biometricEnabledKey = 'biometric_enabled';
  static const _loginPinKey = 'login_pin';
  static const _onboardedKey = 'has_onboarded';

  WaliUser? _user;
  String? _token;
  bool _restoring = true;
  bool _biometricEnabled = false;
  String? _loginPin;
  bool _hasOnboarded = false;

  /// True whenever the session is otherwise valid but still needs a
  /// biometric check before the wali can see the app - set at boot (if
  /// biometricEnabled) and again whenever SessionActivityGuard locks the
  /// app for inactivity. Cleared by a successful unlockWithBiometrics().
  bool _needsBiometricUnlock = false;
  bool _needsPinUnlock = false;

  AuthService(this._api, this._biometric, this._push);

  WaliUser? get user => _user;
  bool get isLoggedIn => _token != null && _user != null;
  bool get mustChangePassword => _user?.mustChangePassword ?? false;
  bool get restoring => _restoring;
  bool get biometricEnabled => _biometricEnabled;
  bool get needsBiometricUnlock => _needsBiometricUnlock;
  bool get needsPinUnlock => _needsPinUnlock;
  bool get loginPinEnabled => _loginPin != null;
  bool get hasOnboarded => _hasOnboarded;

  /// True when there's a retained token a fingerprint tap on the login
  /// screen can resume - only the case right after logout() soft-locked
  /// the session (biometric login enabled). Never true on a genuinely
  /// fresh install or after a hard sign-out, so the button only ever
  /// appears when it can actually do something.
  bool get canUseBiometricLogin => _biometricEnabled && _token != null;
  bool get canUsePinLogin => _loginPin != null && _token != null;

  /// Call once at app startup - tries to resume a previous session from
  /// secure storage before showing the login screen.
  Future<void> restoreSession() async {
    try {
      _token = await _storage.read(key: 'token');
      _biometricEnabled =
          await _storage.read(key: _biometricEnabledKey) == 'true';
      _loginPin = await _storage.read(key: _loginPinKey);
      _hasOnboarded = await _storage.read(key: _onboardedKey) == 'true';

      if (_token != null) {
        _api.setToken(_token);
        try {
          final data = await _api.get('/wali/me');
          _user = WaliUser.fromJson(data as Map<String, dynamic>);
          _needsPinUnlock = _loginPin != null;
          _needsBiometricUnlock = _biometricEnabled && _loginPin == null;
          unawaited(_push.registerCurrentToken());
        } catch (_) {
          // Token expired/revoked or the server is unreachable. Never leave
          // the app stuck in restoring state; fall back to a clean login.
          await _clearSession();
        }
      }

      // A device that already has a session (e.g. upgraded from a build
      // before onboarding existed) shouldn't be interrupted with onboarding
      // slides - treat "already logged in" as implicitly onboarded.
      if (_user != null && !_hasOnboarded) {
        await completeOnboarding();
      }
    } catch (error, stackTrace) {
      // Secure storage can fail on a small subset of devices after an app
      // restore/keystore change. Treat that as no resumable session instead
      // of showing the splash forever.
      _token = null;
      _user = null;
      _needsBiometricUnlock = false;
      _needsPinUnlock = false;
      _api.setToken(null);
      debugPrint('Session restoration skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  Future<void> completeOnboarding() async {
    _hasOnboarded = true;
    await _storage.write(key: _onboardedKey, value: 'true');
    notifyListeners();
  }

  Future<void> login(String login, String password) async {
    final data = await _api.post('/wali/login', {
      'login': login,
      'password': password,
      'device_name': _deviceName(),
    });

    _token = data['token'] as String;
    _user = WaliUser.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.write(key: 'token', value: _token);
    _api.setToken(_token);
    unawaited(_push.registerCurrentToken());
    notifyListeners();
  }

  /// Only meant to be called after BiometricService.authenticate() has
  /// already succeeded once (see ProfilTab's toggle) - this just persists
  /// the resulting preference, it doesn't itself prompt for biometrics.
  Future<void> setBiometricEnabled(bool value) async {
    _biometricEnabled = value;

    if (value) {
      await _storage.write(key: _biometricEnabledKey, value: 'true');
    } else {
      await _storage.delete(key: _biometricEnabledKey);
    }

    notifyListeners();
  }

  Future<void> setLoginPin(String pin) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw ArgumentError('PIN login harus terdiri dari 6 angka.');
    }
    _loginPin = pin;
    await _storage.write(key: _loginPinKey, value: pin);
    notifyListeners();
  }

  Future<void> disableLoginPin() async {
    _loginPin = null;
    _needsPinUnlock = false;
    await _storage.delete(key: _loginPinKey);
    notifyListeners();
  }

  bool unlockWithPin(String pin) {
    if (_loginPin == null || pin != _loginPin) return false;
    _needsPinUnlock = false;
    _needsBiometricUnlock = false;
    notifyListeners();
    return true;
  }

  Future<BiometricAuthResult> unlockWithBiometrics() async {
    final result = await _biometric.authenticate();

    if (result == BiometricAuthResult.success) {
      _needsBiometricUnlock = false;
      _needsPinUnlock = false;
      notifyListeners();
    }

    return result;
  }

  /// Resumes a session that logout() soft-locked (see canUseBiometricLogin)
  /// without retyping the password - re-validates the retained token
  /// against the server so a token that was actually revoked/expired in
  /// the meantime falls back to a normal logged-out state instead of
  /// leaving the wali stuck behind a fingerprint prompt that can never
  /// succeed.
  Future<BiometricAuthResult> loginWithBiometrics() async {
    final result = await _biometric.authenticate();
    if (result != BiometricAuthResult.success) return result;

    if (_token == null) return BiometricAuthResult.failedOrCancelled;

    _api.setToken(_token);
    try {
      final data = await _api.get('/wali/me');
      _user = WaliUser.fromJson(data as Map<String, dynamic>);
      unawaited(_push.registerCurrentToken());
      notifyListeners();
      return BiometricAuthResult.success;
    } catch (_) {
      await _clearSession();
      notifyListeners();
      return BiometricAuthResult.failedOrCancelled;
    }
  }

  Future<bool> loginWithPin(String pin) async {
    if (_loginPin == null || pin != _loginPin || _token == null) return false;

    _api.setToken(_token);
    try {
      final data = await _api.get('/wali/me');
      _user = WaliUser.fromJson(data as Map<String, dynamic>);
      _needsPinUnlock = false;
      _needsBiometricUnlock = false;
      unawaited(_push.registerCurrentToken());
      notifyListeners();
      return true;
    } catch (_) {
      await _clearSession();
      notifyListeners();
      return false;
    }
  }

  /// Called by SessionActivityGuard after enough inactivity has passed.
  /// Soft-locks (keeps the token, just re-shows the biometric gate) when
  /// biometrics are enabled - forcing a full network re-login every idle
  /// timeout would defeat the point of having biometrics on. Falls back to
  /// a real logout when biometrics aren't enabled, matching a plain "auto
  /// logout" expectation with no faster way back in.
  Future<void> lockForInactivity() async {
    if (!isLoggedIn) return;

    if (_loginPin != null || _biometricEnabled) {
      _needsPinUnlock = _loginPin != null;
      _needsBiometricUnlock = _biometricEnabled && _loginPin == null;
      notifyListeners();
    } else {
      await logout();
    }
  }

  Future<void> updateProfile({
    required String name,
    String? email,
    String? phone,
  }) async {
    final data = await _api.put('/wali/profile', {
      'name': name,
      'email': email,
      'phone': phone,
    });

    _user = WaliUser.fromJson(data as Map<String, dynamic>);
    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _api.post('/wali/password', {
      'current_password': currentPassword,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });

    final current = _user!;
    _user = WaliUser(
      id: current.id,
      name: current.name,
      email: current.email,
      phone: current.phone,
      mustChangePassword: false,
    );
    notifyListeners();
  }

  /// Ends the current session. When biometric login is enabled, this is a
  /// soft lock, not a hard sign-out: the token stays valid both locally and
  /// server-side, and only the in-memory user is cleared - the wali lands
  /// on the login screen, but its fingerprint button (canUseBiometricLogin)
  /// can resume instantly instead of retyping a password, matching the
  /// same trade-off already made for inactivity auto-lock. Turning
  /// biometric login off (or a token that turns out to be dead) always
  /// falls through to a real sign-out that revokes the server session.
  Future<void> logout() async {
    if ((_biometricEnabled || _loginPin != null) && _token != null) {
      _user = null;
      _needsBiometricUnlock = false;
      _needsPinUnlock = false;
      notifyListeners();
      return;
    }

    await _hardLogout();
    notifyListeners();
  }

  /// Forces a real sign-out even when biometric login is enabled - unlike
  /// [logout] (which soft-locks in that case), this is for the biometric
  /// lock screen's "bukan {nama}? gunakan akun lain" link, where a
  /// *different* wali is about to sign in on the same device. Also clears
  /// the biometric-login preference itself, not just the session - without
  /// this, the next wali to log in on this device would silently inherit
  /// the previous wali's biometric consent instead of opting in themselves.
  Future<void> switchAccount() async {
    await setBiometricEnabled(false);
    await disableLoginPin();
    await _hardLogout();
    notifyListeners();
  }

  /// Unregister while the bearer token is still valid - this call is
  /// itself authenticated, and _clearSession() below wipes it.
  Future<void> _hardLogout() async {
    await _push.unregisterCurrentToken();

    try {
      await _api.post('/wali/logout');
    } catch (_) {
      // Best-effort - still clear the local session even if the server
      // call fails (e.g. token already expired), so the user isn't stuck.
    }

    await _clearSession();
  }

  Future<void> _clearSession() async {
    _token = null;
    _user = null;
    _needsBiometricUnlock = false;
    _needsPinUnlock = false;
    _api.setToken(null);
    await _storage.delete(key: 'token');
    await _storage.delete(key: _loginPinKey);
    _loginPin = null;
  }

  String _deviceName() {
    final platform = Platform.operatingSystem;
    return 'Wali App ($platform)';
  }
}
