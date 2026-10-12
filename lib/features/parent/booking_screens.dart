import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/booking.dart';
import '../../models/child.dart';
import '../../models/common.dart';
import '../../models/school.dart';
import 'parent_providers.dart';
import 'payment_sheet.dart';

const planLabels = {'MONTHLY': 'Monthly', 'TERMLY': 'Per term', 'PER_TRIP': 'Per trip'};
const coverageLabels = {'MORNING': 'Mornings only', 'AFTERNOON': 'Afternoons only', 'BOTH': 'Mornings & afternoons'};

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key, required this.child});

  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(offersForChildProvider(child.id));
    return Scaffold(
      appBar: AppBar(title: Text('Drivers for ${child.firstName}')),
      body: AsyncBody(
        value: offers,
        onRetry: () => ref.invalidate(offersForChildProvider(child.id)),
        builder: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.airport_shuttle_outlined,
                title: 'No drivers with free seats yet',
                message: 'No verified driver has seats at ${child.schoolName} right now. Check again soon.',
              )
            : Constrained(
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  Text('All drivers are verified by SchoolDrop: Omang, licence, police clearance and vehicle checks.',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  for (final offer in list) OfferCard(offer: offer, child: child),
                ]),
              ),
      ),
    );
  }
}

class OfferCard extends StatelessWidget {
  const OfferCard({super.key, required this.offer, this.child, this.onTap});

  final Offer offer;
  final Child? child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ??
            (child == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => BookingFormScreen(offer: offer, child: child!)))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(child: Text(offer.driverName.characters.first)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(offer.driverName, style: theme.textTheme.titleMedium),
                  if (offer.companyName != null)
                    Text(offer.companyName!,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                  Text('${offer.vehicle} · ${offer.vehiclePlate}', style: theme.textTheme.bodySmall),
                ]),
              ),
              if (offer.featured)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(6)),
                  child: Text('Featured',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onSecondaryContainer, fontWeight: FontWeight.w700)),
                ),
              const Icon(Icons.verified_rounded, color: Color(0xFF15803D)),
            ]),
            const SizedBox(height: 12),
            InfoRow('Covers', offer.serviceArea, icon: Icons.place_outlined),
            InfoRow('Runs', coverageLabels[offer.coverage], icon: Icons.schedule),
            if (offer.morningPickupTime != null)
              InfoRow('Morning pickup', 'around ${offer.morningPickupTime}', icon: Icons.wb_sunny_outlined),
            InfoRow('Seats free', '${offer.seatsAvailable} of ${offer.capacity}', icon: Icons.event_seat_outlined),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final plan in offer.plans)
                Chip(label: Text('${planLabels[plan]}: ${money(offer.priceFor(plan))}')),
              if (!offer.active) const Chip(label: Text('Paused')),
            ]),
          ]),
        ),
      ),
    );
  }
}

class BookingFormScreen extends ConsumerStatefulWidget {
  const BookingFormScreen({super.key, required this.offer, required this.child});

  final Offer offer;
  final Child child;

