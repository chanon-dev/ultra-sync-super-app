import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:ultra_sync/core/error/failures.dart';
import 'package:ultra_sync/core/network/api_client.dart';
import 'package:ultra_sync/features/chat/data/models/chat_message_model.dart';

abstract class ChatRemoteDataSource {
  Future<List<ChatMessageModel>> getHistory(
    String roomId, {
    String? before,
    int limit = 20,
  });

  WebSocketChannel connectWebSocket(String roomId, String token);
}

@LazySingleton(as: ChatRemoteDataSource)
class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final ApiClient _apiClient;

  ChatRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<ChatMessageModel>> getHistory(
    String roomId, {
    String? before,
    int limit = 20,
  }) async {
    try {
      final params = <String, dynamic>{'limit': limit};
      if (before != null) params['before'] = before;

      final response = await _apiClient.dio.get(
        '/api/v1/chat/rooms/$roomId/messages',
        queryParameters: params,
      );

      final body = response.data as Map<String, dynamic>;
      final items = body['data'] as List<dynamic>? ?? [];
      return items
          .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  WebSocketChannel connectWebSocket(String roomId, String token) {
    final baseUrl = _apiClient.dio.options.baseUrl;
    final wsBaseUrl = baseUrl.replaceFirst('http', 'ws');
    final wsUrl = '$wsBaseUrl/api/v1/chat/ws/$roomId';
    
    return IOWebSocketChannel.connect(
      Uri.parse(wsUrl),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
  }

  Failure _mapError(DioException e) {
    final statusCode = e.response?.statusCode;
    final body = e.response?.data as Map<String, dynamic>?;
    final error = body?['error'] as Map<String, dynamic>?;
    final message = error?['message'] as String? ?? 'Failed to load chat';
    final code = error?['code'] as String? ?? 'CHT-001';

    return switch (statusCode) {
      400 => ValidationFailure(message: message, code: code),
      401 => const UnauthorizedFailure(),
      null => const NetworkFailure(),
      _ => ServerFailure(message: message, code: code),
    };
  }
}
