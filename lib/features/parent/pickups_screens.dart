import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/booking.dart';
import '../../models/child.dart';
import 'parent_providers.dart';
import 'payment_sheet.dart';

/// Once-off pickups: "I can't make it — can a verified driver collect my child today?"
class PickupsTab extends ConsumerWidget {
  const PickupsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pickups = ref.watch(pickupsProvider);
    return AsyncBody(
      value: pickups,
      onRetry: () => ref.invalidate(pickupsProvider),
      builder: (list) => list.isEmpty
          ? EmptyState(
              icon: Icons.bolt,
              title: "Can't make school pickup?",
              message: 'Request a once-off pickup and a verified driver from your school will collect your child.',
            )
          : Constrained(
              child: RefreshableList(provider: pickupsProvider, children: [
                for (final p in list) _PickupCard(request: p),
                const SizedBox(height: 72),
              ]),
            ),
    );
  }
}

Future<void> openPickupRequest(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PickupRequestScreen()));

class _PickupCard extends ConsumerWidget {
  const _PickupCard({required this.request});

  final AdHocRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final r = request;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(r.childName, style: theme.textTheme.titleMedium)),
            StatusChip(r.status),
          ]),
          const SizedBox(height: 8),
          InfoRow('From', r.schoolName),
          InfoRow('When', dateTime(r.pickupAt)),
          InfoRow('Drop off at', r.dropoffAddress),
          if (r.driverName != null) InfoRow('Driver', r.driverName),
          if (r.vehicle != null) InfoRow('Vehicle', r.vehicle),
          if (r.fare != null) InfoRow('Fare', money(r.fare)),
          if (r.status == 'OPEN')
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('Looking for a driver…')),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            if (r.status == 'ACCEPTED')
              FilledButton(
                onPressed: () async {
                  await showPaymentSheet(context, adHocId: r.id, amount: r.fare!);
                  refreshParentData(ref);
                },
                child: Text('Pay ${money(r.fare)} to confirm'),
              ),
            if (r.driverPhone != null && (r.status == 'ACCEPTED' || r.status == 'CONFIRMED'))
              OutlinedButton.icon(
                icon: const Icon(Icons.call),
                label: const Text('Call driver'),
                onPressed: () => launchUrl(Uri.parse('tel:${r.driverPhone}')),
              ),
            if (r.active)
              TextButton(
                onPressed: () async {
                  final late = r.status == 'CONFIRMED' && r.pickupAt.difference(DateTime.now()).inMinutes < 60;
                  if (!await confirmDialog(context, 'Cancel pickup?',
                      late ? 'Less than an hour to go — this is not refunded automatically.' : 'Any payment is refunded.',
                      confirm: 'Cancel pickup', destructive: true)) {
                    return;
                  }
                  if (!context.mounted) return;
                  await runAction(context, () => ref.read(parentApiProvider).cancelPickup(r.id), success: 'Cancelled');
                  refreshParentData(ref);
                },
                child: const Text('Cancel'),
              ),
          ]),
        ]),
      ),
    );
  }
}

class PickupRequestScreen extends ConsumerStatefulWidget {
  const PickupRequestScreen({super.key});

  @override
  ConsumerState<PickupRequestScreen> createState() => _PickupRequestScreenState();
}

class _PickupRequestScreenState extends ConsumerState<PickupRequestScreen> {
  final _form = GlobalKey<FormState>();
  Child? _child;
  DateTime? _when;
  final _address = TextEditingController();
  final _notes = TextEditingController();

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 7)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 14, minute: 0));
    if (time == null) return;
    setState(() => _when = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_child == null || _when == null) return showMessage(context, 'Choose a child and a time', error: true);
    final ok = await runAction(
      context,
      () => ref.read(parentApiProvider).requestPickup({
        'childId': _child!.id,
        'pickupAt': _when!.toUtc().toIso8601String(),
        'dropoffAddress': _address.text.trim(),
        'notes': _notes.text.trim(),
      }),
      success: "Request sent — we'll notify you when a driver accepts",
    );
    if (ok && mounted) {
      refreshParentData(ref);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Once-off pickup')),
      body: Constrained(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Verified drivers serving the school see your request with their fare. '
                'The first to accept gets it, then you pay to confirm. The school is told who will collect.'),
            const SizedBox(height: 16),
            AsyncBody(
              value: children,
              builder: (list) {
                final eligible = list.where((c) => c.canBook).toList();
                if (eligible.isEmpty) {
                  return const Text('None of your children has a confirmed school enrollment yet.');
                }
                return DropdownButtonFormField<Child>(
                  value: _child,
                  decoration: const InputDecoration(labelText: 'Child'),
                  items: [
                    for (final c in eligible) DropdownMenuItem(value: c, child: Text('${c.fullName} — ${c.schoolName}')),
                  ],
                  onChanged: (c) => setState(() => _child = c),
                );
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule),
              label: Text(_when == null ? 'Pickup date & time' : dateTime(_when)),
              onPressed: _pickWhen,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Drop off at'), validator: requiredField),
            const SizedBox(height: 12),
            TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
            const SizedBox(height: 24),
            BusyButton(onPressed: _submit, icon: Icons.send, child: const Text('Send request')),
          ]),
        ),
      ),
    );
  }
}
