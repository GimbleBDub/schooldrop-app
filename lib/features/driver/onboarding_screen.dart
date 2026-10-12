import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/common.dart';
import '../../core/session.dart';
import '../../models/driver.dart';
import '../parent/payment_sheet.dart' show paymentMethods;
import '../shared/school_picker.dart';
import 'driver_providers.dart';

const documentLabels = {
  'OMANG_FRONT': 'Omang — front',
  'OMANG_BACK': 'Omang — back',
  'DRIVERS_LICENCE': "Driver's licence",
  'POLICE_CLEARANCE': 'Police clearance certificate',
  'SELFIE': 'Selfie (clear photo of your face)',
  'PSV_PERMIT': 'PSV permit (if you have one)',
  'VEHICLE_REGISTRATION': 'Vehicle registration (blue book)',
  'ROADWORTHY_CERTIFICATE': 'Roadworthy certificate',
  'INSURANCE': 'Insurance certificate',
  'VEHICLE_PHOTO': 'Photo of the vehicle',
  'COMPANY_REGISTRATION': 'Company registration certificate (CIPA)',
};
const driverDocuments = ['OMANG_FRONT', 'OMANG_BACK', 'DRIVERS_LICENCE', 'POLICE_CLEARANCE', 'SELFIE', 'PSV_PERMIT'];
// Insurance isn't required in Botswana, so it isn't asked for
const vehicleDocuments = ['VEHICLE_REGISTRATION', 'ROADWORTHY_CERTIFICATE', 'VEHICLE_PHOTO'];

/// Getting verified. While the driver is still filling things in it's a step-by-step wizard; once submitted
/// (or approved) it's an overview of everything, where documents can be renewed — the "Profile" tab.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(driverProfileProvider);
    return AsyncBody(
      value: profile,
      onRetry: () => ref.invalidate(driverProfileProvider),
      builder: (p) => p.canSubmit ? _VerificationWizard(profile: p) : _ProfileOverview(profile: p),
    );
  }
}

/// The documents this person needs (team drivers no vehicle papers; non-drivers no licence; company owners CIPA).
List<String> personalDocumentsFor(DriverProfile p) => [
      for (final t in driverDocuments)
        if (p.drives || (t != 'DRIVERS_LICENCE' && t != 'PSV_PERMIT')) t,
      if (p.team?.kind == 'COMPANY' && p.team?.role == 'OWNER') 'COMPANY_REGISTRATION',
    ];

const _identityDocs = {'OMANG_FRONT', 'OMANG_BACK', 'SELFIE'};

// ─── Sections shared by the wizard and the overview ─────────────────────────

class _SchoolsSection extends ConsumerWidget {
  const _SchoolsSection({required this.profile});

  final DriverProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = profile;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(p.inTeam ? 'Choose every school your team drives children to.' : 'Choose the schools you can take children to.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final s in p.schools)
          InputChip(
            avatar: const Icon(Icons.school_outlined, size: 18),
            label: Text(s.name),
            onDeleted: () async {
              await runAction(context, () => ref.read(driverApiProvider)
                  .setSchools(p.schools.where((x) => x.id != s.id).map((x) => x.id).toList()));
              ref.invalidate(driverProfileProvider);
            },
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 18),
          label: const Text('Add a school'),
          onPressed: () async {
            final school = await pickSchool(context);
            if (school == null || !context.mounted) return;
            await runAction(context,
                () => ref.read(driverApiProvider).setSchools({...p.schools.map((s) => s.id), school.id}.toList()));
            ref.invalidate(driverProfileProvider);
          },
        ),
      ]),
    ]);
  }
}

class _VehiclesSection extends ConsumerWidget {
  const _VehiclesSection({required this.profile});

  final DriverProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = profile;
    if (!p.managesRoutes) {
      return Column(children: [
        for (final v in p.vehicles)
          ListTile(
            leading: const Icon(Icons.airport_shuttle_outlined),
            title: Text(v.displayName),
            subtitle: Text('${v.seatCapacity} seats'),
            trailing: v.verified ? const Icon(Icons.verified, color: Colors.green) : const StatusChip('PENDING'),
          ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
          p.inTeam
              ? 'Add the vehicles your drivers use, then upload each one\'s papers. Any driver in the team can be assigned to them.'
              : 'Add the vehicle you will use, then upload its papers (tap it to open).',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      for (final v in p.vehicles) _VehicleCard(vehicle: v, profile: p),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: Text(p.vehicles.isEmpty ? 'Add a vehicle' : 'Add another vehicle'),
          onPressed: () => _openVehicleForm(context, ref),
        ),
      ),
    ]);
  }
}

