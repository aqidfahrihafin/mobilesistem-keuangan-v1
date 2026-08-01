import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
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
  static const _loginPinFailedAttemptsKey = 'login_pin_failed_attempts';
  static const _quickLoginUserIdKey = 'quick_login_user_id';
  static const _cachedUserKey = 'quick_login_cached_user';
  static const _quickTokenKey = 'quick_login_refresh_token';
  static const _onboardedKey = 'has_onboarded';

  WaliUser? _user;
  String? _token;
  String? _quickToken;
  bool _restoring = true;
  bool _biometricEnabled = false;
  String? _loginPin;
  int? _quickLoginUserId;
  int _loginPinFailedAttempts = 0;
  bool _hasOnboarded = false;
  String? _sessionNotice;
  String? _quickLoginError;

  /// True whenever the session is otherwise valid but still needs a
  /// biometric check before the wali can see the app - set at boot (if
  /// biometricEnabled) and again whenever SessionActivityGuard locks the
  /// app for inactivity. Cleared by a successful unlockWithBiometrics().
  bool _needsBiometricUnlock = false;
  bool _needsPinUnlock = false;

  AuthService(this._api, this._biometric, this._push) {
    _api.setUnauthorizedHandler(_handleUnauthorized);
    _push.setAuthenticationReadyCheck(
      () => isLoggedIn && !_needsPinUnlock && !_needsBiometricUnlock,
    );
  }

  WaliUser? get user => _user;
  bool get isLoggedIn => _token != null && _user != null;
  bool get mustChangePassword => _user?.mustChangePassword ?? false;
  bool get restoring => _restoring;
  bool get biometricEnabled => _biometricEnabled;
  bool get needsBiometricUnlock => _needsBiometricUnlock;
  bool get needsPinUnlock => _needsPinUnlock;
  bool get loginPinEnabled => _loginPin != null;
  int get loginPinFailedAttempts => _loginPinFailedAttempts;
  bool get hasOnboarded => _hasOnboarded;
  String? get sessionNotice => _sessionNotice;
  String? get quickLoginError => _quickLoginError;

  Future<bool> _handleUnauthorized() async {
    if (_token == null) return false;

    if (_quickToken != null && (_loginPin != null || _biometricEnabled)) {
      try {
        final data = await _api.postPublic('/wali/quick-login', {
          'quick_token': _quickToken,
          'device_name': _deviceName(),
        });
        _token = data['token'] as String;
        _quickToken = data['quick_token'] as String;
        _user = WaliUser.fromJson(data['user'] as Map<String, dynamic>);
        await _storage.write(key: 'token', value: _token);
        await _storage.write(key: _quickTokenKey, value: _quickToken);
        await _cacheCurrentUser();
        _api.setToken(_token);
        notifyListeners();
        return true;
      } catch (_) {
        // Token pemulihan yang ditolak memang mewajibkan password. Gangguan
        // jaringan tetap ditampilkan sebagai kegagalan request biasa.
      }
    }

    _sessionNotice =
        'Sesi Anda telah berakhir demi keamanan. Silakan masuk kembali untuk melanjutkan.';
    // Keep the locally configured PIN/biometric preference. The dead token
    // itself is removed, but a password login by the same wali can restore
    // quick login without forcing them to configure the PIN from scratch.
    // login() clears it if a different account signs in.
    await _clearSession(clearQuickLogin: false);
    notifyListeners();
    return false;
  }

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
      _quickToken = await _storage.read(key: _quickTokenKey);
      _biometricEnabled =
          await _storage.read(key: _biometricEnabledKey) == 'true';
      _loginPin = await _storage.read(key: _loginPinKey);
      _quickLoginUserId = int.tryParse(
        await _storage.read(key: _quickLoginUserIdKey) ?? '',
      );
      _loginPinFailedAttempts =
          int.tryParse(
            await _storage.read(key: _loginPinFailedAttemptsKey) ?? '',
          ) ??
          0;
      _hasOnboarded = await _storage.read(key: _onboardedKey) == 'true';

      if (_token != null) {
        _api.setToken(_token);
        final cachedUser = await _storage.read(key: _cachedUserKey);
        if (cachedUser != null) {
          try {
            _user = WaliUser.fromJson(
              Map<String, dynamic>.from(jsonDecode(cachedUser) as Map),
            );
          } catch (_) {
            await _storage.delete(key: _cachedUserKey);
          }
        }

        // Profil terenkripsi lokal cukup untuk menentukan gerbang PIN atau
        // biometrik saat proses aplikasi dimulai ulang. Validasi token tetap
        // terjadi pada request API berikutnya; startup tidak perlu jatuh ke
        // formulir password hanya karena jaringan sedang lambat.
        if (_user != null) {
          await _adoptLegacyQuickLoginFor(_user!.id);
          _needsPinUnlock = _loginPin != null;
          _needsBiometricUnlock = _biometricEnabled && _loginPin == null;
          unawaited(_push.registerCurrentToken());
        } else {
          try {
            final data = await _api.get('/wali/me');
            _user = WaliUser.fromJson(data as Map<String, dynamic>);
            await _cacheCurrentUser();
            await _adoptLegacyQuickLoginFor(_user!.id);
            _needsPinUnlock = _loginPin != null;
            _needsBiometricUnlock = _biometricEnabled && _loginPin == null;
            unawaited(_push.registerCurrentToken());
          } on ApiException catch (error) {
            if (error.statusCode != 401) {
              // Gangguan koneksi bukan bukti bahwa sesi tersimpan tidak sah.
              _user = null;
              _api.setToken(_token);
              _sessionNotice =
                  'Sesi dan PIN Anda tetap tersimpan, tetapi server belum dapat dihubungi. Coba masuk dengan PIN saat koneksi kembali normal.';
            }
            // Respons 401 ditangani terpusat dan menghapus token yang mati.
          } catch (_) {
            _user = null;
            _api.setToken(_token);
            _sessionNotice =
                'Sesi dan PIN Anda tetap tersimpan. Server belum memberikan respons yang valid; silakan coba kembali.';
          }
        }
      }

      // A device that already has a session (e.g. upgraded from a build
      // before onboarding existed) shouldn't be interrupted with onboarding
      // slides - treat "already logged in" as implicitly onboarded.
      if (_user != null && !_hasOnboarded) {
        await completeOnboarding();
      }
      _openPendingPush();
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
    _quickLoginError = null;
    final data = await _api.post('/wali/login', {
      'login': login,
      'password': password,
      'device_name': _deviceName(),
    });

    _token = data['token'] as String;
    _quickToken = data['quick_token'] as String?;
    final nextUser = WaliUser.fromJson(data['user'] as Map<String, dynamic>);
    if (_quickLoginUserId != null && _quickLoginUserId != nextUser.id) {
      await _clearQuickLogin();
    }
    _user = nextUser;
    await _cacheCurrentUser();
    await _adoptLegacyQuickLoginFor(_user!.id);
    _needsPinUnlock = false;
    _needsBiometricUnlock = false;
    _sessionNotice = null;
    await _resetLoginPinAttempts();
    await _storage.write(key: 'token', value: _token);
    if (_quickToken != null) {
      await _storage.write(key: _quickTokenKey, value: _quickToken);
    }
    _api.setToken(_token);
    unawaited(_push.registerCurrentToken());
    notifyListeners();
    _openPendingPush();
  }

  /// Only meant to be called after BiometricService.authenticate() has
  /// already succeeded once (see ProfilTab's toggle) - this just persists
  /// the resulting preference, it doesn't itself prompt for biometrics.
  Future<void> setBiometricEnabled(bool value) async {
    _biometricEnabled = value;

    if (value) {
      await _storage.write(key: _biometricEnabledKey, value: 'true');
      await _rememberQuickLoginOwner();
    } else {
      await _storage.delete(key: _biometricEnabledKey);
      if (_loginPin == null) {
        // No quick-login gate remains. Revoke the retained session so a
        // process restart cannot bypass the requested password login.
        await _hardLogout();
        notifyListeners();
        return;
      }
    }

    notifyListeners();
  }

  Future<void> setLoginPin(String pin) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw ArgumentError('PIN login harus terdiri dari 6 angka.');
    }
    _loginPin = pin;
    await _storage.write(key: _loginPinKey, value: pin);
    await _resetLoginPinAttempts();
    await _rememberQuickLoginOwner();
    notifyListeners();
  }

  Future<void> disableLoginPin() async {
    _loginPin = null;
    _needsPinUnlock = false;
    await _storage.delete(key: _loginPinKey);
    await _resetLoginPinAttempts();
    if (!_biometricEnabled) {
      // Disabling the final quick-login method means future starts must use
      // credentials, not a bearer token restored directly into the account.
      await _hardLogout();
      notifyListeners();
      return;
    }
    notifyListeners();
  }

  /// Leaves quick-login mode, revokes the retained session, and returns to
  /// the regular credential screen. PIN and biometric are a single
  /// convenience/security preference: choosing "Gunakan Password"
  /// (also invoked after five wrong PIN attempts) disables both, so there
  /// is no second quick-login path silently left active.
  Future<void> usePasswordInsteadOfPin() async {
    _needsPinUnlock = false;
    _needsBiometricUnlock = false;
    // Also revoke the retained token. Keeping it would let reopening the app
    // restore /wali/me and silently skip the password screen.
    await _hardLogout();
    notifyListeners();
  }

  bool unlockWithPin(String pin) {
    if (_loginPin == null || pin != _loginPin) return false;
    _needsPinUnlock = false;
    _needsBiometricUnlock = false;
    _sessionNotice = null;
    notifyListeners();
    _openPendingPush();
    return true;
  }

  /// Persist failures so removing the app from Recents cannot reset four
  /// wrong attempts into unlimited offline guesses.
  ///
  /// Returns true when the fifth failure has disabled quick login and forced
  /// a complete password login.
  Future<bool> recordFailedLoginPinAttempt() async {
    _loginPinFailedAttempts++;
    await _storage.write(
      key: _loginPinFailedAttemptsKey,
      value: '$_loginPinFailedAttempts',
    );

    if (_loginPinFailedAttempts >= 5) {
      await usePasswordInsteadOfPin();
      return true;
    }

    notifyListeners();
    return false;
  }

  Future<void> resetLoginPinAttemptsAfterSuccess() => _resetLoginPinAttempts();

  Future<BiometricAuthResult> unlockWithBiometrics() async {
    final result = await _biometric.authenticate();

    if (result == BiometricAuthResult.success) {
      _needsBiometricUnlock = false;
      _needsPinUnlock = false;
      _sessionNotice = null;
      await _resetLoginPinAttempts();
      notifyListeners();
      _openPendingPush();
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
      await _cacheCurrentUser();
      await _resetLoginPinAttempts();
      unawaited(_push.registerCurrentToken());
      notifyListeners();
      _openPendingPush();
      return BiometricAuthResult.success;
    } catch (_) {
      // ApiClient already removes a genuinely invalid token on 401.
      // Connectivity/maintenance failures leave token and quick-login
      // preferences intact so the user can retry without setting them up.
      notifyListeners();
      return BiometricAuthResult.failedOrCancelled;
    }
  }

  Future<bool> loginWithPin(String pin) async {
    _quickLoginError = null;
    if (_loginPin == null || pin != _loginPin || _token == null) return false;

    _api.setToken(_token);
    try {
      final data = await _api.get('/wali/me');
      _user = WaliUser.fromJson(data as Map<String, dynamic>);
      await _cacheCurrentUser();
      _needsPinUnlock = false;
      _needsBiometricUnlock = false;
      await _resetLoginPinAttempts();
      unawaited(_push.registerCurrentToken());
      notifyListeners();
      _openPendingPush();
      return true;
    } on ApiException catch (error) {
      // Same rule as biometric login: never interpret a temporary network
      // failure as permission to erase the user's locally configured PIN.
      _quickLoginError = error.statusCode == 401
          ? 'Sesi server telah berakhir. Masuk sekali dengan kata sandi; PIN Anda tidak dihapus.'
          : error.message;
      notifyListeners();
      return false;
    } catch (_) {
      _quickLoginError =
          'Server belum memberikan respons yang valid. PIN Anda tetap tersimpan; silakan coba lagi.';
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

    _sessionNotice = _loginPin != null
        ? 'Aplikasi dikunci otomatis karena tidak aktif atau sempat ditinggalkan. Masukkan PIN untuk melanjutkan.'
        : _biometricEnabled
        ? 'Aplikasi dikunci otomatis karena tidak aktif atau sempat ditinggalkan. Verifikasi sidik jari untuk melanjutkan.'
        : 'Sesi ditutup otomatis karena aplikasi tidak aktif. Silakan masuk kembali untuk melanjutkan.';
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
    await _cacheCurrentUser();
    notifyListeners();
  }

  Future<void> updateProfilePhoto(String filePath) async {
    final data = await _api.postFile(
      '/wali/profile/photo',
      field: 'photo',
      filePath: filePath,
    );
    _user = WaliUser.fromJson(data as Map<String, dynamic>);
    await _cacheCurrentUser();
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
      photoUrl: current.photoUrl,
      mustChangePassword: false,
    );
    await _cacheCurrentUser();
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
    await _hardLogout();
    notifyListeners();
  }

  /// Unregister while the bearer token is still valid - this call is
  /// itself authenticated, and _clearSession() below wipes it.
  Future<void> _hardLogout() async {
    final hadToken = _token != null;
    if (hadToken) {
      await _push.unregisterCurrentToken();

      try {
        await _api.post('/wali/logout');
      } catch (_) {
        // Best-effort - still clear the local session even if the server
        // call fails (e.g. token already expired), so the user isn't stuck.
      }
    }

    await _clearSession();
  }

  Future<void> _clearSession({bool clearQuickLogin = true}) async {
    _token = null;
    _quickToken = null;
    _user = null;
    _needsBiometricUnlock = false;
    _needsPinUnlock = false;
    _api.setToken(null);
    await _storage.delete(key: 'token');
    await _storage.delete(key: _quickTokenKey);
    await _storage.delete(key: _cachedUserKey);
    if (clearQuickLogin) await _clearQuickLogin();
  }

  Future<void> _clearQuickLogin() async {
    _loginPin = null;
    _biometricEnabled = false;
    _quickLoginUserId = null;
    _loginPinFailedAttempts = 0;
    await _storage.delete(key: _loginPinKey);
    await _storage.delete(key: _biometricEnabledKey);
    await _storage.delete(key: _quickLoginUserIdKey);
    await _storage.delete(key: _loginPinFailedAttemptsKey);
  }

  Future<void> _resetLoginPinAttempts() async {
    if (_loginPinFailedAttempts == 0) return;
    _loginPinFailedAttempts = 0;
    await _storage.delete(key: _loginPinFailedAttemptsKey);
  }

  Future<void> _rememberQuickLoginOwner() async {
    final userId = _user?.id;
    if (userId == null) return;
    _quickLoginUserId = userId;
    await _storage.write(key: _quickLoginUserIdKey, value: '$userId');
  }

  Future<void> _cacheCurrentUser() async {
    final user = _user;
    if (user == null) return;

    await _storage.write(
      key: _cachedUserKey,
      value: jsonEncode({
        'id': user.id,
        'name': user.name,
        'email': user.email,
        'phone': user.phone,
        'must_change_password': user.mustChangePassword,
      }),
    );
  }

  Future<void> _adoptLegacyQuickLoginFor(int userId) async {
    if ((_loginPin == null && !_biometricEnabled) ||
        _quickLoginUserId != null) {
      return;
    }
    _quickLoginUserId = userId;
    await _storage.write(key: _quickLoginUserIdKey, value: '$userId');
  }

  void _openPendingPush() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _push.openPendingIfReady();
    });
  }

  String _deviceName() {
    final platform = Platform.operatingSystem;
    return 'Wali App ($platform)';
  }
}
