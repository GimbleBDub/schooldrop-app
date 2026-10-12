import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/set_password_screen.dart';
import '../features/admin/admin_home.dart';
import '../features/auth/auth_screens.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/driver/driver_home.dart';
import '../features/kid/kid_home.dart';
import '../features/parent/parent_home.dart';
import '../features/school/school_home.dart';
import 'brand.dart';
import 'session.dart';

const _publicRoutes = {'/welcome', '/login', '/signup', '/pair'};

String homeFor(String role) => switch (role) {
      'PARENT' => '/parent',
      'DRIVER' => '/driver',
      'SCHOOL' => '/school',
      'KID' => '/kid',
      'ADMIN' => kIsWeb ? '/admin' : '/admin-web-only',
      _ => '/welcome',
    };

/// Top-level navigation is decided by who is signed in: each role has its own home.
/// Screens inside a role are pushed with Navigator, so they don't need URLs.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final path = state.matchedLocation;
      if (session.restoring) return path == '/' ? null : '/';
      if (!session.signedIn) return _publicRoutes.contains(path) ? null : '/welcome';
      if (session.user!.passwordChangeRequired) return path == '/set-password' ? null : '/set-password';
      if (!session.user!.onboardingComplete) return path == '/onboarding' ? null : '/onboarding';
      final home = homeFor(session.user!.role);
      return path.startsWith(home) ? null : home;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, state) => SignUpScreen(initialType: state.uri.queryParameters['type'])),
      GoRoute(path: '/pair', builder: (_, __) => const KidPairScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/set-password', builder: (_, __) => const SetPasswordScreen()),
      GoRoute(path: '/parent', builder: (_, __) => const ParentHome()),
      GoRoute(path: '/driver', builder: (_, __) => const DriverHome()),
      GoRoute(path: '/school', builder: (_, __) => const SchoolHome()),
      GoRoute(path: '/kid', builder: (_, __) => const KidHome()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminHome()),
      GoRoute(path: '/admin-web-only', builder: (_, __) => const AdminWebOnlyScreen()),
    ],
  );
});

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: BrandMark(size: 44)));
}
