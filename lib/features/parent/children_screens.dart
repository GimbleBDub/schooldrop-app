import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/child.dart';
import '../../models/school.dart';
import '../shared/school_picker.dart';
import '../shared/sponsored_card.dart';
import 'booking_screens.dart';
import 'parent_providers.dart';

class ChildrenTab extends ConsumerWidget {
  const ChildrenTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenProvider);
    return AsyncBody(
      value: children,
      onRetry: () => ref.invalidate(childrenProvider),
      builder:
          (list) =>
              list.isEmpty
                  ? EmptyState(
                    icon: Icons.child_care,
                    title: 'Add your first child',
                    message:
                        'Link them to their school, then book a verified driver.',
                  )
                  : Constrained(
                    child: RefreshableList(
                      provider: childrenProvider,
                      children: [
                        for (final child in list) _ChildCard(child: child),
                        const SponsoredCard(),
                        const SizedBox(height: 72),
                      ],
                    ),
                  ),
    );
  }
}

Future<void> openChildForm(BuildContext context, {Child? child}) =>
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ChildFormScreen(child: child)));

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(child: Text(child.firstName.characters.first)),
        title: Text(child.fullName),
        subtitle: Text(
          [
            child.schoolName ?? 'No school yet',
            if (child.grade != null) child.grade!,
          ].join(' · '),
        ),
        trailing:
            child.enrollmentStatus == null
                ? null
                : StatusChip(child.enrollmentStatus!),
        onTap:
            () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChildDetailScreen(childId: child.id),
              ),
            ),
      ),
    );
  }
}

class ChildFormScreen extends ConsumerStatefulWidget {
  const ChildFormScreen({super.key, this.child});

  final Child? child;

  @override
  ConsumerState<ChildFormScreen> createState() => _ChildFormScreenState();
}

