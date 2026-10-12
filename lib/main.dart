import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';

void main() {
  // The font is bundled in assets/fonts: never download it at runtime (offline, slow or metered data)
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(
    // No automatic retries: a failed request (e.g. 403) should show its error, not hammer the API
    ProviderScope(retry: (_, __) => null, child: const SchoolDropApp()),
  );
}
