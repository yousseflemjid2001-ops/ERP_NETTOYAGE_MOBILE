import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'notification_service.dart';

/// Polls the backend every [pollInterval] for new unread messages and triggers
/// local/push notifications when new messages arrive.
/// Works alongside ConversationsPage's own UI polling.
class MessagePollingService {
  static final MessagePollingService _instance =
      MessagePollingService._internal();
  factory MessagePollingService() => _instance;
  MessagePollingService._internal();

  final ApiService _api = ApiService();
  final NotificationService _notifications = NotificationService();

  Timer? _timer;
  bool _isRunning = false;

  /// Track known message IDs (per conversation) to detect new ones.
  final Set<String> _knownMessageIds = {};

  /// Current total unread count.
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  /// Stream for unread count changes (for bottom nav badge).
  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();
  Stream<int> get onUnreadCountChanged => _unreadCountController.stream;

  /// Poll interval: 8 seconds.
  static const Duration pollInterval = Duration(seconds: 8);

  // ============================================
  // START / STOP
  // ============================================

  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // Initial check (cache IDs without notifying)
    _checkMessages(isInitial: true);

    _timer = Timer.periodic(pollInterval, (_) {
      _checkMessages(isInitial: false);
    });

    debugPrint('[MsgPolling] Started (every ${pollInterval.inSeconds}s)');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _knownMessageIds.clear();
    debugPrint('[MsgPolling] Stopped');
  }

  // ============================================
  // CORE LOGIC
  // ============================================

  Future<void> _checkMessages({required bool isInitial}) async {
    try {
      // 1. Update unread count
      try {
        final count = await _api.getMessagesUnreadCount();
        if (count != _unreadCount) {
          _unreadCount = count;
          _unreadCountController.add(_unreadCount);
        }
      } catch (e) {
        debugPrint('[MsgPolling] Unread count error: $e');
      }

      // 2. Check conversations for new messages
      final conversations = await _api.getConversations();

      for (final conv in conversations) {
        if (conv.unreadCount > 0 && conv.lastMessage != null) {
          // Use conversation id + lastMessageAt as unique key
          final key = '${conv.id}:${conv.lastMessageAt}';

          if (isInitial) {
            // Initial load: cache without notifications
            _knownMessageIds.add(key);
          } else if (!_knownMessageIds.contains(key)) {
            _knownMessageIds.add(key);

            // Show notification for new message
            await _notifications.showMessageNotification(
              title: 'Message de ${conv.recipientName}',
              body: conv.lastMessage!,
              data: {
                'type': 'new_message',
                'conversationId': conv.id,
                'recipientId': conv.recipientId,
                'recipientName': conv.recipientName,
                'recipientRole': conv.recipientRole,
              },
            );

            debugPrint('[MsgPolling] New message from ${conv.recipientName}');
          }
        }
      }

      if (isInitial) {
        debugPrint(
          '[MsgPolling] Initial cache: ${_knownMessageIds.length} message keys',
        );
      }
    } catch (e) {
      debugPrint('[MsgPolling] Error: $e');
    }
  }

  /// Force refresh (e.g. after reading messages).
  Future<void> refreshUnreadCount() async {
    try {
      final count = await _api.getMessagesUnreadCount();
      _unreadCount = count;
      _unreadCountController.add(_unreadCount);
    } catch (e) {
      debugPrint('[MsgPolling] refreshUnreadCount error: $e');
    }
  }

  void dispose() {
    stop();
    _unreadCountController.close();
  }
}
