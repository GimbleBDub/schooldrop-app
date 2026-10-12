import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/common.dart';
import '../../models/family.dart';
import '../parent/family_screen.dart' show showInviteCode;

final _staffProvider = FutureProvider.autoDispose<SchoolStaffList>((ref) => ref.watch(schoolApiProvider).staff());

const staffRoles = {
  'ADMIN': ('Admin', 'School profile, enrollments and staff, plus everything staff can do'),
  'STAFF': ('Staff', 'Teachers, gate, office: confirm arrivals and release children to drivers'),
};

/// Everyone at the school who can confirm handovers. Admins invite and remove people.
class StaffTab extends ConsumerWidget {
  const StaffTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(_staffProvider);
    return AsyncBody<SchoolStaffList>(
      value: staff,
      onRetry: () => ref.invalidate(_staffProvider),
      builder: (list) {
        final admin = list.myRole == 'ADMIN';
        return Constrained(
          maxWidth: 900,
          child: RefreshableList(provider: _staffProvider, children: [
            PageHeader(
              title: 'Staff',
              subtitle: 'Anyone here can release children to their authorised driver and confirm arrivals.',
              actions: [
                if (admin)
                  FilledButton.icon(
                    onPressed: () => _invite(context, ref),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Invite staff'),
                  ),
              ],
            ),
            for (final m in list.staff)
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(m.name.characters.first.toUpperCase())),
                  title: Text(m.you ? '${m.name} (you)' : m.name),
                  subtitle: Text([staffRoles[m.role]?.$1 ?? label(m.role), if (m.title != null) m.title!, m.email].join(' · ')),
                  trailing: admin && !m.you
                      ? IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.person_remove_outlined),
                          onPressed: () async {
                            if (!await confirmDialog(context, 'Remove ${m.name}?',
                                'They lose access to the school portal immediately.',
                                confirm: 'Remove', destructive: true)) {
                              return;
                            }
                            if (!context.mounted) return;
                            await runAction(context, () => ref.read(schoolApiProvider).removeStaff(m.id));
                            ref.invalidate(_staffProvider);
                          },
                        )
                      : null,
                ),
              ),
            if (admin && list.invites.isNotEmpty) ...[
              const SectionTitle('Waiting to join'),
              for (final i in list.invites)
                ListTile(
                  leading: const Icon(Icons.schedule_rounded),
                  title: Text(i.inviteeName ?? staffRoles[i.role]?.$1 ?? i.role),
                  subtitle: Text('${staffRoles[i.role]?.$1} · code expires ${shortDate(i.expiresAt)}'),
                  trailing: TextButton(
                    onPressed: () async {
                      await runAction(context, () => ref.read(schoolApiProvider).revokeStaffInvite(i.id));
                      ref.invalidate(_staffProvider);
                    },
                    child: const Text('Cancel'),
                  ),
                ),
            ],
          ]),
        );
      },
    );
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    var role = 'STAFF';
    final name = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Invite staff'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Their name (optional)')),
              const SizedBox(height: 12),
              for (final r in ['STAFF', 'ADMIN'])
                RadioListTile<String>(
                  value: r,
                  groupValue: role,
                  onChanged: (v) => setState(() => role = v!),
                  title: Text(staffRoles[r]!.$1),
                  subtitle: Text(staffRoles[r]!.$2),
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
        () async => invite = await ref.read(schoolApiProvider).inviteStaff(role, name.text.trim().isEmpty ? null : name.text.trim()));
    ref.invalidate(_staffProvider);
    if (ok && context.mounted) await showInviteCode(context, invite!, who: 'your school');
  }
}
