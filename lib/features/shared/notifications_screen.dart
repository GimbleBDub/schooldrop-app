import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/common.dart';
import '../../models/user.dart';

final notificationsProvider = FutureProvider.autoDispose<PageResult<NotificationItem>>(
    (ref) => ref.watch(commonApiProvider).notifications());

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) => ref.watch(commonApiProvider).unreadCount());

/// Bell icon with unread badge that opens the inbox.
class NotificationsButton extends ConsumerWidget {
  const NotificationsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadCountProvider).value ?? 0;
    return IconButton(
      tooltip: 'Notifications',
      icon: Badge(isLabelVisible: count > 0, label: Text('$count'), child: const Icon(Icons.notifications_outlined)),
      onPressed: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
        ref.invalidate(unreadCountProvider);
      },
    );
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static IconData _icon(String type) => switch (type) {
        'TRIP' => Icons.directions_bus,
        'BOOKING' => Icons.event_seat,
        'PAYMENT' || 'PAYOUT' => Icons.payments_outlined,
        'SOS' => Icons.sos,
        'ADHOC' || 'ADHOC_REQUEST' || 'AUTHORISED_PICKUP' => Icons.bolt,
        'ENROLLMENT' => Icons.school,
        'DOCUMENT' || 'DRIVER_STATUS' || 'DRIVER_REVIEW' || 'DOCUMENT_REVIEW' => Icons.verified_user_outlined,
        'SECURITY' => Icons.shield_outlined,
        _ => Icons.notifications_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), actions: [
        TextButton(
          onPressed: () async {
            await runAction(context, () => ref.read(commonApiProvider).markAllRead());
            ref.invalidate(notificationsProvider);
          },
          child: const Text('Mark all read'),
        ),
      ]),
      body: AsyncBody(
        value: notifications,
        onRetry: () => ref.invalidate(notificationsProvider),
        builder: (page) => page.content.isEmpty
            ? const EmptyState(icon: Icons.notifications_none, title: 'Nothing yet')
            : Constrained(
                child: RefreshableList(
                  provider: notificationsProvider,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final n in page.content)
                      ListTile(
                        leading: Icon(_icon(n.type),
                            color: n.type == 'SOS' ? Theme.of(context).colorScheme.error : null),
                        title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold)),
                        subtitle: Text('${n.body}\n${dateTime(n.createdAt)}'),
                        isThreeLine: true,
                        onTap: n.read
                            ? null
                            : () async {
                                await ref.read(commonApiProvider).markRead(n.id);
                                ref.invalidate(notificationsProvider);
                              },
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
