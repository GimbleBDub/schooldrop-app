import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/billing.dart';
import 'invoice_screen.dart';
import 'money_widgets.dart';

final billingSummaryProvider = FutureProvider.autoDispose<BillingSummary>((ref) => ref.watch(billingApiProvider).summary());
final billingActivityProvider = FutureProvider.autoDispose<List<MoneyLine>>((ref) => ref.watch(billingApiProvider).transactions());
final billingDocumentsProvider =
    FutureProvider.autoDispose<List<InvoiceSummary>>((ref) => ref.watch(billingApiProvider).invoices());

Future<void> openBilling(BuildContext context) => Navigator.of(context, rootNavigator: true)
    .push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Billing')), body: const BillingView())));

/// Money in one place. Families: what they paid, refunds and receipts. Drivers: earnings after
/// SchoolDrop's commission, payouts, fees paid to SchoolDrop, statements and invoices.
class BillingView extends ConsumerStatefulWidget {
  const BillingView({super.key});

  @override
  ConsumerState<BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends ConsumerState<BillingView> {
  bool _documents = false;

  Future<void> _refresh() async {
    ref.invalidate(billingSummaryProvider);
    ref.invalidate(billingActivityProvider);
    ref.invalidate(billingDocumentsProvider);
    await ref.read(billingSummaryProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(billingSummaryProvider);
    return AsyncBody<BillingSummary>(
      value: summary,
      onRetry: _refresh,
      builder: (s) => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 48), children: [
          Constrained(
            maxWidth: 920,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (s.family != null) _FamilyOverview(f: s.family!),
              if (s.driver != null) _DriverOverview(d: s.driver!),
              const SizedBox(height: 28),
              Row(children: [
                Expanded(child: Text(_documents ? 'Documents' : 'Activity', style: Theme.of(context).textTheme.titleLarge)),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, icon: Icon(Icons.swap_vert_rounded, size: 18), label: Text('Activity')),
                    ButtonSegment(value: true, icon: Icon(Icons.description_outlined, size: 18), label: Text('Documents')),
                  ],
                  selected: {_documents},
                  onSelectionChanged: (v) => setState(() => _documents = v.first),
                ),
              ]),
              const SizedBox(height: 12),
              if (_documents) const _Documents() else _Activity(driver: s.driver != null),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Families ───────────────────────────────────────────────────────────────

class _FamilyOverview extends StatelessWidget {
  const _FamilyOverview({required this.f});

  final FamilyBilling f;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxChild = f.byChild.fold<double>(0, (a, b) => b.total > a ? b.total : a);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MoneyHero(
        label: 'Paid this month',
        amount: f.paidThisMonth,
        caption: 'Everything your family paid for transport, in the app or to drivers directly',
        stats: [
          (label: 'This year', value: money(f.paidThisYear)),
          (label: 'All time', value: money(f.paidAllTime)),
          (label: 'Paid to drivers directly', value: money(f.paidDirectAllTime)),
          (label: 'Refunded to you', value: money(f.refundedAllTime)),
        ],
      ),
      if (f.awaitingPaymentCount > 0) ...[
        const SizedBox(height: 12),
        _Notice(
          icon: Icons.schedule_rounded,
          color: AppColors.warning,
          text: '${f.awaitingPaymentCount} booking${f.awaitingPaymentCount == 1 ? ' is' : 's are'} waiting for payment '
              '(${money(f.awaitingPaymentAmount)}). Seats are only held for a short time — pay from Bookings.',
        ),
      ],
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, c) {
        final chart = _Panel(
          title: 'Last 12 months',
          child: MonthBars(
            months: [for (final m in f.months) m.month],
            parts: [
              for (final m in f.months)
                [(value: m.paidInApp, color: AppColors.brand), (value: m.paidDirect, color: AppColors.amber)]
            ],
            legend: const [(label: 'In the app', color: AppColors.brand), (label: 'To drivers directly', color: AppColors.amber)],
          ),
        );
        final children = _Panel(
          title: 'By child',
          child: f.byChild.isEmpty
              ? Text('Nothing paid yet.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
              : Column(children: [
                  for (final c in f.byChild)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                          Text(money(c.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: maxChild == 0 ? 0 : c.total / maxChild,
                            minHeight: 6,
                            backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                      ]),
                    ),
                ]),
        );
        if (c.maxWidth < 760) return Column(children: [chart, const SizedBox(height: 16), children]);
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: 3, child: chart),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: children),
          ]),
        );
      }),
    ]);
  }
}

