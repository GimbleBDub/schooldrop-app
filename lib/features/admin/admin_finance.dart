import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/billing.dart';
import '../account/billing_screen.dart' show DocumentTile;
import '../account/invoice_screen.dart';
import '../account/money_widgets.dart';
import 'admin_sections.dart' show AdminPaged;

final _financeProvider = FutureProvider.autoDispose.family<FinanceReport, int>(
    (ref, months) => ref.watch(adminApiProvider).finance(months: months));

/// What SchoolDrop makes: commission on in-app payments, driver listing fees and adverts — less refunds.
class FinanceSection extends ConsumerStatefulWidget {
  const FinanceSection({super.key});

  @override
  ConsumerState<FinanceSection> createState() => _FinanceSectionState();
}

class _FinanceSectionState extends ConsumerState<FinanceSection> {
  int _months = 12;

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(_financeProvider(_months));
    return Scaffold(
      body: AsyncBody<FinanceReport>(
        value: report,
        onRetry: () => ref.invalidate(_financeProvider(_months)),
        builder: (r) {
          final t = r.totals;
          final pct = r.commissionPercent.toStringAsFixed(r.commissionPercent % 1 == 0 ? 0 : 1);
          return ListView(padding: const EdgeInsets.all(24), children: [
            Row(children: [
              Expanded(
                child: Text('Last $_months months', style: Theme.of(context).textTheme.titleMedium),
              ),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 3, label: Text('3 mo')),
                  ButtonSegment(value: 12, label: Text('12 mo')),
                  ButtonSegment(value: 24, label: Text('24 mo')),
                ],
                selected: {_months},
                onSelectionChanged: (v) => setState(() => _months = v.first),
              ),
            ]),
            const SizedBox(height: 16),
            Wrap(spacing: 16, runSpacing: 16, children: [
              StatCard(label: 'SchoolDrop revenue', value: money(t.revenue), icon: Icons.trending_up_rounded, color: AppColors.success, highlight: true),
              StatCard(label: 'Commission ($pct% of in-app)', value: money(t.commission - t.refundedCommission), icon: Icons.percent_rounded),
              StatCard(label: 'Driver listing fees', value: money(t.listingFees), icon: Icons.badge_outlined),
              StatCard(label: 'Adverts', value: money(t.adverts), icon: Icons.campaign_outlined),
              StatCard(label: 'Collected in the app', value: money(t.collectedInApp), icon: Icons.payments_outlined, color: AppColors.brand),
              StatCard(label: 'Paid out to drivers', value: money(t.payoutsSent), icon: Icons.account_balance_outlined, color: AppColors.warning),
              StatCard(label: 'Refunded', value: money(t.refunded), icon: Icons.undo_rounded, color: AppColors.danger),
              StatCard(label: 'Paid to drivers directly', value: money(t.paidDirect), icon: Icons.handshake_outlined, color: AppColors.muted),
            ]),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Revenue by month', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  MonthBars(
                    height: 200,
                    months: [for (final m in r.months) m.month!],
                    parts: [
                      for (final m in r.months)
                        [
                          (value: (m.commission - m.refundedCommission).clamp(0, double.infinity).toDouble(), color: AppColors.brand),
                          (value: m.listingFees, color: AppColors.amber),
                          (value: m.adverts, color: AppColors.success),
                        ]
                    ],
                    legend: const [
                      (label: 'Commission', color: AppColors.brand),
                      (label: 'Listing fees', color: AppColors.amber),
                      (label: 'Adverts', color: AppColors.success),
                    ],
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.w700),
                  columns: const [
                    DataColumn(label: Text('Month')),
                    DataColumn(label: Text('Collected'), numeric: true),
                    DataColumn(label: Text('Commission'), numeric: true),
                    DataColumn(label: Text('Listing fees'), numeric: true),
                    DataColumn(label: Text('Adverts'), numeric: true),
                    DataColumn(label: Text('Refunded'), numeric: true),
                    DataColumn(label: Text('Revenue'), numeric: true),
                    DataColumn(label: Text('Paid out'), numeric: true),
                    DataColumn(label: Text('Direct'), numeric: true),
                  ],
                  rows: [
                    for (final m in r.months.reversed) _row(monthName(m.month!), m),
                    _row('Total', t, bold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Revenue = commission on in-app payments + listing fees + adverts − commission on refunded payments. '
              '"Direct" is cash/EFT families paid drivers themselves: no commission, shown for completeness.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ]);
        },
      ),
    );
  }

  DataRow _row(String label, FinanceMonth m, {bool bold = false}) {
    TextStyle s(Color? c) => TextStyle(fontWeight: bold ? FontWeight.w800 : null, color: c);
    return DataRow(cells: [
      DataCell(Text(label, style: s(null))),
      DataCell(Text(money(m.collectedInApp), style: s(null))),
      DataCell(Text(money(m.commission), style: s(null))),
      DataCell(Text(money(m.listingFees), style: s(null))),
      DataCell(Text(money(m.adverts), style: s(null))),
      DataCell(Text(m.refunded == 0 ? '—' : '−${money(m.refunded)}', style: s(m.refunded == 0 ? null : AppColors.danger))),
      DataCell(Text(money(m.revenue), style: s(AppColors.success).copyWith(fontWeight: FontWeight.w700))),
      DataCell(Text(money(m.payoutsSent), style: s(null))),
      DataCell(Text(money(m.paidDirect), style: s(AppColors.muted))),
    ]);
  }
}

/// Every receipt, invoice, credit note and payout statement, searchable by number, name or email.
class InvoicesSection extends ConsumerStatefulWidget {
  const InvoicesSection({super.key});

  @override
  ConsumerState<InvoicesSection> createState() => _InvoicesSectionState();
}

class _InvoicesSectionState extends ConsumerState<InvoicesSection> {
  String? _type;
  String _query = '';
  final _search = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded), hintText: 'Number, name or email', isDense: true),
                onSubmitted: (v) => setState(() => _query = v.trim()),
              ),
            ),
            Wrap(spacing: 6, children: [
              for (final (value, text) in [
                (null, 'All'),
                ('RECEIPT', 'Receipts'),
                ('INVOICE', 'Invoices'),
                ('CREDIT_NOTE', 'Credit notes'),
                ('STATEMENT', 'Payout statements'),
              ])
                ChoiceChip(label: Text(text), selected: _type == value, onSelected: (_) => setState(() => _type = value)),
            ]),
          ]),
        ),
        Expanded(
          child: AdminPaged<InvoiceSummary>(
            key: ValueKey('$_type|$_query'),
            empty: 'No documents found',
            fetch: (page) => ref.read(adminApiProvider).invoices(type: _type, query: _query, page: page),
            itemBuilder: (doc, _) => Card(
              clipBehavior: Clip.antiAlias,
              child: DocumentTile(doc: doc, showRecipient: true, onTap: () => openInvoice(context, doc.id, admin: true)),
            ),
          ),
        ),
      ]),
    );
  }
}
