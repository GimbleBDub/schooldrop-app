import 'package:flutter/foundation.dart';

/// What to call this device in Settings → Signed-in devices.
String deviceName() {
  if (kIsWeb) {
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS => 'Web browser on Mac',
      TargetPlatform.windows => 'Web browser on Windows',
      TargetPlatform.linux => 'Web browser on Linux',
      TargetPlatform.iOS => 'Web browser on iPhone',
      TargetPlatform.android => 'Web browser on Android',
      _ => 'Web browser',
    };
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'iPhone',
    TargetPlatform.android => 'Android phone',
    TargetPlatform.macOS => 'Mac',
    TargetPlatform.windows => 'Windows PC',
    _ => 'Device',
  };
}