// ─── Drivers ────────────────────────────────────────────────────────────────

class _DriverOverview extends StatelessWidget {
  const _DriverOverview({required this.d});

  final DriverBilling d;

  @override
  Widget build(BuildContext context) {
    final pct = d.commissionPercent == d.commissionPercent.roundToDouble()
        ? d.commissionPercent.toStringAsFixed(0)
        : d.commissionPercent.toString();
    final listed = d.listedUntil != null && !d.listedUntil!.isBefore(DateTime.now().subtract(const Duration(days: 1)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MoneyHero(
        label: 'Earned this month',
        amount: d.earnedThisMonth,
        caption: 'After SchoolDrop\'s $pct% commission, including money families paid you directly',
        stats: [
          (label: 'Ready for next payout', value: money(d.availableBalance)),
          (label: 'Upcoming (service not started)', value: money(d.upcomingBalance)),
          (label: 'Paid out to you', value: money(d.paidOutAllTime)),
          (label: 'This year', value: money(d.earnedThisYear)),
        ],
      ),
      const SizedBox(height: 12),
      _Notice(
        icon: listed ? Icons.verified_rounded : Icons.error_outline_rounded,
        color: listed ? AppColors.success : AppColors.warning,
        text: listed
            ? 'Listed until ${formatDate(d.listedUntil)}. Parents can find and book you.'
            : 'Your monthly listing fee isn\'t paid, so parents can\'t find you. Pay it from the Today tab.',
      ),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, c) {
        final chart = _Panel(
          title: 'Earnings, last 12 months',
          child: MonthBars(
            months: [for (final m in d.months) m.month],
            parts: [
              for (final m in d.months)
                [
                  (value: (m.net - m.paidDirect).clamp(0, double.infinity).toDouble(), color: AppColors.brand),
                  (value: m.paidDirect, color: AppColors.amber),
                ]
            ],
            legend: const [(label: 'Through the app', color: AppColors.brand), (label: 'Paid to you directly', color: AppColors.amber)],
          ),
        );
        final ledger = _Panel(
          title: 'How it adds up (all time)',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Ledger(
              rows: [
                (label: 'Families paid in the app', amount: d.grossAllTime, note: null),
                (label: 'SchoolDrop commission ($pct%)', amount: -d.commissionAllTime, note: 'Only on in-app payments'),
                if (d.refundedAllTime > 0) (label: 'Refunded to families', amount: -d.refundedAllTime, note: null),
                (label: 'Paid to you directly', amount: d.paidDirectAllTime, note: 'Cash / EFT — no commission'),
              ],
              totalLabel: 'Your earnings',
              total: d.netAllTime,
            ),
            const SizedBox(height: 18),
            Text('PAID TO SCHOOLDROP',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.8, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Ledger(
              rows: [
                (label: 'Monthly listing fees', amount: d.listingFeesAllTime, note: null),
                (label: 'Adverts', amount: d.advertsAllTime, note: null),
              ],
              totalLabel: 'Total',
              total: d.paidToSchoolDropAllTime,
            ),
          ]),
        );
        if (c.maxWidth < 760) return Column(children: [chart, const SizedBox(height: 16), ledger]);
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: 3, child: chart),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: ledger),
          ]),
        );
      }),
    ]);
  }
}

// ─── Lists ──────────────────────────────────────────────────────────────────

class _Activity extends ConsumerWidget {
  const _Activity({required this.driver});

