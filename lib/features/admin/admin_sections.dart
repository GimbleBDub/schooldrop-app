import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/admin.dart';
import '../../models/booking.dart';
import '../../models/common.dart';
import '../../models/driver.dart';
import '../../models/promo.dart';
import '../../models/school.dart';
import '../../models/trip.dart';
import '../shared/trip_map.dart';
import 'driver_review.dart';
import 'school_form.dart';
import '../../models/family.dart' show Invite;
import '../parent/family_screen.dart' show showInviteCode;
import '../driver/onboarding_screen.dart' show swatchFor;

// ─── Building blocks ───────────────────────────────────────────────────────

/// Filters/actions row at the top of a section (the shell's top bar shows the title).
class AdminHeader extends StatelessWidget {
  const AdminHeader(this.title, {super.key, this.children = const []});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => children.isEmpty
      ? const SizedBox(height: 12)
      : Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: children),
        );
}

/// Status filter chips: null = all.
class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.values, required this.selected, required this.onChanged});

  final List<String> values;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 6, children: [
        ChoiceChip(label: const Text('All'), selected: selected == null, onSelected: (_) => onChanged(null)),
        for (final v in values)
          ChoiceChip(label: Text(label(v)), selected: selected == v, onSelected: (_) => onChanged(v)),
      ]);
}

/// Fetches a page whenever [fetchKey] changes; prev/next paging. [reload] re-runs the current page.
class AdminPaged<T> extends StatefulWidget {
  const AdminPaged({super.key, required this.fetch, required this.itemBuilder, this.empty = 'Nothing here'});

  final Future<PageResult<T>> Function(int page) fetch;
  final Widget Function(T item, VoidCallback reload) itemBuilder;
  final String empty;

  @override
  State<AdminPaged<T>> createState() => _AdminPagedState<T>();
}

class _AdminPagedState<T> extends State<AdminPaged<T>> {
  int _page = 0;
  late Future<PageResult<T>> _future = widget.fetch(0);

  void _load(int page) => setState(() {
        _page = page;
        _future = widget.fetch(page);
      });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PageResult<T>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorState(message: snapshot.error.toString(), onRetry: () => _load(_page));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final result = snapshot.data!;
        if (result.content.isEmpty) return EmptyState(icon: Icons.inbox_outlined, title: widget.empty);
        return Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), children: [
              for (final item in result.content) widget.itemBuilder(item, () => _load(_page)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(onPressed: _page > 0 ? () => _load(_page - 1) : null, icon: const Icon(Icons.chevron_left)),
              Text('Page ${_page + 1} of ${result.totalPages} · ${result.totalElements} total'),
              IconButton(
                  onPressed: _page + 1 < result.totalPages ? () => _load(_page + 1) : null,
                  icon: const Icon(Icons.chevron_right)),
            ]),
          ),
        ]);
      },
    );
  }
}

// ─── Dashboard ─────────────────────────────────────────────────────────────

final _dashboardProvider = FutureProvider.autoDispose<Dashboard>((ref) => ref.watch(adminApiProvider).dashboard());

