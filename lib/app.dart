import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/session_controller.dart';
import 'models/session.dart';
import 'features/nurse/approval_desk_screen.dart';
import 'features/nurse/draft_screen.dart';
import 'features/nurse/intake_screen.dart';
import 'features/nurse/patients_screen.dart';
import 'features/patient/ask_screen.dart';
import 'features/patient/checkin_screen.dart';
import 'features/patient/plan_screen.dart';
import 'features/patient/home_screen.dart';
import 'features/patient/profile_screen.dart';
import 'features/patient/checkin_history_screen.dart';
import 'features/patient/checkin_detail_screen.dart';
import 'features/patient/homecare_screen.dart';
import 'features/patient/booking_request_screen.dart';
import 'features/patient/booking_history_screen.dart';
import 'features/patient/booking_detail_screen.dart';
import 'features/patient/alert_detail_screen.dart';
import 'widgets/app_shell.dart';

/// Protected routes follow the backend-validated identity, including deep links.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionControllerProvider, (_, _) => refresh.value++);
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, route) {
      final session = ref.read(sessionControllerProvider);
      final path = route.uri.path;
      if (session is! SessionAuthenticated) {
        return path == '/' ? null : '/';
      }
      if (path == '/') {
        return session.session.principal.role == 'patient'
            ? '/patient/home'
            : '/account';
      }
      if (path.startsWith('/nurse/') &&
              session.session.principal.role != 'nurse' ||
          path.startsWith('/patient/') &&
              session.session.principal.role != 'patient') {
        return '/account';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: '/account',
        builder: (_, _) =>
            const _BackToHome(child: SessionAccountScreen()),
      ),
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) =>
            _BackToHome(
              child: AppShell(
                key: ValueKey(ref.read(sessionControllerProvider).generation),
                location: GoRouter.of(context).state.uri.path,
                child: child,
              ),
            ),
        routes: <RouteBase>[
          GoRoute(
            path: '/patient/home',
            builder: (_, _) => const PatientHomeScreen(),
          ),
          GoRoute(
            path: '/patient/alerts',
            builder: (_, _) => const AlertHistoryScreen(),
          ),
          GoRoute(
            path: '/patient/alerts/:alertId',
            builder: (_, state) =>
                AlertDetailScreen(alertId: state.pathParameters['alertId']!),
          ),
          GoRoute(
            path: '/patient/profile',
            builder: (_, _) => const PatientProfileScreen(),
          ),
          GoRoute(
            path: '/patient/homecare',
            builder: (_, _) => const HomecareScreen(),
          ),
          GoRoute(
            path: '/patient/homecare/:serviceId/request',
            builder: (_, state) => BookingRequestScreen(
              serviceId: state.pathParameters['serviceId']!,
            ),
          ),
          GoRoute(
            path: '/patient/checkin',
            builder: (BuildContext context, GoRouterState state) =>
                const PatientCheckinScreen(),
          ),
          GoRoute(
            path: '/patient/checkins',
            builder: (_, _) => const CheckinHistoryScreen(),
          ),
          GoRoute(
            path: '/patient/checkins/:checkinId',
            builder: (_, state) => CheckinDetailScreen(
              checkinId: state.pathParameters['checkinId']!,
            ),
          ),
          GoRoute(
            path: '/patient/bookings',
            builder: (_, _) => const BookingHistoryScreen(),
          ),
          GoRoute(
            path: '/patient/bookings/:bookingId',
            builder: (_, state) => BookingDetailScreen(
              bookingId: state.pathParameters['bookingId']!,
            ),
          ),
          GoRoute(
            path: '/patient/plan',
            builder: (BuildContext context, GoRouterState state) =>
                const PatientPlanScreen(),
          ),
          GoRoute(
            path: '/patient/ask',
            builder: (BuildContext context, GoRouterState state) =>
                const PatientAskScreen(),
          ),
          GoRoute(
            path: '/nurse/intake',
            builder: (BuildContext context, GoRouterState state) =>
                const NurseIntakeScreen(),
          ),
          GoRoute(
            path: '/nurse/draft',
            builder: (BuildContext context, GoRouterState state) =>
                const NurseDraftScreen(),
          ),
          GoRoute(
            path: '/nurse/approval',
            builder: (BuildContext context, GoRouterState state) =>
                const NurseApprovalDeskScreen(),
          ),
          GoRoute(
            path: '/nurse/patients',
            builder: (BuildContext context, GoRouterState state) =>
                const NursePatientsScreen(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class _BackToHome extends ConsumerWidget {
  const _BackToHome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    if (session is! SessionAuthenticated) return child;
    final home = session.session.principal.role == 'patient'
        ? '/patient/home'
        : '/nurse/intake';
    final router = GoRouter.of(context);
    return ListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) => PopScope<Object?>(
        canPop: router.state.uri.path == home || router.canPop(),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !router.canPop()) router.go(home);
        },
        child: child,
      ),
    );
  }
}

class SynCareApp extends ConsumerWidget {
  const SynCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SynCare',
      locale: const Locale('id'),
      supportedLocales: const [Locale('id')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
