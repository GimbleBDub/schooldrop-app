import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/family.dart';

final householdProvider = FutureProvider.autoDispose<Household>((ref) => ref.watch(parentApiProvider).household());

const familyRoles = {
  'OWNER': ('Account owner', 'Everything, including the family members'),
  'GUARDIAN': ('Guardian', 'e.g. a partner — children, bookings, payments and trips'),
  'HELPER': ('Helper', "e.g. a nanny — today's trips and confirming handovers only"),
};

/// The family behind a parent account: who can see trips and confirm handovers.
class FamilyTab extends ConsumerWidget {
  const FamilyTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(householdProvider);
    return AsyncBody<Household>(
      value: household,
      onRetry: () => ref.invalidate(householdProvider),
      builder: (h) {
        final owner = h.myRole == 'OWNER';
        return Constrained(
          child: RefreshableList(provider: householdProvider, children: [
            PageHeader(
              title: h.name,
              subtitle: 'Everyone here gets trip updates and can confirm when a child is handed over.',
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            ),
            for (final m in h.members)
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(m.name.characters.first.toUpperCase())),
                  title: Text(m.you ? '${m.name} (you)' : m.name),
                  subtitle: Text([familyRoles[m.role]?.$1 ?? m.role, if (m.phone != null) m.phone!].join(' · ')),
                  trailing: owner && m.role != 'OWNER'
                      ? IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.person_remove_outlined),
                          onPressed: () async {
                            if (!await confirmDialog(context, 'Remove ${m.name}?',
                                'They stop getting trip updates and are signed out straight away.',
                                confirm: 'Remove', destructive: true)) {
                              return;
                            }
                            if (!context.mounted) return;
                            await runAction(context, () => ref.read(parentApiProvider).removeFamilyMember(m.id));
                            ref.invalidate(householdProvider);
                          },
                        )
                      : null,
                ),
              ),
            if (owner) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _invite(context, ref),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add a family member'),
              ),
              if (h.invites.isNotEmpty) ...[
                const SectionTitle('Waiting to join'),
                for (final i in h.invites)
                  ListTile(
                    leading: const Icon(Icons.schedule_rounded),
                    title: Text(i.inviteeName ?? familyRoles[i.role]?.$1 ?? i.role),
                    subtitle: Text('${familyRoles[i.role]?.$1} · code expires ${shortDate(i.expiresAt)}'),
                    trailing: TextButton(
                      onPressed: () async {
                        await runAction(context, () => ref.read(parentApiProvider).revokeFamilyInvite(i.id));
                        ref.invalidate(householdProvider);
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
              ],
              const SectionTitle('Joining someone else\'s family?'),
              OutlinedButton.icon(
                onPressed: () => _join(context, ref),
                icon: const Icon(Icons.vpn_key_outlined),
                label: const Text('Enter an invite code'),
              ),
            ] else ...[
              const SizedBox(height: 16),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                onPressed: () async {
                  if (!await confirmDialog(context, 'Leave ${h.name}?', "You'll stop getting their trip updates.",
                      confirm: 'Leave', destructive: true)) {
                    return;
                  }
                  if (!context.mounted) return;
                  final ok = await runAction(context, () => ref.read(parentApiProvider).leaveFamily());
                  if (ok) await ref.read(sessionProvider.notifier).logout();
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Leave this family'),
              ),
            ],
          ]),
        );
      },
    );
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    var role = 'GUARDIAN';
    final name = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add a family member'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Their name (optional)')),
              const SizedBox(height: 12),
              for (final r in ['GUARDIAN', 'HELPER'])
                RadioListTile<String>(
                  value: r,
                  groupValue: role,
                  onChanged: (v) => setState(() => role = v!),
                  title: Text(familyRoles[r]!.$1),
                  subtitle: Text(familyRoles[r]!.$2),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Get invite code')),
          ],
        ),
      ),
    );
    if (go != true || !context.mounted) return;
    Invite? invite;
    final ok = await runAction(context,
        () async => invite = await ref.read(parentApiProvider).inviteFamilyMember(role, name.text.trim().isEmpty ? null : name.text.trim()));
    ref.invalidate(householdProvider);
    if (ok && context.mounted) await showInviteCode(context, invite!, who: 'your family');
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final code = await askText(context, 'Join a family', label: 'Invite code', confirm: 'Join');
    if (code == null || !context.mounted) return;
    final ok = await runAction(context, () => ref.read(parentApiProvider).joinFamily(code), success: 'You joined the family');
    if (ok) await ref.read(sessionProvider.notifier).refreshProfile();
  }
}

/// Shows a one-time invite code to share (e.g. on WhatsApp).
Future<void> showInviteCode(BuildContext context, Invite invite, {required String who}) {
  final theme = Theme.of(context);
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Share this code'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('They sign up on SchoolDrop, then choose "I have an invite code" to join $who.', textAlign: TextAlign.center),
        const SizedBox(height: 20),
        SelectableText(invite.code!,
            style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 6, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Works once, until ${shortDate(invite.expiresAt)}.', style: theme.textTheme.bodySmall),
      ]),
      actions: [
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: invite.code!));
            showMessage(context, 'Code copied');
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copy'),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    ),
  );
}
