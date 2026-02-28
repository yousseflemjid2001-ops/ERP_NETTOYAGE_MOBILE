import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/message.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import 'chat_page.dart';
import 'contacts_page.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  final ApiService _api = ApiService();
  final CacheService _cache = CacheService();
  List<ConversationPreview> _conversations = [];
  bool _loading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _restoreFromCache();
    _loadConversations();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadConversations(silent: true),
    );
  }

  void _restoreFromCache() {
    final cached = _cache.get<List<ConversationPreview>>(
      CacheService.conversations,
    );
    if (cached != null) {
      _conversations = cached;
      _loading = false;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent && _loading && mounted) {
      setState(() {});
    }
    try {
      final conversations = await _api.getConversations();
      _cache.put(CacheService.conversations, conversations);
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays == 1) {
        return 'Hier';
      } else if (diff.inDays < 7) {
        const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
        return days[date.weekday - 1];
      } else {
        return '${date.day}/${date.month}';
      }
    } catch (_) {
      return '';
    }
  }

  String _getRoleBadge(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
        return 'Super Admin';
      case 'admin':
        return 'Admin';
      case 'supervisor':
        return 'Superviseur';
      case 'agent':
        return 'Agent';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
        return Colors.purple;
      case 'admin':
        return Colors.blue;
      case 'supervisor':
        return Colors.orange;
      case 'agent':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Nouvelle conversation',
            onPressed: () async {
              final result = await Navigator.push<Map<String, String>>(
                context,
                MaterialPageRoute(builder: (_) => const ContactsPage()),
              );
              if (result != null && mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatPage(
                      recipientId: result['id']!,
                      recipientName: result['name']!,
                      recipientRole: result['role'] ?? '',
                    ),
                  ),
                ).then((_) => _loadConversations());
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: () => _loadConversations(),
              child: ListView.separated(
                itemCount: _conversations.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 76),
                itemBuilder: (context, index) {
                  final conv = _conversations[index];
                  return _buildConversationTile(conv);
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 40,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aucune conversation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Commencez une nouvelle conversation\nen appuyant sur le bouton +',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push<Map<String, String>>(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactsPage()),
                );
                if (result != null && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        recipientId: result['id']!,
                        recipientName: result['name']!,
                        recipientRole: result['role'] ?? '',
                      ),
                    ),
                  ).then((_) => _loadConversations());
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle conversation'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(ConversationPreview conv) {
    final hasUnread = conv.unreadCount > 0;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: _getRoleColor(
              conv.recipientRole,
            ).withOpacity(0.15),
            child: Text(
              _getInitials(conv.recipientName),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _getRoleColor(conv.recipientRole),
                fontSize: 16,
              ),
            ),
          ),
          if (hasUnread)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    conv.unreadCount > 9 ? '9+' : '${conv.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conv.recipientName,
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatTime(conv.lastMessageAt),
            style: TextStyle(
              fontSize: 12,
              color: hasUnread ? AppTheme.primaryColor : AppTheme.textSecondary,
              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: _getRoleColor(conv.recipientRole).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _getRoleBadge(conv.recipientRole),
              style: TextStyle(
                fontSize: 10,
                color: _getRoleColor(conv.recipientRole),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              conv.lastMessage ?? 'Aucun message',
              style: TextStyle(
                fontSize: 13,
                color: hasUnread
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
                fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              conversationId: conv.id,
              recipientId: conv.recipientId,
              recipientName: conv.recipientName,
              recipientRole: conv.recipientRole,
            ),
          ),
        ).then((_) => _loadConversations());
      },
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
