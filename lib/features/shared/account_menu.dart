import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../account/account_screen.dart';
import '../account/billing_screen.dart';

/// Avatar menu: who is signed in, Profile, Settings, Billing, sign out.
class AccountMenu extends ConsumerWidget {
  const AccountMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    if (user == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      tooltip: 'Account',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      icon: CircleAvatar(
        radius: 17,
        backgroundColor: AppColors.brand,
        child: Text(user.initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 220),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.fullName, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurface)),
              Text(user.role == 'KID' ? user.roleDescription : user.email,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Text(user.roleDescription,
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'profile', child: ListTile(leading: Icon(Icons.person_outline_rounded), title: Text('Profile'))),
        const PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.settings_outlined), title: Text('Settings'))),
        if (user.hasBilling)
          PopupMenuItem(
            value: 'billing',
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(user.role == 'DRIVER' ? 'Earnings & billing' : 'Payments & receipts'),
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
            title: Text('Sign out', style: TextStyle(color: theme.colorScheme.error)),
          ),
        ),
      ],
      onSelected: (value) async {
        switch (value) {
          case 'profile':
            await openProfile(context);
          case 'settings':
            await openSettings(context);
          case 'billing':
            await openBilling(context);
          case 'logout':
            if (await confirmDialog(context, 'Sign out?', 'You will need to sign in again on this device.',
                confirm: 'Sign out')) {
              await ref.read(sessionProvider.notifier).logout();
            }
        }
      },
    );
  }
}
