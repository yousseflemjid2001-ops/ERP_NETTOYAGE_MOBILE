import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/intervention.dart';
import '../../config/theme.dart';

class MissionsPage extends StatefulWidget {
  const MissionsPage({super.key});

  @override
  State<MissionsPage> createState() => MissionsPageState();
}

class MissionsPageState extends State<MissionsPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ApiService _api = ApiService();
  late TabController _tabController;
  bool _isLoading = true;
  List<Intervention> _missions = [];
  Timer? _autoRefreshTimer;

  final List<String> _tabs = ["Aujourd'hui", 'Demain', 'Semaine', 'Toutes'];

  /// Called externally when user switches to this tab.
  void refresh() {
    _loadMissions();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadMissions();
      }
    });
    _loadMissions();
    // Auto-refresh every 30 seconds
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadMissions(),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadMissions();
    }
  }

  Future<void> _loadMissions() async {
    setState(() => _isLoading = true);
    final user = context.read<AuthProvider>().user;

    try {
      final now = DateTime.now();
      String? dateFrom;
      String? dateTo;

      switch (_tabController.index) {
        case 0: // Today
          dateFrom = _formatDate(now);
          dateTo = _formatDate(now);
          break;
        case 1: // Tomorrow
          final tomorrow = now.add(const Duration(days: 1));
          dateFrom = _formatDate(tomorrow);
          dateTo = _formatDate(tomorrow);
          break;
        case 2: // Week
          dateFrom = _formatDate(now);
          final endOfWeek = now.add(Duration(days: 7 - now.weekday));
          dateTo = _formatDate(endOfWeek);
          break;
        case 3: // All
          break;
      }

      _missions = await _api.getMyMissions(
        agentId: user?.id,
        dateFrom: dateFrom,
        dateTo: dateTo,
        sortBy: 'scheduledDate',
        sortOrder: 'ASC',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Missions'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadMissions,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _missions.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_available,
                      size: 64,
                      color: AppTheme.textSecondary.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Aucune mission',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _missions.length,
                itemBuilder: (context, index) =>
                    _buildMissionCard(_missions[index]),
              ),
      ),
    );
  }

  Widget _buildMissionCard(Intervention mission) {
    final statusColor = _getStatusColor(mission.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                  Text(
                    _formatDisplayDate(mission.scheduledDate),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (mission.clientName != null)
                Text(
                  mission.clientName!,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              if (mission.siteName != null) ...[
                const SizedBox(height: 4),
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
              ],
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
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right,
                    color: AppTheme.textSecondary,
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

  String _formatTimeShort(String? time) {
    if (time == null) return '--:--';
    if (time.length >= 5) return time.substring(0, 5);
    return time;
  }

  String _formatDisplayDate(String date) {
    try {
      final dt = DateTime.parse(date);
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
      return '${dt.day} ${months[dt.month]}';
    } catch (_) {
      return date;
    }
  }
}
