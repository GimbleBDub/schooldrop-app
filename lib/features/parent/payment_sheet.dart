import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/booking.dart';

const paymentMethods = {
  'ORANGE_MONEY': ('Orange Money', Icons.phone_android),
  'MYZAKA': ('Mascom MyZaka', Icons.phone_android),
  'SMEGA': ('BTC Smega', Icons.phone_android),
  'CARD': ('Debit / credit card', Icons.credit_card),
};

typedef StartPayment = Future<Payment> Function(String method, String? payerPhone);

/// Pays a booking (bookingId), a once-off pickup (adHocId), or anything else via [start]
/// (a driver's monthly fee, an advert). Resolves true once the payment succeeded.
Future<bool> showPaymentSheet(BuildContext context,
    {String? bookingId, String? adHocId, StartPayment? start, String? title, required double amount}) async {
  final paid = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    builder: (_) => _PaymentSheet(bookingId: bookingId, adHocId: adHocId, start: start, title: title, amount: amount),
  );
  return paid ?? false;
}

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet({this.bookingId, this.adHocId, this.start, this.title, required this.amount});

  final String? bookingId;
  final String? adHocId;
  final StartPayment? start;
  final String? title;
  final double amount;

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  String _method = 'ORANGE_MONEY';
  late final _phone = TextEditingController(text: ref.read(sessionProvider).user?.phone ?? '');
  Payment? _payment;
  String? _error;
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _pay() async {
    final api = ref.read(parentApiProvider);
    final phone = _method == 'CARD' ? null : _phone.text.trim();
    try {
      final payment = widget.start != null
          ? await widget.start!(_method, phone)
          : widget.bookingId != null
              ? await api.payBooking(widget.bookingId!, _method, phone)
              : await api.payPickup(widget.adHocId!, _method, phone);
      setState(() {
        _payment = payment;
        _error = null;
      });
      if (_method == 'CARD' && !payment.isSandbox && payment.checkoutUrl != null) {
        await launchUrl(Uri.parse(payment.checkoutUrl!), mode: LaunchMode.externalApplication);
      }
      _startPolling();
    } on ApiException catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _startPolling() {
    var attempts = 0;
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (++attempts > 60) {
        timer.cancel();
        setState(() => _error = "We haven't heard back from the payment provider. Check your bookings in a few minutes.");
        return;
      }
      final payment = await ref.read(commonApiProvider).payment(_payment!.id);
      if (!mounted) return;
      setState(() => _payment = payment);
      if (payment.status == 'SUCCEEDED') {
        timer.cancel();
        Navigator.pop(context, true);
        showMessage(context, 'Payment received — thank you!');
      } else if (payment.status != 'PENDING') {
        timer.cancel();
        setState(() {
          _error = payment.failureReason ?? 'Payment ${payment.status.toLowerCase()}';
          _payment = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final waiting = _payment != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(widget.title ?? 'Pay ${money(widget.amount)}', style: theme.textTheme.titleLarge)),
          IconButton(onPressed: () => Navigator.pop(context, false), icon: const Icon(Icons.close)),
        ]),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ),
        const SizedBox(height: 12),
        if (!waiting) ...[
          for (final entry in paymentMethods.entries)
            RadioListTile<String>(
              value: entry.key,
              groupValue: _method,
              onChanged: (v) => setState(() => _method = v!),
              title: Text(entry.value.$1),
              secondary: Icon(entry.value.$2),
            ),
          if (_method != 'CARD') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile money number', helperText: 'e.g. +26771234567'),
            ),
          ],
          const SizedBox(height: 16),
          BusyButton(onPressed: _pay, icon: Icons.lock_outline, child: Text('Pay ${money(widget.amount)}')),
        ] else ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            _method == 'CARD'
                ? 'Complete the card payment in the page that opened.'
                : 'Approve the payment prompt on ${_phone.text}. This screen updates by itself.',
            textAlign: TextAlign.center,
          ),
          if (_payment!.isSandbox && AppConfig.isSandboxPayments) ...[
            const SizedBox(height: 16),
            Text('Test mode', textAlign: TextAlign.center, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => ref.read(commonApiProvider).completeSandbox(_payment!.providerReference!, false),
                  child: const Text('Simulate decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => ref.read(commonApiProvider).completeSandbox(_payment!.providerReference!, true),
                  child: const Text('Simulate success'),
                ),
              ),
            ]),
          ],
        ],
      ]),
    );
  }
}
