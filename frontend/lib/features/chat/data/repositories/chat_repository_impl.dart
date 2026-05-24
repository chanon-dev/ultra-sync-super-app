import 'dart:async';
import 'dart:convert';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/core/ports/token_storage.dart';
import 'package:ultra_sync/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:ultra_sync/features/chat/data/models/chat_message_model.dart';
import 'package:ultra_sync/features/chat/domain/entities/chat_message.dart';
import 'package:ultra_sync/features/chat/domain/repositories/chat_repository.dart';

@LazySingleton(as: ChatRepository)
class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource _remoteDataSource;
  final TokenStorage _tokenStorage;

  WebSocketChannel? _wsChannel;
  StreamController<ChatMessage>? _streamController;
  StreamSubscription? _wsSubscription;

  ChatRepositoryImpl(this._remoteDataSource, this._tokenStorage);

  @override
  Future<Either<Failure, List<ChatMessage>>> getHistory(
    String roomId, {
    String? before,
    int limit = 20,
  }) async {
    try {
      final models = await _remoteDataSource.getHistory(roomId, before: before, limit: limit);
      final domainMsgs = models.map((e) => e.toDomain()).toList();
      return Right(domainMsgs);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Stream<ChatMessage> getMessageStream(String roomId) {
    _closeResources();

    _streamController = StreamController<ChatMessage>.broadcast();
    _initWebSocket(roomId);

    return _streamController!.stream;
  }

  Future<void> _initWebSocket(String roomId) async {
    try {
      final token = await _tokenStorage.getAccessToken();
      if (token == null) {
        _streamController?.addError(const UnauthorizedFailure());
        return;
      }

      _wsChannel = _remoteDataSource.connectWebSocket(roomId, token);

      _wsSubscription = _wsChannel!.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data as String) as Map<String, dynamic>;
            final model = ChatMessageModel.fromJson(decoded);
            _streamController?.add(model.toDomain());
          } catch (e) {
            // Ignore malformed packet
          }
        },
        onError: (err) {
          _streamController?.addError(const NetworkFailure());
        },
        onDone: () {
          _streamController?.close();
        },
      );
    } catch (e) {
      _streamController?.addError(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ChatMessage>> sendMessage(String roomId, String content) async {
    if (_wsChannel == null) {
      return Left(const ServerFailure(message: 'Connection closed'));
    }

    try {
      final payload = jsonEncode({'content': content});
      _wsChannel!.sink.add(payload);
      
      // Return a dummy success entity; the actual message will flow back via the WebSocket subscription channel
      return Right(ChatMessage(
        id: '',
        roomId: roomId,
        senderId: '',
        senderRole: 'user',
        content: content,
        createdAt: DateTime.now(),
      ));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  void closeMessageStream() {
    _closeResources();
  }

  void _closeResources() {
    try {
      _wsSubscription?.cancel();
      _wsChannel?.sink.close();
      _streamController?.close();
    } catch (_) {}
    _wsSubscription = null;
    _wsChannel = null;
    _streamController = null;
  }
}
