import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeController = context.watch<ThemeController>();
    final isDarkMode = themeController.isDarkMode;
    final statusColor = theme.colorScheme.primary.withValues(
      alpha: isDarkMode ? 0.24 : 0.10,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theme Preference',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Dark Mode',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          Switch.adaptive(
                            value: isDarkMode,
                            activeThumbColor: AppTheme.brandColor,
                            activeTrackColor: AppTheme.brandColor.withValues(
                              alpha: 0.40,
                            ),
                            onChanged: (value) {
                              context.read<ThemeController>().setDarkMode(
                                value,
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          isDarkMode
                              ? 'Dark Theme Applied'
                              : 'Light Theme Applied',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
