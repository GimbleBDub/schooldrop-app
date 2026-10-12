import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/account.dart';

final _sessionsProvider = FutureProvider.autoDispose<List<DeviceSession>>((ref) async {
  final deviceId = await ref.read(sessionProvider.notifier).deviceId();
  return ref.watch(accountApiProvider).sessions(deviceId);
});

/// Where this account is signed in. Lost a phone? Sign it out from here.
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(_sessionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Signed-in devices')),
      body: AsyncBody<List<DeviceSession>>(
        value: sessions,
        onRetry: () => ref.invalidate(_sessionsProvider),
        builder: (list) {
          final others = list.where((s) => !s.current).toList();
          return ListView(padding: const EdgeInsets.all(16), children: [
            Constrained(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(
                  "If you don't recognise a device, sign it out and change your password.",
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    for (var i = 0; i < list.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 72),
                      _DeviceTile(session: list[i]),
                    ],
                  ]),
                ),
                if (others.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.logout_rounded),
                    label: Text('Sign out ${others.length} other device${others.length == 1 ? '' : 's'}'),
                    onPressed: () async {
                      if (!await confirmDialog(context, 'Sign out other devices?',
                          'Everywhere except this device will need to sign in again.',
                          confirm: 'Sign out')) {
                        return;
                      }
                      if (!context.mounted) return;
                      final deviceId = await ref.read(sessionProvider.notifier).deviceId();
                      if (!context.mounted) return;
                      await runAction(context, () => ref.read(accountApiProvider).signOutOthers(deviceId),
                          success: 'Other devices signed out');
                      ref.invalidate(_sessionsProvider);
                    },
                  ),
                ],
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

class _DeviceTile extends ConsumerWidget {
  const _DeviceTile({required this.session});

  final DeviceSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = session.deviceName.toLowerCase();
    final icon = name.contains('browser')
        ? Icons.language_rounded
        : name.contains('iphone') || name.contains('android') || name.contains('phone')
            ? Icons.smartphone_rounded
            : Icons.devices_other_rounded;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        child: Icon(icon, color: theme.colorScheme.primary),
      ),
      title: Row(children: [
        Flexible(child: Text(session.deviceName, style: const TextStyle(fontWeight: FontWeight.w600))),
        if (session.current) ...[const SizedBox(width: 8), const StatusChip('THIS_DEVICE')],
      ]),
      subtitle: Text('Signed in ${formatDate(session.signedInAt)} · active ${dateTime(session.lastActiveAt)}'),
      trailing: session.current
          ? null
          : TextButton(
              onPressed: () async {
                await runAction(context, () => ref.read(accountApiProvider).signOutSession(session.id),
                    success: '${session.deviceName} signed out');
                ref.invalidate(_sessionsProvider);
              },
              child: const Text('Sign out'),
            ),
    );
  }
}