class _DocumentsSection extends StatelessWidget {
  const _DocumentsSection({required this.profile, required this.types, this.intro});

  final DriverProfile profile;
  final List<String> types;
  final String? intro;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (intro != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(intro!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        for (final type in types) _DocumentTile(type: type, profile: profile),
      ]);
}

class _SubmitBox extends ConsumerWidget {
  const _SubmitBox({required this.profile, this.onFix});

  final DriverProfile profile;

  /// Jumps to the step where a missing item is fixed (wizard only).
  final ValueChanged<String>? onFix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = profile;
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (p.missingRequirements.isEmpty)
        Text('Everything is in. A SchoolDrop verifier checks your documents, usually within 2 working days.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
      else ...[
        Text('Still needed:', style: theme.textTheme.titleSmall),
        for (final m in p.missingRequirements)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.error_outline, size: 20, color: theme.colorScheme.error),
            title: Text(m),
            trailing: onFix == null ? null : TextButton(onPressed: () => onFix!(m), child: const Text('Fix')),
            onTap: onFix == null ? null : () => onFix!(m),
          ),
      ],
      const SizedBox(height: 12),
      BusyButton(
        icon: Icons.send,
        onPressed: p.missingRequirements.isEmpty
            ? () async {
                await runAction(context, () => ref.read(driverApiProvider).submit(),
                    success: 'Submitted! A verifier will review your documents.');
                ref.invalidate(driverProfileProvider);
              }
            : null,
        child: const Text('Submit for verification'),
      ),
    ]);
  }
}

// ─── The wizard ─────────────────────────────────────────────────────────────

class _VerificationWizard extends ConsumerStatefulWidget {
  const _VerificationWizard({required this.profile});

  final DriverProfile profile;

  @override
  ConsumerState<_VerificationWizard> createState() => _VerificationWizardState();
}

class _VerificationWizardState extends ConsumerState<_VerificationWizard> {
  int? _step;

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final missing = p.missingRequirements.map((m) => m.toLowerCase()).toList();
    bool none(List<String> words) => !missing.any((m) => words.any(m.contains));
    final docs = personalDocumentsFor(p);
    final identity = docs.where(_identityDocs.contains).toList();
    final other = docs.where((t) => !_identityDocs.contains(t)).toList();

    // Titles in order, so a "Still needed" item can jump to its step
    final stepTitles = [
      'About you',
      if (p.managesRoutes) 'schools',
      if (p.managesRoutes) 'vehicles',
      'identity',
      'licence',
      'submit',
    ];
    final steps = <({String title, String subtitle, bool done, Widget body})>[
      (
        title: 'About you',
        subtitle: 'Identity${p.ownsBusiness ? ' and payouts' : ''}',
        done: none(['omang number', 'date of birth', 'licence number', 'licence code', 'payout account']),
        body: _DetailsCard(profile: p),
      ),
      if (p.managesRoutes)
        (
          title: p.inTeam ? 'Team schools' : 'Schools',
          subtitle: '${p.schools.length} chosen',
          done: p.schools.isNotEmpty,
          body: _SchoolsSection(profile: p),
        ),
      if (p.managesRoutes)
        (
          title: p.inTeam ? 'Fleet vehicles' : 'Your vehicle',
          subtitle: '${p.vehicles.where((v) => v.active).length} added',
          done: p.vehicles.any((v) => v.active) && none([' for ', 'vehicle']),
          body: _VehiclesSection(profile: p),
        ),
      (
        title: 'Identity check',
        subtitle: 'Omang and a selfie',
        done: none(identity.map((t) => documentLabels[t]!.toLowerCase().split(' (').first).toList()) &&
            none(['omang (', 'selfie']),
        body: _DocumentsSection(
          profile: p,
          types: identity,
          intro: 'Take clear photos with your camera. Your selfie is compared with your Omang photo by our verification team.',
        ),
      ),
      (
        title: p.drives ? 'Licence & clearance' : 'Police clearance',
        subtitle: p.drives ? 'Driver\'s licence and police clearance' : 'Needed because you can see children\'s details',
        done: none(['licence', 'police', 'company registration', 'psv']),
        body: _DocumentsSection(
          profile: p,
          types: other,
          intro: 'Police clearance must be from the last 90 days. Photos or PDFs are fine.',
        ),
      ),
      (
        title: 'Submit',
        subtitle: 'Send for verification',
        done: false,
        body: _SubmitBox(profile: p, onFix: (m) => setState(() => _step = _stepFor(m, stepTitles))),
      ),
    ];
    // Start at the first unfinished step
    final current = (_step ?? steps.indexWhere((s) => !s.done)).clamp(0, steps.length - 1);

