import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/notification_polling_service.dart';
import '../../services/mission_polling_service.dart';
import '../../services/notification_service.dart';
import '../../models/intervention.dart';
import '../../models/attendance.dart';
import '../../config/theme.dart';
import '../notifications/notifications_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  ShiftStatus? _shiftStatus;
  List<Intervention> _todayMissions = [];
  int _pendingMissions = 0;
  int _completedMissions = 0;
  int _unreadNotifications = 0;
  Timer? _autoRefreshTimer;
  StreamSubscription? _unreadCountSub;
  StreamSubscription? _missionChangeSub;
  StreamSubscription? _inAppNotifSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    // Auto-refresh every 15 seconds to pick up clock-in/out changes
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshShiftStatus(),
    );

    // Listen for unread notification count changes from polling service
    _unreadCountSub = NotificationPollingService().onUnreadCountChanged.listen((
      count,
    ) {
      if (mounted && count != _unreadNotifications) {
        setState(() => _unreadNotifications = count);
      }
    });

    // Listen for mission changes from mission polling service
    _missionChangeSub = MissionPollingService().onMissionsChanged.listen((_) {
      if (mounted) _refreshMissions();
    });

    // Listen for in-app notifications (show snackbar on web)
    _inAppNotifSub = NotificationService().onInAppNotification.listen((notif) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (notif.body.isNotEmpty)
                  Text(
                    notif.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Voir',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                );
              },
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _unreadCountSub?.cancel();
    _missionChangeSub?.cancel();
    _inAppNotifSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  /// Called from MainNavigation when user switches to the dashboard tab.
  void refresh() {
    _loadData();
  }

  /// Lightweight refresh: only shift status (called by timer).
  Future<void> _refreshShiftStatus() async {
    try {
      final newStatus = await _api.getShiftStatus();
      if (mounted && (newStatus.isOnShift != _shiftStatus?.isOnShift)) {
        setState(() => _shiftStatus = newStatus);
      }
    } catch (_) {}
    // Also refresh unread notifications count
    try {
      final countData = await _api.getUnreadCount();
      final count = countData['count'] as int? ?? 0;
      if (mounted && count != _unreadNotifications) {
        setState(() => _unreadNotifications = count);
      }
    } catch (_) {}
  }

  /// Refresh missions data silently (called when MissionPollingService detects changes).
  Future<void> _refreshMissions() async {
    final user = context.read<AuthProvider>().user;
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final todayMissions = await _api.getMyMissions(
        agentId: user?.id,
        dateFrom: today,
        dateTo: today,
        sortBy: 'scheduledStartTime',
        sortOrder: 'ASC',
      );
      final allMissions = await _api.getMyMissions(agentId: user?.id);
      if (mounted) {
        setState(() {
          _todayMissions = todayMissions;
          _pendingMissions = allMissions
              .where(
                (m) =>
                    m.status == InterventionStatus.scheduled ||
                    m.status == InterventionStatus.inProgress,
              )
              .length;
          _completedMissions = allMissions
              .where((m) => m.status == InterventionStatus.completed)
              .length;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = context.read<AuthProvider>().user;

    try {
      // Load shift status
      try {
        _shiftStatus = await _api.getShiftStatus();
      } catch (_) {}

      // Load unread notifications count
      try {
        final countData = await _api.getUnreadCount();
        _unreadNotifications = countData['count'] as int? ?? 0;
      } catch (_) {}

      // Load today's missions
      final today = DateTime.now().toIso8601String().split('T')[0];
      try {
        _todayMissions = await _api.getMyMissions(
          agentId: user?.id,
          dateFrom: today,
          dateTo: today,
          sortBy: 'scheduledStartTime',
          sortOrder: 'ASC',
        );
      } catch (_) {}

      // Count missions
      try {
        final allMissions = await _api.getMyMissions(agentId: user?.id);
        _pendingMissions = allMissions
            .where(
              (m) =>
                  m.status == InterventionStatus.scheduled ||
                  m.status == InterventionStatus.inProgress,
            )
            .length;
        _completedMissions = allMissions
            .where((m) => m.status == InterventionStatus.completed)
            .length;
      } catch (_) {}
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        20,
                        MediaQuery.of(context).padding.top + 16,
                        20,
                        24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.white.withOpacity(
                                      0.2,
                                    ),
                                    child: Text(
                                      user?.initials ?? 'A',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Bonjour,',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        user?.displayName ?? 'Agent',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Stack(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const NotificationsPage(),
                                        ),
                                      ).then((_) {
                                        // Refresh count after returning
                                        _refreshShiftStatus();
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.notifications_outlined,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (_unreadNotifications > 0)
                                    Positioned(
                                      right: 6,
                                      top: 6,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Text(
                                          _unreadNotifications > 99
                                              ? '99+'
                                              : '$_unreadNotifications',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Shift Status Card
                          _buildShiftStatusCard(),
                        ],
                      ),
                    ),
                  ),

                  // Stats
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.calendar_today,
                              label: "Aujourd'hui",
                              value: '${_todayMissions.length}',
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.pending_actions,
                              label: 'En attente',
                              value: '$_pendingMissions',
                              color: AppTheme.warningColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.check_circle_outline,
                              label: 'Terminées',
                              value: '$_completedMissions',
                              color: AppTheme.secondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Today's Missions Title
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        "Missions d'aujourd'hui",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),

                  // Missions List
                  _todayMissions.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.event_available,
                                  size: 64,
                                  color: AppTheme.textSecondary.withOpacity(
                                    0.3,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "Aucune mission aujourd'hui",
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) =>
                                _buildMissionCard(_todayMissions[index]),
                            childCount: _todayMissions.length,
                          ),
                        ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
      ),
    );
  }

  Widget _buildShiftStatusCard() {
    final isOnShift = _shiftStatus?.isOnShift ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnShift ? AppTheme.secondaryColor : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isOnShift ? 'En service' : 'Hors service',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (_shiftStatus?.currentShift != null)
            Text(
              'Depuis ${_formatTime(_shiftStatus!.currentShift!.clockIn)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionCard(Intervention mission) {
    final statusColor = _getStatusColor(mission.status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pushNamed(
              context,
              '/mission-detail',
              arguments: mission.id,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        mission.status.label,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  ],
                ),
                const SizedBox(height: 12),
                if (mission.siteName != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.business,
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mission.siteName!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatTimeShort(mission.scheduledStartTime)} - ${_formatTimeShort(mission.scheduledEndTime)}',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                if (mission.siteAddress != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mission.siteAddress!,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(InterventionStatus status) {
    switch (status) {
      case InterventionStatus.scheduled:
        return Colors.blue;
      case InterventionStatus.inProgress:
        return Colors.amber.shade700;
      case InterventionStatus.completed:
        return AppTheme.secondaryColor;
      case InterventionStatus.cancelled:
        return AppTheme.errorColor;
      case InterventionStatus.rescheduled:
        return Colors.purple;
    }
  }

  String _formatTime(String dateTime) {
    try {
      final dt = DateTime.parse(dateTime);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateTime;
    }
  }

  String _formatTimeShort(String? time) {
    if (time == null) return '--:--';
    if (time.length >= 5) return time.substring(0, 5);
    return time;
  }
}
