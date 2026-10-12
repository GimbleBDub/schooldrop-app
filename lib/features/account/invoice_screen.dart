import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/billing.dart';
import '../../models/common.dart';

final _invoiceProvider = FutureProvider.autoDispose.family<InvoiceDetail, (String, bool)>((ref, key) {
  final (id, admin) = key;
  return admin ? ref.watch(adminApiProvider).invoice(id) : ref.watch(billingApiProvider).invoice(id);
});

Future<void> openInvoice(BuildContext context, String id, {bool admin = false}) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => InvoiceScreen(id: id, admin: admin)));

/// A receipt, invoice, credit note or payout statement, laid out like the PDF.
class InvoiceScreen extends ConsumerWidget {
  const InvoiceScreen({super.key, required this.id, this.admin = false});

  final String id;
  final bool admin;

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    try {
      final link = admin ? await ref.read(adminApiProvider).invoicePdfLink(id) : await ref.read(billingApiProvider).pdfLink(id);
      await launchUrl(link, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoice = ref.watch(_invoiceProvider((id, admin)));
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? null : const Color(0xFFEEF1F7),
      appBar: AppBar(
        title: Text(invoice.value?.number ?? 'Document'),
        actions: [
          if (invoice.hasValue)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: () => _download(context, ref),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('PDF'),
              ),
            ),
        ],
      ),
      body: AsyncBody<InvoiceDetail>(
        value: invoice,
        onRetry: () => ref.invalidate(_invoiceProvider((id, admin))),
        builder: (d) => ListView(padding: const EdgeInsets.all(16), children: [
          Constrained(maxWidth: 820, child: _Paper(d: d)),
        ]),
      ),
    );
  }
}

class _Paper extends StatelessWidget {
  const _Paper({required this.d});

  final InvoiceDetail d;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final wide = MediaQuery.of(context).size.width > 640;
    final statement = d.type == 'STATEMENT';
    final (badge, badgeColor) = switch (d.type) {
      'CREDIT_NOTE' => ('REFUNDED', theme.colorScheme.error),
      'STATEMENT' => ('PAID OUT', AppColors.success),
      _ => (d.paidDirectly ? 'PAID TO DRIVER' : 'PAID', AppColors.success),
    };

