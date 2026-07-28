import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/anak_provider.dart';
import 'providers/app_info_provider.dart';
import 'providers/banner_provider.dart';
import 'providers/tab_index_provider.dart';
import 'screens/auth_gate.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/biometric_service.dart';
import 'services/push_notification_service.dart';
import 'services/wali_api.dart';
import 'theme/app_theme.dart';
import 'widgets/session_activity_guard.dart';
import 'widgets/app_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final apiClient = ApiClient();
  final waliApi = WaliApi(apiClient);
  final biometricService = BiometricService();
  final navigatorKey = GlobalKey<NavigatorState>();
  final pushService = PushNotificationService(waliApi, navigatorKey);

  runApp(
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
        ChangeNotifierProvider<AnakProvider>(
          create: (_) => AnakProvider(waliApi),
        ),
        ChangeNotifierProvider<AppInfoProvider>(
          create: (_) => AppInfoProvider(waliApi),
        ),
        ChangeNotifierProvider<BannerProvider>(
          create: (_) => BannerProvider(waliApi),
        ),
        ChangeNotifierProvider<TabIndexProvider>(
          create: (_) => TabIndexProvider(),
        ),
      ],
      child: WaliSantriApp(navigatorKey: navigatorKey),
    ),
  );

  // Push notification is optional and must never hold the first Flutter
  // frame hostage. Some devices take a long time resolving Google Play
  // Services or the notification permission prompt; initializing it after
  // runApp keeps splash/auth navigation responsive even in that situation.
  unawaited(_initializePushSafely(pushService));
}

Future<void> _initializePushSafely(PushNotificationService pushService) async {
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 10));
    await pushService.init().timeout(const Duration(seconds: 12));
    unawaited(pushService.registerCurrentToken());
  } catch (error, stackTrace) {
    // Login, saldo, tagihan, and every other core feature remain usable
    // without FCM. The next cold start will retry initialization.
    debugPrint('Push notification initialization skipped: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class WaliSantriApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const WaliSantriApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'E-Mall Annuqayah',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);

        return MediaQuery(
          // Preserve accessibility while keeping the dense financial layouts
          // predictable across devices.
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.15,
            ),
          ),
          child: AppBackground(child: child!),
        );
      },
      home: const SessionActivityGuard(child: AuthGate()),
    );
  }
}