  @override
  ConsumerState<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends ConsumerState<BookingFormScreen> {
  final _form = GlobalKey<FormState>();
  late String _plan = widget.offer.plans.first;
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  SchoolTerm? _term;
  DateTimeRange? _range;
  final _address = TextEditingController();
  final _notes = TextEditingController();
  String _paymentMode = 'APP';

  int get _schoolDays {
    if (_range == null) return 0;
    var days = 0;
    for (var d = _range!.start; !d.isAfter(_range!.end); d = d.add(const Duration(days: 1))) {
      if (d.weekday <= 5) days++;
    }
    return days;
  }

  double? get _estimate {
    final price = widget.offer.priceFor(_plan);
    if (price == null) return null;
    if (_plan != 'PER_TRIP') return price;
    final legs = widget.offer.coverage == 'BOTH' ? 2 : 1;
    return price * _schoolDays * legs;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_plan == 'TERMLY' && _term == null) return showMessage(context, 'Choose a term', error: true);
    if (_plan == 'PER_TRIP' && _range == null) return showMessage(context, 'Choose the dates', error: true);

    Booking? booking;
    final ok = await runAction(context, () async {
      booking = await ref.read(parentApiProvider).book({
        'offerId': widget.offer.id,
        'childId': widget.child.id,
        'plan': _plan,
        if (_plan == 'MONTHLY') 'month': yearMonth(_month),
        if (_plan == 'TERMLY') 'termId': _term!.id,
        if (_plan == 'PER_TRIP') 'startDate': dateOrNull(_range!.start),
        if (_plan == 'PER_TRIP') 'endDate': dateOrNull(_range!.end),
        'pickupAddress': _address.text.trim(),
        'notes': _notes.text.trim(),
        'paymentMode': _paymentMode,
      });
    });
    if (!ok || !mounted) return;
    refreshParentData(ref);
    if (_paymentMode == 'OFFLINE') {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pay the driver directly'),
          content: Text('Pay ${widget.offer.driverName} ${money(booking!.amount)} by cash or EFT. '
              'When you have, tap "I\'ve paid the driver" in Bookings — the booking is confirmed once '
              '${widget.offer.driverName.split(' ').first} confirms they received it. Your seat is held for 48 hours.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))],
        ),
      );
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    final paid = await showPaymentSheet(context, bookingId: booking!.id, amount: booking!.amount);
    refreshParentData(ref);
    if (!mounted) return;
    if (!paid) {
      showMessage(context, 'Your seat is held for 30 minutes — pay from the Bookings tab to confirm.');
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final months = [for (var i = 0; i < 4; i++) DateTime(now.year, now.month + i)];
    return Scaffold(
      appBar: AppBar(title: Text('Book ${widget.offer.driverName}')),
      body: Constrained(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text('For ${widget.child.fullName} · ${widget.offer.schoolName}', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: [for (final p in widget.offer.plans) ButtonSegment(value: p, label: Text(planLabels[p]!))],
              selected: {_plan},
              onSelectionChanged: (s) => setState(() => _plan = s.first),
            ),
            const SizedBox(height: 16),
            if (_plan == 'MONTHLY')
              DropdownButtonFormField<DateTime>(
                value: _month,
                decoration: const InputDecoration(labelText: 'Month'),
                items: [for (final m in months) DropdownMenuItem(value: m, child: Text(monthName(m)))],
                onChanged: (m) => setState(() => _month = m!),
              ),
            if (_plan == 'TERMLY')
              Consumer(builder: (context, ref, _) {
                final terms = ref.watch(termsProvider);
                return AsyncBody(
                  value: terms,
                  builder: (list) => list.isEmpty
                      ? const Text('Term dates have not been published yet.')
                      : DropdownButtonFormField<SchoolTerm>(
                          value: _term,
                          decoration: const InputDecoration(labelText: 'Term'),
                          items: [
                            for (final t in list)
                              DropdownMenuItem(
                                  value: t,
                                  child: Text('${t.name} (${shortDate(t.startDate)} – ${shortDate(t.endDate)})')),
                          ],
                          onChanged: (t) => setState(() => _term = t),
                        ),
                );
              }),
            if (_plan == 'PER_TRIP')
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(_range == null
                    ? 'Choose dates (up to 31 days)'
                    : '${shortDate(_range!.start)} – ${shortDate(_range!.end)} · $_schoolDays school days'),
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(now.year, now.month, now.day),
                    lastDate: now.add(const Duration(days: 120)),
                  );
                  if (picked != null) setState(() => _range = picked);
                },
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(
                  labelText: 'Pickup address', helperText: 'Plot number, street, area — where the driver collects'),
              validator: requiredField,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes for the driver (optional)')),
            const SectionTitle('How will you pay?'),
            _PayOption(
              selected: _paymentMode == 'APP',
              icon: Icons.phone_android_rounded,
              title: 'Pay in the app',
              subtitle: 'Orange Money, MyZaka, Smega or card. Protected by SchoolDrop: refunds if you cancel before it starts.',
              onTap: () => setState(() => _paymentMode = 'APP'),
            ),
            const SizedBox(height: 8),
            _PayOption(
              selected: _paymentMode == 'OFFLINE',
              icon: Icons.payments_outlined,
              title: 'Pay the driver directly',
              subtitle: 'Cash or EFT. The driver confirms they received it; refunds are between you and the driver.',
              onTap: () => setState(() => _paymentMode = 'OFFLINE'),
            ),
            const SizedBox(height: 24),
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: ListTile(
                title: const Text('Total'),
                subtitle: _plan == 'MONTHLY' && _month.month == now.month
                    ? const Text('Full month price, even when booking mid-month')
                    : null,
                trailing: Text(money(_estimate), style: theme.textTheme.titleLarge),
              ),
            ),
            const SizedBox(height: 16),
            BusyButton(
                onPressed: _submit,
                icon: Icons.event_seat,
                child: Text(_paymentMode == 'APP' ? 'Book & pay' : 'Book')),
          ]),
        ),
      ),
    );
  }
}

