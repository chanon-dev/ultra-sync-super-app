import 'package:injectable/injectable.dart';
import 'package:local_auth/local_auth.dart';

@lazySingleton
class BiometricService {
  final LocalAuthentication _auth;

  const BiometricService(this._auth);

  Future<bool> isAvailable() async {
    final canCheck = await _auth.canCheckBiometrics;
    final isSupported = await _auth.isDeviceSupported();
    return canCheck && isSupported;
  }

  Future<bool> authenticate() {
    return _auth.authenticate(
      localizedReason: 'Authenticate to access Ultra-Sync',
    );
  }
}
