import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/common.dart';
import '../../models/school.dart';
import '../../models/trip.dart';
import '../../core/session.dart';
import '../shared/app_shell.dart';
import '../shared/sponsored_card.dart';
import '../shared/trip_map.dart';
import 'package:latlong2/latlong.dart';
import 'staff_tab.dart';

final _mySchoolProvider = FutureProvider.autoDispose<School>((ref) => ref.watch(schoolApiProvider).mySchool());
final _schoolTripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) => ref.watch(schoolApiProvider).trips());
final _enrollmentsProvider = FutureProvider.autoDispose.family<PageResult<SchoolChild>, String?>(
    (ref, status) => ref.watch(schoolApiProvider).children(status: status));

/// School portal (mostly used on a computer at the office / gate).
class SchoolHome extends ConsumerWidget {
  const SchoolHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final school = ref.watch(_mySchoolProvider).value;
    final verified = school?.status == 'VERIFIED';
    final admin = ref.watch(sessionProvider).user?.isSchoolAdmin ?? true;
    final profile = ShellDestination(
      icon: Icons.school_outlined,
      selectedIcon: Icons.school_rounded,
      label: 'Our school',
      builder: () => const _SchoolProfile(),
    );
    return AppShell(
      key: ValueKey('$verified$admin'),
      subtitle: school?.name,
      destinations: verified
          ? [
              ShellDestination(
                icon: Icons.door_front_door_outlined,
                selectedIcon: Icons.door_front_door_rounded,
                label: 'Gate list',
                title: "Today's gate list",
                builder: () => const _GateList(),
              ),
              if (admin)
                ShellDestination(
                  icon: Icons.how_to_reg_outlined,
                  selectedIcon: Icons.how_to_reg_rounded,
                  label: 'Enrollments',
                  builder: () => const _Enrollments(),
                ),
              ShellDestination(
                icon: Icons.badge_outlined,
                selectedIcon: Icons.badge_rounded,
                label: 'Staff',
                builder: () => const StaffTab(),
              ),
              profile,
            ]
          : [profile],
    );
  }
}

/// Who is collecting which child today. Staff release each child to the authorised driver.
class _GateList extends ConsumerStatefulWidget {
  const _GateList();

  @override
  ConsumerState<_GateList> createState() => _GateListState();
}

class _GateListState extends ConsumerState<_GateList> {
  Timer? _timer;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => ref.invalidate(_schoolTripsProvider));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(_schoolTripsProvider);
    return AsyncBody<List<Trip>>(
      value: trips,
      onRetry: () => ref.invalidate(_schoolTripsProvider),
      builder: (list) {
        final pickups = list.where((t) => !t.toSchool).toList();
        final arrivals = list.where((t) => t.toSchool).toList();
        bool matches(Passenger p) => _filter.isEmpty || p.childName.toLowerCase().contains(_filter.toLowerCase());
        return Constrained(
          maxWidth: 1000,
          child: RefreshableList(provider: _schoolTripsProvider, children: [
            Text('Today, ${formatDate(DateTime.now())}', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Find a child'),
              onChanged: (v) => setState(() => _filter = v),
            ),
            const SectionTitle('Afternoon pickups — release only to the driver shown'),
            if (pickups.isEmpty) const Text('No pickups booked for today.'),
            for (final trip in pickups)
              for (final p in trip.passengers.where(matches)) _PickupRow(trip: trip, passenger: p),
            const SectionTitle('Morning arrivals'),
            if (arrivals.isEmpty) const Text('No morning trips today.'),
            for (final trip in arrivals)
              for (final p in trip.passengers.where(matches))
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.wb_sunny_outlined),
                    title: Text(p.childName),
                    subtitle: Text([
                      '${trip.driverName} · ${trip.vehiclePlate}',
                      if (p.droppedOffAt != null) 'driver dropped off ${formatTime(p.droppedOffAt)}',
                      if (p.dropoffConfirmedAt != null) 'confirmed by ${p.dropoffConfirmedBy}',
                    ].join(' · ')),
                    trailing: p.dropoffConfirmedAt != null
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D))
                        : p.status == 'ABSENT'
                            ? StatusChip(p.status)
                            : FilledButton.tonal(
                                onPressed: () async {
                                  await runAction(context, () => ref.read(schoolApiProvider).confirmArrival(p.id),
                                      success: '${p.firstName} arrived — family notified');
                                  ref.invalidate(_schoolTripsProvider);
                                },
                                child: const Text('Arrived'),
                              ),
                  ),
                ),
          ]),
        );
      },
    );
  }
}

class _PickupRow extends ConsumerWidget {
  const _PickupRow({required this.trip, required this.passenger});

