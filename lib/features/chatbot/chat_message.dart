enum ChatRole { user, model }

enum ChatStatus { sent, error }

class ChatMessage {
  final int? id;
  final ChatRole role;
  final String content;
  final ChatStatus status;
  final DateTime createdAt;

  const ChatMessage({
    this.id,
    required this.role,
    required this.content,
    this.status = ChatStatus.sent,
    required this.createdAt,
  });

  bool get isUser => role == ChatRole.user;
  bool get isError => status == ChatStatus.error;

  ChatMessage copyWith({int? id, ChatStatus? status}) {
    return ChatMessage(
      id: id ?? this.id,
      role: role,
      content: content,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  /// Format yang dikirim ke Edge Function `chat`.
  Map<String, String> toApi() => {'role': role.name, 'content': content};

  /// Dari baris tabel `chat_messages`.
  factory ChatMessage.fromMap(Map<String, Object?> map) {
    final createdRaw = map['created_at'] as String?;
    return ChatMessage(
      id: map['id'] as int?,
      role: map['role'] == 'model' ? ChatRole.model : ChatRole.user,
      content: (map['content'] as String?) ?? '',
      status: map['status'] == 'error' ? ChatStatus.error : ChatStatus.sent,
      createdAt:
          (createdRaw == null
              ? null
              : DateTime.tryParse(createdRaw)?.toLocal()) ??
          DateTime.now(),
    );
  }
}