class DashboardSection extends ConsumerWidget {
  const DashboardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(_dashboardProvider);
    return Scaffold(
      body: AsyncBody<Dashboard>(
        value: dashboard,
        onRetry: () => ref.invalidate(_dashboardProvider),
        builder: (d) => ListView(padding: const EdgeInsets.all(28), children: [
          PageHeader(
            title: 'Overview',
            subtitle: 'What needs attention across SchoolDrop right now',
            actions: [
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(_dashboardProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const _GroupTitle('Needs attention'),
          Wrap(spacing: 16, runSpacing: 16, children: [
            StatCard(label: 'Drivers to verify', value: '${d.count('driversAwaitingReview')}',
                icon: Icons.verified_user_outlined, highlight: d.count('driversAwaitingReview') > 0),
            StatCard(label: 'Schools to verify', value: '${d.count('schoolsAwaitingReview')}',
                icon: Icons.school_outlined, highlight: d.count('schoolsAwaitingReview') > 0),
            StatCard(label: 'Open incidents', value: '${d.count('openIncidents')}', icon: Icons.sos_outlined,
                color: const Color(0xFFDC2626), highlight: d.count('openIncidents') > 0),
            StatCard(label: 'Payouts to send', value: money(d.money('pendingPayouts')),
                icon: Icons.account_balance_wallet_outlined, color: const Color(0xFFB45309)),
          ]),
          const _GroupTitle('Operations'),
          Wrap(spacing: 16, runSpacing: 16, children: [
            StatCard(label: 'Trips in progress', value: '${d.count('tripsInProgress')}', icon: Icons.directions_bus_outlined),
            StatCard(label: 'Active bookings', value: '${d.count('activeBookings')}', icon: Icons.event_seat_outlined),
            StatCard(label: 'Collected · 30 days', value: money(d.money('grossLast30Days')),
                icon: Icons.payments_outlined, color: const Color(0xFF15803D)),
            StatCard(label: 'SchoolDrop revenue · 30 days', value: money(d.money('feesLast30Days')),
                icon: Icons.trending_up_rounded, color: const Color(0xFF15803D)),
          ]),
          const _GroupTitle('People'),
          Wrap(spacing: 16, runSpacing: 16, children: [
            StatCard(label: 'Parents', value: '${d.count('parents')}', icon: Icons.family_restroom_rounded),
            StatCard(label: 'Drivers', value: '${d.count('drivers')}', icon: Icons.airport_shuttle_outlined),
            StatCard(label: 'School staff', value: '${d.count('schoolStaff')}', icon: Icons.school_outlined),
            StatCard(label: 'Kids with phones', value: '${d.count('kidsPaired')}', icon: Icons.child_care_rounded),
          ]),
        ]),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 12),
        child: Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.8, fontWeight: FontWeight.w700)),
      );
}

// ─── Drivers & schools ─────────────────────────────────────────────────────

class DriversSection extends ConsumerStatefulWidget {
  const DriversSection({super.key});

