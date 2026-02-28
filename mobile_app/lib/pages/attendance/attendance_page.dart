import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../models/attendance.dart';
import '../../config/theme.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => AttendancePageState();
}

class AttendancePageState extends State<AttendancePage>
    with WidgetsBindingObserver {
  final ApiService _api = ApiService();
  final CacheService _cache = CacheService();
  bool _isLoading = true;
  bool _actionLoading = false;
  ShiftStatus? _shiftStatus;
  DailySummary? _dailySummary;
  List<Attendance> _history = [];
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreFromCache();
    _loadData();
    // Auto-refresh every 15 seconds to keep shift status up to date
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _silentRefresh(),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _silentRefresh();
    }
  }

  /// Called externally when user switches to this tab.
  void refresh() {
    _silentRefresh();
  }

  /// Instantly populate fields from cache.
  void _restoreFromCache() {
    final cachedShift = _cache.get<ShiftStatus>(CacheService.attendanceShift);
    final cachedSummary = _cache.get<DailySummary>(
      CacheService.attendanceSummary,
    );
    final cachedHistory = _cache.get<List<Attendance>>(
      CacheService.attendanceHistory,
    );
    if (cachedShift != null || cachedHistory != null) {
      _shiftStatus = cachedShift;
      _dailySummary = cachedSummary;
      _history = cachedHistory ?? [];
      _isLoading = false;
    }
  }

  /// Silent refresh without showing loading spinner (used by timer).
  Future<void> _silentRefresh() async {
    try {
      final status = await _api.getShiftStatus();
      final summary = await _api.getDailySummary();
      final history = await _api.getAttendanceHistory();
      _cache.put(CacheService.attendanceShift, status);
      _cache.put(CacheService.attendanceSummary, summary);
      _cache.put(CacheService.attendanceHistory, history);
      if (mounted) {
        setState(() {
          _shiftStatus = status;
          _dailySummary = summary;
          _history = history;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    if (_isLoading) setState(() {});

    try {
      _shiftStatus = await _api.getShiftStatus();
      _cache.put(CacheService.attendanceShift, _shiftStatus!);
    } catch (_) {}

    try {
      _dailySummary = await _api.getDailySummary();
      _cache.put(CacheService.attendanceSummary, _dailySummary!);
    } catch (_) {}

    try {
      _history = await _api.getAttendanceHistory();
      _cache.put(CacheService.attendanceHistory, _history);
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _clockIn() async {
    setState(() => _actionLoading = true);
    try {
      await _api.clockIn();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pointage d\'entrée enregistré !'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
    if (mounted) setState(() => _actionLoading = false);
  }

  Future<void> _clockOut() async {
    setState(() => _actionLoading = true);
    try {
      await _api.clockOut();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pointage de sortie enregistré !'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
    if (mounted) setState(() => _actionLoading = false);
  }

  Future<void> _pauseShift() async {
    setState(() => _actionLoading = true);
    try {
      await _api.pauseShift(reason: 'break');
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pause enregistrée !'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
    if (mounted) setState(() => _actionLoading = false);
  }

  Future<void> _resumeShift() async {
    setState(() => _actionLoading = true);
    try {
      await _api.resumeShift();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reprise enregistrée !'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
    if (mounted) setState(() => _actionLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pointage')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Status Card
                    _buildStatusCard(),
                    const SizedBox(height: 16),

                    // Action Buttons
                    _buildActionButtons(),
                    const SizedBox(height: 24),

                    // Daily Summary
                    if (_dailySummary != null) ...[
                      const Text(
                        "Résumé du jour",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDailySummaryCard(),
                      const SizedBox(height: 24),
                    ],

                    // History
                    const Text(
                      'Historique récent',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_history.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Aucun historique',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      )
                    else
                      ..._history.take(10).map(_buildHistoryCard),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final isOnShift = _shiftStatus?.isOnShift ?? false;
    final status = _shiftStatus?.currentShift?.status;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (!isOnShift) {
      statusColor = Colors.grey;
      statusText = 'Hors service';
      statusIcon = Icons.access_time;
    } else if (status == 'paused') {
      statusColor = AppTheme.warningColor;
      statusText = 'En pause';
      statusIcon = Icons.pause_circle;
    } else {
      statusColor = AppTheme.secondaryColor;
      statusText = 'En service';
      statusIcon = Icons.play_circle;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor, statusColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(statusIcon, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(
            statusText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isOnShift && _shiftStatus?.currentShift != null) ...[
            const SizedBox(height: 8),
            Text(
              'Depuis ${_formatTime(_shiftStatus!.currentShift!.clockIn)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final isOnShift = _shiftStatus?.isOnShift ?? false;
    final status = _shiftStatus?.currentShift?.status;

    if (!isOnShift) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _actionLoading ? null : _clockIn,
          icon: _actionLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.login, size: 28),
          label: const Text(
            'Pointer l\'entrée',
            style: TextStyle(fontSize: 18),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.secondaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            if (status == 'paused')
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _actionLoading ? null : _resumeShift,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Reprendre'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _actionLoading ? null : _pauseShift,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warningColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _actionLoading ? null : _clockOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Pointer la sortie'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDailySummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem(
              Icons.timer_outlined,
              '${_dailySummary!.totalHoursWorked.toStringAsFixed(1)}h',
              'Travaillé',
              AppTheme.primaryColor,
            ),
            _buildSummaryItem(
              Icons.coffee,
              '${_dailySummary!.totalBreakMinutes.toStringAsFixed(0)} min',
              'Pause',
              AppTheme.warningColor,
            ),
            _buildSummaryItem(
              Icons.format_list_numbered,
              '${_dailySummary!.totalShifts}',
              'Sessions',
              AppTheme.secondaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(Attendance attendance) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 40,
              decoration: BoxDecoration(
                color: attendance.clockOut != null
                    ? AppTheme.secondaryColor
                    : AppTheme.warningColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDisplayDate(attendance.clockIn),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatTime(attendance.clockIn)} → ${attendance.clockOut != null ? _formatTime(attendance.clockOut!) : 'En cours'}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (attendance.hoursWorked != null)
              Text(
                '${attendance.hoursWorked!.toStringAsFixed(1)}h',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String dateTime) {
    try {
      final dt = DateTime.parse(dateTime);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateTime;
    }
  }

  String _formatDisplayDate(String dateTime) {
    try {
      final dt = DateTime.parse(dateTime);
      final months = [
        '',
        'Jan',
        'Fév',
        'Mar',
        'Avr',
        'Mai',
        'Juin',
        'Juil',
        'Aoû',
        'Sep',
        'Oct',
        'Nov',
        'Déc',
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return dateTime;
    }
  }
}
