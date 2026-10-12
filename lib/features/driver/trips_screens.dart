import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/trip.dart';
import '../shared/handover.dart';
import '../shared/incident_sheet.dart';
import 'driver_providers.dart';
import 'promo_widgets.dart';

class DriverTodayTab extends ConsumerWidget {
  const DriverTodayTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(driverTripsProvider);
    return AsyncBody(
      value: trips,
      onRetry: () => ref.invalidate(driverTripsProvider),
      builder: (list) => list.isEmpty
          ? const Constrained(
              child: Column(children: [
                Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 0), child: SubscriptionCard(onlyWhenAttentionNeeded: true)),
                Expanded(
                  child: EmptyState(
                      icon: Icons.free_breakfast_outlined,
                      title: 'No trips today',
                      message: 'Trips appear here on school days when children are booked with you.'),
                ),
              ]),
            )
          : Constrained(
              child: RefreshableList(provider: driverTripsProvider, children: [
                const SubscriptionCard(onlyWhenAttentionNeeded: true),
                for (final t in [...list]..sort((a, b) => (a.toSchool ? 0 : 1).compareTo(b.toSchool ? 0 : 1)))
                  Card(
                    child: ListTile(
                      leading: Icon(t.adHoc ? Icons.bolt : (t.toSchool ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined)),
                      title: Text(t.legLabel),
                      subtitle: Text('${t.schoolName} · ${t.passengers.length} '
                          '${t.passengers.length == 1 ? 'child' : 'children'}'),
                      trailing: StatusChip(t.status),
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => TripRunScreen(trip: t))),
                    ),
                  ),
              ]),
            ),
    );
  }
}

/// Runs one trip: start, share location, verify each pickup by QR, drop off, complete.
class TripRunScreen extends ConsumerStatefulWidget {
  const TripRunScreen({super.key, required this.trip});

  final Trip trip;

  @override
  ConsumerState<TripRunScreen> createState() => _TripRunScreenState();
}

class _TripRunScreenState extends ConsumerState<TripRunScreen> {
  late Trip _trip = widget.trip;
  StreamSubscription<Position>? _location;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  String? _locationIssue;

  DriverApi get _api => ref.read(driverApiProvider);

  @override
  void initState() {
    super.initState();
    if (_trip.inProgress) _shareLocation();
  }

  @override
  void dispose() {
    _location?.cancel();
    super.dispose();
  }

  Future<void> _shareLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() => _locationIssue = "Location is off — parents can't see where you are.");
      return;
    }
    _location = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 30),
    ).listen((position) {
      // At most every 15 seconds
      if (DateTime.now().difference(_lastSent).inSeconds < 15) return;
      _lastSent = DateTime.now();
      _api.sendLocation(_trip.id, position.latitude, position.longitude).catchError((_) {});
    }, onError: (_) => setState(() => _locationIssue = 'Could not read your location.'));
  }

  Future<void> _act(Future<Trip> Function() action, {String? success}) async {
    await runAction(context, () async {
      final updated = await action();
      if (mounted) setState(() => _trip = updated);
    }, success: success);
    ref.invalidate(driverTripsProvider);
  }

  Future<void> _pickup(Passenger p) async {
    if (!_trip.toSchool && p.pickupConfirmedAt == null &&
        !await confirmDialog(context, 'Collect ${p.firstName} without a school release?',
            "The school hasn't confirmed releasing ${p.firstName} to you. The family will be told.")) {
      return;
    }
    await _act(() => _api.pickup(_trip.id, p.id), success: '${p.firstName} picked up — the family has been asked to confirm');
  }

  Future<void> _dropoff(Passenger p) async {
    if (_trip.toSchool) {
      await _act(() => _api.dropoff(_trip.id, p.id), success: '${p.firstName} dropped at school');
      return;
    }
    final handedTo = await _askHandedTo(p);
    if (handedTo == null) return;
    await _act(() => _api.dropoff(_trip.id, p.id, handedTo: handedTo),
        success: '${p.firstName} dropped home — the family has been asked to confirm');
  }

  /// Who received the child at home. Quick choices plus free text (e.g. a helper's name).
  Future<String?> _askHandedTo(Passenger p) {
    final other = TextEditingController();
    const choices = ['Mother', 'Father', 'Guardian', 'Helper / nanny', 'Grandparent', 'Older sibling'];
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Who received ${p.firstName}?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('The family is notified and asked to confirm.'),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in choices) ActionChip(label: Text(c), onPressed: () => Navigator.pop(context, c)),
          ]),
          const SizedBox(height: 16),
          TextField(controller: other, decoration: const InputDecoration(labelText: 'Someone else (name)')),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              if (other.text.trim().isNotEmpty) Navigator.pop(context, other.text.trim());
            },
            child: const Text('Confirm drop-off'),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _trip;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.legLabel), actions: [
        IconButton(
          tooltip: 'Emergency',
          icon: Icon(Icons.sos, color: theme.colorScheme.error),
          onPressed: () => showIncidentSheet(context, tripId: t.id, sos: true),
        ),
      ]),
      body: Constrained(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            child: ListTile(
              title: Text(t.schoolName),
              subtitle: Text(t.vehicle),
              trailing: StatusChip(t.status),
            ),
          ),
          if (_locationIssue != null)
            Card(color: theme.colorScheme.errorContainer, child: ListTile(title: Text(_locationIssue!))),
          if (t.status == 'SCHEDULED')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: BusyButton(
                icon: Icons.play_arrow,
                onPressed: () async {
                  await _act(() => _api.startTrip(t.id), success: 'Trip started — parents are notified');
                  if (_trip.inProgress) _shareLocation();
                },
                child: const Text('Start trip'),
              ),
            ),
          const SectionTitle('Children'),
          for (final p in t.passengers)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(p.childName, style: theme.textTheme.titleMedium)),
                    StatusChip(p.status),
                  ]),
                  if (p.grade != null) Text(p.grade!),
                  if (p.address != null) InfoRow('Address', p.address, icon: Icons.home_outlined),
                  if (p.specialNeeds != null && p.specialNeeds!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.medical_information_outlined, size: 18),
                        const SizedBox(width: 6),
                        Expanded(child: Text(p.specialNeeds!)),
                      ]),
                    ),
                  const SizedBox(height: 10),
                  HandoverTimeline(passenger: p, toSchool: t.toSchool, compact: true),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (t.inProgress && p.status == 'EXPECTED') ...[
                      FilledButton.icon(
                          onPressed: () => _pickup(p), icon: const Icon(Icons.how_to_reg_rounded), label: const Text('Picked up')),
                      TextButton(
                          onPressed: () => _act(() => _api.absent(t.id, p.id)), child: const Text('Absent')),
                    ],
                    if (t.inProgress && p.status == 'PICKED_UP')
                      FilledButton.icon(
                        onPressed: () => _dropoff(p),
                        icon: const Icon(Icons.where_to_vote_rounded),
                        label: Text(t.toSchool ? 'Dropped at school' : 'Dropped home'),
                      ),
                    if (p.parentPhone != null)
                      IconButton(
                        tooltip: 'Call ${p.parentName}',
                        icon: const Icon(Icons.call),
                        onPressed: () => launchUrl(Uri.parse('tel:${p.parentPhone}')),
                      ),
                  ]),
                ]),
              ),
            ),
          if (t.inProgress)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: BusyButton(
                icon: Icons.flag,
                onPressed: () async {
                  await _act(() => _api.completeTrip(t.id), success: 'Trip complete');
                  if (!_trip.inProgress) await _location?.cancel();
                },
                child: const Text('Complete trip'),
              ),
            ),
        ]),
      ),
    );
  }
}
