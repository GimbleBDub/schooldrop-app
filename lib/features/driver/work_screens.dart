import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../account/billing_screen.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/booking.dart';
import '../../models/driver.dart';
import '../parent/booking_screens.dart' show OfferCard, coverageLabels;
import 'driver_providers.dart';
import 'promo_widgets.dart';
import 'team_screen.dart' show teamProvider;

// ─── Offers ────────────────────────────────────────────────────────────────

class DriverOffersTab extends ConsumerWidget {
  const DriverOffersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(driverOffersProvider);
    final bookings = ref.watch(driverBookingsProvider);
    final profile = ref.watch(driverProfileProvider).value;
    final manages = profile?.managesRoutes ?? true;
    final inTeam = profile?.inTeam ?? false;
    return AsyncBody(
      value: offers,
      onRetry: () => ref.invalidate(driverOffersProvider),
      builder: (list) => Constrained(
        child: RefreshableList(provider: driverOffersProvider, children: [
          const SubscriptionCard(),
          if (list.isEmpty)
            EmptyState(
              icon: Icons.alt_route_outlined,
              title: !manages ? 'No routes yet' : inTeam ? 'Create your first route' : 'Create your first offer',
              message: !manages
                  ? 'Your team owner or manager assigns routes to you. They will show here.'
                  : 'Choose a school, a vehicle${inTeam ? ', the driver' : ''}, how many seats and the prices. Parents can then book.',
            ),
          for (final o in list)
            OfferCard(offer: o, onTap: manages ? () => openOfferForm(context, offer: o) : null),
          const SectionTitle('Passengers'),
          AsyncBody(
            value: bookings,
            builder: (bs) {
              final current = bs.where((b) => b.status == 'ACTIVE' || b.status == 'PENDING_PAYMENT').toList();
              if (current.isEmpty) return const Text('No current bookings.');
              return Column(children: [
                for (final b in current)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(children: [
                        ListTile(
                          leading: const Icon(Icons.child_care),
                          title: Text('${b.childName} · ${b.schoolName}'),
                          subtitle: Text('${b.pickupAddress}\n${formatDate(b.startDate)} – ${formatDate(b.endDate)}'
                              '${b.paysDriverDirectly ? ' · pays you directly (${money(b.amount)})' : ''}'),
                          isThreeLine: true,
                          trailing: StatusChip(b.status),
                          onTap: b.parentPhone == null ? null : () => launchUrl(Uri.parse('tel:${b.parentPhone}')),
                        ),
                        if (b.awaitingPayment && b.paysDriverDirectly)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Wrap(spacing: 8, children: [
                              FilledButton(
                                onPressed: () async {
                                  await runAction(context,
                                      () => ref.read(driverApiProvider).confirmDirectPayment(b.id, received: true),
                                      success: 'Booking confirmed');
                                  ref.invalidate(driverBookingsProvider);
                                },
                                child: Text('I received ${money(b.amount)}'),
                              ),
                              if (b.offlinePaidClaimedAt != null)
                                TextButton(
                                  onPressed: () async {
                                    await runAction(context,
                                        () => ref.read(driverApiProvider).confirmDirectPayment(b.id, received: false));
                                    ref.invalidate(driverBookingsProvider);
                                  },
                                  child: const Text('Not received'),
                                ),
                            ]),
                          ),
                      ]),
                    ),
                  ),
              ]);
            },
          ),
          if (profile?.ownsBusiness ?? true) const PromoteSection(),
          const SizedBox(height: 72),
        ]),
      ),
    );
  }
}

Future<void> openOfferForm(BuildContext context, {Offer? offer}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => OfferFormScreen(offer: offer)));

class OfferFormScreen extends ConsumerStatefulWidget {
  const OfferFormScreen({super.key, this.offer});

  final Offer? offer;

  @override
  ConsumerState<OfferFormScreen> createState() => _OfferFormScreenState();
}