  final bool driver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncBody<List<MoneyLine>>(
      value: ref.watch(billingActivityProvider),
      onRetry: () => ref.invalidate(billingActivityProvider),
      builder: (lines) {
        if (lines.isEmpty) {
          return EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No money moved yet',
            message: driver
                ? 'Payments from families, payouts and fees will show here.'
                : 'Payments and refunds will show here, each with a receipt.',
          );
        }
        // Grouped by month, newest first
        final groups = <String, List<MoneyLine>>{};
        for (final l in lines) {
          groups.putIfAbsent(monthName(l.date), () => []).add(l);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final g in groups.entries) ...[
            SectionTitle(g.key),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                for (var i = 0; i < g.value.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 68),
                  _MoneyTile(line: g.value[i]),
                ],
              ]),
            ),
          ],
        ]);
      },
    );
  }
}

class _MoneyTile extends StatelessWidget {
  const _MoneyTile({required this.line});

  final MoneyLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (IconData icon, Color color) = switch (line.kind) {
      'PAYMENT' => (line.paidDirectly ? Icons.handshake_outlined : Icons.north_east_rounded, AppColors.brand),
      'REFUND' => (Icons.undo_rounded, AppColors.success),
      'EARNING' => (line.paidDirectly ? Icons.handshake_outlined : Icons.south_west_rounded, AppColors.success),
      'EARNING_REFUNDED' => (Icons.undo_rounded, theme.colorScheme.error),
      'FEE' => (Icons.storefront_outlined, AppColors.brand),
      'PAYOUT' => (Icons.account_balance_outlined, AppColors.warning),
      _ => (Icons.payments_outlined, AppColors.muted),
    };
    final informational = line.kind == 'PAYOUT';
    final amountColor = informational
        ? theme.colorScheme.onSurfaceVariant
        : line.amount < 0
            ? theme.colorScheme.onSurface
            : AppColors.success;
    return InkWell(
      onTap: line.invoiceId == null ? null : () => openInvoice(context, line.invoiceId!),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          CircleAvatar(radius: 20, backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(line.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${line.subtitle} · ${shortDate(line.date)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              if (line.invoiceNumber != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.description_outlined, size: 13, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(line.invoiceNumber!,
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                  ]),
                ),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(informational ? money(line.amount) : (line.amount > 0 ? '+${money(line.amount)}' : signedMoney(line.amount)),
                style: TextStyle(fontWeight: FontWeight.w700, color: amountColor)),
            if (line.kind == 'PAYOUT' || line.status == 'REFUNDED') ...[
              const SizedBox(height: 4),
              StatusChip(line.status),
            ],
          ]),
        ]),
      ),
    );
  }
}

class _Documents extends ConsumerWidget {
  const _Documents();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncBody<List<InvoiceSummary>>(
      value: ref.watch(billingDocumentsProvider),
      onRetry: () => ref.invalidate(billingDocumentsProvider),
      builder: (docs) {
        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.description_outlined,
            title: 'No documents yet',
            message: 'Receipts, invoices, credit notes and payout statements appear here automatically.',
          );
        }
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < docs.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 68),
              DocumentTile(doc: docs[i], onTap: () => openInvoice(context, docs[i].id)),
            ],
          ]),
        );
      },
    );
  }
}

/// A receipt / invoice / credit note / statement in a list.
class DocumentTile extends StatelessWidget {
  const DocumentTile({super.key, required this.doc, required this.onTap, this.showRecipient = false});

  final InvoiceSummary doc;
  final VoidCallback onTap;
  final bool showRecipient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (IconData icon, Color color) = switch (doc.type) {
      'RECEIPT' => (Icons.receipt_long_outlined, AppColors.brand),
      'INVOICE' => (Icons.request_quote_outlined, AppColors.brandDark),
      'CREDIT_NOTE' => (Icons.undo_rounded, theme.colorScheme.error),
      _ => (Icons.account_balance_outlined, AppColors.success),
    };
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          CircleAvatar(radius: 20, backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(doc.number, style: const TextStyle(fontWeight: FontWeight.w700))),
                const SizedBox(width: 8),
                Text(doc.title, style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 2),
              Text(
                [if (showRecipient) doc.recipientName, doc.description, formatDate(doc.issuedAt)].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ]),
          ),
          Text(money(doc.total), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
        ]),
      ),
    );
  }
}

// ─── Small pieces ───────────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            child,
          ]),
        ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ]),
      );
}