  @override
  ConsumerState<DriversSection> createState() => _DriversSectionState();
}

class _DriversSectionState extends ConsumerState<DriversSection> {
  String? _status = 'UNDER_REVIEW';
  String _query = '';
  Timer? _debounce;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AdminHeader('Drivers', children: [
          _StatusFilter(
            values: const ['UNDER_REVIEW', 'PENDING_DOCUMENTS', 'APPROVED', 'REJECTED', 'SUSPENDED'],
            selected: _status,
            onChanged: (s) => setState(() => _status = s),
          ),
          SizedBox(
            width: 260,
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Name, email, phone', isDense: true),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () => setState(() => _query = v));
              },
            ),
          ),
        ]),
        Expanded(
          child: AdminPaged<DriverSummary>(
            key: ValueKey('$_status|$_query'),
            fetch: (page) => ref.read(adminApiProvider).drivers(status: _status, query: _query, page: page),
            empty: _status == 'UNDER_REVIEW' ? 'Verification queue is empty' : 'No drivers',
            itemBuilder: (d, reload) => Card(
              child: ListTile(
                leading: Icon(d.team == null ? Icons.person_outline : Icons.groups_2_outlined),
                title: Text(d.fullName),
                subtitle: Text('${d.team != null ? '${d.team}\n' : ''}${d.email} · ${d.phone ?? '—'}'
                    '${d.submittedAt != null ? ' · submitted ${dateTime(d.submittedAt)}' : ''}'),
                trailing: StatusChip(d.status),
                onTap: () async {
                  await Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => DriverReviewScreen(driverId: d.id)));
                  reload();
                },
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class SchoolsSection extends ConsumerStatefulWidget {
  const SchoolsSection({super.key});

  @override
  ConsumerState<SchoolsSection> createState() => _SchoolsSectionState();
}

class _SchoolsSectionState extends ConsumerState<SchoolsSection> {
  String? _status = 'VERIFIED';
  String _query = '';
  int _generation = 0;

  Future<void> _open([School? school]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => SchoolFormScreen(school: school)));
    if (saved == true) setState(() => _generation++);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).user;
    final canEdit = (user?.can('VERIFIER') ?? false) || (user?.can('SUPPORT') ?? false);
    return Scaffold(
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AdminHeader('Schools', children: [
          if (canEdit)
            FilledButton.icon(onPressed: () => _open(), icon: const Icon(Icons.add_location_alt_outlined), label: const Text('Add school')),
          SizedBox(
            width: 260,
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search schools', isDense: true),
              onSubmitted: (v) => setState(() => _query = v.trim()),
            ),
          ),
          _StatusFilter(
            values: const ['VERIFIED', 'SUSPENDED', 'PENDING'],
            selected: _status,
            onChanged: (s) => setState(() => _status = s),
          ),
        ]),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text('Families and drivers choose from these schools. Pin each one on the map, then give its admin an invite code.'),
        ),
        Expanded(
          child: AdminPaged<School>(
            key: ValueKey('$_status|$_query|$_generation'),
            empty: 'No schools yet — add the first one',
            fetch: (page) => ref.read(adminApiProvider).schools(status: _status, query: _query, page: page),
            itemBuilder: (s, reload) => Card(
              child: ListTile(
                leading: Icon(s.latitude == null ? Icons.location_off_outlined : Icons.location_on_outlined,
                    color: s.latitude == null ? Theme.of(context).colorScheme.error : null),
                title: Text(s.name),
                subtitle: Text([
                  '${s.address}, ${s.city}',
                  if (s.latitude == null) 'not pinned on the map',
                  if (s.phone != null) s.phone!,
                  if (s.statusReason != null) s.statusReason!,
                ].join(' · ')),
                onTap: canEdit ? () => _open(s) : null,
                trailing: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  StatusChip(s.status),
                  if (canEdit && s.status == 'VERIFIED')
                    TextButton.icon(
                      icon: const Icon(Icons.vpn_key_outlined, size: 18),
                      label: const Text('Invite staff'),
                      onPressed: () async {
                        Invite? invite;
                        final ok = await runAction(context, () async {
                          invite = await ref.read(adminApiProvider).inviteSchoolStaff(s.id, 'ADMIN', null);
                        });
                        if (ok && invite != null && context.mounted) {
                          await showInviteCode(context, invite!, who: '${s.name} as its admin');
                        }
                      },
                    ),
                  if (canEdit && s.status == 'PENDING')
                    FilledButton(
                      onPressed: () async {
                        await runAction(context, () => ref.read(adminApiProvider).schoolAction(s.id, 'verify'));
                        reload();
                      },
                      child: const Text('Verify'),
                    ),
                  if (canEdit && s.status == 'SUSPENDED')
                    TextButton(
                      onPressed: () async {
                        await runAction(context, () => ref.read(adminApiProvider).schoolAction(s.id, 'verify'), success: 'Reinstated');
                        reload();
                      },
                      child: const Text('Reinstate'),
                    ),
                  if (s.status == 'VERIFIED')
                    TextButton(
                      onPressed: () async {
                        final reason = await askText(context, 'Suspend ${s.name}?');
                        if (reason == null || !context.mounted) return;
                        await runAction(context, () => ref.read(adminApiProvider).schoolAction(s.id, 'suspend', reason: reason));
                        reload();
                      },
                      child: const Text('Suspend'),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// The vehicle colour dropdown drivers pick from.
class VehicleColoursSection extends ConsumerStatefulWidget {
  const VehicleColoursSection({super.key});

  @override
  ConsumerState<VehicleColoursSection> createState() => _VehicleColoursSectionState();
}

class _VehicleColoursSectionState extends ConsumerState<VehicleColoursSection> {
  late Future<List<({String id, String name, bool active})>> _future = ref.read(adminApiProvider).vehicleColours();

  void _reload() => setState(() => _future = ref.read(adminApiProvider).vehicleColours());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorState(message: snap.error.toString(), onRetry: _reload);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final colours = snap.data!;
          return ListView(padding: const EdgeInsets.all(24), children: [
            Row(children: [
              const Expanded(child: Text('Drivers choose their vehicle\'s colour from this list. Removed colours stay on vehicles that already use them.')),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add colour'),
                onPressed: () async {
                  final name = await askText(context, 'Add a colour', label: 'Colour name', confirm: 'Add');
                  if (name == null || !context.mounted) return;
                  await runAction(context, () => ref.read(adminApiProvider).addVehicleColour(name), success: 'Added');
                  _reload();
                },
              ),
            ]),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in colours)
                InputChip(
                  label: Text(c.name),
                  avatar: CircleAvatar(backgroundColor: swatchFor(c.name), radius: 8),
                  isEnabled: true,
                  selected: c.active,
                  showCheckmark: false,
                  deleteIcon: Icon(c.active ? Icons.close : Icons.undo, size: 18),
                  deleteButtonTooltipMessage: c.active ? 'Remove from the list' : 'Bring back',
                  onDeleted: () async {
                    await runAction(context, () => ref.read(adminApiProvider).setVehicleColourActive(c.id, !c.active));
                    _reload();
                  },
                ),
            ]),
          ]);
        },
      ),
    );
  }
}

