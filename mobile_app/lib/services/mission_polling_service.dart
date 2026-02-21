import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'notification_service.dart';
import '../models/intervention.dart';

/// Polls the backend every [pollInterval] for mission changes and triggers
/// local notifications when a new mission is assigned or an existing one is
/// modified (status change, rescheduled, etc.).
class MissionPollingService {
  static final MissionPollingService _instance =
      MissionPollingService._internal();
  factory MissionPollingService() => _instance;
  MissionPollingService._internal();

  final ApiService _api = ApiService();
  final NotificationService _notifications = NotificationService();

  Timer? _timer;
  bool _isRunning = false;

  /// Cached mission IDs → status, used to detect changes.
  final Map<String, _MissionSnapshot> _knownMissions = {};

  /// How often we poll (every 15 seconds for more responsive updates).
  static const Duration pollInterval = Duration(seconds: 15);

  /// Stream that broadcasts when missions have changed (for UI refresh).
  final StreamController<void> _missionChangedController =
      StreamController<void>.broadcast();
  Stream<void> get onMissionsChanged => _missionChangedController.stream;

  // ============================================
  // START / STOP
  // ============================================

  /// Start polling. Safe to call multiple times — only one timer will run.
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // Initial fetch to populate cache (don't notify on first load).
    _fetchAndCompare(isInitialLoad: true);

    _timer = Timer.periodic(pollInterval, (_) {
      _fetchAndCompare(isInitialLoad: false);
    });

    debugPrint('[MissionPolling] Started (every ${pollInterval.inSeconds}s)');
  }

  /// Stop polling.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _knownMissions.clear();
    debugPrint('[MissionPolling] Stopped');
  }

  // ============================================
  // CORE LOGIC
  // ============================================

  Future<void> _fetchAndCompare({required bool isInitialLoad}) async {
    try {
      final missions = await _api.getMyMissions();

      if (isInitialLoad) {
        // Populate cache without notifying.
        for (final m in missions) {
          _knownMissions[m.id] = _MissionSnapshot.from(m);
        }
        debugPrint(
          '[MissionPolling] Initial cache: ${_knownMissions.length} missions',
        );
        return;
      }

      // Compare with cache.
      final currentIds = <String>{};
      bool hasChanges = false;

      for (final m in missions) {
        currentIds.add(m.id);
        final old = _knownMissions[m.id];

        if (old == null) {
          // ====== NEW MISSION ======
          _knownMissions[m.id] = _MissionSnapshot.from(m);
          hasChanges = true;
          try {
            await _notifications.showMissionNotification(
              title: '🆕 Nouvelle mission',
              body: _buildMissionBody(m),
              data: {'type': 'new_mission', 'missionId': m.id},
            );
          } catch (e) {
            debugPrint('[MissionPolling] Notification error (new): $e');
          }
          debugPrint('[MissionPolling] New mission: ${m.id}');
        } else if (old.hasChanged(m)) {
          // ====== MODIFIED MISSION ======
          final changeDesc = old.describeChanges(m);
          _knownMissions[m.id] = _MissionSnapshot.from(m);
          hasChanges = true;
          try {
            await _notifications.showMissionNotification(
              title: '📝 Mission modifiée',
              body: changeDesc,
              data: {'type': 'mission_updated', 'missionId': m.id},
            );
          } catch (e) {
            debugPrint('[MissionPolling] Notification error (update): $e');
          }
          debugPrint('[MissionPolling] Updated mission: ${m.id}');
        }
      }

      // Detect removed missions (cancelled / unassigned).
      final removedIds = _knownMissions.keys.toSet().difference(currentIds);
      for (final id in removedIds) {
        final snapshot = _knownMissions.remove(id);
        hasChanges = true;
        try {
          await _notifications.showMissionNotification(
            title: '❌ Mission retirée',
            body: snapshot != null
                ? '${snapshot.siteName ?? "Mission"} le ${snapshot.scheduledDate} a été retirée de votre planning.'
                : 'Une mission a été retirée de votre planning.',
            data: {'type': 'mission_removed', 'missionId': id},
          );
        } catch (e) {
          debugPrint('[MissionPolling] Notification error (remove): $e');
        }
        debugPrint('[MissionPolling] Removed mission: $id');
      }

      // Notify listeners (UI refresh)
      if (hasChanges) {
        _missionChangedController.add(null);
      }
    } catch (e) {
      debugPrint('[MissionPolling] Error: $e');
    }
  }

  String _buildMissionBody(Intervention m) {
    final parts = <String>[];
    if (m.siteName != null) parts.add(m.siteName!);
    parts.add('le ${m.scheduledDate}');
    if (m.scheduledStartTime != null) {
      final t = m.scheduledStartTime!;
      parts.add('à ${t.length >= 5 ? t.substring(0, 5) : t}');
    }
    return parts.join(' ');
  }

  void dispose() {
    stop();
    _missionChangedController.close();
  }
}

/// Lightweight snapshot of a mission used for change detection.
class _MissionSnapshot {
  final String status;
  final String scheduledDate;
  final String? scheduledStartTime;
  final String? scheduledEndTime;
  final String? siteName;
  final String? notes;

  _MissionSnapshot({
    required this.status,
    required this.scheduledDate,
    this.scheduledStartTime,
    this.scheduledEndTime,
    this.siteName,
    this.notes,
  });

  factory _MissionSnapshot.from(Intervention m) {
    return _MissionSnapshot(
      status: m.status.value,
      scheduledDate: m.scheduledDate,
      scheduledStartTime: m.scheduledStartTime,
      scheduledEndTime: m.scheduledEndTime,
      siteName: m.siteName,
      notes: m.notes,
    );
  }

  bool hasChanged(Intervention m) {
    return status != m.status.value ||
        scheduledDate != m.scheduledDate ||
        scheduledStartTime != m.scheduledStartTime ||
        scheduledEndTime != m.scheduledEndTime ||
        siteName != m.siteName ||
        notes != m.notes;
  }

  String describeChanges(Intervention m) {
    final changes = <String>[];
    final name = m.siteName ?? siteName ?? 'Mission';

    if (status != m.status.value) {
      changes.add('statut → ${m.status.label}');
    }
    if (scheduledDate != m.scheduledDate) {
      changes.add('date → ${m.scheduledDate}');
    }
    if (scheduledStartTime != m.scheduledStartTime ||
        scheduledEndTime != m.scheduledEndTime) {
      changes.add(
        'horaire → ${m.scheduledStartTime ?? "?"} - ${m.scheduledEndTime ?? "?"}',
      );
    }
    if (siteName != m.siteName) {
      changes.add('site → ${m.siteName ?? "?"}');
    }
    if (notes != m.notes && m.notes != null) {
      changes.add('notes mises à jour');
    }

    if (changes.isEmpty) return '$name a été modifiée.';
    return '$name : ${changes.join(", ")}';
  }
}
