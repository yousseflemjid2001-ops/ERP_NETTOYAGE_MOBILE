import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// In-app notification payload — used for platforms where native notifications
/// are not available (e.g. web) and also for UI badge updates.
class InAppNotification {
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  InAppNotification({required this.title, required this.body, this.data})
    : timestamp = DateTime.now();
}

/// NotificationService — gère les notifications locales (sans Firebase).
/// Les notifications sont déclenchées depuis l'API NestJS/Supabase via polling.
/// Sur web : utilise un flux in-app (les notifications natives ne sont pas supportées).
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Null on web — instantiated lazily only on native platforms.
  FlutterLocalNotificationsPlugin? _localNotifications;

  bool _initialized = false;
  bool _nativeSupported = false;

  final StreamController<Map<String, dynamic>> _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTapController.stream;

  /// Stream for in-app notifications (works on ALL platforms including web).
  final StreamController<InAppNotification> _inAppController =
      StreamController<InAppNotification>.broadcast();
  Stream<InAppNotification> get onInAppNotification => _inAppController.stream;

  /// Unread in-app notification count (for badge updates).
  int _unreadInAppCount = 0;
  int get unreadInAppCount => _unreadInAppCount;

  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();
  Stream<int> get onUnreadCountChanged => _unreadCountController.stream;

  void updateUnreadCount(int count) {
    _unreadInAppCount = count;
    _unreadCountController.add(count);
  }

  // ============================================
  // INITIALISATION
  // ============================================

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Native local notifications are only supported on Android/iOS/macOS/Linux
    if (!kIsWeb) {
      try {
        await _initLocalNotifications();
        _nativeSupported = true;
        debugPrint('[Notifications] Native notifications initialized');
      } catch (e) {
        _nativeSupported = false;
        debugPrint('[Notifications] Native init failed (using in-app): $e');
      }
    } else {
      _nativeSupported = false;
      debugPrint('[Notifications] Web platform — using in-app notifications');
    }
  }

  Future<void> _initLocalNotifications() async {
    _localNotifications = FlutterLocalNotificationsPlugin();

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

    await _localNotifications!.initialize(
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

    // Créer les canaux Android
    await _createAndroidChannel();

    // Demander la permission POST_NOTIFICATIONS (Android 13+ / API 33+)
    await _requestAndroidPermission();
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
        ?.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(defaultChannel);
    await android?.createNotificationChannel(missionChannel);
  }

  /// Demande la permission POST_NOTIFICATIONS sur Android 13+ (API 33+).
  Future<void> _requestAndroidPermission() async {
    final android = _localNotifications
        ?.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      debugPrint('[Notifications] Permission accordée: $granted');
    }
  }

  /// Expose la méthode pour re-demander la permission depuis l'UI.
  Future<bool?> requestPermission() async {
    final android = _localNotifications
        ?.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return android?.requestNotificationsPermission();
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
    if (!_nativeSupported) return;

    try {
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

      await _localNotifications?.show(
        id,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[Notifications] Native show failed: $e');
    }
  }

  /// Affiche une notification locale immédiate.
  /// Also emits to the in-app stream (works on all platforms).
  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Always emit to in-app stream (works everywhere)
    _inAppController.add(
      InAppNotification(title: title, body: body, data: data),
    );
    _unreadInAppCount++;
    _unreadCountController.add(_unreadInAppCount);

    // Try native notification (Android/iOS only)
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
    // Always emit to in-app stream
    _inAppController.add(
      InAppNotification(title: title, body: body, data: data),
    );
    _unreadInAppCount++;
    _unreadCountController.add(_unreadInAppCount);

    if (!_nativeSupported) return;

    try {
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

      await _localNotifications?.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: data != null ? jsonEncode(data) : null,
      );
    } catch (e) {
      debugPrint('[Notifications] Mission notification native show failed: $e');
    }
  }

  void dispose() {
    _notificationTapController.close();
    _inAppController.close();
    _unreadCountController.close();
  }
}
