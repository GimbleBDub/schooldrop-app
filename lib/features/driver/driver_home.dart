import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../parent/parent_home.dart' show greeting;
import '../shared/app_shell.dart';
import 'driver_providers.dart';
import 'onboarding_screen.dart';
import 'team_screen.dart';
import 'trips_screens.dart';
import 'work_screens.dart';

/// Until approved the driver sees verification (plus their team, if they run one); afterwards the workspace,
/// shaped by what they do: drivers drive, owners / managers run routes and the team, owners handle money.
class DriverHome extends ConsumerWidget {
  const DriverHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(driverProfileProvider).value;
    final approved = profile?.isApproved ?? false;
    final user = ref.watch(sessionProvider).user;
    final teamRole = user?.teamRole;
    final inTeam = teamRole != null;
    final manages = !inTeam || teamRole != 'DRIVER';
    final owns = !inTeam || teamRole == 'OWNER';
    final drives = profile?.drives ?? true;

    final verification = ShellDestination(
      icon: Icons.verified_user_outlined,
      selectedIcon: Icons.verified_user_rounded,
      label: approved ? 'Profile' : 'Verification',
      title: approved ? 'Profile & documents' : 'Get verified',
      builder: () => const OnboardingScreen(),
    );
    final team = ShellDestination(
      icon: Icons.groups_2_outlined,
      selectedIcon: Icons.groups_2_rounded,
      label: 'Team',
      title: user?.teamName ?? 'Team',
      builder: () => const TeamTab(),
    );

    if (!approved) {
      return AppShell(
        key: ValueKey('verification$teamRole'),
        destinations: [verification, if (inTeam && manages) team],
      );
    }
    return AppShell(
      key: ValueKey('workspace$teamRole$drives'),
      destinations: [
        // People who only run the business start on the team's runs
        if (!drives && inTeam) team,
        if (drives)
          ShellDestination(
            icon: Icons.today_outlined,
            selectedIcon: Icons.today_rounded,
            label: 'Today',
            title: greeting(user?.firstName),
            builder: () => const DriverTodayTab(),
          ),
        if (drives)
          ShellDestination(
            icon: Icons.bolt_outlined,
            selectedIcon: Icons.bolt_rounded,
            label: 'Pickups',
            title: 'Once-off pickups',
            builder: () => const DriverPickupsTab(),
          ),
        ShellDestination(
          icon: Icons.alt_route_outlined,
          selectedIcon: Icons.alt_route_rounded,
          label: inTeam ? 'Routes' : 'Offers',
          title: inTeam ? (manages ? 'Team routes' : 'My routes') : 'My offers',
          builder: () => const DriverOffersTab(),
          fab: manages
              ? (context) => FloatingActionButton.extended(
                  onPressed: () => openOfferForm(context),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(inTeam ? 'New route' : 'New offer'))
              : null,
        ),
        if (owns)
          ShellDestination(
            icon: Icons.account_balance_wallet_outlined,
            selectedIcon: Icons.account_balance_wallet_rounded,
            label: 'Money',
            title: 'Earnings & billing',
            builder: () => const EarningsTab(),
          ),
        if (drives && inTeam) team,
        verification,
      ],
    );
  }
}
