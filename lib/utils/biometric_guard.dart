import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class BiometricGuard {
  static final _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate(BuildContext context) async {
    try {
      final available = await isAvailable();
      if (!available) return true; // No biometrics → allow access

      final result = await _auth.authenticate(
        localizedReason: 'Authenticate to access Settings',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (!result && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication failed. Settings locked.'),
            backgroundColor: Color(0xFFFF1744),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return result;
    } catch (_) {
      return true; // On error, fail open rather than locking out
    }
  }
}
