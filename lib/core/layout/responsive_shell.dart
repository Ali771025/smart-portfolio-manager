import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

@immutable
class ShellDestination {
  const ShellDestination({
    required this.labelFa,
    required this.icon,
    required this.location,
  });

  final String labelFa;
  final IconData icon;
  final String location;
}

class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({
    required this.child,
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final Widget child;
  final List<ShellDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _mobileBreakpoint = 760.0;
  static const _desktopBreakpoint = 1220.0;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (width < _mobileBreakpoint) {
            return _MobileShell(
              destinations: destinations,
              currentIndex: currentIndex,
              onDestinationSelected: onDestinationSelected,
              child: child,
            );
          }
          if (width < _desktopBreakpoint) {
            return _TabletShell(
              destinations: destinations,
              currentIndex: currentIndex,
              onDestinationSelected: onDestinationSelected,
              child: child,
            );
          }
          return _DesktopShell(
            destinations: destinations,
            currentIndex: currentIndex,
            onDestinationSelected: onDestinationSelected,
            child: child,
          );
        },
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  final List<ShellDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // Do not wrap routed shell content with AnimatedSwitcher:
        // keeping old/new route trees alive during transition can break
        // inherited dependency teardown ordering on web.
        child: child,
      ),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: currentIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                label: item.labelFa,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _TabletShell extends StatelessWidget {
  const _TabletShell({
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  final List<ShellDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: child,
            ),
          ),
          const VerticalDivider(width: 1),
          SafeArea(
            child: NavigationRail(
              selectedIndex: currentIndex,
              labelType: NavigationRailLabelType.all,
              minWidth: 96,
              groupAlignment: -0.7,
              useIndicator: true,
              onDestinationSelected: onDestinationSelected,
              destinations: destinations
                  .map(
                    (item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      label: Text(item.labelFa),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  final List<ShellDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    return Scaffold(
      body: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: Row(
          children: [
            _GlassMenu(
              destinations: destinations,
              currentIndex: currentIndex,
              onDestinationSelected: onDestinationSelected,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: semantic.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: scheme.outlineVariant,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassMenu extends StatelessWidget {
  const _GlassMenu({
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final List<ShellDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 272,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: semantic.surface.withValues(alpha: isDark ? 0.9 : 0.96),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: scheme.outlineVariant,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Smart Portfolio',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'مدیریت هوشمند پرتفوی',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.separated(
                    itemCount: destinations.length,
                    itemBuilder: (context, index) {
                      final item = destinations[index];
                      final selected = index == currentIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: selected
                              ? scheme.primaryContainer.withValues(
                                  alpha: isDark ? 0.24 : 0.62,
                                )
                              : Colors.transparent,
                          border: Border.all(
                            color: selected
                                ? scheme.primary.withValues(alpha: 0.55)
                                : scheme.outlineVariant,
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          onTap: () => onDestinationSelected(index),
                          leading: Icon(item.icon),
                          title: Text(item.labelFa),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