    return Constrained(
      child: RefreshableList(provider: driverProfileProvider, children: [
        _StatusBanner(profile: p),
        _TeamBanner(profile: p),
        const SizedBox(height: 8),
        _WizardProgress(done: steps.where((s) => s.done).length, total: steps.length - 1),
        Stepper(
          physics: const NeverScrollableScrollPhysics(),
          currentStep: current,
          onStepTapped: (i) => setState(() => _step = i),
          onStepContinue: current < steps.length - 1 ? () => setState(() => _step = current + 1) : null,
          onStepCancel: current > 0 ? () => setState(() => _step = current - 1) : null,
          controlsBuilder: (context, details) => current == steps.length - 1
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(children: [
                    FilledButton(onPressed: details.onStepContinue, child: const Text('Next')),
                    if (details.onStepCancel != null) ...[
                      const SizedBox(width: 8),
                      TextButton(onPressed: details.onStepCancel, child: const Text('Back')),
                    ],
                  ]),
                ),
          steps: [
            for (var i = 0; i < steps.length; i++)
              Step(
                title: Text(steps[i].title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(steps[i].done ? 'Done' : steps[i].subtitle),
                state: steps[i].done ? StepState.complete : (i == current ? StepState.editing : StepState.indexed),
                isActive: i == current || steps[i].done,
                content: Align(alignment: Alignment.centerLeft, child: steps[i].body),
              ),
          ],
        ),
        const SizedBox(height: 32),
      ]),
    );
  }
}

/// Which wizard step fixes a "Still needed" item.
int _stepFor(String missing, List<String> titles) {
  final m = missing.toLowerCase();
  String key;
  if (m.contains(' for ') || m.contains('vehicle')) {
    key = 'vehicles';
  } else if (m.contains('school')) {
    key = 'schools';
  } else if (m.contains('omang (') || m.contains('selfie')) {
    key = 'identity';
  } else if (m.contains("licence") && !m.contains('number') && !m.contains('code') || m.contains('police') ||
      m.contains('company') || m.contains('psv')) {
    key = 'licence';
  } else {
    key = 'About you';
  }
  final i = titles.indexOf(key);
  return i < 0 ? 0 : i;
}

class _WizardProgress extends StatelessWidget {
  const _WizardProgress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$done of $total steps done', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: total == 0 ? 0 : done / total, minHeight: 6),
        ),
      ]),
    );
  }
}

// ─── After submitting: the overview ─────────────────────────────────────────

class _ProfileOverview extends ConsumerWidget {
  const _ProfileOverview({required this.profile});

  final DriverProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = profile;
    return Constrained(
      child: RefreshableList(provider: driverProfileProvider, children: [
        _StatusBanner(profile: p),
        _TeamBanner(profile: p),
        const SectionTitle('Your details'),
        _DetailsCard(profile: p),
        if (p.managesRoutes) ...[
          SectionTitle(p.inTeam ? 'Schools your team serves' : 'Schools you serve'),
          _SchoolsSection(profile: p),
        ],
        if (p.vehicles.isNotEmpty || p.managesRoutes) ...[
          SectionTitle(p.inTeam ? (p.managesRoutes ? 'Fleet vehicles' : 'Team vehicles') : 'Vehicles'),
          _VehiclesSection(profile: p),
        ],
        const SectionTitle('Your documents'),
        _DocumentsSection(
          profile: p,
          types: personalDocumentsFor(p),
          intro: 'Upload a renewed document before the old one expires to keep taking bookings.',
        ),
        if (p.missingRequirements.isNotEmpty) ...[
          const SectionTitle('Needs attention'),
          for (final m in p.missingRequirements)
            ListTile(dense: true, leading: const Icon(Icons.error_outline, size: 20), title: Text(m)),
        ],
        const SizedBox(height: 32),
      ]),
    );
  }
}

/// Team membership, or (for drivers on their own) a way to start or join a team.
class _TeamBanner extends ConsumerWidget {
  const _TeamBanner({required this.profile});

