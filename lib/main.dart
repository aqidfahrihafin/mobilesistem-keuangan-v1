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
import 'widgets/session_activity_guard.dart';
import 'widgets/app_background.dart';

const _teal = Color(0xFF0F766E);

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
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _teal, // matches the web app's teal-700 brand color
        scaffoldBackgroundColor: Colors.transparent,
        // Flat/PayPal-style look throughout: no drop shadows on the
        // surfaces that show them by default in Material.
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xDDF8FBFC),
          foregroundColor: Color(0xFF17212B),
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xEAF1F8F6),
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0x80A9CEC8), width: 1.1),
          ),
        ),
        dialogTheme: DialogThemeData(
          elevation: 0,
          backgroundColor: const Color(0xF2F4F9F8),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xCCFFFFFF)),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xF2F4F9F8),
          modalBackgroundColor: Color(0xF2F4F9F8),
          surfaceTintColor: Colors.transparent,
          showDragHandle: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0x1F475569),
          thickness: 1,
          space: 1,
        ),
        // 'fixed' (Material's default) reserves space at the very bottom of
        // the Scaffold and pushes any floatingActionButton up above it while
        // shown - very visible on MainScreen's docked Top Up button. Every
        // SnackBar in this app goes through this theme, so 'floating' fixes
        // that jump everywhere at once instead of passing `behavior:` at
        // each individual showSnackBar() call site.
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _teal,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _teal,
            side: const BorderSide(color: _teal),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xCCFFFFFF),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _teal, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
          ),
        ),
      ),
      // Locks text scale to the OS default regardless of the user's system
      // font-size setting - the same choice most banking/fintech apps make,
      // so layouts (fixed-height rows/buttons, card grids, etc.) render
      // identically for every user rather than needing to tolerate a range
      // of scales. Trade-off: a wali who relies on a larger system font for
      // readability gets no accommodation within this app specifically.
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);

        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: TextScaler.noScaling),
          child: AppBackground(child: child!),
        );
      },
      home: const SessionActivityGuard(child: AuthGate()),
    );
  }
}
