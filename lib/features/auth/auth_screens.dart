import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
import '../account/password_fields.dart';

/// Account types someone can sign up as.
const accountTypes = [
  ('PARENT', Icons.family_restroom_rounded, 'Parent', 'Book trusted transport and track every trip'),
  ('DRIVER', Icons.airport_shuttle_rounded, 'Driver', 'Get verified and drive children to school'),
  ('SCHOOL', Icons.school_rounded, 'School staff', 'Join your school with the invite code you were given'),
];

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final expired = ref.watch(sessionProvider).expired;
    return AuthLayout(
      title: 'Welcome to SchoolDrop',
      subtitle: 'Safe, verified school transport in Botswana.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (expired)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, color: theme.colorScheme.onSecondaryContainer),
              const SizedBox(width: 10),
              const Expanded(child: Text('Your session ended. Please sign in again.')),
            ]),
          ),
        FilledButton(onPressed: () => context.push('/signup'), child: const Text('Create an account')),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: () => context.push('/login'), child: const Text('Sign in')),
        const SizedBox(height: 24),
        if (!kIsWeb) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => context.push('/pair'),
            icon: const Icon(Icons.child_care_rounded),
            label: const Text("I'm a kid — connect my phone"),
          ),
        ],
      ]),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await runAction(context, () => ref.read(sessionProvider.notifier).login(_email.text, _password.text));
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Sign in',
      subtitle: 'Good to see you again.',
      onBack: () => context.canPop() ? context.pop() : context.go('/welcome'),
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              validator: requiredField,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: requiredField,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 28),
            BusyButton(onPressed: _submit, child: const Text('Sign in')),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text("Don't have an account?"),
              TextButton(onPressed: () => context.pushReplacement('/signup'), child: const Text('Create one')),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Sign-up asks only for the account type, email, phone and password. Everything else is onboarding.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key, this.initialType});

  final String? initialType;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  late String _type = accountTypes.any((t) => t.$1 == widget.initialType) ? widget.initialType! : 'PARENT';
  final _email = TextEditingController();
  final _phone = TextEditingController(text: '+267 ');
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await runAction(
      context,
      () => ref.read(sessionProvider.notifier).register(
            accountType: _type,
            email: _email.text,
            phone: _phone.text.replaceAll(' ', ''),
            password: _password.text,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthLayout(
      step: 'Step 1 of 2',
      title: 'Create your account',
      subtitle: "You'll add your details on the next screen.",
      onBack: () => context.canPop() ? context.pop() : context.go('/welcome'),
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('I am a', style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            for (final (type, icon, name, description) in accountTypes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TypeOption(
                  icon: icon,
                  title: name,
                  subtitle: description,
                  selected: _type == type,
                  onTap: () => setState(() => _type = type),
                ),
              ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              validator: (v) => v != null && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? null : 'Enter a valid email',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                prefixIcon: Icon(Icons.phone_outlined),
                helperText: 'Drivers and schools use this to reach you',
              ),
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              textInputAction: TextInputAction.next,
              validator: (v) => RegExp(r'^\+?[0-9]{7,15}$').hasMatch((v ?? '').replaceAll(' ', '')) ? null : 'Enter a valid phone number',
            ),
            const SizedBox(height: 16),
            NewPasswordFields(password: _password, confirm: _confirm, label: 'Password'),
            const SizedBox(height: 28),
            BusyButton(onPressed: _submit, child: const Text('Continue')),
            const SizedBox(height: 16),
            Text('By continuing you agree to the SchoolDrop terms and privacy policy.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Already have an account?'),
              TextButton(onPressed: () => context.pushReplacement('/login'), child: const Text('Sign in')),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});

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
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? scheme.primary : scheme.outline),
          ]),
        ),
      ),
    );
  }
}

class KidPairScreen extends ConsumerStatefulWidget {
  const KidPairScreen({super.key});

  @override
  ConsumerState<KidPairScreen> createState() => _KidPairScreenState();
}

class _KidPairScreenState extends ConsumerState<KidPairScreen> {
  final _code = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthLayout(
      title: 'Connect your phone',
      subtitle: 'Ask your parent for the 8-letter code in their SchoolDrop app.',
      onBack: () => context.canPop() ? context.pop() : context.go('/welcome'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 8, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(hintText: 'ABCD2345'),
        ),
        const SizedBox(height: 24),
        BusyButton(
          onPressed: () => runAction(context, () => ref.read(sessionProvider.notifier).pairKid(_code.text)),
          child: const Text('Connect'),
        ),
      ]),
    );
  }
}
