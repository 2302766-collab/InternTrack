import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/exceptions/api_exception.dart';
import '../../core/services/student_report_service.dart';
import '../models/student_report.dart';

class ProgressWidget extends StatefulWidget {
  final int? totalHours;
  final int? completedHours;
  final String? token;
  final StudentReportService? reportService;

  const ProgressWidget({
    super.key,
    required this.totalHours,
    required this.completedHours,
  }) : token = null,
       reportService = null;

  const ProgressWidget.dynamic({
    super.key,
    required this.token,
    this.reportService,
  }) : totalHours = null,
       completedHours = null;

  bool get isDynamic => token != null;

  @override
  State<ProgressWidget> createState() => _ProgressWidgetState();
}

class _ProgressWidgetState extends State<ProgressWidget> {
  StudentReportService? _reportService;

  bool _isLoading = false;
  String? _errorMessage;
  _ProgressSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();

    if (widget.isDynamic) {
      _reportService =
          widget.reportService ?? context.read<StudentReportService>();
      _loadProgress();
    } else {
      _snapshot = _ProgressSnapshot.fromHours(
        completedHours: widget.completedHours ?? 0,
        requiredHours: widget.totalHours ?? 0,
      );
    }
  }

  @override
  void didUpdateWidget(covariant ProgressWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.isDynamic) {
      if (oldWidget.isDynamic ||
          oldWidget.completedHours != widget.completedHours ||
          oldWidget.totalHours != widget.totalHours) {
        _isLoading = false;
        _errorMessage = null;
        _snapshot = _ProgressSnapshot.fromHours(
          completedHours: widget.completedHours ?? 0,
          requiredHours: widget.totalHours ?? 0,
        );
      }

      return;
    }

    if (!oldWidget.isDynamic || oldWidget.token != widget.token) {
      _snapshot = null;
      _loadProgress();
    }
  }

  Future<void> _loadProgress() async {
    final token = widget.token ?? '';
    if (token.isEmpty) {
      setState(() {
        _errorMessage = 'Unable to load progress.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final report = await _reportService!.getReport();

      if (!mounted) return;

      setState(() {
        _snapshot = _ProgressSnapshot.fromSummary(report.summary);
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      // Log error for debugging
      debugPrint('ProgressWidget: ApiException - ${e.message} (statusCode: ${e.statusCode})');

      setState(() {
        _errorMessage = e.statusCode == 404
            ? 'Create your internship profile first to see progress.'
            : 'Unable to load progress.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Unable to load progress.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _snapshot == null) {
      return const SizedBox(
        height: 112,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null && _snapshot == null) {
      return _ProgressErrorState(
        message: _errorMessage!,
        onRetry: _loadProgress,
      );
    }

    final snapshot =
        _snapshot ??
        _ProgressSnapshot.fromHours(completedHours: 0, requiredHours: 0);

    return _ProgressContent(
      snapshot: snapshot,
      showRefreshOverlay: _isLoading && widget.isDynamic,
    );
  }
}

class _ProgressContent extends StatelessWidget {
  final _ProgressSnapshot snapshot;
  final bool showRefreshOverlay;

  const _ProgressContent({
    required this.snapshot,
    required this.showRefreshOverlay,
  });

  Color get _progressColor {
    if (snapshot.progressFraction >= 1) {
      return const Color(0xFF10B981);
    }

    if (snapshot.progressFraction >= 0.5) {
      return const Color(0xFF2563EB);
    }

    return const Color(0xFFF59E0B);
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Progress',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF16354D),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _progressColor.withAlpha(24),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                snapshot.percentageLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _progressColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: snapshot.progressFraction),
          duration: const Duration(milliseconds: 700),
          builder: (context, value, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 14,
                backgroundColor: const Color(0xFFDADFE8),
                valueColor: AlwaysStoppedAnimation<Color>(_progressColor),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Text(
          'Approved Hours: ${snapshot.approvedHours} / ${snapshot.requiredHours} hours',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF23364A),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Remaining: ${snapshot.remainingHours} hours',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF526072)),
        ),
      ],
    );

    if (!showRefreshOverlay) {
      return content;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 0.72, child: IgnorePointer(child: content)),
        const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ],
    );
  }
}

class _ProgressErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ProgressErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFC9C4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFFB42318),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ProgressSnapshot {
  final int approvedHours;
  final int requiredHours;
  final double percentage;

  const _ProgressSnapshot({
    required this.approvedHours,
    required this.requiredHours,
    required this.percentage,
  });

  factory _ProgressSnapshot.fromSummary(StudentReportSummary summary) {
    return _ProgressSnapshot(
      approvedHours: summary.totalApprovedHours,
      requiredHours: summary.requiredHours,
      percentage: summary.completionPercentage,
    );
  }

  factory _ProgressSnapshot.fromHours({
    required int completedHours,
    required int requiredHours,
  }) {
    final safeRequiredHours = math.max(requiredHours, 0);
    final safeCompletedHours = math.max(completedHours, 0);
    final rawPercentage = safeRequiredHours == 0
        ? 0.0
        : (safeCompletedHours / safeRequiredHours) * 100;

    return _ProgressSnapshot(
      approvedHours: safeCompletedHours,
      requiredHours: safeRequiredHours,
      percentage: rawPercentage,
    );
  }

  int get remainingHours => math.max(requiredHours - approvedHours, 0);

  double get cappedPercentage => percentage.clamp(0, 100).toDouble();

  double get progressFraction => (cappedPercentage / 100).clamp(0, 1);

  String get percentageLabel => '${cappedPercentage.round()}%';
}
