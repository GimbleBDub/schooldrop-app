import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/trip.dart';
import '../shared/account_menu.dart';
import '../shared/incident_sheet.dart';

final _kidTripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) => ref.watch(kidApiProvider).tripsToday());

/// Big, simple screen for a child: who's driving me, "I'm in the car", "I've arrived", SOS.
class KidHome extends ConsumerStatefulWidget {
  const KidHome({super.key});

  @override
  ConsumerState<KidHome> createState() => _KidHomeState();
}

class _KidHomeState extends ConsumerState<KidHome> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => ref.invalidate(_kidTripsProvider));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(sessionProvider).user?.firstName ?? '';
    final trips = ref.watch(_kidTripsProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Hi $name!'), actions: const [AccountMenu(), SizedBox(width: 8)]),
      body: AsyncBody<List<Trip>>(
        value: trips,
        onRetry: () => ref.invalidate(_kidTripsProvider),
        builder: (list) => RefreshableList(provider: _kidTripsProvider, children: [
          if (list.isEmpty)
            const EmptyState(icon: Icons.directions_bus_outlined, title: 'No rides today'),
          for (final trip in list)
            for (final p in trip.passengers)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(trip.toSchool ? 'Ride to school' : 'Ride home', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text('Driver: ${trip.driverName}', style: theme.textTheme.titleMedium),
                    Text('Look for: ${trip.vehicle}', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('Status: ${p.status.replaceAll('_', ' ').toLowerCase()}'),
                    const SizedBox(height: 16),
                    if (p.kidConfirmedPickupAt == null)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                        icon: const Icon(Icons.directions_car),
                        label: const Text("I'm in the car"),
                        onPressed: () => _confirm(p.id, pickup: true),
                      )
                    else
                      Text('✓ You said you were in the car at ${formatTime(p.kidConfirmedPickupAt)}'),
                    const SizedBox(height: 8),
                    if (p.kidConfirmedDropoffAt == null)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                        icon: const Icon(Icons.home_outlined),
                        label: Text(trip.toSchool ? "I've arrived at school" : "I'm home"),
                        onPressed: () => _confirm(p.id, pickup: false),
                      )
                    else
                      Text('✓ You arrived at ${formatTime(p.kidConfirmedDropoffAt)}'),
                  ]),
                ),
              ),
          const SizedBox(height: 24),
          SizedBox(
            height: 72,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
              icon: const Icon(Icons.sos, size: 32),
              label: const Text('I need help', style: TextStyle(fontSize: 20)),
              onPressed: () => showIncidentSheet(context,
                  sos: true, tripId: list.where((t) => t.inProgress).firstOrNull?.id),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Pressing this tells your parent and SchoolDrop straight away.',
              textAlign: TextAlign.center, style: TextStyle(color: AppTheme.navy)),
        ]),
      ),
    );
  }

  Future<void> _confirm(String passengerId, {required bool pickup}) async {
    await runAction(context, () => ref.read(kidApiProvider).confirm(passengerId, pickup: pickup),
        success: 'Thanks! Your parent can see it.');
    ref.invalidate(_kidTripsProvider);
  }
}
