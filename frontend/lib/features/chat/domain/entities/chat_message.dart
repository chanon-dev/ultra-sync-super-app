import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  final String id;
  final String roomId;
  final String senderId;
  final String senderRole;
  final String content;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderRole,
    required this.content,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, roomId, senderId, senderRole, content, createdAt];
}
