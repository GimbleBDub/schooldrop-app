import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../shared/app_shell.dart';
import 'admin_finance.dart';
import 'admin_sections.dart';
import 'admin_staff.dart';

class _Section {
  const _Section(this.icon, this.label, this.builder, {this.permission});

  final IconData icon;
  final String label;
  final Widget Function() builder;

  /// Staff permission needed to see this section (null = any staff).
  final String? permission;
}

final _sections = <_Section>[
  _Section(Icons.space_dashboard_outlined, 'Dashboard', () => const DashboardSection()),
  _Section(Icons.verified_user_outlined, 'Drivers', () => const DriversSection(), permission: 'VERIFIER|SUPPORT|VIEWER'),
  _Section(Icons.school_outlined, 'Schools', () => const SchoolsSection(), permission: 'VERIFIER|SUPPORT|VIEWER'),
  _Section(Icons.sos_outlined, 'Incidents', () => const IncidentsSection(), permission: 'SUPPORT|VIEWER'),
  _Section(Icons.map_outlined, 'Live trips', () => const LiveTripsSection(), permission: 'SUPPORT|VIEWER'),
  _Section(Icons.people_outline, 'Users', () => const UsersSection(), permission: 'SUPPORT|VIEWER'),
  _Section(Icons.event_seat_outlined, 'Bookings', () => const BookingsSection(), permission: 'SUPPORT|FINANCE|VIEWER'),
  _Section(Icons.campaign_outlined, 'Adverts', () => const AdvertsSection(), permission: 'MARKETING|VIEWER'),
  _Section(Icons.insights_outlined, 'Finance', () => const FinanceSection(), permission: 'FINANCE|VIEWER'),
  _Section(Icons.payments_outlined, 'Payments', () => const PaymentsSection(), permission: 'FINANCE|VIEWER'),
  _Section(Icons.account_balance_wallet_outlined, 'Payouts', () => const PayoutsSection(), permission: 'FINANCE|VIEWER'),
  _Section(Icons.description_outlined, 'Documents', () => const InvoicesSection(), permission: 'FINANCE|SUPPORT|VIEWER'),
  _Section(Icons.calendar_month_outlined, 'School terms', () => const TermsSection()),
  _Section(Icons.palette_outlined, 'Vehicle colours', () => const VehicleColoursSection(), permission: 'VERIFIER|SUPPORT'),
  _Section(Icons.badge_outlined, 'Staff', () => const StaffSection(), permission: 'SUPER_ADMIN'),
  _Section(Icons.history, 'Audit log', () => const AuditSection(), permission: 'SUPER_ADMIN'),
];

/// SchoolDrop back office. Web only; each section is shown only to staff with the right permission.
class AdminHome extends ConsumerWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    if (user == null) return const SizedBox.shrink();
    final visible = _sections.where((s) => s.permission == null || s.permission!.split('|').any(user.can));
    return AppShell(
      nestedNavigation: true,
      subtitle: 'SchoolDrop back office',
      destinations: [
        for (final s in visible) ShellDestination(icon: s.icon, label: s.label, builder: s.builder),
      ],
    );
  }
}

class AdminWebOnlyScreen extends ConsumerWidget {
  const AdminWebOnlyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.desktop_windows_outlined, size: 64),
            const SizedBox(height: 16),
            const Text('The SchoolDrop admin panel is only available on the web.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => ref.read(sessionProvider.notifier).logout(),
              child: const Text('Sign out'),
            ),
          ]),
        ),
      ),
    );
  }
}