class _ChildFormScreenState extends ConsumerState<ChildFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _first = TextEditingController(text: widget.child?.firstName);
  late final _last = TextEditingController(text: widget.child?.lastName);
  late final _grade = TextEditingController(text: widget.child?.grade);
  late final _studentNumber = TextEditingController(
    text: widget.child?.studentNumber,
  );
  late final _specialNeeds = TextEditingController(
    text: widget.child?.specialNeeds,
  );
  late DateTime? _dob = widget.child?.dateOfBirth;
  late String? _schoolId = widget.child?.schoolId;
  late String? _schoolName = widget.child?.schoolName;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ok = await runAction(context, () async {
      await ref.read(parentApiProvider).saveChild(widget.child?.id, {
        'firstName': _first.text.trim(),
        'lastName': _last.text.trim(),
        'dateOfBirth': dateOrNull(_dob),
        'grade': _grade.text.trim(),
        'studentNumber': _studentNumber.text.trim(),
        'specialNeeds': _specialNeeds.text.trim(),
        'schoolId': _schoolId,
      });
    }, success: 'Saved');
    if (ok && mounted) {
      refreshParentData(ref);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final changingSchool =
        widget.child != null && widget.child!.schoolId != _schoolId;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.child == null
              ? 'Add child'
              : 'Edit ${widget.child!.firstName}',
        ),
      ),
      body: Constrained(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _first,
                decoration: const InputDecoration(labelText: 'First name'),
                validator: requiredField,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _last,
                decoration: const InputDecoration(labelText: 'Last name'),
                validator: requiredField,
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                leading: const Icon(Icons.cake_outlined),
                title: Text(
                  _dob == null ? 'Date of birth (optional)' : formatDate(_dob),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dob ?? DateTime(DateTime.now().year - 8),
                    firstDate: DateTime(DateTime.now().year - 20),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _dob = picked);
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                leading: const Icon(Icons.school_outlined),
                title: Text(_schoolName ?? 'Choose school'),
                subtitle:
                    changingSchool
                        ? const Text(
                          'The new school will need to confirm enrollment',
                        )
                        : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final School? school = await pickSchool(context);
                  if (school != null) {
                    setState(() {
                      _schoolId = school.id;
                      _schoolName = school.name;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _grade,
                decoration: const InputDecoration(
                  labelText: 'Grade / standard (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _studentNumber,
                decoration: const InputDecoration(
                  labelText: 'Student number (optional)',
                  helperText: 'Helps the school find your child quickly',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _specialNeeds,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Allergies, medical needs (optional)',
                  helperText:
                      'Shown to your driver so they can keep your child safe',
                ),
              ),
              const SizedBox(height: 24),
              BusyButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
  }
}

final _childProvider = FutureProvider.autoDispose.family<Child, String>(
  (ref, id) => ref.watch(parentApiProvider).child(id),
);

class ChildDetailScreen extends ConsumerWidget {
  const ChildDetailScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(_childProvider(childId));
    final helper = ref.watch(sessionProvider).user?.isHelper ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(child.value?.firstName ?? ''),
        actions: [
          if (child.value != null && !helper)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await openChildForm(context, child: child.value);
                ref.invalidate(_childProvider(childId));
              },
            ),
        ],
      ),
      body: AsyncBody(
        value: child,
        onRetry: () => ref.invalidate(_childProvider(childId)),
        builder:
            (c) => Constrained(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.fullName,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              if (c.enrollmentStatus != null)
                                StatusChip(c.enrollmentStatus!),
                            ],
                          ),
                          const SizedBox(height: 8),
                          InfoRow('School', c.schoolName),
                          InfoRow('Grade', c.grade),
                          InfoRow(
                            'Date of birth',
                            c.dateOfBirth == null
                                ? null
                                : formatDate(c.dateOfBirth),
                          ),
                          InfoRow('Special needs', c.specialNeeds),
                          if (c.enrollmentStatus == 'PENDING')
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Waiting for the school to confirm. You can book transport once they do.',
                              ),
                            ),
                          if (c.enrollmentStatus == 'REJECTED')
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'The school could not confirm: ${c.enrollmentNote ?? 'no reason given'}. '
                                'Check the details and choose the school again.',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (c.canBook && !helper) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.search),
                      label: const Text('Find transport'),
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => OffersScreen(child: c),
                            ),
                          ),
                    ),
                  ],
                  if (!helper) ...[
                    const SectionTitle("Child's phone"),
                    Card(
                      child: ListTile(
                        leading: Icon(
                          c.devicePaired
                              ? Icons.phone_android
                              : Icons.phonelink_off,
                        ),
                        title: Text(
                          c.devicePaired
                              ? 'Phone connected'
                              : 'No phone connected',
                        ),
                        subtitle: const Text(
                          'Lets your child confirm pickups and send an SOS',
                        ),
                        trailing:
                            c.devicePaired
                                ? TextButton(
                                  onPressed: () async {
                                    await runAction(
                                      context,
                                      () => ref
                                          .read(parentApiProvider)
                                          .unpair(c.id),
                                      success: 'Phone disconnected',
                                    );
                                    ref.invalidate(_childProvider(childId));
                                  },
                                  child: const Text('Disconnect'),
                                )
                                : FilledButton.tonal(
                                  onPressed:
                                      () => _showPairingCode(context, ref, c),
                                  child: const Text('Connect'),
                                ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (!helper)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: Text('Remove ${c.firstName}'),
                      onPressed: () async {
                        if (!await confirmDialog(
                          context,
                          'Remove ${c.firstName}?',
                          'Active bookings must be cancelled first. Trip history is kept for safety records.',
                          confirm: 'Remove',
                          destructive: true,
                        )) {
                          return;
                        }
                        if (!context.mounted) return;
                        final ok = await runAction(
                          context,
                          () => ref.read(parentApiProvider).removeChild(c.id),
                        );
                        if (ok && context.mounted) {
                          refreshParentData(ref);
                          Navigator.pop(context);
                        }
                      },
                    ),
                ],
              ),
            ),
      ),
    );
  }

  Future<void> _showPairingCode(
    BuildContext context,
    WidgetRef ref,
    Child child,
  ) async {
    PairingCode? code;
    final ok = await runAction(
      context,
      () async =>
          code = await ref.read(parentApiProvider).pairingCode(child.id),
    );
    if (!ok || !context.mounted) return;
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Connect ${child.firstName}'s phone"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "On your child's phone, open SchoolDrop, tap \"I'm a kid\" and enter:",
                ),
                const SizedBox(height: 16),
                SelectableText(
                  code!.code,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    letterSpacing: 6,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Valid until ${formatTime(code!.expiresAt)}. It works once.',
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  ref.invalidate(_childProvider(childId));
                },
                child: const Text('Done'),
              ),
            ],
          ),
    );
  }
}
