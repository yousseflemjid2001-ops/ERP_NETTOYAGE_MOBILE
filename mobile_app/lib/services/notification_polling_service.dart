import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'notification_service.dart';

/// Polls the backend every [pollInterval] for new notifications (from admin
/// or system) and triggers local/in-app notifications when a new one appears.
/// Also keeps the unread count updated for UI badges.
class NotificationPollingService {
  static final NotificationPollingService _instance =
      NotificationPollingService._internal();
  factory NotificationPollingService() => _instance;
  NotificationPollingService._internal();

  final ApiService _api = ApiService();
  final NotificationService _notifications = NotificationService();

  Timer? _timer;
  bool _isRunning = false;

  /// IDs of notifications we've already shown locally.
  final Set<String> _knownIds = {};

  /// Current unread count from backend.
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  /// Stream that broadcasts the latest unread count.
  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();
  Stream<int> get onUnreadCountChanged => _unreadCountController.stream;

  /// Stream that emits when new notifications arrive.
  final StreamController<List<Map<String, dynamic>>>
  _newNotificationsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get onNewNotifications =>
      _newNotificationsController.stream;

  /// Poll interval: 10 seconds.
  static const Duration pollInterval = Duration(seconds: 10);

  // ============================================
  // START / STOP
  // ============================================

  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // Initial load: cache all existing notification IDs without showing them.
    _fetchAndCompare(isInitialLoad: true);

    _timer = Timer.periodic(pollInterval, (_) {
      _fetchAndCompare(isInitialLoad: false);
    });

    debugPrint('[NotifPolling] Started (every ${pollInterval.inSeconds}s)');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _knownIds.clear();
    debugPrint('[NotifPolling] Stopped');
  }

  // ============================================
  // CORE LOGIC
  // ============================================

  Future<void> _fetchAndCompare({required bool isInitialLoad}) async {
    try {
      // Fetch recent notifications from backend
      final notifications = await _api.getNotifications();

      // Update unread count
      try {
        final countData = await _api.getUnreadCount();
        final count = countData['count'] as int? ?? 0;
        if (count != _unreadCount) {
          _unreadCount = count;
          _unreadCountController.add(_unreadCount);
          _notifications.updateUnreadCount(count);
        }
      } catch (e) {
        debugPrint('[NotifPolling] Unread count error: $e');
      }

      if (isInitialLoad) {
        // Populate cache without showing notifications.
        for (final n in notifications) {
          final id = n['id'] as String?;
          if (id != null) _knownIds.add(id);
        }
        debugPrint(
          '[NotifPolling] Initial cache: ${_knownIds.length} notifications',
        );
        return;
      }

      // Find new notifications
      final newNotifs = <Map<String, dynamic>>[];
      for (final n in notifications) {
        final id = n['id'] as String?;
        if (id != null && !_knownIds.contains(id)) {
          _knownIds.add(id);
          newNotifs.add(n);
        }
      }

      // Show local notifications for new backend notifications
      for (final n in newNotifs) {
        final title = n['title'] as String? ?? 'Notification';
        final body = n['body'] as String? ?? n['message'] as String? ?? '';
        final type = n['type'] as String? ?? 'info';

        try {
          await _notifications.showNotification(
            title: title,
            body: body,
            data: {'type': type, 'notificationId': n['id']},
          );
        } catch (e) {
          debugPrint('[NotifPolling] Show notification error: $e');
        }
      }

      if (newNotifs.isNotEmpty) {
        _newNotificationsController.add(newNotifs);
        debugPrint('[NotifPolling] ${newNotifs.length} new notification(s)');
      }
    } catch (e) {
      debugPrint('[NotifPolling] Error: $e');
    }
  }

  /// Force refresh unread count (e.g. after marking all as read).
  Future<void> refreshUnreadCount() async {
    try {
      final countData = await _api.getUnreadCount();
      final count = countData['count'] as int? ?? 0;
      _unreadCount = count;
      _unreadCountController.add(_unreadCount);
      _notifications.updateUnreadCount(count);
    } catch (e) {
      debugPrint('[NotifPolling] refreshUnreadCount error: $e');
    }
  }

  void dispose() {
    stop();
    _unreadCountController.close();
    _newNotificationsController.close();
  }
}
