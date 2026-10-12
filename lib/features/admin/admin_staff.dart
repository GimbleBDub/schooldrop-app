import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/admin.dart';

/// What each back-office permission unlocks. Order = how they're shown.
const staffPermissions = <({String id, String name, String description, IconData icon})>[
  (id: 'SUPER_ADMIN', name: 'Super admin', description: 'Everything, including staff, school terms and the audit log', icon: Icons.shield_rounded),
  (id: 'VERIFIER', name: 'Verification', description: 'Review drivers, documents and schools', icon: Icons.verified_user_outlined),
  (id: 'SUPPORT', name: 'Support', description: 'Users, bookings, incidents and live trips', icon: Icons.support_agent_rounded),
  (id: 'FINANCE', name: 'Finance', description: 'Payments, refunds, payouts, invoices and revenue', icon: Icons.account_balance_outlined),
  (id: 'MARKETING', name: 'Marketing', description: 'Review and run adverts', icon: Icons.campaign_outlined),
  (id: 'VIEWER', name: 'Read-only', description: 'See every area but change nothing (e.g. an accountant)', icon: Icons.visibility_outlined),
];

final _staffProvider = FutureProvider.autoDispose<List<AdminUser>>((ref) => ref.watch(adminApiProvider).staff());

/// Super admins add SchoolDrop staff and decide which parts of the back office each one can see and change.
class StaffSection extends ConsumerWidget {
  const StaffSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider).user;
    return Scaffold(
      body: AsyncBody<List<AdminUser>>(
        value: ref.watch(_staffProvider),
        onRetry: () => ref.invalidate(_staffProvider),
        builder: (staff) {
          final active = staff.where((s) => s.enabled).length;
          return ListView(padding: const EdgeInsets.all(24), children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 12,
              spacing: 12,
              children: [
                Text('$active active staff member${active == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.titleMedium),
                FilledButton.icon(
                  onPressed: () => _addStaff(context, ref),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Add staff member'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final s in staff) _StaffCard(staff: s, isMe: s.id == me?.id),
            const SizedBox(height: 24),
            const _PermissionGuide(),
          ]);
        },
      ),
    );
  }
}

class _StaffCard extends ConsumerWidget {
  const _StaffCard({required this.staff, required this.isMe});

  final AdminUser staff;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final api = ref.read(adminApiProvider);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: staff.enabled ? AppColors.brand : theme.colorScheme.outline,
              child: Text(staff.fullName.isEmpty ? '?' : staff.fullName[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(staff.fullName, style: const TextStyle(fontWeight: FontWeight.w700))),
                  if (isMe) ...[const SizedBox(width: 8), const StatusChip('YOU')],
                  const SizedBox(width: 8),
                  StatusChip(!staff.enabled
                      ? 'DISABLED'
                      : staff.passwordChangeRequired
                          ? 'AWAITING_FIRST_SIGN_IN'
                          : 'ACTIVE'),
                ]),
                Text([staff.email, if (staff.phone != null) staff.phone!, 'added ${formatDate(staff.createdAt)}'].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ]),
            ),
            if (!isMe)
              PopupMenuButton<String>(
                tooltip: 'More',
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'reset', child: Text('Reset password')),
                  PopupMenuItem(value: 'toggle', child: Text(staff.enabled ? 'Disable account' : 'Enable account')),
                ],
                onSelected: (v) async {
                  if (v == 'reset') {
                    if (!await confirmDialog(context, 'Reset ${staff.fullName}\'s password?',
                        'They\'ll be signed out everywhere and get a new temporary password to change on first sign-in.',
                        confirm: 'Reset')) {
                      return;
                    }
                    try {
                      final updated = await api.resetStaffPassword(staff.id);
                      if (context.mounted) await _showTemporaryPassword(context, updated);
                    } catch (e) {
                      if (context.mounted) showMessage(context, e.toString(), error: true);
                    }
                  } else if (staff.enabled) {
                    final reason = await askText(context, 'Disable ${staff.fullName}?', label: 'Reason (e.g. left SchoolDrop)', confirm: 'Disable');
                    if (reason == null || !context.mounted) return;
                    await runAction(context, () => api.setUserEnabled(staff.id, false, reason: reason),
                        success: '${staff.fullName} can no longer sign in');
                  } else {
                    await runAction(context, () => api.setUserEnabled(staff.id, true), success: '${staff.fullName} re-enabled');
                  }
                  ref.invalidate(_staffProvider);
                },
              ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in staffPermissions)
              FilterChip(
                avatar: Icon(p.icon, size: 16),
                label: Text(p.name),
                tooltip: p.description,
                selected: staff.staffPermissions.contains(p.id),
                // You can't take super admin away from yourself (someone must always be able to manage staff)
                onSelected: !staff.enabled
                    ? null
                    : (on) async {
                        if (isMe && p.id == 'SUPER_ADMIN') {
                          showMessage(context, "You can't remove your own super admin access — ask another super admin");
                          return;
                        }
                        final next = {...staff.staffPermissions};
                        on ? next.add(p.id) : next.remove(p.id);
                        if (next.isEmpty) {
                          showMessage(context, 'Keep at least one permission, or disable the account', error: true);
                          return;
                        }
                        await runAction(context, () => api.setPermissions(staff.id, next),
                            success: 'Permissions updated — ${staff.fullName} is signed out to apply them');
                        ref.invalidate(_staffProvider);
                      },
              ),
          ]),
        ]),
      ),
    );
  }
}

