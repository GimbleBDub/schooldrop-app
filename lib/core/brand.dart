import 'package:flutter/material.dart';

import 'theme.dart';

/// The SchoolDrop logo: a rounded tile with the bus mark, plus the wordmark.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 36, this.onDark = false, this.showName = true});

  final double size;
  final bool onDark;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final textColor = onDark ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.brand, AppColors.brandDark],
          ),
          boxShadow: [BoxShadow(color: AppColors.brand.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Icon(Icons.directions_bus_rounded, color: AppColors.amber, size: size * 0.6),
      ),
      if (showName) ...[
        SizedBox(width: size * 0.3),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: 'School', style: TextStyle(color: textColor)),
            TextSpan(text: 'Drop', style: TextStyle(color: onDark ? AppColors.amber : Theme.of(context).colorScheme.primary)),
          ]),
          style: TextStyle(fontSize: size * 0.55, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ],
    ]);
  }
}

/// Sign-in / sign-up / onboarding frame. Wide screens get a brand panel beside the form;
/// phones get a compact brand header above it.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.title, this.subtitle, required this.child, this.onBack, this.step});

  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onBack;

  /// e.g. "Step 2 of 2"
  final String? step;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 960;
    final theme = Theme.of(context);
    final form = SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              if (onBack != null)
                IconButton.outlined(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded), tooltip: 'Back'),
              const Spacer(),
              if (!wide) const BrandMark(size: 30),
            ]),
            const SizedBox(height: 28),
            if (step != null) ...[
              Text(step!.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
            ],
            Text(title, style: theme.textTheme.headlineMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 32),
            child,
          ]),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: wide ? Row(children: [const Expanded(flex: 5, child: _BrandPanel()), Expanded(flex: 6, child: form)]) : form,
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandDark, Color(0xFF0B1636)],
        ),
      ),
      child: Stack(children: [
        Positioned(
          right: -80,
          bottom: -60,
          child: Icon(Icons.directions_bus_rounded, size: 360, color: Colors.white.withValues(alpha: 0.04)),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const BrandMark(size: 40, onDark: true),
          const Spacer(),
          Text('Every school run,\nverified.',
              style: theme.textTheme.displaySmall?.copyWith(color: Colors.white, height: 1.1)),
          const SizedBox(height: 16),
          Text('Book vetted drivers, follow every pickup live, and know exactly who collects your child.',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.75), fontWeight: FontWeight.w400, height: 1.5)),
          const SizedBox(height: 40),
          for (final (icon, text) in const [
            (Icons.verified_user_rounded, 'Omang, licence and police clearance checked for every driver'),
            (Icons.handshake_outlined, 'Every handover confirmed, every trip tracked live'),
            (Icons.school_rounded, 'Schools see who is authorised to collect each child'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: AppColors.amber, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15)),
                ),
              ]),
            ),
          const Spacer(),
          Text('© SchoolDrop · Made in Botswana',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13)),
        ]),
      ]),
    );
  }
}
