import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DashboardRefreshStatus extends StatelessWidget {
  const DashboardRefreshStatus({
    super.key,
    required this.lastUpdated,
    required this.isRefreshing,
    this.pullToRefreshLabel = 'Pull down to refresh dashboard data',
    this.refreshingLabel = 'Refreshing dashboard data...',
  });

  final DateTime? lastUpdated;
  final bool isRefreshing;
  final String pullToRefreshLabel;
  final String refreshingLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.78) ??
        const Color(0xFF6B7F99);
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: mutedColor,
      fontWeight: FontWeight.w600,
    );

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(pullToRefreshLabel, style: labelStyle),
        if (lastUpdated != null)
          Text(
            'Last updated: ${DateFormat('h:mm a').format(lastUpdated!.toLocal())}',
            style: labelStyle,
          ),
        if (isRefreshing)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(refreshingLabel, style: labelStyle),
            ],
          ),
      ],
    );
  }
}

class DashboardInlineNotice extends StatelessWidget {
  const DashboardInlineNotice({
    super.key,
    required this.message,
    this.onRetry,
    this.isError = true,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final tone = isError
        ? const (
            background: Color(0xFFFFF1F1),
            border: Color(0xFFF5C2C2),
            foreground: Color(0xFFB42318),
            icon: Icons.error_outline,
          )
        : const (
            background: Color(0xFFEFF8FF),
            border: Color(0xFFB2DDFF),
            foreground: Color(0xFF175CD3),
            icon: Icons.info_outline,
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.background,
        border: Border.all(color: tone.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tone.icon, color: tone.foreground, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: tone.foreground,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: tone.foreground,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

class DashboardSkeletonBlock extends StatelessWidget {
  const DashboardSkeletonBlock({
    super.key,
    required this.height,
    this.width,
    this.radius = 10,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EEF4),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
