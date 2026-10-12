import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand.dart';
import '../../core/device.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import 'password_fields.dart';

/// Staff created (or reset) with a temporary password choose their own before anything else.
class SetPasswordScreen extends ConsumerStatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final session = ref.read(sessionProvider.notifier);
    await runAction(context, () async {
      final signIn = await ref
          .read(accountApiProvider)
          .changePassword(_current.text, _next.text, await session.deviceId(), deviceName());
      await session.applySignIn(signIn);
    }, success: 'Password saved. Welcome to SchoolDrop.');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).user;
    return AuthLayout(
      title: 'Choose your password',
      subtitle: 'You signed in with a temporary password. Pick your own to continue — '
          'only you should know it.',
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PasswordField(controller: _current, label: 'Temporary password', validator: requiredField),
          const SizedBox(height: 16),
          NewPasswordFields(password: _next, confirm: _confirm),
          const SizedBox(height: 24),
          BusyButton(onPressed: _save, child: const Text('Save and continue')),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Signed in as ${user?.email ?? ''}', style: Theme.of(context).textTheme.bodySmall),
            TextButton(onPressed: () => ref.read(sessionProvider.notifier).logout(), child: const Text('Sign out')),
          ]),
        ]),
      ),
    );
  }
}
