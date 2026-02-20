import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../config/theme.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _api.getNotifications();
      if (mounted) setState(() => _notifications = data);

      // Mark all notifications as read when the page is opened
      try {
        await _api.markAllNotificationsAsRead();
      } catch (_) {}
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Activer les notifications',
            onPressed: () async {
              final granted = await NotificationService().requestPermission();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      granted == true
                          ? 'Notifications activées !'
                          : 'Permission refusée. Activez-les dans les paramètres.',
                    ),
                    backgroundColor: granted == true
                        ? AppTheme.secondaryColor
                        : AppTheme.errorColor,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildError()
            : _notifications.isEmpty
            ? _buildEmpty()
            : _buildList(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text(
            'Impossible de charger les notifications',
            style: const TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadNotifications,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Icon(
                Icons.notifications_none_outlined,
                size: 80,
                color: AppTheme.textSecondary.withOpacity(0.3),
              ),
              const SizedBox(height: 20),
              const Text(
                'Aucune notification',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vous serez notifié ici lorsqu\'une\nmission vous sera assignée.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _notifications.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 72, endIndent: 16),
      itemBuilder: (context, index) {
        final n = _notifications[index];
        return _NotificationTile(notification: n);
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final isRead =
        notification['isRead'] == true || notification['read'] == true;
    final title = notification['title'] as String? ?? 'Notification';
    final body =
        notification['body'] as String? ??
        notification['message'] as String? ??
        '';
    final type = notification['type'] as String? ?? '';
    final createdAt = notification['createdAt'] as String?;

    return Container(
      color: isRead ? null : AppTheme.primaryColor.withOpacity(0.04),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _iconColor(type).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_iconForType(type), color: _iconColor(type), size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (body.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                body,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatDate(createdAt),
                style: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
        trailing: isRead
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'mission':
      case 'new_mission':
      case 'mission_assigned':
        return Icons.assignment_outlined;
      case 'mission_updated':
      case 'mission_modified':
        return Icons.edit_outlined;
      case 'mission_removed':
      case 'mission_cancelled':
        return Icons.cancel_outlined;
      case 'message':
        return Icons.chat_bubble_outline;
      case 'absence':
        return Icons.event_busy_outlined;
      case 'attendance':
        return Icons.fingerprint;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _iconColor(String type) {
    switch (type.toLowerCase()) {
      case 'mission':
      case 'new_mission':
      case 'mission_assigned':
        return AppTheme.primaryColor;
      case 'mission_updated':
      case 'mission_modified':
        return AppTheme.warningColor;
      case 'mission_removed':
      case 'mission_cancelled':
        return AppTheme.errorColor;
      case 'message':
        return Colors.teal;
      default:
        return AppTheme.secondaryColor;
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'À l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
      if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
