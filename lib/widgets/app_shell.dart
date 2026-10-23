import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Outer navigation shell shared by every role screen.
///
/// Each screen keeps its own `Scaffold` and `AppBar`; this widget only adds the
/// bottom [NavigationBar] whose destinations follow the current role section.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  /// Current absolute route path, used to pick the destination set and the
  /// selected index.
  final String location;

  final Widget child;

  static const List<_ShellDestination> _patientDestinations =
      <_ShellDestination>[
        _ShellDestination(
          label: 'Check-in',
          path: '/patient/checkin',
          icon: Icons.monitor_heart_outlined,
        ),
        _ShellDestination(
          label: 'Rencana',
          path: '/patient/plan',
          icon: Icons.description_outlined,
        ),
        _ShellDestination(
          label: 'Tanya',
          path: '/patient/ask',
          icon: Icons.question_answer_outlined,
        ),
        _ShellDestination(
          label: 'Peran',
          path: '/',
          icon: Icons.switch_account_outlined,
        ),
      ];

  static const List<_ShellDestination> _nurseDestinations = <_ShellDestination>[
    _ShellDestination(
      label: 'Intake',
      path: '/nurse/intake',
      icon: Icons.assignment_outlined,
    ),
    _ShellDestination(
      label: 'Draf',
      path: '/nurse/draft',
      icon: Icons.edit_document,
    ),
    _ShellDestination(
      label: 'Setujui',
      path: '/nurse/approval',
      icon: Icons.fact_check_outlined,
    ),
    _ShellDestination(
      label: 'Pasien',
      path: '/nurse/patients',
      icon: Icons.groups_outlined,
    ),
    _ShellDestination(
      label: 'Peran',
      path: '/',
      icon: Icons.switch_account_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isNurse = location.startsWith('/nurse');
    final List<_ShellDestination> destinations = isNurse
        ? _nurseDestinations
        : _patientDestinations;
    final int selectedIndex = destinations.indexWhere(
      (_ShellDestination destination) => destination.path == location,
    );

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        onDestinationSelected: (int index) =>
            context.go(destinations[index].path),
        destinations: <Widget>[
          for (final _ShellDestination destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.path,
    required this.icon,
  });

  final String label;
  final String path;
  final IconData icon;
}
