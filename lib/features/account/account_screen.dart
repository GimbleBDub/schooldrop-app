import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/device.dart';
import '../../core/format.dart';
import '../../core/preferences.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/account.dart';
import '../../models/user.dart';
import 'billing_screen.dart';
import 'devices_screen.dart';
import 'password_fields.dart';

final accountProvider = FutureProvider.autoDispose<Account>((ref) => ref.watch(accountApiProvider).account());

const supportEmail = 'support@schooldrop.co.bw';

/// Opens Profile (who you are) above whatever is on screen — works from every role's shell.
Future<void> openProfile(BuildContext context) => Navigator.of(context, rootNavigator: true)
    .push(MaterialPageRoute(builder: (_) => const AccountScreen(settings: false)));

/// Opens Settings (how the app behaves: appearance, notifications, security, help).
Future<void> openSettings(BuildContext context) => Navigator.of(context, rootNavigator: true)
    .push(MaterialPageRoute(builder: (_) => const AccountScreen(settings: true)));

/// Profile: who you are, your details and role. Settings: appearance, notifications, sign-in security, help.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key, required this.settings});

  final bool settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    return Scaffold(
      appBar: AppBar(title: Text(settings ? 'Settings' : 'Profile')),
      body: AsyncBody<Account>(
        value: account,
        onRetry: () => ref.invalidate(accountProvider),
        builder: (a) => _AccountBody(account: a, settings: settings),
      ),
    );
  }
}

class _AccountBody extends ConsumerWidget {
  const _AccountBody({required this.account, required this.settings});