  final DriverProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = profile.team;
    final theme = Theme.of(context);
    if (team != null) {
      final role = switch (team.role) { 'OWNER' => 'You own', 'MANAGER' => 'You manage for', _ => 'You drive for' };
      return Card(
        child: ListTile(
          leading: const Icon(Icons.groups_2_outlined),
          title: Text('$role ${team.name}'),
          subtitle: Text(team.role == 'OWNER'
              ? (team.kind == 'COMPANY' ? 'Registered company' : 'Team') + (profile.drives ? ' · you also drive' : " · you don't drive")
              : 'Run by ${team.ownerName}. Payouts and the listing fee go through them.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Work with other drivers?', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('Start a team or company to add drivers and share vehicles, or join one with an invite code. '
              'Your vehicles and routes come with you.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.add_business_outlined, size: 18),
              label: const Text('Start a team'),
              onPressed: () => startTeam(context, ref),
            ),
            TextButton.icon(
              icon: const Icon(Icons.vpn_key_outlined, size: 18),
              label: const Text('I have a code'),
              onPressed: () async {
                final code = await askText(context, 'Join a team', label: 'Invite code', confirm: 'Join');
                if (code == null || !context.mounted) return;
                final ok = await runAction(context, () => ref.read(driverApiProvider).joinTeam(code),
                    success: 'You joined the team. Your future earnings go to the team.');
                if (ok) await refreshDriver(ref);
              },
            ),
          ]),
        ]),
      ),
    );
  }
}

/// After joining / starting a team: the session (role label, tabs) and every driver screen change.
Future<void> refreshDriver(WidgetRef ref) async {
  ref.invalidate(driverProfileProvider);
  ref.invalidate(driverOffersProvider);
  ref.invalidate(driverBookingsProvider);
  await ref.read(sessionProvider.notifier).refreshProfile();
}

Future<void> startTeam(BuildContext context, WidgetRef ref) async {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final reg = TextEditingController();
  var kind = 'COMPANY';
  var drives = true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Start a team or company'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Name'), validator: requiredField),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'COMPANY', label: Text('Registered company')),
                  ButtonSegment(value: 'TEAM', label: Text('Informal team')),
                ],
                selected: {kind},
                onSelectionChanged: (s) => setState(() => kind = s.first),
              ),
              if (kind == 'COMPANY') ...[
                const SizedBox(height: 12),
                TextFormField(controller: reg, decoration: const InputDecoration(labelText: 'CIPA registration number'),
                    validator: requiredField),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('I also drive'),
                value: drives,
                onChanged: (v) => setState(() => drives = v),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) Navigator.pop(context, true);
              },
              child: const Text('Create')),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final created = await runAction(
      context,
      () => ref.read(driverApiProvider).createTeam({
            'name': name.text.trim(),
            'kind': kind,
            'registrationNumber': kind == 'COMPANY' ? reg.text.trim() : null,
            'ownerDrives': drives,
          }),
      success: 'Created. Invite your drivers from the Team tab.');
  if (created) await refreshDriver(ref);
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.profile});

  final DriverProfile profile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, title, body, color) = switch (profile.status) {
      'APPROVED' => (Icons.verified, "You're verified", 'Parents can book you. Keep your documents up to date.',
          Colors.green.withValues(alpha: 0.15)),
      'UNDER_REVIEW' => (Icons.hourglass_top, 'Under review',
          'A SchoolDrop verifier is checking your documents. We will notify you.', scheme.secondaryContainer),
      'REJECTED' => (Icons.error_outline, 'Not approved', profile.statusReason ?? 'Fix the issues below and resubmit.',
          scheme.errorContainer),
      'SUSPENDED' => (Icons.block, 'Suspended', profile.statusReason ?? 'Contact SchoolDrop support.', scheme.errorContainer),
      _ => (Icons.assignment_outlined, 'Get verified',
          profile.statusReason ?? 'Complete the steps below, then submit for verification.', scheme.surfaceContainerHigh),
    };
    return Card(
      color: color,
      child: ListTile(leading: Icon(icon), title: Text(title), subtitle: Text(body)),
    );
  }
}

class _DetailsCard extends ConsumerWidget {
  const _DetailsCard({required this.profile});

