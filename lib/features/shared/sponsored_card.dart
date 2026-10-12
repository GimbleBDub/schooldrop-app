import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/api.dart';
import '../../models/promo.dart';

final _advertProvider = FutureProvider.autoDispose<Advert?>((ref) async {
  try {
    return await ref.watch(commonApiProvider).nextAdvert();
  } catch (_) {
    return null; // An advert must never break a screen
  }
});

/// Dismissed for this session (per app run).
final _dismissedProvider = NotifierProvider<_Dismissed, bool>(_Dismissed.new);

class _Dismissed extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

/// One clearly labelled sponsored card. Only for calm screens (parent home, children list, school portal) —
/// never on trip tracking, SOS, the gate list, or in the kid and driver apps.
class SponsoredCard extends ConsumerWidget {
  const SponsoredCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(_dismissedProvider)) return const SizedBox.shrink();
    final advert = ref.watch(_advertProvider).value;
    if (advert == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Future<void> open() async {
      ref.read(commonApiProvider).advertClicked(advert.id).ignore();
      final uri = advert.ctaUrl != null
          ? Uri.parse(advert.ctaUrl!)
          : advert.ctaPhone != null
              ? Uri.parse('tel:${advert.ctaPhone}')
              : null;
      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(6)),
              child: Text('Sponsored',
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(advert.advertiserName,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ),
            IconButton(
              tooltip: 'Hide',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 18, color: scheme.onSurfaceVariant),
              onPressed: () => ref.read(_dismissedProvider.notifier).dismiss(),
            ),
          ]),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(advert.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(advert.body, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              if (advert.ctaPhone != null || advert.ctaUrl != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: open,
                  icon: Icon(advert.ctaUrl != null ? Icons.open_in_new_rounded : Icons.call_rounded, size: 18),
                  label: Text(advert.ctaLabel ?? (advert.ctaUrl != null ? 'Learn more' : 'Call')),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