  final Account account;
  final bool settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = account.profile;
    final kid = user.role == 'KID';
    final theme = Theme.of(context);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
      Constrained(
        maxWidth: 760,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!settings) ...[
          _ProfileHeader(account: account),
          const SectionTitle('Personal details'),
          _Group(children: [
            _Row(
              icon: Icons.person_outline_rounded,
              title: 'Name',
              value: user.fullName,
              note: account.nameLocked ? account.nameLockedReason : null,
              locked: account.nameLocked || kid,
              onTap: account.nameLocked || kid ? null : () => _editName(context, ref, user),
            ),
            _Row(
              icon: Icons.alternate_email_rounded,
              title: 'Email',
              value: kid ? 'Signed in with a pairing code' : user.email,
              badge: kid || user.role == 'ADMIN' ? null : (account.profile.emailVerified ? null : 'Not verified'),
              note: kid ? null : 'You sign in with this. It must not be used by another SchoolDrop account.',
              locked: kid,
              onTap: kid ? null : () => _changeEmail(context, ref, user),
            ),
            if (!kid)
              _Row(
                icon: Icons.phone_iphone_rounded,
                title: 'Phone',
                value: user.phone ?? 'Not set',
                note: 'Drivers, schools and SchoolDrop use it to reach you.',
                onTap: () => _changePhone(context, ref, user),
              ),
          ]),
          const SectionTitle('Your role'),
          _Group(children: [
            _Row(
              icon: Icons.badge_outlined,
              title: 'Account',
              value: user.roleDescription,
              note: switch (user.role) {
                'PARENT' => user.isHelper
                    ? 'You can see today\'s trips and confirm handovers for your family.'
                    : 'Manage your family in the Family tab.',
                'DRIVER' => user.teamName != null ? 'Your team is managed in the Team tab.' : 'Your documents and vehicles are in the Profile tab.',
                'SCHOOL' => 'Your school\'s staff are managed in the Staff tab.',
                _ => null,
              },
            ),
            if (account.memberSince != null)
              _Row(icon: Icons.event_available_outlined, title: 'Member since', value: monthName(account.memberSince!)),
          ]),
          if (account.hasBilling) ...[
            const SectionTitle('Billing'),
            _Group(children: [
              _Row(
                icon: user.role == 'DRIVER' ? Icons.account_balance_wallet_outlined : Icons.receipt_long_outlined,
                title: user.role == 'DRIVER' ? 'Earnings & billing' : 'Payments & receipts',
                value: user.role == 'DRIVER'
                    ? 'Earnings, commission, payouts, statements and invoices'
                    : 'What your family paid, refunds and receipts',
                onTap: () => openBilling(context),
              ),
            ]),
          ],
          ] else ...[
          const SectionTitle('Appearance'),
          const _AppearanceCard(),
          if (!kid) ...[
            const SectionTitle('Notifications'),
            _NotificationSettingsCard(account: account),
          ],
          const SectionTitle('Sign-in & security'),
          _Group(children: [
            if (!kid)
              _Row(
                icon: Icons.lock_outline_rounded,
                title: 'Password',
                value: account.passwordChangedAt == null
                    ? 'Change your password'
                    : 'Changed ${formatDate(account.passwordChangedAt)}',
                onTap: () => _changePassword(context, ref),
              ),
            _Row(
              icon: Icons.devices_rounded,
              title: 'Signed-in devices',
              value: 'See where you\'re signed in and sign out remotely',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DevicesScreen())),
            ),
          ]),
          const SectionTitle('Help'),
          _Group(children: [
            _Row(
              icon: Icons.support_agent_rounded,
              title: 'Contact support',
              value: supportEmail,
              onTap: () => launchUrl(Uri.parse('mailto:$supportEmail?subject=SchoolDrop%20help')),
            ),
            const _Row(icon: Icons.info_outline_rounded, title: 'About', value: 'SchoolDrop · safe school transport in Botswana'),
          ]),
          ],
          const SizedBox(height: 28),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.4)),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
            onPressed: () async {
              if (await confirmDialog(context, 'Sign out?', 'You will need to sign in again on this device.',
                  confirm: 'Sign out')) {
                if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                await ref.read(sessionProvider.notifier).logout();
              }
            },
          ),
        ]),
      ),
    ]);
  }

  // ─── Edits ────────────────────────────────────────────────────────────────

  Future<void> _editName(BuildContext context, WidgetRef ref, UserProfile user) async {
    final first = TextEditingController(text: user.firstName);
    final last = TextEditingController(text: user.lastName);
    await _formDialog(
      context,
      title: 'Your name',
      fields: [
        TextFormField(
            controller: first,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'First name'),
            validator: requiredField),
        const SizedBox(height: 12),
        TextFormField(
            controller: last,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Last name'),
            validator: requiredField),
      ],
      save: () async {
        final updated = await ref.read(accountApiProvider).updateProfile(first.text.trim(), last.text.trim());
        ref.read(sessionProvider.notifier).updateUser(updated.profile);
        ref.invalidate(accountProvider);
      },
      success: 'Name updated',
    );
  }

  Future<void> _changeEmail(BuildContext context, WidgetRef ref, UserProfile user) async {
    final email = TextEditingController();
    final password = TextEditingController();
    await _formDialog(
      context,
      title: 'Change email',
      intro: 'You\'ll sign in with the new address. For your security, other devices will be signed out.',
      fields: [
        TextFormField(
          controller: email,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: 'New email', hintText: user.email, prefixIcon: const Icon(Icons.alternate_email_rounded)),
          validator: (v) {
            final value = v?.trim() ?? '';
            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) return 'Enter a valid email address';
            if (value.toLowerCase() == user.email) return "That's already your email";
            return null;
          },
        ),
        const SizedBox(height: 12),
        PasswordField(controller: password, label: 'Current password', validator: requiredField),
      ],
      save: () async {
        final session = ref.read(sessionProvider.notifier);
        final signIn = await ref
            .read(accountApiProvider)
            .changeEmail(email.text.trim(), password.text, await session.deviceId(), deviceName());
        await session.applySignIn(signIn);
        ref.invalidate(accountProvider);
      },
      success: 'Email changed. Other devices were signed out.',
    );
  }

  Future<void> _changePhone(BuildContext context, WidgetRef ref, UserProfile user) async {
    final phone = TextEditingController();
    final password = TextEditingController();
    await _formDialog(
      context,
      title: 'Change phone number',
      intro: 'Each phone number can only belong to one SchoolDrop account.',
      fields: [
        TextFormField(
          controller: phone,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
              labelText: 'New phone number', hintText: 'e.g. 71 234 567', prefixIcon: const Icon(Icons.phone_iphone_rounded)),
          validator: (v) => RegExp(r'^\+?[0-9]{7,15}$').hasMatch((v ?? '').replaceAll(' ', ''))
              ? null
              : 'Enter a valid phone number',
        ),
        const SizedBox(height: 12),
        PasswordField(controller: password, label: 'Current password', validator: requiredField),
      ],
      save: () async {
        final updated = await ref.read(accountApiProvider).changePhone(phone.text.trim(), password.text);
        ref.read(sessionProvider.notifier).updateUser(updated.profile);
        ref.invalidate(accountProvider);
      },
      success: 'Phone number updated',
    );
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    await _formDialog(
      context,
      title: 'Change password',
      intro: 'Other devices will be signed out. This one stays signed in.',
      fields: [
        PasswordField(controller: current, label: 'Current password', autofocus: true, validator: requiredField),
        const SizedBox(height: 16),
        NewPasswordFields(password: next, confirm: confirm),
      ],
      save: () async {
        final session = ref.read(sessionProvider.notifier);
        final signIn = await ref
            .read(accountApiProvider)
            .changePassword(current.text, next.text, await session.deviceId(), deviceName());
        await session.applySignIn(signIn);
        ref.invalidate(accountProvider);
      },
      success: 'Password changed. Other devices were signed out.',
    );
  }
}

