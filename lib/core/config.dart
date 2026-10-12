import 'package:flutter/foundation.dart';

/// Build-time configuration. Override with --dart-define, e.g.
///   flutter run --dart-define=API_BASE_URL=https://api.schooldrop.co.bw/api/v1
class AppConfig {
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// The backend. Without API_BASE_URL it's the local dev server: `localhost` on web, iOS simulator and
  /// desktop; `10.0.2.2` on the Android emulator (its own `localhost` is the emulator itself).
  static String get apiBaseUrl {
    if (_apiBaseUrl.isNotEmpty) return _apiBaseUrl;
    final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
    return 'http://$host:8097/api/v1';
  }

  /// The sandbox payment gateway lets testers complete payments from the app.
  static const isSandboxPayments = bool.fromEnvironment('SANDBOX_PAYMENTS', defaultValue: true);
}
