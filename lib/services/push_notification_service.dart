import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/notification_item.dart';
import '../screens/notification_destination_screen.dart';
import '../screens/notifications_screen.dart';
import 'wali_api.dart';

const _teal = Color(0xFF0F766E);

/// Must be a top-level (or static) function - firebase_messaging invokes
/// this in its own isolate for messages that arrive while the app is fully
/// backgrounded/killed. Left intentionally empty: the OS already shows a
/// system notification for FCM's notification+data payload in that state,
/// this only exists because onBackgroundMessage requires a handler to be
/// registered at all.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Owns everything FCM: requesting notification permission, obtaining and
/// refreshing the device token (registering it server-side via
/// [WaliApi.registerDeviceToken]/[WaliApi.unregisterDeviceToken]), and
/// showing an OS notification for messages that arrive in the foreground
/// (FCM does not auto-display those - only background/killed-state
/// messages get a system banner for free).
///
/// Tapping a push opens the exact transaction/tagihan destination when its
/// payload contains an object id, with the inbox as a safe fallback.
class PushNotificationService {
  final WaliApi _waliApi;
  final GlobalKey<NavigatorState> navigatorKey;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  String? _currentToken;
  Map<String, dynamic>? _pendingDestination;
  bool _pendingInbox = false;
  bool Function()? _authenticationReady;

  PushNotificationService(this._waliApi, this.navigatorKey);

  void setAuthenticationReadyCheck(bool Function() check) {
    _authenticationReady = check;
  }

  /// Authentication can finish after an OS notification tap (cold start,
  /// expired session, PIN/biometric lock). Keep the destination until the
  /// auth gate is genuinely ready instead of firing an API request that
  /// immediately receives 401 and loses the deep link.
  void openPendingIfReady() {
    if (!(_authenticationReady?.call() ?? false)) return;
    final data = _pendingDestination;
    if (data == null && !_pendingInbox) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => openPendingIfReady());
      return;
    }

    _pendingDestination = null;
    final openInbox = _pendingInbox;
    _pendingInbox = false;
    navigator.popUntil((route) => route.isFirst);
    if (openInbox && data == null) {
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
      );
      return;
    }
    if (data == null) return;
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationDestinationScreen(
          item: NotificationItem(
            id: 0,
            title: data['_title']?.toString() ?? 'Notifikasi',
            body: data['_body']?.toString() ?? '',
            type: data['type']?.toString() ?? 'info',
            data: data,
            createdAt: DateTime.now(),
          ),
        ),
      ),
    );
  }

  // A getter, not a field initialized at construction time - accessing
  // FirebaseMessaging.instance requires Firebase.initializeApp() to have
  // already run, which main() does before constructing this service, but
  // widget tests construct this without touching Firebase at all and never
  // call init()/registerCurrentToken() either, so this is never evaluated.
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  Future<void> init() async {
    await _messaging.requestPermission();

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) {
          _openNotificationInbox();
          return;
        }
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            _openNotificationDestination(
              Map<String, dynamic>.from(decoded),
            );
          }
        } catch (_) {
          _openNotificationInbox();
        }
      },
    );

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    _messaging.onTokenRefresh.listen((token) {
      _currentToken = token;
      _waliApi.registerDeviceToken(token).catchError((_) {});
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _handleNotificationTap(initialMessage);
  }

  /// Call at every point the app confirms who's signed in (login,
  /// restoreSession, biometric unlock) - fetches the current token (if
  /// permission was granted) and registers it server-side. Best-effort:
  /// never throws, since a failed registration must never block sign-in.
  Future<void> registerCurrentToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      _currentToken = token;
      await _waliApi.registerDeviceToken(token);
    } catch (_) {
      // No permission granted, no network, etc - not fatal to signing in.
    }
  }

  /// Called on a hard sign-out only (see AuthService.logout()) - a soft
  /// lock keeps the session alive, so the device should keep receiving
  /// pushes. Must run before the auth token is cleared, since this call is
  /// itself authenticated.
  Future<void> unregisterCurrentToken() async {
    final token = _currentToken;
    if (token == null) return;

    try {
      await _waliApi.unregisterDeviceToken(token);
    } catch (_) {
      // Best-effort, same reasoning as registerCurrentToken().
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'wali_default',
          'Notifikasi',
          importance: Importance.high,
          priority: Priority.high,
          // Brand teal + the app's own launcher icon as the large icon -
          // without these, Android falls back to a plain grey/generic
          // bell, which reads as far less "trustworthy" than the branded
          // look banking apps use for exactly this reason.
          color: _teal,
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          styleInformation: BigTextStyleInformation(notification.body ?? ''),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode({
        ...message.data,
        '_title': notification.title,
        '_body': notification.body,
      }),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    if (message.data.isEmpty) {
      _openNotificationInbox();
      return;
    }
    _openNotificationDestination({
      ...message.data,
      '_title': message.notification?.title,
      '_body': message.notification?.body,
    });
  }

  void _openNotificationDestination(Map<String, dynamic> data) {
    _pendingInbox = false;
    _pendingDestination = Map<String, dynamic>.from(data);
    openPendingIfReady();
  }

  void _openNotificationInbox() {
    _pendingDestination = null;
    _pendingInbox = true;
    openPendingIfReady();
  }
}