  final DriverProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = profile;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          InfoRow('Omang', p.omangNumber),
          if (p.drives) ...[
            InfoRow('Licence', [p.licenceNumber, p.licenceCode].whereType<String>().join(' · ')),
            InfoRow('Licence expires', p.licenceExpiry == null ? null : formatDate(p.licenceExpiry)),
          ],
          InfoRow('Date of birth', p.dateOfBirth == null ? null : formatDate(p.dateOfBirth)),
          InfoRow('Home area', p.homeArea),
          if (p.ownsBusiness)
            InfoRow('Payouts to', p.payoutMethod == null ? null : '${paymentMethods[p.payoutMethod]?.$1 ?? p.payoutMethod} ${p.payoutAccount ?? ''}'),
          if (p.drives) SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Take once-off pickups'),
            subtitle: const Text('Get requests when a parent needs a one-off pickup'),
            value: p.acceptsAdHoc,
            onChanged: (v) async {
              await runAction(context, () => ref.read(driverApiProvider).updateProfile({'acceptsAdHoc': v}));
              ref.invalidate(driverProfileProvider);
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit details'),
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => _DetailsForm(profile: p))),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DetailsForm extends ConsumerStatefulWidget {
  const _DetailsForm({required this.profile});

  final DriverProfile profile;

  @override
  ConsumerState<_DetailsForm> createState() => _DetailsFormState();
}

class _DetailsFormState extends ConsumerState<_DetailsForm> {
  late final _locked = widget.profile.status == 'APPROVED' || widget.profile.status == 'UNDER_REVIEW';
  final _omang = TextEditingController();
  final _licence = TextEditingController();
  late final _code = TextEditingController(text: widget.profile.licenceCode);
  late final _area = TextEditingController(text: widget.profile.homeArea);
  final _account = TextEditingController();
  late DateTime? _dob = widget.profile.dateOfBirth;
  late String? _payout = widget.profile.payoutMethod;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your details')),
      body: Constrained(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (_locked)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Identity details are locked after you submit. Contact support to change them.'),
            ),
          TextField(
            controller: _omang,
            enabled: !_locked,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Omang number', hintText: widget.profile.omangNumber),
          ),
          const SizedBox(height: 12),
          if (widget.profile.drives) ...[
            TextField(
              controller: _licence,
              enabled: !_locked,
              decoration: InputDecoration(labelText: 'Licence number', hintText: widget.profile.licenceNumber),
            ),
            const SizedBox(height: 12),
            TextField(controller: _code, decoration: const InputDecoration(labelText: 'Licence code (e.g. B, C1, EB)')),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            icon: const Icon(Icons.cake_outlined),
            label: Text(_dob == null ? 'Date of birth' : formatDate(_dob)),
            onPressed: _locked
                ? null
                : () async {
                    final picked = await showDatePicker(
                        context: context,
                        initialDate: _dob ?? DateTime(1985),
                        firstDate: DateTime(1940),
                        lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)));
                    if (picked != null) setState(() => _dob = picked);
                  },
          ),
          const SizedBox(height: 12),
          TextField(controller: _area, decoration: const InputDecoration(labelText: 'Home area (e.g. Tlokweng)')),
          if (widget.profile.ownsBusiness) ...[
          SectionTitle(widget.profile.inTeam ? "Where should we send the team's earnings?" : 'Where should we send your earnings?'),
          DropdownButtonFormField<String>(
            value: _payout,
            decoration: const InputDecoration(labelText: 'Payout method'),
            items: [
              for (final m in ['ORANGE_MONEY', 'MYZAKA', 'SMEGA', 'BANK_TRANSFER'])
                DropdownMenuItem(value: m, child: Text(paymentMethods[m]?.$1 ?? 'Bank transfer')),
            ],
            onChanged: (v) => setState(() => _payout = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _account,
            decoration: InputDecoration(
                labelText: 'Mobile money number or bank account', hintText: widget.profile.payoutAccount),
          ),
          ],
          const SizedBox(height: 24),
          BusyButton(
            onPressed: () async {
              String? v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
              final ok = await runAction(context, () => ref.read(driverApiProvider).updateProfile({
                    if (!_locked) 'omangNumber': v(_omang),
                    if (!_locked) 'licenceNumber': v(_licence),
                    if (!_locked) 'dateOfBirth': dateOrNull(_dob),
                    'licenceCode': v(_code),
                    'homeArea': v(_area),
                    if (widget.profile.ownsBusiness) 'payoutMethod': _payout,
                    if (widget.profile.ownsBusiness) 'payoutAccount': v(_account),
                  }), success: 'Saved');
              if (ok && context.mounted) {
                ref.invalidate(driverProfileProvider);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ]),
      ),
    );
  }
}

