import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'features/auth/role_picker_screen.dart';
import 'features/nurse/approval_desk_screen.dart';
import 'features/nurse/draft_screen.dart';
import 'features/nurse/intake_screen.dart';
import 'features/nurse/patients_screen.dart';
import 'features/patient/ask_screen.dart';
import 'features/patient/checkin_screen.dart';
import 'features/patient/plan_screen.dart';
import 'widgets/app_shell.dart';

/// Application router: the role picker stands alone, every role screen renders
/// inside the shared [AppShell] navigation bar.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const RolePickerScreen(),
      ),
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) =>
            AppShell(location: state.uri.path, child: child),
        routes: <RouteBase>[
          GoRoute(
            path: '/patient/checkin',
            builder: (BuildContext context, GoRouterState state) =>
                const PatientCheckinScreen(),
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
  ref.onDispose(router.dispose);
  return router;
});

class SynCareApp extends ConsumerWidget {
  const SynCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SynCare',
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
