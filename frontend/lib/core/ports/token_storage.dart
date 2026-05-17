abstract class TokenStorage {
  Future<void> save({required String access, required String refresh});
  Future<void> clear();
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
}