class _VehicleCard extends ConsumerWidget {
  const _VehicleCard({required this.vehicle, required this.profile});

  final Vehicle vehicle;
  final DriverProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = vehicle;
    final theme = Theme.of(context);
    final uploaded = vehicleDocuments
        .where((t) => profile.documents.any((d) => d.type == t && d.vehicleId == v.id && d.status != 'REJECTED' && d.status != 'EXPIRED'))
        .length;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ListTile(
            leading: Icon(Icons.airport_shuttle, color: v.active ? null : theme.disabledColor),
            title: Text(v.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${label(v.type)} · ${v.seatCapacity} seats${v.active ? '' : ' · inactive'}'),
            trailing: v.verified ? const Icon(Icons.verified, color: Colors.green) : const StatusChip('PENDING'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              uploaded == vehicleDocuments.length
                  ? 'All ${vehicleDocuments.length} papers uploaded'
                  : 'Upload this vehicle\'s papers ($uploaded of ${vehicleDocuments.length} done) — tap Upload on each',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: uploaded == vehicleDocuments.length ? Colors.green : theme.colorScheme.error, fontWeight: FontWeight.w600),
            ),
          ),
          for (final type in vehicleDocuments) _DocumentTile(type: type, profile: profile, vehicle: v),
          OverflowBar(alignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => _openVehicleForm(context, ref, vehicle: v), child: const Text('Edit')),
            if (v.active)
              TextButton(
                onPressed: () async {
                  await runAction(context, () => ref.read(driverApiProvider).deactivateVehicle(v.id));
                  ref.invalidate(driverProfileProvider);
                },
                child: const Text('Deactivate'),
              ),
          ]),
        ]),
      ),
    );
  }
}

/// Add or edit a vehicle. A full page rather than a dialog: it has several fields and dropdowns, and on a
/// phone a dialog can't size two dropdowns side by side.
Future<void> _openVehicleForm(BuildContext context, WidgetRef ref, {Vehicle? vehicle}) =>
    Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => VehicleFormPage(vehicle: vehicle)));

final vehicleColoursProvider = FutureProvider.autoDispose<List<String>>((ref) => ref.watch(commonApiProvider).vehicleColours());

class VehicleFormPage extends ConsumerStatefulWidget {
  const VehicleFormPage({super.key, this.vehicle});

  final Vehicle? vehicle;

  @override
  ConsumerState<VehicleFormPage> createState() => VehicleFormPageState();
}