class IncidentsSection extends ConsumerStatefulWidget {
  const IncidentsSection({super.key});

  @override
  ConsumerState<IncidentsSection> createState() => _IncidentsSectionState();
}

class _IncidentsSectionState extends ConsumerState<IncidentsSection> {
  String? _status = 'OPEN';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AdminHeader('Incidents', children: [
          _StatusFilter(
              values: const ['OPEN', 'IN_PROGRESS', 'RESOLVED'],
              selected: _status,
              onChanged: (s) => setState(() => _status = s)),
        ]),
        Expanded(
          child: AdminPaged<Incident>(
            key: ValueKey(_status),
            fetch: (page) => ref.read(adminApiProvider).incidents(status: _status, page: page),
            empty: 'No incidents',
            itemBuilder: (i, reload) => Card(
              color: i.type == 'SOS' && i.status != 'RESOLVED' ? scheme.errorContainer : null,
              child: ListTile(
                leading: Icon(i.type == 'SOS' ? Icons.sos : Icons.report_outlined),
                title: Text('${label(i.type)} — ${i.reporterName} (${label(i.reporterRole)})'),
                subtitle: Text([
                  i.description,
                  dateTime(i.createdAt),
                  if (i.reporterPhone != null) 'Call ${i.reporterPhone}',
                  if (i.driverName != null) 'Driver: ${i.driverName}',
                  if (i.latitude != null) 'At ${i.latitude!.toStringAsFixed(5)}, ${i.longitude!.toStringAsFixed(5)}',
                  if (i.resolution != null) 'Resolution: ${i.resolution}',
                ].join('\n')),
                isThreeLine: true,
                trailing: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  StatusChip(i.status),
                  if (i.status == 'OPEN')
                    OutlinedButton(
                      onPressed: () async {
                        await runAction(context, () => ref.read(adminApiProvider).updateIncident(i.id, 'IN_PROGRESS', null));
                        reload();
                      },
                      child: const Text('Take it'),
                    ),
                  if (i.status != 'RESOLVED')
                    FilledButton(
                      onPressed: () async {
                        final resolution = await askText(context, 'Resolve incident', label: 'What was done?');
                        if (resolution == null || !context.mounted) return;
                        await runAction(context, () => ref.read(adminApiProvider).updateIncident(i.id, 'RESOLVED', resolution));
                        reload();
                      },
                      child: const Text('Resolve'),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

final _liveTripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) => ref.watch(adminApiProvider).liveTrips());

class LiveTripsSection extends ConsumerStatefulWidget {
  const LiveTripsSection({super.key});

  @override
  ConsumerState<LiveTripsSection> createState() => _LiveTripsSectionState();
}

class _LiveTripsSectionState extends ConsumerState<LiveTripsSection> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => ref.invalidate(_liveTripsProvider));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(_liveTripsProvider);
    return Scaffold(
      body: AsyncBody<List<Trip>>(
        value: trips,
        onRetry: () => ref.invalidate(_liveTripsProvider),
        builder: (list) => ListView(padding: const EdgeInsets.all(24), children: [
          PageHeader(title: '${list.length} trips in progress', subtitle: 'Refreshes every 20 seconds'),
          const SizedBox(height: 16),
          TripMap(
            height: 420,
            points: {
              for (final t in list.where((t) => t.lastLatitude != null))
                '${t.driverName} · ${t.vehiclePlate}': LatLng(t.lastLatitude!, t.lastLongitude!),
            },
          ),
          const SizedBox(height: 16),
          for (final t in list)
            ListTile(
              leading: const Icon(Icons.directions_bus),
              title: Text('${t.driverName} — ${t.schoolName}'),
              subtitle: Text('${t.legLabel} · ${t.passengers.length} children · '
                  'last seen ${formatTime(t.lastLocationAt)}'),
              trailing: Text(t.driverPhone ?? ''),
            ),
        ]),
      ),
    );
  }
}

class UsersSection extends ConsumerStatefulWidget {
  const UsersSection({super.key});

