import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:wali_santri/services/api_client.dart';
import 'package:wali_santri/services/auth_service.dart';
import 'package:wali_santri/services/biometric_service.dart';
import 'package:wali_santri/services/push_notification_service.dart';
import 'package:wali_santri/services/wali_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  late Map<String, String> secureValues;

  setUp(() {
    secureValues = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          final arguments =
              (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
          final key = arguments['key'] as String?;

          switch (call.method) {
            case 'read':
              return key == null ? null : secureValues[key];
            case 'write':
              if (key != null) {
                secureValues[key] = arguments['value'] as String;
              }
              return null;
            case 'delete':
              if (key != null) secureValues.remove(key);
              return null;
            case 'deleteAll':
              secureValues.clear();
              return null;
            case 'containsKey':
              return key != null && secureValues.containsKey(key);
            case 'readAll':
              return secureValues;
          }

          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  AuthService createService() {
    final api = ApiClient();
    final navigatorKey = GlobalKey<NavigatorState>();
    final push = PushNotificationService(WaliApi(api), navigatorKey);

    return AuthService(api, BiometricService(), push);
  }

  test(
    'wrong PIN attempts survive a process restart and the fifth forces password',
    () async {
      final firstProcess = createService();
      await firstProcess.setLoginPin('246810');

      for (var attempt = 0; attempt < 4; attempt++) {
        expect(await firstProcess.recordFailedLoginPinAttempt(), isFalse);
      }
      expect(firstProcess.loginPinFailedAttempts, 4);

      final restartedProcess = createService();
      await restartedProcess.restoreSession();

      expect(restartedProcess.loginPinEnabled, isTrue);
      expect(restartedProcess.loginPinFailedAttempts, 4);
      expect(await restartedProcess.recordFailedLoginPinAttempt(), isTrue);
      expect(restartedProcess.loginPinEnabled, isFalse);
      expect(restartedProcess.loginPinFailedAttempts, 0);
    },
  );

  test(
    'restart proses memulihkan sesi terenkripsi langsung ke gerbang PIN',
    () async {
      secureValues.addAll({
        'token': '1|token-uji',
        'login_pin': '246810',
        'quick_login_user_id': '7',
        'quick_login_cached_user':
            '{"id":7,"name":"Wali Uji","email":"wali@example.test","phone":null,"must_change_password":false}',
        'has_onboarded': 'true',
      });

      final restartedProcess = createService();
      await restartedProcess.restoreSession();

      expect(restartedProcess.isLoggedIn, isTrue);
      expect(restartedProcess.user?.id, 7);
      expect(restartedProcess.needsPinUnlock, isTrue);
      expect(restartedProcess.needsBiometricUnlock, isFalse);
    },
  );

  test(
    'restart proses memulihkan sesi langsung ke gerbang biometrik',
    () async {
      secureValues.addAll({
        'token': '1|token-uji',
        'biometric_enabled': 'true',
        'quick_login_user_id': '8',
        'quick_login_cached_user':
            '{"id":8,"name":"Wali Biometrik","email":null,"phone":null,"must_change_password":false}',
        'has_onboarded': 'true',
      });

      final restartedProcess = createService();
      await restartedProcess.restoreSession();

      expect(restartedProcess.isLoggedIn, isTrue);
      expect(restartedProcess.user?.id, 8);
      expect(restartedProcess.needsPinUnlock, isFalse);
      expect(restartedProcess.needsBiometricUnlock, isTrue);
    },
  );
}
