import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../account/account_screen.dart';
import 'account_menu.dart';
import 'notifications_screen.dart';

class ShellDestination {
  const ShellDestination({
    required this.icon,
    required this.label,
    required this.builder,
    this.selectedIcon,
    this.title,
    this.fab,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  /// Page title in the header; defaults to [label].
  final String? title;
  final Widget Function() builder;
  final Widget Function(BuildContext context)? fab;
}

/// The frame around every signed-in experience. Wide screens get a dark sidebar;
/// phones get a top bar plus bottom navigation (or a drawer when there are many sections).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.destinations, this.subtitle, this.banner, this.nestedNavigation = false});

  final List<ShellDestination> destinations;

  /// Shown under the page title on wide screens, e.g. the school name.
  final String? subtitle;

  /// Optional strip above the content (e.g. "awaiting verification").
  final Widget? banner;

  /// Give each section its own Navigator so detail pages open inside the content area (admin).
  final bool nestedNavigation;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final destinations = widget.destinations;
    final index = _index.clamp(0, destinations.length - 1);
    final current = destinations[index];
    final width = MediaQuery.of(context).size.width;
    final wide = width >= 1000;
    final useDrawer = !wide && destinations.length > 5;

    Widget content = widget.nestedNavigation
        ? Navigator(
            key: ValueKey(current.label),
            onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => current.builder()),
          )
        : IndexedStack(index: index, children: [for (final d in destinations) d.builder()]);
    if (widget.banner != null) {
      content = Column(children: [widget.banner!, Expanded(child: content)]);
    }

    if (wide) {
      return Scaffold(
        body: Row(children: [
          _Sidebar(destinations: destinations, index: index, onSelect: (i) => setState(() => _index = i)),
          Expanded(
            child: Column(children: [
              _TopBar(title: current.title ?? current.label, subtitle: widget.subtitle),
              Expanded(child: content),
            ]),
          ),
        ]),
        floatingActionButton: current.fab?.call(context),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: useDrawer ? Text(current.title ?? current.label) : _MobileTitle(title: current.title ?? current.label),
        actions: const [NotificationsButton(), AccountMenu(), SizedBox(width: 8)],
      ),
      drawer: useDrawer
          ? Drawer(
              backgroundColor: AppColors.ink,
              child: _SidebarContent(
                destinations: destinations,
                index: index,
                onSelect: (i) {
                  setState(() => _index = i);
                  Navigator.pop(context);
                },
              ),
            )
          : null,
      body: content,
      floatingActionButton: current.fab?.call(context),
      bottomNavigationBar: useDrawer || destinations.length < 2
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: [
                  for (final d in destinations)
                    NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon ?? d.icon), label: d.label),
                ],
              ),
            ),
    );
  }
}

class _MobileTitle extends StatelessWidget {
  const _MobileTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(title);
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 20, 20, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: theme.textTheme.headlineSmall),
            if (subtitle != null)
              Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
        const NotificationsButton(),
        const SizedBox(width: 4),
        const AccountMenu(),
      ]),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.destinations, required this.index, required this.onSelect});

  final List<ShellDestination> destinations;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
        width: 264,
        color: AppColors.ink,
        child: _SidebarContent(destinations: destinations, index: index, onSelect: onSelect),
      );
}

class _SidebarContent extends ConsumerWidget {
  const _SidebarContent({required this.destinations, required this.index, required this.onSelect});

  final List<ShellDestination> destinations;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    return SafeArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(padding: EdgeInsets.fromLTRB(20, 24, 20, 28), child: BrandMark(size: 34, onDark: true)),
        Expanded(
          child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (var i = 0; i < destinations.length; i++)
              _SidebarItem(destination: destinations[i], selected: i == index, onTap: () => onSelect(i)),
          ]),
        ),
        if (user != null)
          Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
            borderRadius: BorderRadius.circular(14),
            hoverColor: Colors.white.withValues(alpha: 0.05),
            onTap: () => openProfile(context),
            child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.brand,
                child: Text(user.initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(user.roleDescription,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12)),
                ]),
              ),
              IconButton(
                tooltip: 'Sign out',
                icon: Icon(Icons.logout_rounded, color: Colors.white.withValues(alpha: 0.7), size: 20),
                onPressed: () async {
                  if (await confirmDialog(context, 'Sign out?', 'You will need to sign in again on this device.',
                      confirm: 'Sign out')) {
                    await ref.read(sessionProvider.notifier).logout();
                  }
                },
              ),
            ]),
            ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.destination, required this.selected, required this.onTap});

  final ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white.withValues(alpha: 0.65);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: 0.09) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          hoverColor: Colors.white.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(children: [
              Icon(selected ? (destination.selectedIcon ?? destination.icon) : destination.icon, size: 20,
                  color: selected ? AppColors.amber : color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(destination.label,
                    style: TextStyle(color: color, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, fontSize: 14)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
