import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

bool _isExpiredSessionHandling = false;

Future<void> handleExpiredSession(BuildContext context) async {
  if (_isExpiredSessionHandling) {
    return;
  }

  _isExpiredSessionHandling = true;
  try {
    await context.read<AuthProvider>().logout();
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your session has expired. Please log in again.'),
      ),
    );

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  } finally {
    _isExpiredSessionHandling = false;
  }
}
