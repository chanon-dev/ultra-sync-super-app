import 'package:fpdart/fpdart.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/features/chat/domain/entities/chat_message.dart';

abstract class ChatRepository {
  Future<Either<Failure, List<ChatMessage>>> getHistory(
    String roomId, {
    String? before,
    int limit = 20,
  });

  Future<Either<Failure, ChatMessage>> sendMessage(
    String roomId,
    String content,
  );

  Stream<ChatMessage> getMessageStream(String roomId);

  void closeMessageStream();
}
