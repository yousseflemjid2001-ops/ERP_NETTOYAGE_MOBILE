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

  factory ConversationPreview.fromJson(Map<String, dynamic> json) {
    return ConversationPreview(
      id: json['id'] ?? '',
      recipientId: json['recipientId'] ?? '',
      recipientName: json['recipientName'] ?? 'Utilisateur',
      recipientAvatar: json['recipientAvatar'],
      recipientRole: json['recipientRole'] ?? '',
      lastMessage: json['lastMessage'],
      lastMessageAt: json['lastMessageAt'],
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

  factory ConversationContact.fromJson(Map<String, dynamic> json) {
    return ConversationContact(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'],
      role: json['role'] ?? '',
    );
  }
}
