import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// OfflineService — queue d'actions à synchroniser quand le réseau revient.
/// Usage :
///   await OfflineService().enqueue(OfflineAction(...));
///   await OfflineService().flushQueue(apiService);

class OfflineAction {
  final String id;
  final String
  type; // 'checkIn', 'checkOut', 'addPhoto', 'clockIn', 'clockOut', 'createAbsence'
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  int retryCount;

  OfflineAction({
    required this.id,
    required this.type,
    required this.payload,
    DateTime? createdAt,
    this.retryCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory OfflineAction.fromJson(Map<String, dynamic> json) {
    return OfflineAction(
      id: json['id'] as String,
      type: json['type'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: (json['retryCount'] as int?) ?? 0,
    );
  }
}

class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  static const String _queueKey = 'offline_action_queue';
  static const String _cachedMissionsKey = 'cached_missions';
  static const String _cachedAttendanceKey = 'cached_attendance';
  static const String _cachedNotificationsKey = 'cached_notifications';
  static const int _maxRetries = 5;

  // ============================================
  // ACTION QUEUE
  // ============================================

  Future<List<OfflineAction>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => OfflineAction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveQueue(List<OfflineAction> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _queueKey,
      jsonEncode(queue.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> enqueue(OfflineAction action) async {
    final queue = await getQueue();
    queue.add(action);
    await saveQueue(queue);
  }

  Future<void> removeAction(String id) async {
    final queue = await getQueue();
    queue.removeWhere((a) => a.id == id);
    await saveQueue(queue);
  }

  Future<int> getPendingCount() async {
    final queue = await getQueue();
    return queue.length;
  }

  /// Rejoue la queue. Appelé quand la connectivité est restaurée.
  Future<SyncResult> flushQueue(dynamic apiService) async {
    final queue = await getQueue();
    if (queue.isEmpty) return SyncResult(synced: 0, failed: 0);

    int synced = 0;
    int failed = 0;
    final remaining = <OfflineAction>[];

    for (final action in queue) {
      try {
        await _executeAction(action, apiService);
        synced++;
      } catch (e) {
        action.retryCount++;
        if (action.retryCount < _maxRetries) {
          remaining.add(action);
        } else {
          // Abandon après maxRetries
          failed++;
        }
      }
    }

    await saveQueue(remaining);
    return SyncResult(synced: synced, failed: failed);
  }

  Future<void> _executeAction(OfflineAction action, dynamic api) async {
    switch (action.type) {
      case 'checkIn':
        await api.checkIn(
          action.payload['missionId'] as String,
          action.payload['lat'] as double,
          action.payload['lng'] as double,
        );
        break;
      case 'checkOut':
        await api.checkOut(
          action.payload['missionId'] as String,
          action.payload['lat'] as double,
          action.payload['lng'] as double,
        );
        break;
      case 'addPhoto':
        await api.addPhoto(
          action.payload['missionId'] as String,
          action.payload['photoUrl'] as String,
        );
        break;
      case 'clockIn':
        await api.clockIn(
          notes: action.payload['notes'] as String?,
          lat: action.payload['lat'] as double?,
          lng: action.payload['lng'] as double?,
        );
        break;
      case 'clockOut':
        await api.clockOut(
          notes: action.payload['notes'] as String?,
          lat: action.payload['lat'] as double?,
          lng: action.payload['lng'] as double?,
        );
        break;
      case 'createAbsence':
        await api.createAbsence(
          agentId: action.payload['agentId'] as String,
          absenceType: action.payload['absenceType'] as String,
          startDate: action.payload['startDate'] as String,
          endDate: action.payload['endDate'] as String,
          reason: action.payload['reason'] as String?,
        );
        break;
      default:
        throw Exception('Unknown offline action type: ${action.type}');
    }
  }

  // ============================================
  // CACHE LOCAL — données lues hors-ligne
  // ============================================

  Future<void> cacheMissions(List<dynamic> missions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedMissionsKey, jsonEncode(missions));
  }

  Future<List<Map<String, dynamic>>> getCachedMissions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedMissionsKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> cacheAttendance(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedAttendanceKey, jsonEncode(data));
  }

  Future<Map<String, dynamic>?> getCachedAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedAttendanceKey);
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> cacheNotifications(List<dynamic> notifications) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedNotificationsKey, jsonEncode(notifications));
  }

  Future<List<Map<String, dynamic>>> getCachedNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedNotificationsKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
    await prefs.remove(_cachedMissionsKey);
    await prefs.remove(_cachedAttendanceKey);
    await prefs.remove(_cachedNotificationsKey);
  }
}

class SyncResult {
  final int synced;
  final int failed;
  const SyncResult({required this.synced, required this.failed});

  bool get hasFailures => failed > 0;
  bool get hasSync => synced > 0;

  @override
  String toString() => 'SyncResult(synced: $synced, failed: $failed)';
}