  final Trip trip;
  final Passenger passenger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = passenger;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.childName, style: theme.textTheme.titleMedium),
              if (p.grade != null) Text(p.grade!),
              if (trip.adHoc) const Text('Once-off pickup arranged by parent', style: TextStyle(fontStyle: FontStyle.italic)),
            ]),
          ),
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.verified, color: Colors.green, size: 18),
                const SizedBox(width: 4),
                Flexible(child: Text(trip.driverName, style: const TextStyle(fontWeight: FontWeight.w600))),
              ]),
              Text(trip.vehicle),
              Text('Plate: ${trip.vehiclePlate}', style: theme.textTheme.titleSmall),
            ]),
          ),
          SizedBox(
            width: 150,
            child: p.pickupConfirmedAt != null
                ? Text('Released ${formatTime(p.pickupConfirmedAt)}\nby ${p.pickupConfirmedBy}', textAlign: TextAlign.end)
                : p.status != 'EXPECTED'
                    ? Align(alignment: Alignment.centerRight, child: StatusChip(p.status))
                    : FilledButton(
                        onPressed: () async {
                          if (!await confirmDialog(context, 'Release ${p.childName}?',
                              'Only hand over to ${trip.driverName} in vehicle ${trip.vehiclePlate}.',
                              confirm: 'Release')) {
                            return;
                          }
                          if (!context.mounted) return;
                          await runAction(context, () => ref.read(schoolApiProvider).release(p.id),
                              success: '${p.childName} released — parent notified');
                          ref.invalidate(_schoolTripsProvider);
                        },
                        child: const Text('Release'),
                      ),
          ),
        ]),
      ),
    );
  }
}

class _Enrollments extends ConsumerStatefulWidget {
  const _Enrollments();

  @override
  ConsumerState<_Enrollments> createState() => _EnrollmentsState();
}

class _EnrollmentsState extends ConsumerState<_Enrollments> {
  String? _status = 'PENDING';

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(_enrollmentsProvider(_status));
    return Constrained(
      maxWidth: 1000,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<String?>(
            segments: const [
              ButtonSegment(value: 'PENDING', label: Text('To confirm')),
              ButtonSegment(value: 'CONFIRMED', label: Text('Confirmed')),
              ButtonSegment(value: 'REJECTED', label: Text('Rejected')),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
        ),
        Expanded(
          child: AsyncBody<PageResult<SchoolChild>>(
            value: children,
            onRetry: () => ref.invalidate(_enrollmentsProvider(_status)),
            builder: (page) => page.content.isEmpty
                ? const EmptyState(icon: Icons.inbox_outlined, title: 'Nothing here')
                : ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                    const SponsoredCard(),
                    if (_status == 'PENDING')
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('Parents say these children attend your school. Confirm only pupils you can '
                            'identify — confirmed children can be booked for transport and collected from your gate.'),
                      ),
                    for (final c in page.content)
                      Card(
                        child: ListTile(
                          title: Text(c.fullName),
                          subtitle: Text([
                            if (c.grade != null) c.grade!,
                            if (c.studentNumber != null) 'No. ${c.studentNumber}',
                            if (c.dateOfBirth != null) 'Born ${formatDate(c.dateOfBirth)}',
                            'Parent: ${c.parentName}${c.parentPhone != null ? ' (${c.parentPhone})' : ''}',
                          ].join(' · ')),
                          trailing: _status != 'PENDING'
                              ? StatusChip(c.enrollmentStatus)
                              : Wrap(spacing: 8, children: [
                                  OutlinedButton(
                                    onPressed: () async {
                                      final reason = await askText(context, 'Not a pupil here?', label: 'Reason for the parent');
                                      if (reason == null || !context.mounted) return;
                                      await runAction(context, () => ref.read(schoolApiProvider).reject(c.id, reason));
                                      ref.invalidate(_enrollmentsProvider);
                                    },
                                    child: const Text('Reject'),
                                  ),
                                  FilledButton(
                                    onPressed: () async {
                                      await runAction(context, () => ref.read(schoolApiProvider).confirm(c.id),
                                          success: '${c.fullName} confirmed');
                                      ref.invalidate(_enrollmentsProvider);
                                    },
                                    child: const Text('Confirm'),
                                  ),
                                ]),
                        ),
                      ),
                  ]),
          ),
        ),
      ]),
    );
  }
}

class _SchoolProfile extends ConsumerWidget {
  const _SchoolProfile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final school = ref.watch(_mySchoolProvider);
    final admin = ref.watch(sessionProvider).user?.isSchoolAdmin ?? true;
    return AsyncBody<School>(
      value: school,
      onRetry: () => ref.invalidate(_mySchoolProvider),
      builder: (s) => Constrained(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (s.status != 'VERIFIED')
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(label(s.status)),
                subtitle: Text(s.statusReason ?? 'Contact SchoolDrop support.'),
              ),
            ),
          if (s.latitude != null && s.longitude != null) ...[
            TripMap(points: {s.name: LatLng(s.latitude!, s.longitude!)}, height: 220),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                InfoRow('Name', s.name),
                InfoRow('Registration no.', s.registrationNumber),
                InfoRow('Address', '${s.address}, ${s.city}'),
                InfoRow('Phone', s.phone),
                InfoRow('Email', s.email),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Your school\'s name, address and map pin are set by SchoolDrop, because families and drivers rely on them. '
              'To correct them, contact support@schooldrop.co.bw.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          if (admin)
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit contact details'),
              onPressed: () => _edit(context, ref, s),
            ),
          if (s.status == 'VERIFIED') const SponsoredCard(),
        ]),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, School s) async {
    final phone = TextEditingController(text: s.phone);
    final email = TextEditingController(text: s.email);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact details'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: phone, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'School phone', prefixIcon: Icon(Icons.phone_outlined))),
            const SizedBox(height: 12),
            TextField(controller: email, keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'School email', prefixIcon: Icon(Icons.mail_outline_rounded))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          BusyButton(
            onPressed: () async {
              final ok = await runAction(context, () => ref.read(schoolApiProvider).update({
                    'phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
                    'email': email.text.trim().isEmpty ? null : email.text.trim(),
                  }), success: 'Saved');
              if (ok && context.mounted) {
                ref.invalidate(_mySchoolProvider);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