class _PermissionGuide extends StatelessWidget {
  const _PermissionGuide();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('What each permission allows', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final p in staffPermissions)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icon(p.icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                SizedBox(width: 120, child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(child: Text(p.description, style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
              ]),
            ),
          const SizedBox(height: 8),
          Text('Combine permissions as needed. New staff sign in with a temporary password and must choose their own first. '
              'Every change is recorded in the audit log.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

Future<void> _addStaff(BuildContext context, WidgetRef ref) async {
  final form = GlobalKey<FormState>();
  final first = TextEditingController();
  final last = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final selected = <String>{'SUPPORT'};
  final created = await showDialog<AdminUser>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Add staff member'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(
                      child: TextFormField(
                          controller: first, decoration: const InputDecoration(labelText: 'First name'), validator: requiredField)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextFormField(
                          controller: last, decoration: const InputDecoration(labelText: 'Last name'), validator: requiredField)),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Work email', prefixIcon: Icon(Icons.alternate_email_rounded)),
                  validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v?.trim() ?? '') ? null : 'Enter a valid email',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone (optional)', prefixIcon: Icon(Icons.phone_iphone_rounded)),
                ),
                const SizedBox(height: 20),
                Text('Access', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                for (final p in staffPermissions)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: selected.contains(p.id),
                    onChanged: (on) => setState(() => on! ? selected.add(p.id) : selected.remove(p.id)),
                    secondary: Icon(p.icon),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(p.description),
                  ),
                const SizedBox(height: 8),
                Text('A temporary password is generated for you to share privately. They choose their own on first sign-in.',
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          BusyButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              if (selected.isEmpty) {
                showMessage(context, 'Choose at least one permission', error: true);
                return;
              }
              try {
                final user = await ref.read(adminApiProvider).createStaff({
                  'firstName': first.text.trim(),
                  'lastName': last.text.trim(),
                  'email': email.text.trim(),
                  'phone': phone.text.trim().isEmpty ? null : phone.text.replaceAll(' ', ''),
                  'permissions': selected.toList(),
                });
                if (context.mounted) Navigator.pop(context, user);
              } catch (e) {
                if (context.mounted) showMessage(context, e.toString(), error: true);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );
  ref.invalidate(_staffProvider);
  if (created != null && context.mounted) await _showTemporaryPassword(context, created);
}

/// Shown once: the server never reveals it again.
Future<void> _showTemporaryPassword(BuildContext context, AdminUser staff) => showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        final password = staff.temporaryPassword ?? '';
        return AlertDialog(
          icon: const Icon(Icons.key_rounded, size: 32),
          title: Text('Temporary password for ${staff.fullName}'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Share it privately (not in a group chat). It\'s shown only once — '
                  '${staff.email} must replace it when they first sign in.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25)),
                ),
                child: SelectableText(password,
                    style: theme.textTheme.headlineSmall?.copyWith(fontFamily: 'monospace', letterSpacing: 2, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: password));
                showMessage(context, 'Copied');
              },
            ),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ],
        );
      },
    );
