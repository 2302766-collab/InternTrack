import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import 'app_routes.dart';

class RouteManager {
  static String resolveInitialRoute(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isReady) {
      return AppRoutes.home;
    }

    if (authProvider.isAuthenticated) {
      return authProvider.dashboardRoute;
    }

    return AppRoutes.home;
  }

  static bool canAccessProtectedRoute(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.isAuthenticated;
  }

  static bool canAccessGuestRoute(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return !authProvider.isAuthenticated;
  }
}