    final header = [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: 'School', style: TextStyle(color: theme.colorScheme.onSurface)),
          const TextSpan(text: 'Drop', style: TextStyle(color: AppColors.brand)),
        ]), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(d.issuerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        if (d.issuerAddress != null) Text(d.issuerAddress!, style: TextStyle(color: muted, fontSize: 13)),
        if (d.issuerRegistration != null) Text('Company reg. ${d.issuerRegistration}', style: TextStyle(color: muted, fontSize: 13)),
        if (d.issuerVatNumber != null) Text('VAT no. ${d.issuerVatNumber}', style: TextStyle(color: muted, fontSize: 13)),
      ]),
      Column(crossAxisAlignment: wide ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        Text(d.title.toUpperCase(), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: d.number));
            showMessage(context, 'Number copied');
          },
          child: Text(d.number, style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w700)),
        ),
        Text('Issued ${formatDate(d.issuedAt)}', style: TextStyle(color: muted, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
          ),
          child: Text(badge, style: TextStyle(color: badgeColor, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6)),
        ),
      ]),
    ];

    final parties = [
      _PartyBox(
        label: statement ? 'PAID TO' : 'BILLED TO',
        name: d.recipientName,
        lines: [if (d.recipientEmail != null) d.recipientEmail!, if (d.recipientPhone != null) d.recipientPhone!],
      ),
      _PartyBox(
        label: statement ? 'FROM' : d.type == 'RECEIPT' ? 'SERVICE BY' : 'SUPPLIER',
        name: d.supplierName,
        lines: [
          if (d.type == 'RECEIPT' && !d.paidDirectly) 'Collected by ${d.issuerName}',
          if (d.creditedInvoiceNumber != null) 'Credits ${d.creditedInvoiceNumber}',
        ],
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.colorScheme.outlineVariant)),
      child: Padding(
        padding: EdgeInsets.all(wide ? 40 : 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: header)
          else ...[header[0], const SizedBox(height: 20), header[1]],
          const SizedBox(height: 28),
          if (wide)
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: parties[0]),
                const SizedBox(width: 12),
                Expanded(child: parties[1]),
              ]),
            )
          else ...[parties[0], const SizedBox(height: 12), parties[1]],
          const SizedBox(height: 28),
          // Lines
          Row(children: [
            Expanded(child: Text('DESCRIPTION', style: _head(context))),
            SizedBox(width: 110, child: Text('AMOUNT', textAlign: TextAlign.right, style: _head(context))),
          ]),
          const Divider(height: 20),
          for (final l in d.lines) ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(l.description,
                    style: TextStyle(color: l.amount < 0 ? theme.colorScheme.error : null, height: 1.35)),
              ),
              SizedBox(
                width: 110,
                child: Text(l.amount < 0 ? '−${money(-l.amount)}' : money(l.amount),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.w600, color: l.amount < 0 ? theme.colorScheme.error : null)),
              ),
            ]),
            const Divider(height: 20),
          ],
          // Totals
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 320,
              child: Column(children: [
                if (statement) ...[
                  _TotalRow('Paid by families', money(d.subtotal)),
                  _TotalRow('SchoolDrop commission', '−${money(d.subtotal - d.total)}'),
                  if (d.tax > 0) _TotalRow('VAT included in commission', money(d.tax)),
                ] else if (d.tax > 0) ...[
                  _TotalRow('Amount excl. VAT', money(d.total - d.tax)),
                  _TotalRow('VAT (${d.vatPercent?.toStringAsFixed(0) ?? ''}%)', money(d.tax)),
                ],
                const Divider(height: 16),
                _TotalRow(
                  switch (d.type) {
                    'STATEMENT' => 'Sent to you',
                    'CREDIT_NOTE' => 'Refunded',
                    'RECEIPT' => d.paidDirectly ? 'Paid to driver' : 'Paid',
                    _ => 'Total paid',
                  },
                  money(d.total),
                  strong: true,
                ),
              ]),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PAYMENT DETAILS', style: _head(context)),
              const SizedBox(height: 8),
              if (d.paymentMethod != null)
                Text('Method: ${d.paidDirectly ? 'Cash or bank transfer, paid to the driver' : _method(d.paymentMethod!)}'),
              if (d.paidAt != null)
                Text('${switch (d.type) {
                  'CREDIT_NOTE' => 'Refunded',
                  'STATEMENT' => 'Sent',
                  _ => 'Paid',
                }}: ${dateTime(d.paidAt)}'),
              if (d.notes != null) ...[
                const SizedBox(height: 8),
                Text(d.notes!, style: TextStyle(color: muted)),
              ],
            ]),
          ),
          const SizedBox(height: 24),
          Text(
            'Questions about this document? Contact ${d.supportEmail} and quote ${d.number}. Amounts are in Botswana Pula (BWP).',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ]),
      ),
    );
  }

  static TextStyle? _head(BuildContext context) => Theme.of(context).textTheme.labelSmall?.copyWith(
      letterSpacing: 0.8, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant);

  static String _method(String m) => switch (m) {
        'ORANGE_MONEY' => 'Orange Money',
        'MYZAKA' => 'MyZaka',
        'SMEGA' => 'Smega',
        'CARD' => 'Card',
        'BANK_TRANSFER' => 'Bank transfer',
        _ => label(m),
      };
}

class _PartyBox extends StatelessWidget {
  const _PartyBox({required this.label, required this.name, required this.lines});

  final String label;
  final String name;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: _Paper._head(context)),
        const SizedBox(height: 6),
        Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        for (final l in lines) Text(l, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
      ]),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = strong
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
        : theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: strong ? style : const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
