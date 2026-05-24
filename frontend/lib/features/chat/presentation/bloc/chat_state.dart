import 'package:equatable/equatable.dart';
import 'package:ultra_sync/features/chat/domain/entities/chat_message.dart';

sealed class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {
  const ChatInitial();
}

class ChatLoading extends ChatState {
  const ChatLoading();
}

class ChatHistoryLoaded extends ChatState {
  final List<ChatMessage> messages;
  final bool hasReachedMax;
  final String? errorMessage;

  const ChatHistoryLoaded({
    required this.messages,
    this.hasReachedMax = false,
    this.errorMessage,
  });

  ChatHistoryLoaded copyWith({
    List<ChatMessage>? messages,
    bool? hasReachedMax,
    String? errorMessage,
  }) {
    return ChatHistoryLoaded(
      messages: messages ?? this.messages,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [messages, hasReachedMax, errorMessage];
}

class ChatError extends ChatState {
  final String message;

  const ChatError(this.message);

  @override
  List<Object?> get props => [message];
}
