import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/domain/models/auth_session.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/controllers/auth_state.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/assets/presentation/screens/assets_page.dart';
import '../../features/analytics/presentation/screens/analytics_performance_screen.dart';
import '../../features/analytics/presentation/screens/hf_benchmark_harness_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/portfolio/presentation/screens/portfolio_list_screen.dart';
import '../../features/portfolio/presentation/providers/portfolio_providers.dart';
import '../../features/portfolio_manager/domain/models/portfolio_card_dto.dart';
import '../../features/portfolio_manager/presentation/providers/portfolio_manager_controller.dart';
import '../../features/portfolio_manager/presentation/screens/portfolio_manager_screen.dart';
import '../../features/multi_portfolio_import/presentation/screens/multi_portfolio_import_screen.dart';
import '../../features/import_excel/presentation/screens/excel_import_screen.dart';
import '../../features/import_excel/presentation/screens/import_progress_screen.dart';
import '../../features/market/presentation/screens/market_screen.dart';
import '../../features/watchlist/presentation/screens/watchlist_screen.dart';
import '../../features/trades/presentation/screens/trade_entry_screen.dart';
import '../../features/portfolio/presentation/screens/portfolio_detail_screen.dart';
import '../../features/portfolio/presentation/screens/portfolio_charts_screen.dart';
import '../../features/portfolio/presentation/screens/portfolio_reports_screen.dart';
import '../../features/portfolio/presentation/screens/symbol_analytics_screen.dart';
import '../layout/responsive_shell.dart';

part 'app_router.g.dart';

enum AppShellTab {
  dashboard(
    path: '/dashboard',
    labelFa: 'داشبورد',
    icon: Icons.space_dashboard_rounded,
  ),
  portfolios(
    path: '/portfolios',
    labelFa: 'پرتفوها',
    icon: Icons.account_balance_wallet_rounded,
  ),
  assets(
    path: '/assets',
    labelFa: 'دارایی‌ها',
    icon: Icons.stacked_line_chart_rounded,
  ),
  analytics(
    path: '/analytics',
    labelFa: 'تحلیل',
    icon: Icons.analytics_rounded,
  ),
  market(
    path: '/market',
    labelFa: 'بازار',
    icon: Icons.public_rounded,
  ),
  watchlist(
    path: '/watchlist',
    labelFa: 'دیده‌بان',
    icon: Icons.visibility_rounded,
  ),
  trades(
    path: '/trades',
    labelFa: 'معاملات',
    icon: Icons.swap_horiz_rounded,
  );

  const AppShellTab({
    required this.path,
    required this.labelFa,
    required this.icon,
  });

  final String path;
  final String labelFa;
  final IconData icon;
}

class _RouterRefreshListenable extends ChangeNotifier {
  void refresh() => notifyListeners();
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final refreshListenable = _RouterRefreshListenable();
  ref
    ..onDispose(refreshListenable.dispose)
    ..listen<AsyncValue<AuthSession?>>(
      authControllerProvider,
      (previous, next) {
        if (_shouldRefreshRouter(previous, next)) {
          refreshListenable.refresh();
        }
      },
    );

