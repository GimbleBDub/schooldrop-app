import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/driver.dart';
import '../../models/family.dart' show Invite;
import '../../models/trip.dart';
import '../parent/family_screen.dart' show showInviteCode;
import 'driver_providers.dart';
import 'onboarding_screen.dart' show refreshDriver;

final teamProvider = FutureProvider.autoDispose<Team>((ref) => ref.watch(driverApiProvider).team());
final teamTripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) => ref.watch(driverApiProvider).teamTrips());

/// A team / transport company: who's in it, today's runs, invites. Owners and managers run it from here.
class TeamTab extends ConsumerWidget {
  const TeamTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncBody<Team>(
      value: ref.watch(teamProvider),
      onRetry: () => ref.invalidate(teamProvider),
      builder: (team) => Constrained(
        maxWidth: 860,
        child: RefreshableList(provider: teamProvider, children: [
          _TeamHeader(team: team),
          if (team.iManage) ...[
            SectionTitle("Today's runs", trailing: IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => ref.invalidate(teamTripsProvider),
            )),
            _TeamRuns(team: team),
          ],
          SectionTitle('People', trailing: team.iManage
              ? FilledButton.tonalIcon(
                  onPressed: () => _invite(context, ref, team),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Invite'),
                )
              : null),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < team.members.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 72),
                _MemberTile(team: team, member: team.members[i]),
              ],
            ]),
          ),
          if (team.invites.isNotEmpty) ...[
            const SectionTitle('Waiting to join'),
            for (final inv in team.invites)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.mark_email_unread_outlined),
                  title: Text(inv.inviteeName ?? 'Invite'),
                  subtitle: Text('${_roleName(inv.role)} · code works until ${shortDate(inv.expiresAt)}'),
                  trailing: TextButton(
                    onPressed: () async {
                      await runAction(context, () => ref.read(driverApiProvider).revokeTeamInvite(inv.id), success: 'Invite cancelled');
                      ref.invalidate(teamProvider);
                    },
                    child: const Text('Cancel'),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          _HowItWorks(team: team),
          if (!team.iOwn) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout_rounded),
              label: Text('Leave ${team.name}'),
              onPressed: () async {
                if (!await confirmDialog(context, 'Leave ${team.name}?',
                    "You'll drive on your own again. Earnings already made stay with the team.", confirm: 'Leave')) {
                  return;
                }
                if (!context.mounted) return;
                final ok = await runAction(context, () => ref.read(driverApiProvider).leaveTeam(), success: 'You left the team');
                if (ok) await refreshDriver(ref);
              },
            ),
          ],
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Future<void> _invite(BuildContext context, WidgetRef ref, Team team) async {
    final name = TextEditingController();
    var role = 'DRIVER';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Invite to ${team.name}'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Their name (optional)')),
              const SizedBox(height: 12),
              RadioListTile<String>(
                value: 'DRIVER',
                groupValue: role,
                onChanged: (v) => setState(() => role = v!),
                title: const Text('Driver'),
                subtitle: const Text('Drives the routes you assign'),
              ),
              if (team.iOwn)
                RadioListTile<String>(
                  value: 'MANAGER',
                  groupValue: role,
                  onChanged: (v) => setState(() => role = v!),
                  title: const Text('Manager'),
                  subtitle: const Text('Runs drivers, vehicles and routes with you (no access to money)'),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create code')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    TeamInvite? invite;
    final created = await runAction(context, () async {
      invite = await ref.read(driverApiProvider).inviteToTeam(role, name.text.trim().isEmpty ? null : name.text.trim());
    });
    ref.invalidate(teamProvider);
    if (created && context.mounted && invite != null) {
      await showInviteCode(
          context,
          Invite(id: invite!.id, role: invite!.role, code: invite!.code, expiresAt: invite!.expiresAt, inviteeName: invite!.inviteeName),
          who: team.name);
    }
  }
}

String _roleName(String role) => switch (role) { 'OWNER' => 'Owner', 'MANAGER' => 'Manager', _ => 'Driver' };

