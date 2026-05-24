import 'package:ultra_sync/features/chat/domain/entities/chat_message.dart';

class ChatMessageModel {
  final String id;
  final String roomId;
  final String senderId;
  final String senderRole;
  final String content;
  final DateTime createdAt;

  const ChatMessageModel({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderRole,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) => ChatMessageModel(
        id: json['id'] as String? ?? '',
        roomId: json['room_id'] as String? ?? '',
        senderId: json['sender_id'] as String? ?? '',
        senderRole: json['sender_role'] as String? ?? 'user',
        content: json['content'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      );

  ChatMessage toDomain() => ChatMessage(
        id: id,
        roomId: roomId,
        senderId: senderId,
        senderRole: senderRole,
        content: content,
        createdAt: createdAt,
      );
}
