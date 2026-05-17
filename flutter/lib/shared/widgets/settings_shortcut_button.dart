import 'package:flutter/material.dart';

import '../../core/constants/app_routes.dart';

class SettingsShortcutButton extends StatelessWidget {
  const SettingsShortcutButton({
    super.key,
    this.iconColor,
  });

  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Settings',
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.settings);
      },
      icon: Icon(
        Icons.dark_mode_outlined,
        color: iconColor,
      ),
    );
  }
}
