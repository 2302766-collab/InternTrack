import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../providers/auth_provider.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _hasRedirected = false;

  void _redirectWhenReady(AuthProvider authProvider) {
    if (_hasRedirected || !authProvider.isReady) return;

    _hasRedirected = true;

    final nextRoute = authProvider.isAuthenticated
        ? authProvider.dashboardRoute
        : AppRoutes.login;

    // Defer navigation until after build to avoid setState during build errors.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      debugPrint(
        '[AuthGate] redirecting to $nextRoute isAuthenticated=${authProvider.isAuthenticated} role=${authProvider.role}',
      );
      Navigator.pushReplacementNamed(context, nextRoute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    _redirectWhenReady(authProvider);

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
