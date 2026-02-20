import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// NotificationService — gère les notifications locales (sans Firebase).
/// Les notifications sont déclenchées depuis l'API NestJS/Supabase via polling.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final StreamController<Map<String, dynamic>> _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTapController.stream;

  // ============================================
  // INITIALISATION
  // ============================================

  Future<void> initialize() async {
    await _initLocalNotifications();
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
    const defaultChannel = AndroidNotificationChannel(
      'nettoyage_plus_default',
      'Nettoyage Plus',
      description: 'Notifications de l\'application Nettoyage Plus',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    const missionChannel = AndroidNotificationChannel(
      'nettoyage_plus_missions',
      'Missions',
      description: 'Notifications de nouvelles missions et modifications',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(defaultChannel);
    await android?.createNotificationChannel(missionChannel);
  }

  // ============================================
  // NOTIFICATIONS LOCALES
  // ============================================

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
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

  /// Affiche une notification locale immédiate.
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

  /// Notification spécifique aux missions (canal dédié).
  Future<void> showMissionNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'nettoyage_plus_missions',
      'Missions',
      channelDescription: 'Notifications de missions',
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

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  void dispose() {
    _notificationTapController.close();
  }
}