/// A dialog with a form; [save] runs when the form is valid and the dialog closes if it succeeds.
Future<void> _formDialog(BuildContext context,
    {required String title,
    String? intro,
    required List<Widget> fields,
    required Future<void> Function() save,
    required String success}) {
  final form = GlobalKey<FormState>();
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (intro != null) ...[
                Text(intro, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
              ],
              ...fields,
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        BusyButton(
          onPressed: () async {
            if (!form.currentState!.validate()) return;
            final ok = await runAction(context, save, success: success);
            if (ok && context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

// ─── Pieces ─────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final user = account.profile;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.brand, AppColors.brandDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.amber, width: 3),
          ),
          child: Text(_initials(user),
              style: const TextStyle(color: AppColors.brandDark, fontSize: 26, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.fullName,
                style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
              child: Text(user.roleDescription,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 10),
            Text(
              [if (user.role != 'KID') user.email, if (user.phone != null) user.phone!].join('  ·  '),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
            ),
            if (account.memberSince != null)
              Text('Member since ${monthName(account.memberSince!)}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  static String _initials(UserProfile u) {
    final first = (u.firstName ?? u.email).trim();
    final last = (u.lastName ?? '').trim();
    return (first.isEmpty ? '' : first[0]).toUpperCase() + (last.isEmpty ? '' : last[0]).toUpperCase();
  }
}

/// A card of rows separated by dividers.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 60),
            children[i],
          ],
        ]),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.value, this.note, this.badge, this.locked = false, this.onTap});

  final IconData icon;
  final String title;
  final String value;
  final String? note;
  final String? badge;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(title, style: theme.textTheme.bodySmall?.copyWith(color: muted, fontWeight: FontWeight.w600)),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  StatusChip(badge!.toUpperCase().replaceAll(' ', '_')),
                ],
              ]),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (note != null) ...[
                const SizedBox(height: 4),
                Text(note!, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              ],
            ]),
          ),
          if (onTap != null || locked)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 8),
              child: Icon(locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded, size: 20, color: muted),
            ),
        ]),
      ),
    );
  }
}

class _NotificationSettingsCard extends ConsumerStatefulWidget {
  const _NotificationSettingsCard({required this.account});

  final Account account;

  @override
  ConsumerState<_NotificationSettingsCard> createState() => _NotificationSettingsCardState();
}

class _NotificationSettingsCardState extends ConsumerState<_NotificationSettingsCard> {
  late NotificationSettings _settings = widget.account.notifications;

  Future<void> _set(NotificationSettings next) async {
    final before = _settings;
    setState(() => _settings = next);
    try {
      await ref.read(accountApiProvider).updateNotifications(next);
    } catch (e) {
      if (!mounted) return;
      setState(() => _settings = before);
      showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.account.profile.role;
    final theme = Theme.of(context);
    final tiles = <Widget>[
      _switch(Icons.directions_bus_outlined, 'Trips & handovers',
          role == 'SCHOOL' ? 'Arrivals and collections at your school' : 'Pickups, drop-offs and confirmations',
          _settings.trips, (v) => _set(_settings.copyWith(trips: v))),
      _switch(Icons.event_seat_outlined, 'Bookings & enrollments', 'New bookings, cancellations, school confirmations',
          _settings.bookings, (v) => _set(_settings.copyWith(bookings: v))),
      if (role == 'PARENT' || role == 'DRIVER' || role == 'ADMIN')
        _switch(Icons.payments_outlined, 'Payments & payouts', 'Receipts, refunds, payouts and fees',
            _settings.payments, (v) => _set(_settings.copyWith(payments: v))),
      _switch(Icons.campaign_outlined, 'News & tips', 'New features and occasional tips from SchoolDrop',
          _settings.news, (v) => _set(_settings.copyWith(news: v))),
    ];
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < tiles.length; i++) ...[if (i > 0) const Divider(height: 1, indent: 60), tiles[i]],
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          color: theme.colorScheme.primary.withValues(alpha: 0.04),
          child: Row(children: [
            Icon(Icons.shield_outlined, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Safety alerts (SOS, disputed handovers) and account security messages are always sent. '
                'Everything also stays in your in-app notifications.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _switch(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        secondary: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      );
}

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Theme', style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('System')),
            ],
            selected: {mode},
            onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
          ),
          const SizedBox(height: 8),
          Text('"System" follows your phone or computer\'s setting.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
