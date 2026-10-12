import 'package:schooldrop/app.dart';
import 'package:schooldrop/core/session.dart';
import 'package:schooldrop/core/token_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _NoTokens extends TokenStore {
  @override
  Future<String?> get accessToken async => null;
}

void main() {
  // Use the bundled fallback font in tests instead of fetching Inter
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('signed-out users land on the welcome screen', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [tokenStoreProvider.overrideWithValue(_NoTokens())],
      child: const SchoolDropApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to SchoolDrop'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    // No "SchoolDrop is for" list any more — just the two actions
    expect(find.text('SchoolDrop is for'), findsNothing);
    expect(find.text('Parents'), findsNothing);
  });
}
