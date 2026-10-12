import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';

/// Step 2 after sign-up: the details each account type needs before the app opens up.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  DateTime? _dateOfBirth;

  /// Family members, school staff and team drivers join with an invite code instead.
  bool _joining = false;

  /// Drivers: running a team / transport company (vs driving on their own).
  bool _team = false;
  String _teamKind = 'COMPANY';
  bool _ownerDrives = true;

  TextEditingController _c(String key) => _fields.putIfAbsent(key, TextEditingController.new);

  String? _v(String key) {
    final text = _fields[key]?.text.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  Future<void> _submit(String role) async {
    if (!_form.currentState!.validate()) return;
    if (_joining || role == 'SCHOOL') {
      await runAction(
        context,
        () => ref.read(sessionProvider.notifier).joinWithCode(
              firstName: _v('firstName')!,
              lastName: _v('lastName')!,
              code: _v('code')!,
              title: _v('title'),
            ),
      );
      return;
    }
    final body = <String, dynamic>{'firstName': _v('firstName'), 'lastName': _v('lastName')};
    if (role == 'DRIVER') {
      body.addAll({'omangNumber': _v('omangNumber'), 'dateOfBirth': dateOrNull(_dateOfBirth), 'homeArea': _v('homeArea')});
      if (_team) {
        body['team'] = {
          'name': _v('teamName'),
          'kind': _teamKind,
          'registrationNumber': _teamKind == 'COMPANY' ? _v('registrationNumber') : null,
          'ownerDrives': _ownerDrives,
        };
      }
    }
    await runAction(context, () => ref.read(sessionProvider.notifier).completeOnboarding(body));
  }

  Widget _field(String key, String label,
      {bool required = true, TextInputType? keyboard, String? helper, IconData? icon, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: _c(key),
        keyboardType: keyboard,
        textInputAction: TextInputAction.next,
        textCapitalization: keyboard == null ? TextCapitalization.words : TextCapitalization.none,
        decoration: InputDecoration(
          labelText: required ? label : '$label (optional)',
          helperText: helper,
          prefixIcon: icon == null ? null : Icon(icon),
        ),
        validator: validator ?? (required ? requiredField : null),
      ),
    );
  }

  Widget _nameRow() => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _field('firstName', 'First name')),
        const SizedBox(width: 12),
        Expanded(child: _field('lastName', 'Last name')),
      ]);

  Widget _groupLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).user;
    if (user == null) return const SizedBox.shrink();
    final role = user.role;

    // Schools are added by SchoolDrop: staff always join theirs with an invite code
    if (role == 'SCHOOL') _joining = true;
    final canJoin = role == 'PARENT';
    final (title, subtitle) = _joining
        ? switch (role) {
            'SCHOOL' => ('Join your school',
                'Enter the invite code from your school admin (or from SchoolDrop if you are setting your school up).'),
            'DRIVER' => ('Join your team', 'Enter the invite code from the team or company you drive for.'),
            _ => ('Join your family', 'Enter the invite code you were sent. The parent can create one in SchoolDrop.'),
          }
        : switch (role) {
      'DRIVER' when _team => ('Set up your business',
          'Add your drivers and vehicles next. Everyone who drives or manages is verified individually.'),
      'DRIVER' => ('Tell us about you', 'Parents see your name. Your Omang stays private and is only seen by our verification team.'),
      'SCHOOL' => ('Set up your school', "We'll verify your school before parents can link their children to it."),
      _ => ('Tell us about you', 'Drivers and schools will see your name.'),
    };

    return AuthLayout(
      step: 'Step 2 of 2',
      title: title,
      subtitle: subtitle,
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (role == 'DRIVER') ...[
            Text('How do you work?', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            for (final (mode, icon, name, description) in [
              ('SOLO', Icons.person_outline_rounded, 'I drive on my own', 'Your own vehicle(s), your own routes'),
              ('TEAM', Icons.groups_2_outlined, 'I run a company or team', 'Several drivers and vehicles; you may or may not drive'),
              ('JOIN', Icons.vpn_key_outlined, 'I drive for a company or team', 'Join them with the invite code they sent you'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ModeOption(
                  icon: icon,
                  title: name,
                  subtitle: description,
                  selected: (mode == 'JOIN' && _joining) || (mode == 'TEAM' && _team && !_joining) || (mode == 'SOLO' && !_team && !_joining),
                  onTap: () => setState(() {
                    _joining = mode == 'JOIN';
                    _team = mode == 'TEAM';
                  }),
                ),
              ),
            const SizedBox(height: 16),
          ],
          if (canJoin) ...[
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(role == 'SCHOOL' ? 'Register a school' : 'Start my family')),
                const ButtonSegment(value: true, label: Text('I have an invite code')),
              ],
              selected: {_joining},
              onSelectionChanged: (s) => setState(() => _joining = s.first),
            ),
            const SizedBox(height: 24),
          ],
          _nameRow(),
          if (_joining) ...[
            _field('code', 'Invite code', icon: Icons.vpn_key_outlined, keyboard: TextInputType.text),
            if (role == 'SCHOOL') _field('title', 'Your role at the school', required: false, helper: 'e.g. Grade 3 teacher, Gate'),
          ],
          if (role == 'DRIVER' && _team && !_joining) ...[
            _groupLabel('Your business'),
            _field('teamName', 'Company or team name', icon: Icons.business_outlined, helper: 'Parents see this next to your drivers'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'COMPANY', label: Text('Registered company')),
                  ButtonSegment(value: 'TEAM', label: Text('Informal team')),
                ],
                selected: {_teamKind},
                onSelectionChanged: (s) => setState(() => _teamKind = s.first),
              ),
            ),
            if (_teamKind == 'COMPANY')
              _field('registrationNumber', 'CIPA registration number', keyboard: TextInputType.text, icon: Icons.numbers_rounded,
                  helper: "You'll upload the certificate during verification"),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('I also drive'),
              subtitle: const Text("Turn off if you only run the business — you won't need a driver's licence"),
              value: _ownerDrives,
              onChanged: (v) => setState(() => _ownerDrives = v),
            ),
          ],
          if (role == 'DRIVER' && !_joining) ...[
            _field('omangNumber', 'Omang number',
                required: false,
                keyboard: TextInputType.number,
                icon: Icons.badge_outlined,
                helper: 'Needed before verification — you can add it later',
                validator: (v) => v == null || v.isEmpty || RegExp(r'^\d{9}$').hasMatch(v) ? null : 'Omang numbers have 9 digits'),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
                icon: const Icon(Icons.cake_outlined),
                label: Text(_dateOfBirth == null ? 'Date of birth (optional)' : 'Born ${formatDate(_dateOfBirth)}'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(1988),
                    firstDate: DateTime(1940),
                    lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                  );
                  if (picked != null) setState(() => _dateOfBirth = picked);
                },
              ),
            ),
            _field('homeArea', 'Where you live', required: false, icon: Icons.home_outlined, helper: 'e.g. Tlokweng, Block 8'),
          ],
          const SizedBox(height: 12),
          BusyButton(
            onPressed: () => _submit(role),
            child: Text(_joining ? 'Join' : _team ? 'Create my business' : 'Finish'),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Signed in as ${user.email}', style: Theme.of(context).textTheme.bodySmall),
            TextButton(onPressed: () => ref.read(sessionProvider.notifier).logout(), child: const Text('Sign out')),
          ]),
        ]),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer.withValues(alpha: 0.5) : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(icon, color: selected ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
              ]),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: scheme.primary),
          ]),
        ),
      ),
    );
  }
}
