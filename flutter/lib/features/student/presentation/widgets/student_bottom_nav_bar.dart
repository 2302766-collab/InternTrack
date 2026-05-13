import 'package:flutter/material.dart';

import '../../../../core/constants/app_routes.dart';

class StudentBottomNavBar extends StatelessWidget {
  const StudentBottomNavBar({super.key, required this.currentRoute});

  final String currentRoute;

  static const List<_StudentNavDestination> _destinations =
      <_StudentNavDestination>[
        _StudentNavDestination(
          label: 'Dashboard',
          route: AppRoutes.studentDashboard,
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard_rounded,
        ),
        _StudentNavDestination(
          label: 'Logbook',
          route: AppRoutes.logbook,
          icon: Icons.menu_book_outlined,
          activeIcon: Icons.menu_book_rounded,
        ),
        _StudentNavDestination(
          label: 'DTR',
          route: AppRoutes.studentDtr,
          icon: Icons.access_time_outlined,
          activeIcon: Icons.access_time_filled_rounded,
        ),
        _StudentNavDestination(
          label: 'Report',
          route: AppRoutes.studentReport,
          icon: Icons.assessment_outlined,
          activeIcon: Icons.assessment_rounded,
        ),
        _StudentNavDestination(
          label: 'Profile',
          route: AppRoutes.internshipProfile,
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
        ),
      ];

  int get _currentIndex {
    if (currentRoute == AppRoutes.dashboard) {
      return 0;
    }

    final matchedIndex = _destinations.indexWhere(
      (destination) => destination.route == currentRoute,
    );

    return matchedIndex >= 0 ? matchedIndex : 0;
  }

  void _handleTap(BuildContext context, int tappedIndex) {
    if (tappedIndex == _currentIndex) {
      return;
    }

    Navigator.pushReplacementNamed(context, _destinations[tappedIndex].route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _currentIndex,
      selectedItemColor: theme.colorScheme.primary,
      unselectedItemColor: theme.colorScheme.onSurface.withAlpha(170),
      selectedLabelStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      iconSize: 22,
      onTap: (index) => _handleTap(context, index),
      items: _destinations
          .map(
            (destination) => BottomNavigationBarItem(
              icon: Icon(
                destination.icon,
                key: ValueKey<String>('student-nav-${destination.route}'),
              ),
              activeIcon: Icon(
                destination.activeIcon,
                key: ValueKey<String>('student-nav-${destination.route}'),
              ),
              label: destination.label,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _StudentNavDestination {
  const _StudentNavDestination({
    required this.label,
    required this.route,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final String route;
  final IconData icon;
  final IconData activeIcon;
}
