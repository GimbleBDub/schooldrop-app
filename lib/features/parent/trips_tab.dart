import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../models/trip.dart';
import '../../data/api.dart';
import '../shared/handover.dart';
import '../shared/incident_sheet.dart';
import '../shared/sponsored_card.dart';
import '../shared/trip_map.dart';
import 'parent_providers.dart';

/// Today's trips for the parent's children, refreshed every 15 seconds while visible.
class TodayTab extends ConsumerStatefulWidget {
  const TodayTab({super.key});

  @override
  ConsumerState<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends ConsumerState<TodayTab> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => ref.invalidate(parentTripsProvider));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(parentTripsProvider);
    return AsyncBody(
      value: trips,
      onRetry: () => ref.invalidate(parentTripsProvider),
      builder: (list) => list.isEmpty
          ? const Constrained(
              child: Column(children: [
                Expanded(
                  child: EmptyState(
                    icon: Icons.directions_bus_outlined,
                    title: 'No trips today',
                    message: "When your children ride today, you'll see every handover here, live.",
                  ),
                ),
                Padding(padding: EdgeInsets.all(16), child: SponsoredCard()),
              ]),
            )
          : Constrained(
              child: RefreshableList(provider: parentTripsProvider, children: [
                // Morning run first, then afternoon / once-off
                for (final trip in [...list]..sort((a, b) => (a.toSchool ? 0 : 1).compareTo(b.toSchool ? 0 : 1)))
                  ParentTripCard(trip: trip),
                // Below the trips, never between them
                const SponsoredCard(),
              ]),
            ),
    );
  }
}

class ParentTripCard extends StatelessWidget {
  const ParentTripCard({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(trip.legLabel, style: theme.textTheme.titleMedium)),
            StatusChip(trip.status),
          ]),
          const SizedBox(height: 4),
          Text('${trip.driverName} · ${trip.vehicle}', style: theme.textTheme.bodySmall),
          if (trip.inProgress && trip.lastLatitude != null) ...[
            const SizedBox(height: 12),
            TripMap(points: {trip.vehiclePlate: LatLng(trip.lastLatitude!, trip.lastLongitude!)}),
            Text('Updated ${formatTime(trip.lastLocationAt)}', style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 8),
          for (final p in trip.passengers) _FamilyHandover(trip: trip, passenger: p),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            if (trip.driverPhone != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.call),
                label: const Text('Call driver'),
                onPressed: () => launchUrl(Uri.parse('tel:${trip.driverPhone}')),
              ),
            TextButton.icon(
              icon: const Icon(Icons.report_outlined),
              label: const Text('Report a problem'),
              onPressed: () => showIncidentSheet(context, tripId: trip.id),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// The family's view of one child's handovers, with the confirmations that are theirs to give.
class _FamilyHandover extends ConsumerWidget {
  const _FamilyHandover({required this.trip, required this.passenger});

  final Trip trip;
  final Passenger passenger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = passenger;
    final name = p.firstName;
    // The family confirms the morning handover at home and the afternoon arrival at home
    final canConfirmHandedOver = trip.toSchool && p.pickupConfirmedAt == null && p.status != 'ABSENT' && trip.status != 'COMPLETED';
    final canConfirmHome = !trip.toSchool && p.droppedOffAt != null && p.dropoffConfirmedAt == null;

    Future<void> confirm(String stage) async {
      await runAction(context, () => ref.read(parentApiProvider).confirmHandover(p.id, stage), success: 'Thanks — confirmed');
      ref.invalidate(parentTripsProvider);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(p.childName, style: const TextStyle(fontWeight: FontWeight.w700))),
          StatusChip(p.status),
        ]),
        const SizedBox(height: 10),
        HandoverTimeline(passenger: p, toSchool: trip.toSchool),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (canConfirmHandedOver)
            FilledButton.icon(
              onPressed: () => confirm('PICKUP'),
              icon: const Icon(Icons.how_to_reg_rounded, size: 18),
              label: Text('I handed $name over'),
            ),
          if (canConfirmHome)
            FilledButton.icon(
              onPressed: () => confirm('DROPOFF'),
              icon: const Icon(Icons.home_rounded, size: 18),
              label: Text('$name is home'),
            ),
          if (p.disputedAt == null && (p.pickedUpAt != null || p.droppedOffAt != null))
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: () async {
                final reason = await askText(context, "Something's not right?",
                    label: 'What happened? SchoolDrop support is alerted immediately', confirm: 'Report');
                if (reason == null || !context.mounted) return;
                await runAction(context, () => ref.read(parentApiProvider).disputeHandover(p.id, reason),
                    success: 'Support has been alerted and will call you');
                ref.invalidate(parentTripsProvider);
              },
              icon: const Icon(Icons.report_outlined, size: 18),
              label: const Text('Not right'),
            ),
        ]),
      ]),
    );
  }
}
