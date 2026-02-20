class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String? readAt;
  final String createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      conversationId: json['conversationId'] ?? json['conversation_id'] ?? '',
      senderId: json['senderId'] ?? json['sender_id'] ?? '',
      content: json['content'] ?? '',
      readAt: json['readAt'] ?? json['read_at'],
      createdAt: json['createdAt'] ?? json['created_at'] ?? '',
    );
  }
}

class ConversationPreview {
  final String id;
  final String recipientId;
  final String recipientName;
  final String? recipientAvatar;
  final String recipientRole;
  final String? lastMessage;
  final String? lastMessageAt;
  final int unreadCount;

  ConversationPreview({
    required this.id,
    required this.recipientId,
    required this.recipientName,
    this.recipientAvatar,
    required this.recipientRole,
    this.lastMessage,
    this.lastMessageAt,
    required this.unreadCount,
  });

  /// Parse the real backend format:
  /// { id, otherUser: { id, firstName, lastName, role, avatarUrl },
  ///   lastMessage: { content, ... }, unreadCount, lastMessageAt }
  factory ConversationPreview.fromJson(Map<String, dynamic> json) {
    final otherUser = json['otherUser'] as Map<String, dynamic>? ?? {};
    final lastMsg = json['lastMessage'] as Map<String, dynamic>?;

    final firstName = otherUser['firstName'] ?? '';
    final lastName = otherUser['lastName'] ?? '';
    final name = '$firstName $lastName'.trim();

    return ConversationPreview(
      id: json['id'] ?? '',
      recipientId: otherUser['id'] ?? '',
      recipientName: name.isNotEmpty ? name : 'Utilisateur',
      recipientAvatar: otherUser['avatarUrl'],
      recipientRole: otherUser['role'] ?? '',
      lastMessage: lastMsg?['content'],
      lastMessageAt: json['lastMessageAt'] ?? lastMsg?['createdAt'],
      unreadCount: json['unreadCount'] ?? 0,
    );
  }
}

class ConversationContact {
  final String id;
  final String name;
  final String? avatar;
  final String role;

  ConversationContact({
    required this.id,
    required this.name,
    this.avatar,
    required this.role,
  });

  /// Parse: { id, firstName, lastName, role, email, avatarUrl }
  factory ConversationContact.fromJson(Map<String, dynamic> json) {
    final firstName = json['firstName'] ?? '';
    final lastName = json['lastName'] ?? '';
    final name = '$firstName $lastName'.trim();

    return ConversationContact(
      id: json['id'] ?? '',
      name: name.isNotEmpty ? name : (json['email'] ?? 'Utilisateur'),
      avatar: json['avatarUrl'],
      role: json['role'] ?? '',
    );
  }
}