class _TeamHeader extends StatelessWidget {
  const _TeamHeader({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) {
    final drivers = team.drivers;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.brand, AppColors.brandDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.groups_2_rounded, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(team.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
            child: Text('You: ${_roleName(team.myRole)}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          [
            team.kind == 'COMPANY' ? 'Registered company' : 'Team',
            if (team.registrationNumber != null) 'CIPA ${team.registrationNumber}',
            'run by ${team.ownerName}',
          ].join(' · '),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
        ),
        const SizedBox(height: 18),
        Wrap(spacing: 28, runSpacing: 12, children: [
          _stat('People', '${team.members.length}'),
          _stat('Drivers', '$drivers'),
          _stat('Vehicles', '${team.vehicles}'),
          _stat('Listing fee', '${money(team.monthlyFee)}/mo'),
          _stat('Listed until', team.listedUntil == null ? 'Not paid' : formatDate(team.listedUntil)),
        ]),
        if (team.ownerStatus != 'APPROVED') ...[
          const SizedBox(height: 14),
          Text(
            team.iOwn
                ? 'Your routes go live once SchoolDrop verifies you (and each driver).'
                : "Routes go live once SchoolDrop verifies ${team.ownerName}'s business.",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
          ),
        ],
      ]),
    );
  }

  static Widget _stat(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
      ]);
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.team, required this.member});

  final Team team;
  final TeamMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = member;
    final theme = Theme.of(context);
    final canEdit = team.iOwn && !m.you && m.role != 'OWNER';
    final canRemove = !m.you && m.role != 'OWNER' && (team.iOwn || (team.iManage && m.role == 'DRIVER'));
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        child: Text(m.name.isEmpty ? '?' : m.name[0], style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
      ),
      title: Row(children: [
        Flexible(child: Text(m.you ? '${m.name} (you)' : m.name, style: const TextStyle(fontWeight: FontWeight.w600))),
        const SizedBox(width: 8),
        StatusChip(m.status),
      ]),
      subtitle: Text([
        _roleName(m.role),
        m.drives ? 'drives' : "doesn't drive",
        if (m.activeRoutes > 0) '${m.activeRoutes} route${m.activeRoutes == 1 ? '' : 's'}',
        if (m.status != 'APPROVED') 'not verified yet',
      ].join(' · ')),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (m.phone != null && !m.you)
          IconButton(tooltip: 'Call', icon: const Icon(Icons.call_outlined), onPressed: () => launchUrl(Uri.parse('tel:${m.phone}'))),
        if (canEdit || canRemove)
          PopupMenuButton<String>(
            itemBuilder: (_) => [
              if (canEdit && m.role == 'DRIVER') const PopupMenuItem(value: 'manager', child: Text('Make manager')),
              if (canEdit && m.role == 'MANAGER') const PopupMenuItem(value: 'driver', child: Text('Make driver')),
              if (canEdit && m.role == 'MANAGER')
                PopupMenuItem(value: 'drives', child: Text(m.drives ? "Doesn't drive" : 'Also drives')),
              if (canRemove) const PopupMenuItem(value: 'remove', child: Text('Remove from team')),
            ],
            onSelected: (action) async {
              final api = ref.read(driverApiProvider);
              switch (action) {
                case 'manager':
                  await runAction(context, () => api.updateTeamMember(m.driverId, 'MANAGER', m.drives), success: '${m.name} is now a manager');
                case 'driver':
                  await runAction(context, () => api.updateTeamMember(m.driverId, 'DRIVER', true), success: '${m.name} is now a driver');
                case 'drives':
                  await runAction(context, () => api.updateTeamMember(m.driverId, m.role, !m.drives));
                case 'remove':
                  if (!await confirmDialog(context, 'Remove ${m.name}?',
                      "They'll be signed out and can't see your routes or children's details any more. "
                          'Hand their routes to someone else first.',
                      confirm: 'Remove')) {
                    return;
                  }
                  if (!context.mounted) return;
                  await runAction(context, () => api.removeTeamMember(m.driverId), success: '${m.name} removed');
              }
              ref.invalidate(teamProvider);
              ref.invalidate(driverOffersProvider);
            },
          ),
      ]),
    );
  }
}

/// Every run of the team today; an owner / manager can hand a run to another driver.
class _TeamRuns extends ConsumerWidget {
  const _TeamRuns({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncBody<List<Trip>>(
      value: ref.watch(teamTripsProvider),
      onRetry: () => ref.invalidate(teamTripsProvider),
      builder: (trips) {
        if (trips.isEmpty) {
          return Text('No runs today.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant));
        }
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < trips.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 72),
              _RunTile(team: team, trip: trips[i]),
            ],
          ]),
        );
      },
    );
  }
}

class _RunTile extends ConsumerWidget {
  const _RunTile({required this.team, required this.trip});

  final Team team;
  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trip;
    final morning = t.leg == 'TO_SCHOOL';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: (morning ? AppColors.amber : AppColors.brand).withValues(alpha: 0.12),
        child: Icon(morning ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined, color: morning ? AppColors.warning : AppColors.brand),
      ),
      title: Text('${t.schoolName} · ${morning ? 'morning' : 'afternoon'}', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${t.driverName} · ${t.vehicle} · ${t.passengers.length} child${t.passengers.length == 1 ? '' : 'ren'}'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        StatusChip(t.status),
        if (t.status == 'SCHEDULED')
          TextButton(onPressed: () => _reassign(context, ref), child: const Text('Hand to…')),
      ]),
    );
  }

  Future<void> _reassign(BuildContext context, WidgetRef ref) async {
    final drivers = team.members.where((m) => m.canDrive && m.name != trip.driverName).toList();
    if (drivers.isEmpty) {
      showMessage(context, 'No other verified driver in the team yet', error: true);
      return;
    }
    final chosen = await showDialog<TeamMember>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Who covers this run?'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text("Just this run. The families on it are told who's coming. To move the route for good, edit it in Routes.",
                style: Theme.of(context).textTheme.bodySmall),
          ),
          for (final d in drivers)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, d),
              child: ListTile(leading: const Icon(Icons.person_outline), title: Text(d.name), subtitle: Text(_roleName(d.role))),
            ),
        ],
      ),
    );
    if (chosen == null || !context.mounted) return;
    await runAction(context, () => ref.read(driverApiProvider).assignTrip(trip.id, chosen.driverId),
        success: '${chosen.name} is covering this run');
    ref.invalidate(teamTripsProvider);
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final points = [
      'Everyone is verified individually (Omang, police clearance; a licence for those who drive).',
      'Owners and managers add vehicles and routes, and choose which driver runs each route.',
      'Families see the driver and "${team.name}" on every route.',
      'Payouts, the monthly listing fee (${money(team.drivers == 0 ? 0 : team.monthlyFee / team.drivers)} per driver) and adverts go through ${team.ownerName}.',
      "Earnings stay with the team even if a driver leaves; a driver can't leave while they have routes.",
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How teams work', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final p in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('•  '),
                Expanded(child: Text(p, style: muted)),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// For the session-driven shell: is this driver account part of a team, and can they manage it?
bool managesTeam(WidgetRef ref) {
  final role = ref.watch(sessionProvider).user?.teamRole;
  return role == 'OWNER' || role == 'MANAGER';
}
