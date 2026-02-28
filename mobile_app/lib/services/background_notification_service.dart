import 'dart:convert';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../config/api_config.dart';

/// Unique task name for WorkManager periodic registration.
const String backgroundNotificationTask = 'backgroundNotificationPolling';

/// Key used to store the last-known notification IDs in SharedPreferences.
const String _knownIdsKey = 'bg_known_notification_ids';

/// Top-level callback — runs in a separate isolate (no access to widget tree).
/// This is the entry point that WorkManager invokes.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == backgroundNotificationTask ||
        taskName == Workmanager.iOSBackgroundTask) {
      try {
        await _pollNotificationsInBackground();
      } catch (e) {
        debugPrint('[BgNotif] Error: $e');
      }
    }
    return Future.value(true);
  });
}

/// Does the actual polling work inside the background isolate.
Future<void> _pollNotificationsInBackground() async {
  // 1. Read auth token from secure storage
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'auth_token');
  if (token == null || token.isEmpty) {
    debugPrint('[BgNotif] No auth token — skipping');
    return;
  }

  // 2. Fetch recent notifications from the backend
  final url = Uri.parse(
    '${ApiConfig.productionUrl}/notifications/recent?limit=20',
  );
  final response = await http
      .get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      )
      .timeout(const Duration(seconds: 15));

  if (response.statusCode != 200) {
    debugPrint('[BgNotif] API returned ${response.statusCode}');
    return;
  }

  final List<dynamic> notifications = jsonDecode(response.body);

  // 3. Load previously known IDs from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final storedIds = prefs.getStringList(_knownIdsKey) ?? [];
  final knownIds = storedIds.toSet();

  // 4. Find new notifications
  final newNotifs = <Map<String, dynamic>>[];
  final allIds = <String>{...knownIds};

  for (final n in notifications) {
    final id = n['id'] as String?;
    if (id != null) {
      allIds.add(id);
      if (!knownIds.contains(id)) {
        newNotifs.add(Map<String, dynamic>.from(n));
      }
    }
  }

  // 5. Save updated known IDs (keep last 100 to avoid unbounded growth)
  final idsList = allIds.toList();
  if (idsList.length > 100) {
    idsList.removeRange(0, idsList.length - 100);
  }
  await prefs.setStringList(_knownIdsKey, idsList);

  // 6. Show local notifications for each new one
  if (newNotifs.isEmpty) {
    debugPrint('[BgNotif] No new notifications');
    return;
  }

  // Initialize flutter_local_notifications in this isolate
  final flutterLocalNotifications = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  await flutterLocalNotifications.initialize(initSettings);

  for (final n in newNotifs) {
    final title = n['title'] as String? ?? 'Nettoyage Plus';
    final body = n['body'] as String? ?? n['message'] as String? ?? '';
    final type = n['type'] as String? ?? 'info';

    // Pick the right channel based on notification type
    String channelId = 'nettoyage_plus_default';
    String channelName = 'Nettoyage Plus';
    if (type.contains('mission')) {
      channelId = 'nettoyage_plus_missions';
      channelName = 'Missions';
    } else if (type.contains('message')) {
      channelId = 'nettoyage_plus_messages';
      channelName = 'Messages';
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
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

    await flutterLocalNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + newNotifs.indexOf(n),
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode({'type': type, 'notificationId': n['id']}),
    );
  }

  debugPrint('[BgNotif] Showed ${newNotifs.length} notification(s)');
}

/// Helper: sync the foreground polling service's known IDs to SharedPreferences
/// so the background isolate won't re-notify about IDs the app already showed.
Future<void> syncKnownIdsToPrefs(Set<String> ids) async {
  final prefs = await SharedPreferences.getInstance();
  final existing = (prefs.getStringList(_knownIdsKey) ?? []).toSet();
  existing.addAll(ids);
  final list = existing.toList();
  if (list.length > 100) list.removeRange(0, list.length - 100);
  await prefs.setStringList(_knownIdsKey, list);
}
