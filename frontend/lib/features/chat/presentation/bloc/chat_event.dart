import 'package:equatable/equatable.dart';
import 'package:ultra_sync/features/chat/domain/entities/chat_message.dart';

sealed class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class ChatHistoryRequested extends ChatEvent {
  final String roomId;
  final String? before;

  const ChatHistoryRequested(this.roomId, {this.before});

  @override
  List<Object?> get props => [roomId, before];
}

class ChatStreamSubscribed extends ChatEvent {
  final String roomId;

  const ChatStreamSubscribed(this.roomId);

  @override
  List<Object?> get props => [roomId];
}

class ChatMessageSent extends ChatEvent {
  final String roomId;
  final String content;

  const ChatMessageSent(this.roomId, this.content);

  @override
  List<Object?> get props => [roomId, content];
}

class ChatMessageReceived extends ChatEvent {
  final ChatMessage message;

  const ChatMessageReceived(this.message);

  @override
  List<Object?> get props => [message];
}