  @override
  ConsumerState<UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends ConsumerState<UsersSection> {
  String? _role;
  String _query = '';
  Timer? _debounce;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AdminHeader('Users', children: [
          _StatusFilter(
              values: const ['PARENT', 'DRIVER', 'SCHOOL', 'KID', 'ADMIN'],
              selected: _role,
              onChanged: (r) => setState(() => _role = r)),
          SizedBox(
            width: 260,
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Name, email, phone', isDense: true),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () => setState(() => _query = v));
              },
            ),
          ),
        ]),
        Expanded(
          child: AdminPaged<AdminUser>(
            key: ValueKey('$_role|$_query'),
            fetch: (page) => ref.read(adminApiProvider).users(role: _role, query: _query, page: page),
            itemBuilder: (u, reload) => Card(
              child: ListTile(
                leading: Icon(u.enabled ? Icons.person_outline : Icons.person_off_outlined),
                title: Text(u.fullName),
                subtitle: Text('${label(u.role)} · ${u.email} · ${u.phone ?? '—'} · joined ${formatDate(u.createdAt)}'),
                trailing: u.enabled
                    ? TextButton(
                        onPressed: () async {
                          final reason = await askText(context, 'Disable ${u.fullName}?',
                              label: 'Reason — they are signed out everywhere immediately');
                          if (reason == null || !context.mounted) return;
                          await runAction(context, () => ref.read(adminApiProvider).setUserEnabled(u.id, false, reason: reason));
                          reload();
                        },
                        child: const Text('Disable'))
                    : FilledButton.tonal(
                        onPressed: () async {
                          await runAction(context, () => ref.read(adminApiProvider).setUserEnabled(u.id, true));
                          reload();
                        },
                        child: const Text('Enable')),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Money ─────────────────────────────────────────────────────────────────

class BookingsSection extends ConsumerStatefulWidget {
  const BookingsSection({super.key});

  @override
  ConsumerState<BookingsSection> createState() => _BookingsSectionState();
}

class _BookingsSectionState extends ConsumerState<BookingsSection> {
  String? _status = 'ACTIVE';

  @override
  Widget build(BuildContext context) {
    final canCancel = ref.watch(sessionProvider).user?.can('SUPPORT') ?? false;
    return Scaffold(
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AdminHeader('Bookings', children: [
          _StatusFilter(
              values: const ['PENDING_PAYMENT', 'ACTIVE', 'COMPLETED', 'CANCELLED', 'EXPIRED'],
              selected: _status,
              onChanged: (s) => setState(() => _status = s)),
        ]),
        Expanded(
          child: AdminPaged<Booking>(
            key: ValueKey(_status),
            fetch: (page) => ref.read(adminApiProvider).bookings(status: _status, page: page),
            itemBuilder: (b, reload) => Card(
              child: ListTile(
                title: Text('${b.childName} → ${b.schoolName} · ${money(b.amount)}'),
                subtitle: Text('Parent ${b.parentName} · driver ${b.driverName} · ${label(b.plan)} '
                    '${formatDate(b.startDate)}–${formatDate(b.endDate)}'),
                trailing: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  StatusChip(b.status),
                  if (canCancel && b.cancellable)
                    TextButton(
                      onPressed: () async {
                        final reason = await askText(context, 'Cancel booking');
                        if (reason == null || !context.mounted) return;
                        final refund = await confirmDialog(context, 'Refund the parent?',
                            'Refund every successful payment for this booking (not possible once the driver was paid).',
                            confirm: 'Refund');
                        if (!context.mounted) return;
                        await runAction(context, () => ref.read(adminApiProvider).cancelBooking(b.id, reason, refund));
                        reload();
                      },
                      child: const Text('Cancel'),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class PaymentsSection extends ConsumerStatefulWidget {
  const PaymentsSection({super.key});

  @override
  ConsumerState<PaymentsSection> createState() => _PaymentsSectionState();
}

class _PaymentsSectionState extends ConsumerState<PaymentsSection> {
  String? _status = 'SUCCEEDED';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AdminHeader('Payments', children: [
          _StatusFilter(
              values: const ['PENDING', 'SUCCEEDED', 'FAILED', 'CANCELLED', 'REFUNDED'],
              selected: _status,
              onChanged: (s) => setState(() => _status = s)),
        ]),
        Expanded(
          child: AdminPaged<Payment>(
            key: ValueKey(_status),
            fetch: (page) => ref.read(adminApiProvider).payments(status: _status, page: page),
            itemBuilder: (p, reload) => Card(
              child: ListTile(
                title: Text('${money(p.amount)} from ${p.payerName} to ${p.driverName}'),
                subtitle: Text('${label(p.purpose)}${p.offline ? ' · paid to driver directly' : ''} · '
                    '${label(p.method)} · ref ${p.providerReference ?? '—'} · fee ${money(p.platformFee)} · '
                    'driver ${money(p.driverAmount)} · ${dateTime(p.paidAt ?? p.createdAt)}'
                    '${p.failureReason != null ? '\n${p.failureReason}' : ''}'),
                trailing: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  StatusChip(p.status),
                  if (p.status == 'SUCCEEDED' && !p.offline)
                    TextButton(
                      onPressed: () async {
                        final reason = await askText(context, 'Refund ${money(p.amount)}?');
                        if (reason == null || !context.mounted) return;
                        await runAction(context, () => ref.read(adminApiProvider).refund(p.id, reason), success: 'Refunded');
                        reload();
                      },
                      child: const Text('Refund'),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class PayoutsSection extends ConsumerStatefulWidget {
  const PayoutsSection({super.key});

  @override
  ConsumerState<PayoutsSection> createState() => _PayoutsSectionState();
}

class _PayoutsSectionState extends ConsumerState<PayoutsSection> {
  String? _status = 'PENDING';
  int _generation = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AdminHeader('Payouts', children: [
          _StatusFilter(
              values: const ['PENDING', 'PAID', 'FAILED'], selected: _status, onChanged: (s) => setState(() => _status = s)),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.playlist_add),
            label: const Text('Prepare payouts now'),
            onPressed: () async {
              int created = 0;
              await runAction(context, () async => created = await ref.read(adminApiProvider).runPayouts());
              if (context.mounted) showMessage(context, '$created payouts prepared');
              setState(() => _generation++);
            },
          ),
        ]),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text('Send each payout by mobile money or bank transfer, then mark it paid with the transaction reference.'),
        ),
        Expanded(
          child: AdminPaged<Payout>(
            key: ValueKey('$_status|$_generation'),
            fetch: (page) => ref.read(adminApiProvider).payouts(status: _status, page: page),
            itemBuilder: (p, reload) => Card(
              child: ListTile(
                title: Text('${money(p.amount)} → ${p.driverName}'),
                subtitle: SelectableText('${label(p.method)}: ${p.account} · prepared ${dateTime(p.createdAt)}'
                    '${p.reference != null ? ' · ref ${p.reference}' : ''}'
                    '${p.failureReason != null ? ' · ${p.failureReason}' : ''}'),
                trailing: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  StatusChip(p.status),
                  if (p.status == 'PENDING') ...[
                    TextButton(
                      onPressed: () async {
                        final reason = await askText(context, 'Mark as failed');
                        if (reason == null || !context.mounted) return;
                        await runAction(context, () => ref.read(adminApiProvider).payoutFailed(p.id, reason));
                        reload();
                      },
                      child: const Text('Failed'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        final reference = await askText(context, 'Mark as paid',
                            label: 'Transaction reference', confirm: 'Mark paid');
                        if (reference == null || !context.mounted) return;
                        await runAction(context, () => ref.read(adminApiProvider).payoutPaid(p.id, reference));
                        reload();
                      },
                      child: const Text('Paid'),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Adverts ───────────────────────────────────────────────────────────────

class AdvertsSection extends ConsumerStatefulWidget {
  const AdvertsSection({super.key});

  @override
  ConsumerState<AdvertsSection> createState() => _AdvertsSectionState();
}

class _AdvertsSectionState extends ConsumerState<AdvertsSection> {
  String? _status = 'PENDING_REVIEW';
  int _generation = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AdminHeader('Adverts', children: [
          _StatusFilter(
              values: const ['PENDING_REVIEW', 'ACTIVE', 'PAUSED', 'REJECTED', 'EXPIRED', 'PENDING_PAYMENT'],
              selected: _status,
              onChanged: (s) => setState(() => _status = s)),
          FilledButton.tonalIcon(
            onPressed: _createForAdvertiser,
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Add advertiser'),
          ),
        ]),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text('Check every advert is appropriate for a children\'s transport app. '
              'Rejected driver adverts are refunded automatically.'),
        ),
        Expanded(
          child: AdminPaged<Advert>(
            key: ValueKey('$_status|$_generation'),
            fetch: (page) => ref.read(adminApiProvider).adverts(status: _status, page: page),
            empty: _status == 'PENDING_REVIEW' ? 'Nothing to review' : 'No adverts',
            itemBuilder: (a, reload) => Card(
              child: ListTile(
                leading: Icon(a.fromDriver ? Icons.airport_shuttle_outlined : Icons.storefront_outlined),
                title: Text('${a.title} — ${a.advertiserName}'),
                subtitle: Text([
                  a.body,
                  [a.targetSchoolName ?? 'All schools', if (a.price != null) money(a.price),
                    if (a.endsAt != null) 'until ${shortDate(a.endsAt)}', '${a.impressions} views · ${a.clicks} taps',
                    if (a.ctaPhone != null) a.ctaPhone!, if (a.ctaUrl != null) a.ctaUrl!].join(' · '),
                ].join('\n')),
                isThreeLine: true,
                trailing: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  StatusChip(a.status),
                  if (a.status == 'PENDING_REVIEW') ...[
                    OutlinedButton(
                      onPressed: () async {
                        final note = await askText(context, 'Reject advert', label: 'Reason (sent to the advertiser)');
                        if (note == null || !context.mounted) return;
                        await runAction(context, () => ref.read(adminApiProvider).reviewAdvert(a.id, false, note));
                        reload();
                      },
                      child: const Text('Reject'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        await runAction(context, () => ref.read(adminApiProvider).reviewAdvert(a.id, true, null),
                            success: 'Advert is live');
                        reload();
                      },
                      child: const Text('Approve'),
                    ),
                  ],
                  if (a.status == 'ACTIVE' || a.status == 'PAUSED')
                    TextButton(
                      onPressed: () async {
                        await runAction(context, () => ref.read(adminApiProvider).setAdvertPaused(a.id, a.status == 'ACTIVE'));
                        reload();
                      },
                      child: Text(a.status == 'ACTIVE' ? 'Pause' : 'Resume'),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _createForAdvertiser() async {
    final fields = {
      'advertiserName': TextEditingController(),
      'title': TextEditingController(),
      'body': TextEditingController(),
      'ctaLabel': TextEditingController(),
      'ctaPhone': TextEditingController(),
      'ctaUrl': TextEditingController(),
      'days': TextEditingController(text: '30'),
      'pricePaid': TextEditingController(),
    };
    const labels = {
      'advertiserName': 'Advertiser',
      'title': 'Headline (80 characters)',
      'body': 'Message (280 characters)',
      'ctaLabel': 'Button label (optional)',
      'ctaPhone': 'Phone (optional)',
      'ctaUrl': 'Link, https://… (optional)',
      'days': 'Runs for (days)',
      'pricePaid': 'Amount paid to SchoolDrop (P)',
    };
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add an advertiser\'s advert'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final e in fields.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(controller: e.value, decoration: InputDecoration(labelText: labels[e.key])),
                ),
              const Text('Goes live immediately for all schools. Use this for advertisers who paid you directly.'),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Publish')),
        ],
      ),
    );
    if (go != true || !mounted) return;
    String? v(String k) => fields[k]!.text.trim().isEmpty ? null : fields[k]!.text.trim();
    await runAction(context, () => ref.read(adminApiProvider).createAdvert({
          'advertiserName': v('advertiserName'),
          'title': v('title'),
          'body': v('body'),
          'ctaLabel': v('ctaLabel'),
          'ctaPhone': v('ctaPhone'),
          'ctaUrl': v('ctaUrl'),
          'days': int.tryParse(v('days') ?? ''),
          'pricePaid': double.tryParse(v('pricePaid') ?? '0') ?? 0,
        }), success: 'Advert is live');
    setState(() => _generation++);
  }
}

// ─── Settings ──────────────────────────────────────────────────────────────

final _termsProvider = FutureProvider.autoDispose<List<SchoolTerm>>((ref) => ref.watch(adminApiProvider).terms());

class TermsSection extends ConsumerWidget {
  const TermsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terms = ref.watch(_termsProvider);
    final canEdit = ref.watch(sessionProvider).user?.can('SUPER_ADMIN') ?? false;
    return Scaffold(
      body: AsyncBody<List<SchoolTerm>>(
        value: terms,
        onRetry: () => ref.invalidate(_termsProvider),
        builder: (list) => ListView(padding: const EdgeInsets.all(24), children: [
          Row(children: [
            const Spacer(),
            if (canEdit)
              FilledButton.icon(
                  onPressed: () => _editTerm(context, ref), icon: const Icon(Icons.add), label: const Text('Add term')),
          ]),
          const Text('Termly bookings use these dates. Publish them before each term.'),
          const SizedBox(height: 12),
          for (final t in list)
            Card(
              child: ListTile(
                title: Text(t.name),
                subtitle: Text('${formatDate(t.startDate)} – ${formatDate(t.endDate)}'),
                trailing: canEdit
                    ? IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editTerm(context, ref, term: t))
                    : null,
              ),
            ),
        ]),
      ),
    );
  }

  Future<void> _editTerm(BuildContext context, WidgetRef ref, {SchoolTerm? term}) async {
    final name = TextEditingController(text: term?.name);
    DateTimeRange? range = term == null ? null : DateTimeRange(start: term.startDate, end: term.endDate);
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(term == null ? 'Add term' : 'Edit term'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name, e.g. Term 1 2027')),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                final picked = await showDateRangePicker(
                    context: context, firstDate: DateTime(2025), lastDate: DateTime(2035), initialDateRange: range);
                if (picked != null) setState(() => range = picked);
              },
              child: Text(range == null ? 'Choose dates' : '${formatDate(range!.start)} – ${formatDate(range!.end)}'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            BusyButton(
              onPressed: () async {
                if (name.text.trim().isEmpty || range == null) return;
                final ok = await runAction(context,
                    () => ref.read(adminApiProvider).saveTerm(term?.id, name.text.trim(), range!.start, range!.end));
                if (ok && context.mounted) {
                  ref.invalidate(_termsProvider);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class AuditSection extends ConsumerWidget {
  const AuditSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const AdminHeader('Audit log'),
        Expanded(
          child: AdminPaged<AuditEntry>(
            fetch: (page) => ref.read(adminApiProvider).audit(page: page),
            itemBuilder: (a, _) => ListTile(
              dense: true,
              leading: const Icon(Icons.history, size: 20),
              title: Text('${a.actorName} · ${label(a.action)}'),
              subtitle: Text('${a.targetType} ${a.targetId ?? ''}${a.details != null ? ' — ${a.details}' : ''}'),
              trailing: Text(dateTime(a.createdAt)),
            ),
          ),
        ),
      ]),
    );
  }
}