class _PayOption extends StatelessWidget {
  const _PayOption({required this.selected, required this.icon, required this.title, required this.subtitle, required this.onTap});

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer.withValues(alpha: 0.5) : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(icon, color: selected ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
              ]),
            ),
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? scheme.primary : scheme.outline),
          ]),
        ),
      ),
    );
  }
}

class BookingsTab extends ConsumerWidget {
  const BookingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider);
    return AsyncBody(
      value: bookings,
      onRetry: () => ref.invalidate(bookingsProvider),
      builder: (list) => list.isEmpty
          ? const EmptyState(
              icon: Icons.event_seat_outlined,
              title: 'No bookings yet',
              message: 'Open a child and tap "Find transport".')
          : Constrained(
              child: RefreshableList(provider: bookingsProvider, children: [
                for (final b in list) _BookingCard(booking: b),
              ]),
            ),
    );
  }
}

class _BookingCard extends ConsumerWidget {
  const _BookingCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${booking.childName} → ${booking.schoolName}', style: theme.textTheme.titleMedium)),
            StatusChip(booking.status),
          ]),
          const SizedBox(height: 8),
          InfoRow('Driver', booking.driverName),
          InfoRow('Vehicle', booking.vehicle),
          InfoRow('Plan', [planLabels[booking.plan], if (booking.termName != null) booking.termName].join(' · ')),
          InfoRow('Dates', '${formatDate(booking.startDate)} – ${formatDate(booking.endDate)}'),
          InfoRow('Pickup', booking.pickupAddress),
          InfoRow('Amount', money(booking.amount)),
          if (booking.cancelReason != null) InfoRow('Cancelled', booking.cancelReason),
          InfoRow('Payment', booking.paysDriverDirectly ? 'Directly to the driver' : 'In the app'),
          if (booking.awaitingPayment && booking.holdExpiresAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  booking.paysDriverDirectly
                      ? (booking.offlinePaidClaimedAt != null
                          ? 'Waiting for ${booking.driverName.split(' ').first} to confirm your payment.'
                          : 'Pay ${booking.driverName.split(' ').first} ${money(booking.amount)} directly by ${dateTime(booking.holdExpiresAt)}.')
                      : 'Seat held until ${formatTime(booking.holdExpiresAt)} — pay to confirm.',
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            if (booking.awaitingPayment && booking.paysDriverDirectly && booking.offlinePaidClaimedAt == null)
              FilledButton(
                onPressed: () async {
                  await runAction(context, () => ref.read(parentApiProvider).claimPaidDriver(booking.id),
                      success: "We've asked the driver to confirm");
                  refreshParentData(ref);
                },
                child: const Text("I've paid the driver"),
              ),
            if (booking.awaitingPayment)
              (booking.paysDriverDirectly ? OutlinedButton.new : FilledButton.new)(
                onPressed: () async {
                  await showPaymentSheet(context, bookingId: booking.id, amount: booking.amount);
                  refreshParentData(ref);
                },
                child: Text(booking.paysDriverDirectly ? 'Pay in the app instead' : 'Pay now'),
              ),
            if (booking.driverPhone != null && booking.status == 'ACTIVE')
              OutlinedButton.icon(
                icon: const Icon(Icons.call),
                label: const Text('Call driver'),
                onPressed: () => launchUrl(Uri.parse('tel:${booking.driverPhone}')),
              ),
            if (booking.cancellable)
              TextButton(
                onPressed: () async {
                  final started = !DateTime.now().isBefore(booking.startDate);
                  final reason = await askText(context, 'Cancel booking?',
                      label: started
                          ? 'Reason (service has started — contact support about refunds)'
                          : 'Reason (you will be refunded in full)',
                      confirm: 'Cancel booking');
                  if (reason == null || !context.mounted) return;
                  await runAction(context, () => ref.read(parentApiProvider).cancelBooking(booking.id, reason),
                      success: 'Booking cancelled');
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

/// Re-exported so the parent home can show labels.
String planLabel(String plan) => planLabels[plan] ?? label(plan);
