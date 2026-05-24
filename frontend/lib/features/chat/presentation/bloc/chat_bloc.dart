import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:ultra_sync/features/chat/domain/entities/chat_message.dart';
import 'package:ultra_sync/features/chat/domain/repositories/chat_repository.dart';
import 'package:ultra_sync/features/chat/presentation/bloc/chat_event.dart';
import 'package:ultra_sync/features/chat/presentation/bloc/chat_state.dart';

@injectable
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository _repository;
  StreamSubscription<ChatMessage>? _streamSubscription;

  ChatBloc({required ChatRepository repository})
      : _repository = repository,
        super(const ChatInitial()) {
    on<ChatHistoryRequested>(_onHistoryRequested);
    on<ChatStreamSubscribed>(_onStreamSubscribed);
    on<ChatMessageReceived>(_onMessageReceived);
    on<ChatMessageSent>(_onMessageSent);
  }

  Future<void> _onHistoryRequested(
    ChatHistoryRequested event,
    Emitter<ChatState> emit,
  ) async {
    final beforeId = event.before;
    final isInitial = beforeId == null;

    if (isInitial) {
      emit(const ChatLoading());
    }

    final result = await _repository.getHistory(
      event.roomId,
      before: beforeId,
      limit: 25,
    );

    result.fold(
      (failure) {
        if (state is ChatHistoryLoaded) {
          emit((state as ChatHistoryLoaded).copyWith(
            errorMessage: failure.message,
          ));
        } else {
          emit(ChatError(failure.message));
        }
      },
      (messages) {
        if (state is ChatHistoryLoaded && !isInitial) {
          final current = state as ChatHistoryLoaded;
          // Prepend historical messages (they are older)
          final updated = [...messages, ...current.messages];
          emit(ChatHistoryLoaded(
            messages: updated,
            hasReachedMax: messages.length < 25,
          ));
        } else {
          emit(ChatHistoryLoaded(
            messages: messages,
            hasReachedMax: messages.length < 25,
          ));
        }
      },
    );
  }

  void _onStreamSubscribed(
    ChatStreamSubscribed event,
    Emitter<ChatState> emit,
  ) {
    _streamSubscription?.cancel();
    
    // Subscribe to live messages stream from repository
    _streamSubscription = _repository.getMessageStream(event.roomId).listen(
      (message) {
        add(ChatMessageReceived(message));
      },
      onError: (error) {
        // Handle stream error locally
      },
    );
  }

  void _onMessageReceived(
    ChatMessageReceived event,
    Emitter<ChatState> emit,
  ) {
    if (state is ChatHistoryLoaded) {
      final current = state as ChatHistoryLoaded;
      
      // Prevent duplicates in case the user ID matches, but we don't have it yet
      final exists = current.messages.any((m) => m.id == event.message.id);
      if (exists) return;

      final updated = [...current.messages, event.message];
      emit(current.copyWith(messages: updated));
    } else {
      emit(ChatHistoryLoaded(messages: [event.message]));
    }
  }

  Future<void> _onMessageSent(
    ChatMessageSent event,
    Emitter<ChatState> emit,
  ) async {
    final result = await _repository.sendMessage(event.roomId, event.content);
    result.fold(
      (failure) {
        if (state is ChatHistoryLoaded) {
          emit((state as ChatHistoryLoaded).copyWith(
            errorMessage: 'Failed to send: ${failure.message}',
          ));
        }
      },
      (tempMessage) {
        // We do not append the message here; the repository WebSocket stream 
        // will receive the message broadcast and trigger ChatMessageReceived.
      },
    );
  }

  @override
  Future<void> close() {
    _streamSubscription?.cancel();
    _repository.closeMessageStream();
    return super.close();
  }
}