class VehicleFormPageState extends ConsumerState<VehicleFormPage> {
  final _form = GlobalKey<FormState>();
  late final _make = TextEditingController(text: widget.vehicle?.make);
  late final _model = TextEditingController(text: widget.vehicle?.model);
  late final _plate = TextEditingController(text: widget.vehicle?.plateNumber);
  late final _seats = TextEditingController(text: widget.vehicle?.seatCapacity.toString());
  late String _type = widget.vehicle?.type ?? 'MINIBUS';
  late int? _year = widget.vehicle?.year;
  late String? _colour = widget.vehicle?.colour;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    Vehicle? saved;
    final ok = await runAction(context, () async => saved = await ref.read(driverApiProvider).saveVehicle(widget.vehicle?.id, {
          'make': _make.text.trim(),
          'model': _model.text.trim(),
          'year': _year,
          'colour': _colour,
          'plateNumber': _plate.text.trim().toUpperCase(),
          'type': _type,
          'seatCapacity': int.parse(_seats.text),
        }), success: widget.vehicle == null ? 'Vehicle added — now upload its papers below' : 'Saved');
    if (!ok || !mounted) return;
    ref.invalidate(driverProfileProvider);
    if (widget.vehicle == null && saved != null) {
      // Straight on to this vehicle's papers
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(fullscreenDialog: true, builder: (_) => VehicleFormPage(vehicle: saved)));
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thisYear = DateTime.now().year;
    final years = [for (var y = thisYear + 1; y >= 1990; y--) y];
    final colours = ref.watch(vehicleColoursProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.vehicle == null ? 'Add vehicle' : 'Edit vehicle')),
      body: AsyncBody<List<String>>(
        value: colours,
        onRetry: () => ref.invalidate(vehicleColoursProvider),
        builder: (list) {
          // A colour SchoolDrop has since removed from the list still shows for this vehicle
          final options = [...list, if (_colour != null && !list.contains(_colour)) _colour!];
          return Form(
            key: _form,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Constrained(
                maxWidth: 560,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextFormField(
                      controller: _make,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Make', hintText: 'e.g. Toyota'),
                      validator: requiredField),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: _model,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Model', hintText: 'e.g. Quantum'),
                      validator: requiredField),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _year,
                    isExpanded: true,
                    menuMaxHeight: 320,
                    decoration: const InputDecoration(labelText: 'Year'),
                    items: [for (final y in years) DropdownMenuItem(value: y, child: Text('$y'))],
                    onChanged: (v) => setState(() => _year = v),
                    validator: (v) => v == null ? 'Choose the year' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _colour,
                    isExpanded: true,
                    menuMaxHeight: 320,
                    decoration: const InputDecoration(labelText: 'Colour'),
                    items: [
                      for (final c in options)
                        DropdownMenuItem(
                          value: c,
                          child: Row(children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: swatchFor(c),
                                shape: BoxShape.circle,
                                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(c, overflow: TextOverflow.ellipsis)),
                          ]),
                        ),
                    ],
                    onChanged: (v) => setState(() => _colour = v),
                    validator: (v) => v == null ? 'Choose the colour' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: _plate,
                      enabled: widget.vehicle == null,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                          labelText: 'Number plate',
                          hintText: 'e.g. B 123 ABC',
                          helperText: widget.vehicle == null ? null : "A plate can't change — add a new vehicle instead"),
                      validator: requiredField),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: [for (final t in ['SEDAN', 'SUV', 'MINIBUS', 'BUS']) DropdownMenuItem(value: t, child: Text(label(t)))],
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _seats,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                    decoration: const InputDecoration(
                        labelText: 'Number of children it can carry', helperText: 'Seats for children, not counting the driver'),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null) return 'Enter a number';
                      if (n < 1 || n > 80) return 'Between 1 and 80';
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  BusyButton(onPressed: _save, child: Text(widget.vehicle == null ? 'Add vehicle' : 'Save')),
                  if (widget.vehicle != null) _VehiclePapers(vehicle: widget.vehicle!),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

/// The vehicle's papers, on its own page: registration (blue book), roadworthy and a photo.
class _VehiclePapers extends ConsumerWidget {
  const _VehiclePapers({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(driverProfileProvider).value;
    final theme = Theme.of(context);
    if (profile == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 28),
      Text('Papers for ${vehicle.plateNumber}', style: theme.textTheme.titleMedium),
      const SizedBox(height: 4),
      Text('Upload each one. Clear photos or PDFs are fine.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      Card(
        margin: EdgeInsets.zero,
        child: Column(children: [
          for (final type in vehicleDocuments) _DocumentTile(type: type, profile: profile, vehicle: vehicle),
        ]),
      ),
    ]);
  }
}

/// A small swatch next to each colour name; unknown (admin-added) colours get a neutral grey.
Color swatchFor(String name) => switch (name.toLowerCase()) {
      'white' => Colors.white,
      'silver' => const Color(0xFFC0C0C0),
      'grey' || 'gray' => Colors.grey,
      'black' => Colors.black,
      'blue' => Colors.blue,
      'navy blue' || 'navy' => const Color(0xFF1F2A5A),
      'red' => Colors.red,
      'maroon' => const Color(0xFF800000),
      'green' => Colors.green,
      'yellow' => Colors.yellow,
      'orange' => Colors.orange,
      'brown' => Colors.brown,
      'beige' => const Color(0xFFE8DCC4),
      'gold' => const Color(0xFFD4AF37),
      'purple' => Colors.purple,
      'pink' => Colors.pink,
      _ => Colors.blueGrey,
    };

/// One required document: its latest upload's status, and an upload button.
class _DocumentTile extends ConsumerWidget {
  const _DocumentTile({required this.type, required this.profile, this.vehicle});