  return GoRouter(
    initialLocation: AppShellTab.dashboard.path,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final session = authState.value;
      final isLoggedIn = session != null && !session.isExpired;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final onRoot = state.matchedLocation == '/';

      if (onRoot) {
        return isLoggedIn ? AppShellTab.dashboard.path : '/auth/login';
      }

      if (!isLoggedIn && !isAuthRoute) {
        final from = Uri.encodeComponent(state.uri.toString());
        return '/auth/login?from=$from';
      }

      if (isLoggedIn && isAuthRoute) {
        final from = state.uri.queryParameters['from'];
        if (from == null || from.isEmpty) {
          return AppShellTab.dashboard.path;
        }
        return from;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/auth/login',
        name: 'auth-login',
        pageBuilder: (context, state) {
          final from = state.uri.queryParameters['from'];
          return _authTransitionPage(
            state: state,
            child: LoginScreen(redirectTo: from),
          );
        },
      ),
      GoRoute(
        path: '/auth/register',
        name: 'auth-register',
        pageBuilder: (context, state) {
          return _authTransitionPage(
            state: state,
            child: const RegisterScreen(),
          );
        },
      ),
      GoRoute(
        path: '/auth/otp',
        name: 'auth-otp',
        redirect: (context, state) {
          final queryEmail = state.uri.queryParameters['email']?.trim() ?? '';
          if (queryEmail.isNotEmpty) {
            return null;
          }

          final pending = ref.read(pendingRegistrationProvider);
          if (pending != null && pending.email.isNotEmpty) {
            return '/auth/otp?email=${Uri.encodeComponent(pending.email)}';
          }

          return '/auth/register';
        },
        pageBuilder: (context, state) {
          final queryEmail = state.uri.queryParameters['email']?.trim() ?? '';
          return _authTransitionPage(
            state: state,
            child: OtpVerificationScreen(email: queryEmail),
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          final currentIndex = _indexForLocation(state.matchedLocation);
          final destinations = AppShellTab.values
              .map(
                (tab) => ShellDestination(
                  labelFa: tab.labelFa,
                  icon: tab.icon,
                  location: tab.path,
                ),
              )
              .toList(growable: false);
          return ResponsiveShell(
            destinations: destinations,
            currentIndex: currentIndex,
            onDestinationSelected: (index) => context.go(
              destinations[index].location,
            ),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: AppShellTab.dashboard.path,
            name: AppShellTab.dashboard.name,
            pageBuilder: (_, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: const DashboardScreen(),
            ),
          ),
          GoRoute(
            path: AppShellTab.portfolios.path,
            name: AppShellTab.portfolios.name,
            pageBuilder: (_, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: const PortfolioListScreen(),
            ),
            routes: [
              GoRoute(
                path: 'manage',
                name: 'portfolio-manage',
                pageBuilder: (_, state) => NoTransitionPage<void>(
                  key: state.pageKey,
                  child: const PortfolioManagerScreen(),
                ),
              ),
              GoRoute(
                path: ':portfolioId/detail',
                name: 'portfolio-detail',
                pageBuilder: (_, state) => NoTransitionPage<void>(
                  key: state.pageKey,
                  child: PortfolioDetailScreen(
                    portfolioId: state.pathParameters['portfolioId'] ?? '',
                  ),
                ),
              ),
              GoRoute(
                path: ':portfolioId/charts',
                name: 'portfolio-charts',
                pageBuilder: (_, state) => NoTransitionPage<void>(
                  key: state.pageKey,
                  child: PortfolioChartsScreen(
                    portfolioId: state.pathParameters['portfolioId'] ?? '',
                  ),
                ),
              ),
              GoRoute(
                path: ':portfolioId/reports',
                name: 'portfolio-reports',
                pageBuilder: (_, state) => NoTransitionPage<void>(
                  key: state.pageKey,
                  child: PortfolioReportsScreen(
                    portfolioId: state.pathParameters['portfolioId'] ?? '',
                  ),
                ),
              ),
              GoRoute(
                path: ':portfolioId/symbol-analytics',
                name: 'portfolio-symbol-analytics',
                pageBuilder: (_, state) => NoTransitionPage<void>(
                  key: state.pageKey,
                  child: SymbolAnalyticsScreen(
                    portfolioId: state.pathParameters['portfolioId'] ?? '',
                  ),
                ),
              ),
              GoRoute(
                path: ':portfolioId/assets/:ticker',
                name: 'portfolio-asset-detail',
                redirect: (_, state) {
                  final portfolioId = state.pathParameters['portfolioId'] ?? '';
                  final ticker = state.pathParameters['ticker'] ?? '';
                  if (portfolioId.isEmpty || ticker.isEmpty) {
                    return AppShellTab.assets.path;
                  }
                  return '${AppShellTab.assets.path}?portfolio_id=${Uri.encodeComponent(portfolioId)}'
                      '&ticker=${Uri.encodeComponent(ticker)}';
                },
              ),
            ],
          ),
          GoRoute(
            path: AppShellTab.assets.path,
            name: AppShellTab.assets.name,
            pageBuilder: (_, state) {
              return NoTransitionPage<void>(
                key: state.pageKey,
                child: AssetsDashboardPage(
                  initialPortfolioId: state.uri.queryParameters['portfolio_id'],
                  initialTicker: state.uri.queryParameters['ticker'],
                ),
              );
            },
          ),
          GoRoute(
            path: AppShellTab.analytics.path,
            name: AppShellTab.analytics.name,
            pageBuilder: (_, state) {
              final queryPortfolioId =
                  (state.uri.queryParameters['portfolio_id'] ?? '').trim();
              final resolvedPortfolioId = queryPortfolioId.isNotEmpty
                  ? queryPortfolioId
                  : _resolveDefaultPortfolioId(ref);
              return NoTransitionPage<void>(
                key: state.pageKey,
                child: AnalyticsPerformanceScreen(
                  portfolioId: resolvedPortfolioId,
                ),
              );
            },
            routes: [
              GoRoute(
                path: 'hf-benchmark-harness',
                name: 'analytics-hf-benchmark-harness',
                pageBuilder: (_, state) {
                  final queryPortfolioId =
                      (state.uri.queryParameters['portfolio_id'] ?? '').trim();
                  final resolvedPortfolioId = queryPortfolioId.isNotEmpty
                      ? queryPortfolioId
                      : _resolveDefaultPortfolioId(ref);
                  return NoTransitionPage<void>(
                    key: state.pageKey,
                    child: HighFrequencyBenchmarkHarnessScreen(
                      portfolioId: resolvedPortfolioId,
                    ),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: AppShellTab.market.path,
            name: AppShellTab.market.name,
            pageBuilder: (_, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: const MarketScreen(),
            ),
          ),
          GoRoute(
            path: AppShellTab.watchlist.path,
            name: AppShellTab.watchlist.name,
            pageBuilder: (_, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: const WatchlistScreen(),
            ),
          ),
          GoRoute(
            path: AppShellTab.trades.path,
            name: AppShellTab.trades.name,
            pageBuilder: (_, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: const TradeEntryScreen(),
            ),
            routes: [
              GoRoute(
                path: 'multi-import',
                name: 'multi-portfolio-import',
                pageBuilder: (_, state) => NoTransitionPage<void>(
                  key: state.pageKey,
                  child: const MultiPortfolioImportScreen(),
                ),
              ),
              GoRoute(
                path: 'excel-import',
                name: 'excel-import',
                pageBuilder: (_, state) => NoTransitionPage<void>(
                  key: state.pageKey,
                  child: const ExcelImportScreen(),
                ),
              ),
              GoRoute(
                path: 'excel-import/:jobId',
                name: 'excel-import-progress',
                pageBuilder: (_, state) => NoTransitionPage<void>(
                  key: state.pageKey,
                  child: ImportProgressScreen(
                    jobId: state.pathParameters['jobId'] ?? '',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

String _resolveDefaultPortfolioId(Ref ref) {
  final selectedId = ref.read(selectedPortfolioIdProvider);
  final managerPortfolios =
      ref.read(portfolioManagerControllerProvider).value ?? const <PortfolioCardDto>[];
  if (selectedId != null && managerPortfolios.any((item) => item.id == selectedId)) {
    return selectedId;
  }

  final listPortfolios =
      ref.read(portfolioListProvider).value ?? const <PortfolioListItem>[];
  if (selectedId != null && listPortfolios.any((item) => item.id == selectedId)) {
    return selectedId;
  }

  if (managerPortfolios.isNotEmpty) {
    final preferred = managerPortfolios.where((item) => item.isDefault).toList();
    if (preferred.isNotEmpty) {
      return preferred.first.id;
    }
    return managerPortfolios.first.id;
  }

  if (listPortfolios.isNotEmpty) {
    return listPortfolios.first.id;
  }
  return '';
}

int _indexForLocation(String location) {
  for (var i = 0; i < AppShellTab.values.length; i++) {
    if (location.startsWith(AppShellTab.values[i].path)) {
      return i;
    }
  }
  return 0;
}

bool _shouldRefreshRouter(
  AsyncValue<AuthSession?>? previous,
  AsyncValue<AuthSession?> next,
) {
  final previousSession = previous?.value;
  final nextSession = next.value;
  final wasLoggedIn = previousSession != null && !previousSession.isExpired;
  final isLoggedIn = nextSession != null && !nextSession.isExpired;

  if (wasLoggedIn != isLoggedIn) {
    return true;
  }

  final previousToken = previousSession?.accessToken ?? '';
  final nextToken = nextSession?.accessToken ?? '';
  return previousToken != nextToken;
}

CustomTransitionPage<void> _authTransitionPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.035),
        end: Offset.zero,
      ).animate(curved);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: slide,
          child: child,
        ),
      );
    },
  );
}
