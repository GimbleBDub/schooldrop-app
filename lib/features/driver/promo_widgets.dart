import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/promo.dart';
import '../parent/payment_sheet.dart';
import 'driver_providers.dart';

final subscriptionProvider = FutureProvider.autoDispose<Subscription>((ref) => ref.watch(driverApiProvider).subscription());
final myAdvertsProvider = FutureProvider.autoDispose<List<Advert>>((ref) => ref.watch(driverApiProvider).adverts());

/// The monthly listing fee. Prominent when unpaid (the driver is hidden from parents), quiet when paid.
class SubscriptionCard extends ConsumerWidget {
  const SubscriptionCard({super.key, this.onlyWhenAttentionNeeded = false});

  /// On the Today tab, only show when unpaid or about to run out.
  final bool onlyWhenAttentionNeeded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subscriptionProvider).value;
    if (sub == null) return const SizedBox.shrink();
    final dueSoon = sub.active && sub.daysLeft <= 5;
    if (onlyWhenAttentionNeeded && sub.active && !dueSoon) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final urgent = !sub.active;

    Future<void> pay() async {
      final paid = await showPaymentSheet(context,
          title: 'Monthly listing fee · ${money(sub.monthlyFee)}',
          amount: sub.monthlyFee,
          start: (method, phone) => ref.read(driverApiProvider).paySubscription(method, phone));
      if (paid) {
        ref.invalidate(subscriptionProvider);
        ref.invalidate(driverOffersProvider);
      }
    }

    return Card(
      color: urgent ? scheme.errorContainer : dueSoon ? scheme.secondaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(urgent ? Icons.visibility_off_rounded : Icons.verified_rounded,
              color: urgent ? scheme.onErrorContainer : const Color(0xFF15803D)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(urgent ? 'Parents can\'t find you yet' : dueSoon ? 'Your listing renews soon' : 'You\'re listed',
                  style: theme.textTheme.titleSmall),
              Text(
                !sub.canPay
                    ? (urgent
                        ? "${sub.teamName}'s listing fee isn't paid, so parents can't book the team. The owner pays it."
                        : '${sub.teamName} is listed until ${formatDate(sub.paidUntil)}.')
                    : urgent
                        ? 'Pay ${money(sub.monthlyFee)}/month${sub.drivers > 1 ? ' (${sub.drivers} drivers × ${money(sub.feePerDriver)})' : ''} to appear to parents and take bookings.'
                        : 'Paid until ${formatDate(sub.paidUntil)} · ${money(sub.monthlyFee)}/month'
                            '${sub.drivers > 1 ? ' for ${sub.drivers} drivers' : ''}',
                style: theme.textTheme.bodySmall,
              ),
            ]),
          ),
          if (!sub.canPay)
            const SizedBox.shrink()
          else if (urgent || dueSoon)
            FilledButton(onPressed: pay, child: Text(urgent ? 'Pay ${money(sub.monthlyFee)}' : 'Renew'))
          else
            TextButton(onPressed: pay, child: const Text('Pay ahead')),
        ]),
      ),
    );
  }
}

/// Drivers advertise to parents (and school staff) at the schools they serve. Reviewed before going live.
class PromoteSection extends ConsumerWidget {
  const PromoteSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adverts = ref.watch(myAdvertsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle('Promote yourself',
          trailing: TextButton.icon(
            onPressed: () => _create(context, ref),
            icon: const Icon(Icons.campaign_outlined, size: 18),
            label: const Text('New advert'),
          )),
      const Text('Your advert appears to parents at your schools, and your offers show as Featured. '
          'Every advert is checked by SchoolDrop before it goes live.'),
      const SizedBox(height: 8),
      AsyncBody<List<Advert>>(
        value: adverts,
        builder: (list) => Column(children: [
          for (final a in list)
            Card(
              child: ListTile(
                title: Text(a.title),
                subtitle: Text([
                  a.targetSchoolName ?? 'All my schools',
                  if (a.status == 'ACTIVE' && a.endsAt != null) 'until ${shortDate(a.endsAt)}',
                  if (a.status == 'ACTIVE' || a.status == 'EXPIRED') '${a.impressions} views · ${a.clicks} taps',
                  if (a.reviewNote != null && a.status == 'REJECTED') a.reviewNote!,
                ].join(' · ')),
                trailing: a.status == 'PENDING_PAYMENT'
                    ? FilledButton(onPressed: () => _pay(context, ref, a), child: Text('Pay ${money(a.price)}'))
                    : StatusChip(a.status),
              ),
            ),
        ]),
      ),
    ]);
  }

  Future<void> _pay(BuildContext context, WidgetRef ref, Advert a) async {
    await showPaymentSheet(context,
        title: 'Advert · ${money(a.price)}',
        amount: a.price ?? 0,
        start: (method, phone) => ref.read(driverApiProvider).payAdvert(a.id, method, phone));
    ref.invalidate(myAdvertsProvider);
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final profile = await ref.read(driverProfileProvider.future);
    if (!context.mounted) return;
    final title = TextEditingController();
    final body = TextEditingController();
    String? schoolId;
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New advert'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, maxLength: 80, decoration: const InputDecoration(labelText: 'Headline')),
              TextField(
                controller: body,
                maxLength: 280,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Message', helperText: 'e.g. "2 seats left from Phakalane, AC kombi"'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                value: schoolId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Show to parents at'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All my schools')),
                  for (final s in profile.schools) DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setState(() => schoolId = v),
              ),
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue to payment')),
          ],
        ),
      ),
    );
    if (go != true || !context.mounted) return;
    Advert? advert;
    final ok = await runAction(context, () async => advert = await ref.read(driverApiProvider).createAdvert({
          'title': title.text.trim(),
          'body': body.text.trim(),
          'targetSchoolId': schoolId,
        }));
    ref.invalidate(myAdvertsProvider);
    if (ok && context.mounted) await _pay(context, ref, advert!);
  }
}