  final String type;
  final DriverProfile profile;
  final Vehicle? vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = profile.documents
        .where((d) => d.type == type && d.vehicleId == vehicle?.id)
        .fold<DriverDocument?>(null, (a, d) => a == null || d.uploadedAt.isAfter(a.uploadedAt) ? d : a);
    return ListTile(
      leading: Icon(latest == null ? Icons.upload_file : Icons.description_outlined),
      title: Text(documentLabels[type]!),
      subtitle: latest == null
          ? null
          : Text([
              if (latest.expiresOn != null) 'Expires ${formatDate(latest.expiresOn)}',
              if (latest.reviewNote != null) latest.reviewNote!,
            ].join(' · ')),
      trailing: latest == null || latest.status == 'REJECTED' || latest.status == 'EXPIRED'
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              if (latest != null) ...[StatusChip(latest.status), const SizedBox(width: 6)],
              FilledButton.tonalIcon(
                onPressed: () => _upload(context, ref),
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: Text(latest == null ? 'Upload' : 'Replace'),
              ),
            ])
          : Row(mainAxisSize: MainAxisSize.min, children: [
              StatusChip(latest.status),
              IconButton(
                tooltip: 'Upload a new one',
                icon: const Icon(Icons.file_upload_outlined),
                onPressed: () => _upload(context, ref),
              ),
            ]),
    );
  }

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    final needsExpiry = {'DRIVERS_LICENCE', 'ROADWORTHY_CERTIFICATE', 'INSURANCE', 'PSV_PERMIT'}.contains(type);
    final isPolice = type == 'POLICE_CLEARANCE';
    DateTime? issuedOn;
    DateTime? expiresOn;
    final reference = TextEditingController();

    if (needsExpiry || isPolice) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(documentLabels[type]!),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              if (isPolice) ...[
                TextField(controller: reference, decoration: const InputDecoration(labelText: 'Certificate number')),
                const SizedBox(height: 8),
              ],
              OutlinedButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: isPolice ? now.subtract(const Duration(days: 90)) : now,
                    lastDate: isPolice ? now : DateTime(now.year + 50, 12, 31),
                  );
                  if (picked != null) setState(() => isPolice ? issuedOn = picked : expiresOn = picked);
                },
                child: Text(isPolice
                    ? (issuedOn == null ? 'Date issued' : 'Issued ${formatDate(issuedOn)}')
                    : (expiresOn == null ? 'Expiry date' : 'Expires ${formatDate(expiresOn)}')),
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Choose file')),
            ],
          ),
        ),
      );
      if (ok != true) return;
    }

    if (!context.mounted) return;
    final picked = await pickDocumentImage(context, selfie: type == 'SELFIE', allowPdf: type != 'SELFIE' && type != 'VEHICLE_PHOTO');
    if (picked == null || !context.mounted) return;
    await runAction(
      context,
      () => ref.read(driverApiProvider).uploadDocument(
            type: type,
            bytes: picked.bytes,
            filename: picked.name,
            vehicleId: vehicle?.id,
            referenceNumber: reference.text.trim(),
            issuedOn: issuedOn,
            expiresOn: expiresOn,
          ),
      success: 'Uploaded',
    );
    ref.invalidate(driverProfileProvider);
  }
}

/// Where a document comes from: the camera (front camera for selfies), the photo library, or a file (PDF).
Future<({List<int> bytes, String name})?> pickDocumentImage(BuildContext context,
    {bool selfie = false, bool allowPdf = true}) async {
  final source = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: Icon(selfie ? Icons.face_retouching_natural_outlined : Icons.photo_camera_outlined),
          title: Text(selfie ? 'Take a selfie' : 'Take a photo'),
          subtitle: Text(selfie
              ? 'Face the camera in good light, no hat or sunglasses'
              : 'Lay it flat in good light so every corner and word is readable'),
          onTap: () => Navigator.pop(context, 'camera'),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('Choose a photo'),
          onTap: () => Navigator.pop(context, 'gallery'),
        ),
        if (allowPdf)
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Choose a file (PDF or image)'),
            onTap: () => Navigator.pop(context, 'file'),
          ),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (source == null) return null;
  try {
    if (source == 'file') {
      final result = await FilePicker.pickFiles(
          type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'], withData: true);
      final file = result?.files.single;
      if (file?.bytes == null) return null;
      return (bytes: file!.bytes!.toList(), name: file.name);
    }
    final image = await ImagePicker().pickImage(
      source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
      preferredCameraDevice: selfie ? CameraDevice.front : CameraDevice.rear,
      // Sharp enough to read an Omang, small enough for a slow connection
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );
    if (image == null) return null;
    final name = image.name.toLowerCase().endsWith('.png') ? image.name : '${image.name.split('.').first}.jpg';
    return (bytes: await image.readAsBytes(), name: name);
  } catch (e) {
    if (context.mounted) {
      showMessage(context, source == 'camera' ? "Couldn't open the camera. Allow camera access, or choose a photo instead." : e.toString(),
          error: true);
    }
    return null;
  }
}
