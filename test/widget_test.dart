import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wali_santri/main.dart';
import 'package:wali_santri/providers/app_info_provider.dart';
import 'package:wali_santri/providers/maintenance_provider.dart';
import 'package:wali_santri/services/api_client.dart';
import 'package:wali_santri/services/auth_service.dart';
import 'package:wali_santri/services/biometric_service.dart';
import 'package:wali_santri/services/push_notification_service.dart';
import 'package:wali_santri/services/wali_api.dart';

void main() {
  // flutter_secure_storage talks to a platform channel that doesn't exist
  // under `flutter test` - mock it to behave like a fresh install (no saved
  // token) so AuthService.restoreSession() can run without a real device.
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
  });

  testWidgets(
    'shows onboarding then the login screen on a fresh install with no saved session',
    (tester) async {
      final apiClient = ApiClient();
      final waliApi = WaliApi(apiClient);
      final biometricService = BiometricService();
      final navigatorKey = GlobalKey<NavigatorState>();
      // Not initialized (no .init() call) - a fresh install never has a
      // saved token, so AuthService.restoreSession() never reaches the
      // registerCurrentToken() call that would need FirebaseMessaging's
      // platform channel, which isn't mocked here.
      final pushService = PushNotificationService(waliApi, navigatorKey);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiClient>.value(value: apiClient),
            Provider<WaliApi>.value(value: waliApi),
            Provider<BiometricService>.value(value: biometricService),
            Provider<PushNotificationService>.value(value: pushService),
            ChangeNotifierProvider<AuthService>(
              create: (_) =>
                  AuthService(apiClient, biometricService, pushService)
                    ..restoreSession(),
            ),
            ChangeNotifierProvider<AppInfoProvider>(
              create: (_) => AppInfoProvider(waliApi),
            ),
            ChangeNotifierProvider<MaintenanceProvider>(
              create: (_) => MaintenanceProvider(apiClient),
            ),
          ],
          child: WaliSantriApp(navigatorKey: navigatorKey),
        ),
      );

      // AuthGate holds the splash screen open for a fixed minimum duration
      // (independent of how fast restoreSession() resolves) - it also has
      // an indeterminate spinner, so pumpAndSettle() would hang while it's
      // still mounted. Advance real+fake time past that window instead.
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Fresh install -> not logged in and not yet onboarded -> onboarding.
      expect(find.text('Lewati'), findsOneWidget);

      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();

      expect(find.text('Selamat datang kembali'), findsOneWidget);
      expect(find.text('Masuk'), findsOneWidget);
    },
  );
}
