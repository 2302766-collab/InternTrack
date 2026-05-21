import 'package:flutter/material.dart';

import '../../core/theme/theme_utils.dart';

class DashboardInfoCard extends StatelessWidget {
  final String? title;
  final Widget child;

  const DashboardInfoCard({super.key, this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((title ?? '').isNotEmpty) ...[
              Text(
                title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.primaryTextColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
