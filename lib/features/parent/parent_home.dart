import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../shared/app_shell.dart';
import 'booking_screens.dart';
import 'children_screens.dart';
import 'family_screen.dart';
import 'pickups_screens.dart';
import 'trips_tab.dart';

String greeting(String? name) {
  final hour = DateTime.now().hour;
  final part = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
  return name == null ? part : '$part, $name';
}

class ParentHome extends ConsumerWidget {
  const ParentHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    final name = user?.firstName;
    final today = ShellDestination(
      icon: Icons.today_outlined,
      selectedIcon: Icons.today_rounded,
      label: 'Today',
      title: greeting(name),
      builder: () => const TodayTab(),
    );
    final family = ShellDestination(
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups_rounded,
      label: 'Family',
      builder: () => const FamilyTab(),
    );
    // Helpers (e.g. a nanny) only see today's trips and confirm handovers
    if (user?.isHelper ?? false) {
      return AppShell(key: const ValueKey('helper'), destinations: [today, family]);
    }
    return AppShell(key: const ValueKey('family'), destinations: [
      today,
      ShellDestination(
        icon: Icons.child_care_outlined,
        selectedIcon: Icons.child_care_rounded,
        label: 'Children',
        title: 'My children',
        builder: () => const ChildrenTab(),
        fab: (context) => FloatingActionButton.extended(
            onPressed: () => openChildForm(context), icon: const Icon(Icons.add_rounded), label: const Text('Add child')),
      ),
      ShellDestination(
        icon: Icons.event_seat_outlined,
        selectedIcon: Icons.event_seat_rounded,
        label: 'Bookings',
        builder: () => const BookingsTab(),
      ),
      ShellDestination(
        icon: Icons.bolt_outlined,
        selectedIcon: Icons.bolt_rounded,
        label: 'Pickups',
        title: 'Once-off pickups',
        builder: () => const PickupsTab(),
        fab: (context) => FloatingActionButton.extended(
            onPressed: () => openPickupRequest(context), icon: const Icon(Icons.bolt_rounded), label: const Text('Request pickup')),
      ),
      family,
    ]);
  }
}
