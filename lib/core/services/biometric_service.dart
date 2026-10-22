import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;

      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      if (!await isAvailable()) {
        return false;
      }

      return await _auth.authenticate(
        localizedReason: 'Verifikasi identitas untuk masuk ke Gerak-in',
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }
}
