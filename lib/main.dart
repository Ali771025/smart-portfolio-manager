import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/theme_reveal_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  assert(() {
    // Debug only: print lifecycle moves for GlobalKey widgets to spot duplicates.
    debugPrintGlobalKeyedWidgetLifecycle = true;
    return true;
  }());
  usePathUrlStrategy();
  runApp(const ProviderScope(child: SmartPortfolioApp()));
}

class SmartPortfolioApp extends ConsumerWidget {
  const SmartPortfolioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Smart Portfolio',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [
        Locale('fa', 'IR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightRTL(),
      darkTheme: AppTheme.darkRTL(),
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 420),
      themeAnimationCurve: Curves.easeOutCubic,
      builder: (context, child) {
        return _ThemeRevealTransitionHost(
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: router,
    );
  }
}

class _ThemeRevealTransitionHost extends ConsumerStatefulWidget {
  const _ThemeRevealTransitionHost({
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<_ThemeRevealTransitionHost> createState() =>
      _ThemeRevealTransitionHostState();
}

class _ThemeRevealTransitionHostState
    extends ConsumerState<_ThemeRevealTransitionHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _revealController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _previousTheme = null;
          });
        }
        ref.read(themeRevealOriginProvider.notifier).state = null;
      }
    });

  ThemeData? _previousTheme;
  Offset? _origin;

  @override
  Widget build(BuildContext context) {
    ref.listen<ThemeMode>(themeModeProvider, (previous, next) {
      if (previous == null || previous == next) {
        return;
      }

      final platformBrightness = MediaQuery.platformBrightnessOf(context);
      final previousTheme = _themeForMode(previous, platformBrightness);
      final revealOrigin = ref.read(themeRevealOriginProvider);

      if (!mounted) {
        return;
      }

      setState(() {
        _previousTheme = previousTheme;
        _origin = revealOrigin;
      });
      _revealController.forward(from: 0);
    });

    return AnimatedBuilder(
      animation: _revealController,
      builder: (context, _) {
        if (_previousTheme == null || !_revealController.isAnimating) {
          return widget.child;
        }

        final size = MediaQuery.sizeOf(context);
        final center = _origin ?? Offset(size.width - 40, 40);
        final maxRadius = _maxRadius(size, center);
        final easedProgress =
            Curves.easeInOutCubicEmphasized.transform(_revealController.value);
        final radius = easedProgress * maxRadius;

        return Stack(
          fit: StackFit.expand,
          children: [
            Theme(
              data: _previousTheme!,
              child: widget.child,
            ),
            ClipPath(
              clipper: _CircularRevealClipper(center: center, radius: radius),
              child: widget.child,
            ),
          ],
        );
      },
    );
  }

  ThemeData _themeForMode(ThemeMode mode, Brightness platformBrightness) {
    return switch (mode) {
      ThemeMode.dark => AppTheme.darkRTL(),
      ThemeMode.light => AppTheme.lightRTL(),
      ThemeMode.system =>
        platformBrightness == Brightness.dark ? AppTheme.darkRTL() : AppTheme.lightRTL(),
    };
  }

  double _maxRadius(Size size, Offset center) {
    final corners = <Offset>[
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    return corners
        .map((corner) => (corner - center).distance)
        .reduce(math.max);
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }
}

class _CircularRevealClipper extends CustomClipper<Path> {
  const _CircularRevealClipper({
    required this.center,
    required this.radius,
  });

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) {
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(_CircularRevealClipper oldClipper) {
    return oldClipper.center != center || oldClipper.radius != radius;
  }
}
