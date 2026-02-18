import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

/// NotificationService — gère FCM (Firebase Cloud Messaging) + notifications locales.
///
/// Setup requis :
///   1. Ajouter google-services.json dans android/app/
///   2. Ajouter GoogleService-Info.plist dans ios/Runner/
///   3. Appeler NotificationService().initialize() dans main()

/// Handler de background messages (doit être top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM Background: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _messaging;
  String? _fcmToken;

  final StreamController<Map<String, dynamic>> _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTapController.stream;

  // ============================================
  // INITIALISATION
  // ============================================

  Future<void> initialize() async {
    await _initLocalNotifications();
    await _initFCM();
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload != null) {
          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;
            _notificationTapController.add(data);
          } catch (_) {}
        }
      },
    );

    // Créer le canal Android par défaut
    await _createAndroidChannel();
  }

  Future<void> _createAndroidChannel() async {
    const channel = AndroidNotificationChannel(
      'nettoyage_plus_default',
      'Nettoyage Plus',
      description: 'Notifications de l\'application Nettoyage Plus',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  Future<void> _initFCM() async {
    try {
      _messaging = FirebaseMessaging.instance;

      // Demande de permission (iOS)
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('FCM Permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Récupère le token FCM
        _fcmToken = await _messaging!.getToken();
        debugPrint('FCM Token: $_fcmToken');

        // Envoie le token au backend
        if (_fcmToken != null) {
          await _registerTokenWithBackend(_fcmToken!);
        }

        // Renouvellement du token
        _messaging!.onTokenRefresh.listen((newToken) {
          _fcmToken = newToken;
          _registerTokenWithBackend(newToken);
        });

        // Message reçu en foreground
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Message tap depuis notification (app en background)
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

        // App lancée depuis une notification
        final initialMessage = await _messaging!.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageTap(initialMessage);
        }

        // Handler background
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
      }
    } catch (e) {
      debugPrint('FCM init error (likely missing google-services.json): $e');
    }
  }

  Future<void> _registerTokenWithBackend(String token) async {
    try {
      await ApiService().registerFCMToken(token);
    } catch (e) {
      debugPrint('Failed to register FCM token with backend: $e');
    }
  }

  // ============================================
  // TRAITEMENT DES MESSAGES FCM
  // ============================================

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('FCM Foreground: ${message.notification?.title}');
    final notification = message.notification;
    if (notification == null) return;

    _showLocalNotification(
      id: message.hashCode,
      title: notification.title ?? 'Nettoyage Plus',
      body: notification.body ?? '',
      payload: jsonEncode(message.data),
      type: message.data['type'] as String? ?? 'default',
    );
  }

  void _handleMessageTap(RemoteMessage message) {
    _notificationTapController.add(message.data);
  }

  // ============================================
  // NOTIFICATIONS LOCALES
  // ============================================

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String type = 'default',
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'nettoyage_plus_default',
      'Nettoyage Plus',
      channelDescription: 'Notifications Nettoyage Plus',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF2563EB),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  /// Affiche une notification locale immédiate (sans FCM).
  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  /// Notification de sync offline réussie.
  Future<void> showSyncSuccess(int count) async {
    await showNotification(
      title: 'Synchronisé !',
      body: '$count action(s) synchronisée(s) avec succès.',
      data: {'type': 'sync'},
    );
  }

  /// Notification de rappel de mission.
  Future<void> showMissionReminder(String missionTitle, String time) async {
    await showNotification(
      title: 'Rappel de mission',
      body: '$missionTitle à $time',
      data: {'type': 'mission_reminder'},
    );
  }

  String? get fcmToken => _fcmToken;

  void dispose() {
    _notificationTapController.close();
  }
}
