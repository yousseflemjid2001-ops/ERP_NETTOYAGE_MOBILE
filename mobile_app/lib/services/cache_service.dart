/// In-memory cache service.
///
/// Pages store their last-fetched data here.  On the next visit the page
/// renders the cached value *immediately* (no loading spinner) then
/// silently refreshes from the API in the background.
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, _CacheEntry> _store = {};

  /// Maximum age before a cache entry is considered stale (but still usable).
  static const Duration maxAge = Duration(minutes: 5);

  // -------------------------------------------------------------------
  // Generic get / put
  // -------------------------------------------------------------------

  /// Returns the cached value, or `null` if nothing is stored for [key].
  T? get<T>(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (entry.data is T) return entry.data as T;
    return null;
  }

  /// Stores [data] under [key].
  void put<T>(String key, T data) {
    _store[key] = _CacheEntry(data: data, storedAt: DateTime.now());
  }

  /// Returns `true` when the entry exists **and** is younger than [maxAge].
  bool isFresh(String key) {
    final entry = _store[key];
    if (entry == null) return false;
    return DateTime.now().difference(entry.storedAt) < maxAge;
  }

  /// Whether at least *some* data is stored (fresh or stale).
  bool has(String key) => _store.containsKey(key);

  /// Evict a single key.
  void remove(String key) => _store.remove(key);

  /// Wipe everything (e.g. on logout).
  void clear() => _store.clear();

  // -------------------------------------------------------------------
  // Convenience keys  (avoids magic strings scattered across pages)
  // -------------------------------------------------------------------
  static const String dashboardShiftStatus = 'dashboard.shiftStatus';
  static const String dashboardTodayMissions = 'dashboard.todayMissions';
  static const String dashboardPendingCount = 'dashboard.pendingCount';
  static const String dashboardCompletedCount = 'dashboard.completedCount';
  static const String dashboardUnreadNotifs = 'dashboard.unreadNotifs';

  static const String missionsToday = 'missions.today';
  static const String missionsTomorrow = 'missions.tomorrow';
  static const String missionsWeek = 'missions.week';
  static const String missionsAll = 'missions.all';
  static String missionsKey(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return missionsToday;
      case 1:
        return missionsTomorrow;
      case 2:
        return missionsWeek;
      default:
        return missionsAll;
    }
  }

  static const String attendanceShift = 'attendance.shift';
  static const String attendanceSummary = 'attendance.summary';
  static const String attendanceHistory = 'attendance.history';

  static const String absencesList = 'absences.list';
  static const String absencesBalance = 'absences.balance';

  static const String conversations = 'conversations.list';

  static const String profileData = 'profile.data';

  static const String notificationsList = 'notifications.list';
}

class _CacheEntry {
  final dynamic data;
  final DateTime storedAt;
  _CacheEntry({required this.data, required this.storedAt});
}
