import 'dart:convert';

abstract final class JwtDecoder {
  static Map<String, dynamic> decode(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        throw const FormatException('Invalid JWT structure');
      }
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decodedBytes = base64Url.decode(normalized);
      final decodedString = utf8.decode(decodedBytes);
      return jsonDecode(decodedString) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  static String? getUserId(String token) {
    final claims = decode(token);
    return claims['user_id'] as String?;
  }

  static String? getUserRole(String token) {
    final claims = decode(token);
    return claims['role'] as String?;
  }
}