class _OfferFormScreenState extends ConsumerState<OfferFormScreen> {
  final _form = GlobalKey<FormState>();
  late String? _schoolId = widget.offer?.schoolId;
  late String? _vehicleId = widget.offer?.vehicleId;
  late String _coverage = widget.offer?.coverage ?? 'BOTH';
  late bool _active = widget.offer?.active ?? true;
  late String? _driverId = widget.offer?.driverId;
  late final _capacity = TextEditingController(text: widget.offer?.capacity.toString());
  late final _area = TextEditingController(text: widget.offer?.serviceArea);
  late final _time = TextEditingController(text: widget.offer?.morningPickupTime);
  late final _trip = TextEditingController(text: widget.offer?.pricePerTrip?.toStringAsFixed(2));
  late final _month = TextEditingController(text: widget.offer?.pricePerMonth?.toStringAsFixed(2));
  late final _term = TextEditingController(text: widget.offer?.pricePerTerm?.toStringAsFixed(2));
  late final _adHoc = TextEditingController(text: widget.offer?.adHocFare?.toStringAsFixed(2));

  double? _num(TextEditingController c) => double.tryParse(c.text.trim());

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(driverProfileProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.offer == null ? 'New offer' : 'Edit offer')),
      body: AsyncBody<DriverProfile>(
        value: profile,
        builder: (p) => Constrained(
          child: Form(
            key: _form,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              DropdownButtonFormField<String>(
                value: _schoolId,
                decoration: const InputDecoration(labelText: 'School'),
                items: [for (final s in p.schools) DropdownMenuItem(value: s.id, child: Text(s.name))],
                onChanged: widget.offer == null ? (v) => setState(() => _schoolId = v) : null,
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _vehicleId,
                decoration: const InputDecoration(labelText: 'Vehicle', helperText: 'Only fully verified vehicles'),
                items: [
                  for (final v in p.vehicles.where((v) => v.active && v.verified))
                    DropdownMenuItem(value: v.id, child: Text('${v.displayName} · ${v.seatCapacity} seats')),
                ],
                onChanged: (v) => setState(() => _vehicleId = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              if (p.inTeam) ...[
                const SizedBox(height: 12),
                _DriverPicker(
                  value: _driverId ?? (p.drives ? p.id : null),
                  onChanged: (v) => setState(() => _driverId = v),
                ),
              ],
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [
                  for (final e in coverageLabels.entries) ButtonSegment(value: e.key, label: Text(e.value.split(' ').first)),
                ],
                selected: {_coverage},
                onSelectionChanged: (s) => setState(() => _coverage = s.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _capacity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Seats on this run'),
                validator: (v) => int.tryParse(v ?? '') == null ? 'Enter a number' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _area,
                decoration: const InputDecoration(labelText: 'Areas you collect from', helperText: 'e.g. Phakalane, Block 10, Tlokweng'),
                validator: requiredField,
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _time, decoration: const InputDecoration(labelText: 'Usual morning pickup time (HH:mm)')),
              const SectionTitle('Prices (leave blank for plans you don\'t offer)'),
              Row(children: [
                Expanded(child: TextFormField(controller: _month, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Per month (P)'))),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _term, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Per term (P)'))),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _trip, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Per trip (P)'))),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _adHoc,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Once-off pickup fare (P, optional)',
                    helperText: 'Set this to receive one-off pickup requests at this school'),
              ),
              SwitchListTile(
                  title: const Text('Taking bookings'), value: _active, onChanged: (v) => setState(() => _active = v)),
              const SizedBox(height: 16),
              BusyButton(
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  final ok = await runAction(context, () => ref.read(driverApiProvider).saveOffer(widget.offer?.id, {
                        'schoolId': _schoolId,
                        'vehicleId': _vehicleId,
                        'coverage': _coverage,
                        'capacity': int.parse(_capacity.text),
                        'serviceArea': _area.text.trim(),
                        'morningPickupTime': _time.text.trim().isEmpty ? null : _time.text.trim(),
                        'pricePerTrip': _num(_trip),
                        'pricePerMonth': _num(_month),
                        'pricePerTerm': _num(_term),
                        'adHocFare': _num(_adHoc),
                        'active': _active,
                        if (p.inTeam) 'driverId': _driverId ?? (p.drives ? p.id : null),
                      }), success: 'Saved');
                  if (ok && context.mounted) {
                    ref.invalidate(driverOffersProvider);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save offer'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Teams: which verified team driver runs the route. Changing it moves upcoming runs and tells the families.
class _DriverPicker extends ConsumerWidget {
  const _DriverPicker({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(teamProvider).value;
    final drivers = team?.members.where((m) => m.canDrive).toList() ?? const [];
    return DropdownButtonFormField<String>(
      value: drivers.any((d) => d.driverId == value) ? value : null,
      decoration: const InputDecoration(
        labelText: 'Driver',
        helperText: 'Only verified drivers in your team. Families are told if the driver changes.',
        prefixIcon: Icon(Icons.person_pin_circle_outlined),
      ),
      items: [
        for (final d in drivers) DropdownMenuItem(value: d.driverId, child: Text(d.you ? '${d.name} (you)' : d.name)),
      ],
      onChanged: onChanged,
      validator: (v) => v == null ? 'Choose who drives this route' : null,
    );
  }
}

// ─── Once-off pickups ─────────────────────────────────────────────────────

class DriverPickupsTab extends ConsumerWidget {
  const DriverPickupsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(openPickupsProvider);
    final mine = ref.watch(myPickupsProvider);
    void refresh() {
      ref.invalidate(openPickupsProvider);
      ref.invalidate(myPickupsProvider);
      ref.invalidate(driverTripsProvider);
    }

    return Constrained(
      child: RefreshableList(provider: openPickupsProvider, children: [
        const SectionTitle('Open requests near you'),
        AsyncBody<List<AdHocRequest>>(
          value: open,
          builder: (list) => list.isEmpty
              ? const Text('No open requests. Turn on once-off pickups and set a fare on your offers to get them.')
              : Column(children: [
                  for (final r in list)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.bolt),
                        title: Text('${r.schoolName} · ${dateTime(r.pickupAt)}'),
                        subtitle: Text('${r.childName}${r.childGrade != null ? ' (${r.childGrade})' : ''} → ${r.dropoffAddress}'),
                        trailing: FilledButton(
                          onPressed: () async {
                            await runAction(context, () => ref.read(driverApiProvider).acceptPickup(r.id),
                                success: 'Accepted — waiting for the parent to pay');
                            refresh();
                          },
                          child: Text('Accept ${money(r.fare)}'),
                        ),
                      ),
                    ),
                ]),
        ),
        const SectionTitle('My once-off pickups'),
        AsyncBody<List<AdHocRequest>>(
          value: mine,
          builder: (list) => list.isEmpty
              ? const Text('None yet.')
              : Column(children: [
                  for (final r in list)
                    Card(
                      child: ListTile(
                        title: Text('${r.childName} · ${dateTime(r.pickupAt)}'),
                        subtitle: Text('${r.schoolName} → ${r.dropoffAddress}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          StatusChip(r.status),
                          if (r.status == 'ACCEPTED' || r.status == 'CONFIRMED')
                            PopupMenuButton<String>(
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                    value: r.status == 'ACCEPTED' ? 'release' : 'cancel',
                                    child: Text(r.status == 'ACCEPTED' ? "I can't do it" : 'Cancel (parent refunded)')),
                              ],
                              onSelected: (action) async {
                                if (action == 'release') {
                                  await runAction(context, () => ref.read(driverApiProvider).releasePickup(r.id));
                                } else {
                                  final reason = await askText(context, 'Cancel confirmed pickup?');
                                  if (reason == null || !context.mounted) return;
                                  await runAction(context, () => ref.read(driverApiProvider).cancelPickup(r.id, reason));
                                }
                                refresh();
                              },
                            ),
                        ]),
                      ),
                    ),
                ]),
        ),
      ]),
    );
  }
}

// ─── Earnings ──────────────────────────────────────────────────────────────

/// Earnings, commission, payouts, statements and the fees paid to SchoolDrop.
class EarningsTab extends StatelessWidget {
  const EarningsTab({super.key});

  @override
  Widget build(BuildContext context) => const BillingView();
}
