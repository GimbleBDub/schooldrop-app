import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// A password input with a show/hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({super.key, required this.controller, required this.label, this.validator, this.helper,
      this.autofocus = false, this.autofillHints = const [AutofillHints.password], this.onSubmitted});

  final TextEditingController controller;
  final String label;
  final String? helper;
  final bool autofocus;
  final Iterable<String> autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        obscureText: _hidden,
        autofocus: widget.autofocus,
        autofillHints: widget.autofillHints,
        onFieldSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.helper,
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            tooltip: _hidden ? 'Show' : 'Hide',
            icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _hidden = !_hidden),
          ),
        ),
        validator: widget.validator,
      );
}

/// SchoolDrop's password rules — the same ones the server enforces.
class PasswordRules {
  static const minLength = 8;
  static const maxLength = 72;

  static List<({String label, bool met})> check(String p) => [
        (label: 'At least $minLength characters', met: p.length >= minLength),
        (label: 'An uppercase letter (A–Z)', met: RegExp(r'[A-Z]').hasMatch(p)),
        (label: 'A lowercase letter (a–z)', met: RegExp(r'[a-z]').hasMatch(p)),
        (label: 'A number (0–9)', met: RegExp(r'\d').hasMatch(p)),
        (label: 'A symbol (e.g. ! @ # - _)', met: RegExp(r'[^A-Za-z0-9]').hasMatch(p)),
      ];

  static bool isStrong(String p) => p.length <= maxLength && check(p).every((r) => r.met);

  static String? validate(String? value) {
    final p = value ?? '';
    if (p.length > maxLength) return 'Use at most $maxLength characters';
    final missing = check(p).where((r) => !r.met).toList();
    if (missing.isEmpty) return null;
    return 'Needs: ${missing.map((r) => r.label.split(' (').first.toLowerCase()).join(', ')}';
  }
}

/// New password + confirmation, with a strength bar and a live checklist of the rules.
class NewPasswordFields extends StatefulWidget {
  const NewPasswordFields({super.key, required this.password, required this.confirm, this.label = 'New password'});

  final TextEditingController password;
  final TextEditingController confirm;
  final String label;

  @override
  State<NewPasswordFields> createState() => _NewPasswordFieldsState();
}

class _NewPasswordFieldsState extends State<NewPasswordFields> {
  @override
  void initState() {
    super.initState();
    widget.password.addListener(_changed);
  }

  @override
  void dispose() {
    widget.password.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.password.text;
    final rules = PasswordRules.check(p);
    final met = rules.where((r) => r.met).length;
    final strong = met == rules.length;
    final (text, color) = p.isEmpty
        ? ('', theme.colorScheme.outlineVariant)
        : strong
            ? (p.length >= 12 ? 'Strong' : 'Good', AppColors.success)
            : met >= 3
                ? ('Almost there', AppColors.warning)
                : ('Weak', AppColors.danger);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PasswordField(
        controller: widget.password,
        label: widget.label,
        autofillHints: const [AutofillHints.newPassword],
        validator: PasswordRules.validate,
      ),
      const SizedBox(height: 10),
      Row(children: [
        for (var i = 0; i < rules.length; i++)
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 4,
              margin: EdgeInsets.only(right: i < rules.length - 1 ? 4 : 0),
              decoration: BoxDecoration(
                color: i < met ? color : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        const SizedBox(width: 10),
        SizedBox(width: 84, child: Text(text, style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 14, runSpacing: 4, children: [
        for (final r in rules)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(r.met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 15, color: r.met ? AppColors.success : theme.colorScheme.outline),
            const SizedBox(width: 4),
            Text(r.label,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: r.met ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant)),
          ]),
      ]),
      const SizedBox(height: 16),
      PasswordField(
        controller: widget.confirm,
        label: 'Confirm password',
        autofillHints: const [AutofillHints.newPassword],
        validator: (v) => (v ?? '').isEmpty
            ? 'Type the password again'
            : v != widget.password.text
                ? "Passwords don't match"
                : null,
      ),
    ]);
  }
}
