import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/services/internship_service.dart';
import '../../../../core/services/logbook_service.dart';
import '../../../../core/services/student_report_service.dart';
import '../../../../shared/models/internship_profile.dart';
import '../../../../shared/models/log_entry.dart';
import '../../../../shared/models/student_report.dart';
import '../../../../shared/widgets/dashboard_info_card.dart';
import '../../../../shared/widgets/notification_bell_button.dart';
import '../../../../shared/widgets/settings_shortcut_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class StudentDashboardScreen extends StatefulWidget {
  final String userName;
  final String? companyName;
  final int? requiredHours;
  final InternshipService? internshipService;
  final LogbookService? logbookService;
  final StudentReportService? reportService;

  const StudentDashboardScreen({
    super.key,
    required this.userName,
    this.companyName,
    this.requiredHours,
    this.internshipService,
    this.logbookService,
    this.reportService,
  });

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  late final InternshipService _internshipService;
  late final LogbookService _logbookService;
  late final StudentReportService _reportService;

  InternshipProfile? _profile;
  StudentReportData? _report;
  List<LogEntryItem> _logs = <LogEntryItem>[];

  bool _isLoading = true;
  bool _didLoadDashboard = false;
  String? _dashboardError;
  String? _profileError;
  String? _reportError;
  String? _logsError;

  @override
  void initState() {
    super.initState();
    _internshipService =
        widget.internshipService ?? context.read<InternshipService>();
    _logbookService = widget.logbookService ?? context.read<LogbookService>();
    _reportService =
        widget.reportService ?? context.read<StudentReportService>();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadDashboard) return;
    _didLoadDashboard = true;
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final token = context.read<AuthProvider>().token ?? '';
    if (token.isEmpty) {
      setState(() {
        _isLoading = false;
        _dashboardError = 'Your session has expired. Please log in again.';
        _profileError = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _dashboardError = null;
      _profileError = null;
      _reportError = null;
      _logsError = null;
    });

    InternshipProfile? profile;
    StudentReportData? report;
    List<LogEntryItem> logs = <LogEntryItem>[];
    String? profileError;
    String? reportError;
    String? logsError;

    try {
      profile = await _internshipService.getInternshipProfile();
    } catch (e) {
      profileError = _readErrorMessage(e);
    }

    if (profile != null) {
      try {
        report = await _reportService.getReport();
      } catch (e) {
        reportError = _readErrorMessage(e);
      }

      try {
        logs = await _logbookService.getLogs();
      } catch (e) {
        logsError = _readErrorMessage(e);
      }
    }

    if (!mounted) return;

    final dashboardError = profile == null && profileError != null
        ? profileError
        : null;

    setState(() {
      _profile = profile;
      _report = report;
      _logs = logs;
      _dashboardError = dashboardError;
      _profileError = profileError;
      _reportError = reportError;
      _logsError = logsError;
      _isLoading = false;
    });
  }

  String _readErrorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }

    return error.toString().replaceFirst('Exception: ', '');
  }

  int get _approvedHours => _report?.summary.approvedHours ?? 0;

  int get _requiredHours {
    return _profile?.requiredHours ??
        _report?.summary.requiredHours ??
        widget.requiredHours ??
        0;
  }

  int get _pendingHours => _logs
      .where((log) => log.status.toUpperCase() == 'PENDING')
      .fold(0, (sum, log) => sum + log.hoursRendered);

  int get _rejectedLogsCount =>
      _logs.where((log) => log.status.toUpperCase() == 'REJECTED').length;

  int get _pendingLogsCount =>
      _logs.where((log) => log.status.toUpperCase() == 'PENDING').length;

  bool get _hasTodayLog {
    final today = _formatApiDate(_today);
    return _logs.any((log) => log.date == today);
  }

  int? get _daysRemaining {
    final endDate = _parseApiDate(_profile?.endDate);
    if (endDate == null) return null;
    final remaining = endDate.difference(_today).inDays;
    return math.max(0, remaining);
  }

  int? get _expectedHoursByToday {
    final profile = _profile;
    if (profile == null) return null;

    final startDate = _parseApiDate(profile.startDate);
    final endDate = _parseApiDate(profile.endDate);
    if (startDate == null || endDate == null || endDate.isBefore(startDate)) {
      return null;
    }

    final requiredHours = profile.requiredHours;
    if (requiredHours <= 0) return null;

    if (_today.isBefore(startDate)) {
      return 0;
    }

    if (_today.isAfter(endDate)) {
      return requiredHours;
    }

    final totalDays = endDate.difference(startDate).inDays + 1;
    final elapsedDays = _today.difference(startDate).inDays + 1;
    final progressRatio = elapsedDays / totalDays;

    return (requiredHours * progressRatio).round();
  }

  int? get _paceDelta {
    final expected = _expectedHoursByToday;
    if (expected == null) return null;
    return _approvedHours - expected;
  }

  int? get _paceDeltaAfterPending {
    final expected = _expectedHoursByToday;
    if (expected == null) return null;
    return (_approvedHours + _pendingHours) - expected;
  }

  bool get _isBehindPace {
    final deltaAfterPending = _paceDeltaAfterPending;
    return deltaAfterPending != null && deltaAfterPending < 0;
  }

  bool get _profileComplete => _profile != null;

  String get _attentionChipLabel {
    if (!_profileComplete) return 'Profile Incomplete';
    if (!_hasTodayLog) return 'Action Needed';
    if (_pendingLogsCount > 0) return 'For Review';
    if (_isBehindPace) return 'Needs Recovery';
    return 'On Track';
  }

  (Color, Color) get _attentionChipColors {
    if (!_profileComplete) {
      return (const Color(0xFFFEECEE), const Color(0xFFB42318));
    }
    if (!_hasTodayLog || _pendingLogsCount > 0 || ((_paceDelta ?? 0) < 0)) {
      return (const Color(0xFFFFF4E5), const Color(0xFFB54708));
    }
    return (const Color(0xFFE8F7EE), const Color(0xFF027A48));
  }

  List<LogEntryItem> get _recentLogs => _logs.take(4).toList();

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? _parseApiDate(String? value) {
    final parsed = DateTime.tryParse(value ?? '');
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  String _formatApiDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _formatDisplayDate(String? value) {
    final parsed = DateTime.tryParse(value ?? '');
    if (parsed == null) {
      return value ?? 'Unknown date';
    }
    return DateFormat('MMM d, yyyy').format(parsed);
  }

  String _formatShortDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('MMM d').format(parsed);
  }

  void _openRoute(String route) {
    Navigator.pushNamed(context, route);
  }

  void _handlePrimaryAction() {
    if (_profile == null) {
      _openRoute(AppRoutes.internshipProfile);
      return;
    }

    if (!_hasTodayLog) {
      _openRoute(AppRoutes.logbook);
      return;
    }

    if (_pendingLogsCount > 0) {
      _openRoute(AppRoutes.logbook);
      return;
    }

    if (_isBehindPace) {
      _openRoute(AppRoutes.logbook);
      return;
    }

    _openRoute(AppRoutes.studentReport);
  }

  String get _primaryActionLabel {
    if (_profile == null) return 'Complete Internship Profile';
    if (!_hasTodayLog) return 'Add Today\'s Log';
    if (_pendingLogsCount > 0) return 'Review Pending Logs';
    if (_isBehindPace) return 'Catch Up in Logbook';
    return 'View Full Report';
  }

  IconData get _primaryActionIcon {
    if (_profile == null) return Icons.business_center_outlined;
    if (!_hasTodayLog) return Icons.edit_note;
    if (_pendingLogsCount > 0) return Icons.pending_actions_outlined;
    if (_isBehindPace) return Icons.edit_note;
    return Icons.assessment_outlined;
  }

  String get _nextActionTitle {
    if (_profile == null) {
      return 'Complete your internship profile';
    }
    if (!_hasTodayLog) {
      return 'Add today\'s log entry';
    }
    if (_pendingLogsCount > 0) {
      final noun = _pendingLogsCount == 1 ? 'log' : 'logs';
      return 'You have $_pendingLogsCount $noun pending review';
    }
    if (_isBehindPace) {
      return 'You are behind expected pace';
    }
    return 'You are on track';
  }

  String get _nextActionDescription {
    if (_profile == null) {
      return 'Add your company, schedule, and supervisor details so progress tracking and reporting can work.';
    }
    if (!_hasTodayLog) {
      return 'You haven\'t added today\'s log yet. Submit it now so your internship record stays current.';
    }
    if (_pendingLogsCount > 0) {
      return 'Your recent submissions are waiting for supervisor review. You can still open the logbook to inspect them.';
    }
    final paceDelta = _paceDeltaAfterPending;
    if (paceDelta != null && paceDelta < 0) {
      return 'You are ${paceDelta.abs()} hours behind expected pace. Add or update logs so your approved hours can catch up.';
    }
    return 'No immediate action is blocking you. Keep your DTR and daily logs current.';
  }

  Color get _nextActionColor {
    if (_profile == null) {
      return const Color(0xFFB42318);
    }
    if (!_hasTodayLog) {
      return const Color(0xFFB54708);
    }
    if (_pendingLogsCount > 0 || _isBehindPace) {
      return const Color(0xFFB54708);
    }
    return const Color(0xFF027A48);
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 640;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${widget.userName}',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: const Color(0xFF102A56),
                fontWeight: FontWeight.w800,
                fontSize: isCompact ? 28 : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _profile == null
                  ? 'Set up your internship details, submit logs, and keep your approved hours moving.'
                  : 'Track what needs attention today, monitor pace, and jump back into the internship workflow.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF4A6480),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Pull down to refresh dashboard data',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6B7F99),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNextActionSection() {
    return DashboardInfoCard(
      title: 'Next Action',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 640;

          final attentionChip = Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: _attentionChipColors.$1,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _attentionChipLabel,
              style: TextStyle(
                color: _attentionChipColors.$2,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          );

          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompact) ...[
                Text(
                  _nextActionTitle,
                  style: const TextStyle(
                    color: Color(0xFF102A56),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                attentionChip,
              ] else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _nextActionTitle,
                        style: const TextStyle(
                          color: Color(0xFF102A56),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    attentionChip,
                  ],
                ),
              const SizedBox(height: 6),
              Text(
                _nextActionDescription,
                style: const TextStyle(
                  color: Color(0xFF4A6480),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: isCompact ? double.infinity : null,
                child: FilledButton.icon(
                  onPressed: _handlePrimaryAction,
                  icon: Icon(_primaryActionIcon),
                  label: Text(_primaryActionLabel),
                ),
              ),
            ],
          );

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _nextActionColor.withValues(alpha: 0.08),
              border: Border.all(
                color: _nextActionColor.withValues(alpha: 0.18),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: isCompact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _nextActionColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(_primaryActionIcon, color: _nextActionColor),
                      ),
                      const SizedBox(height: 14),
                      content,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _nextActionColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(_primaryActionIcon, color: _nextActionColor),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: content),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryAndMetricsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final summaryWidth = constraints.maxWidth >= 980
            ? (constraints.maxWidth - 16) * 0.4
            : constraints.maxWidth;
        final metricsWidth = constraints.maxWidth >= 980
            ? (constraints.maxWidth - 16) * 0.6
            : constraints.maxWidth;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: summaryWidth,
              child: DashboardInfoCard(
                title: 'Internship Summary',
                child: _buildInternshipSummary(),
              ),
            ),
            SizedBox(
              width: metricsWidth,
              child: DashboardInfoCard(
                title: 'Internship Status',
                child: LayoutBuilder(
                  builder: (context, metricConstraints) {
                    final isWideMetrics = metricConstraints.maxWidth >= 620;
                    final tileWidth = isWideMetrics
                        ? (metricConstraints.maxWidth - 12) / 2
                        : metricConstraints.maxWidth;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _MetricTile(
                          width: tileWidth,
                          label: 'Approved Hours',
                          value: '$_approvedHours h',
                          helper: 'Accepted by supervisor',
                          icon: Icons.verified_outlined,
                          tone: const _TileTone(
                            background: Color(0xFFF3FBF7),
                            border: Color(0xFFCDEEDC),
                            icon: Color(0xFF027A48),
                          ),
                        ),
                        _MetricTile(
                          width: tileWidth,
                          label: 'Pending Hours',
                          value: '$_pendingHours h',
                          helper: 'Awaiting review',
                          icon: Icons.pending_actions_outlined,
                          tone: const _TileTone(
                            background: Color(0xFFFFF8ED),
                            border: Color(0xFFFFE1B3),
                            icon: Color(0xFFB54708),
                          ),
                        ),
                        _MetricTile(
                          width: tileWidth,
                          label: 'Rejected Logs',
                          value: '$_rejectedLogsCount',
                          helper: 'Needs correction or resubmission',
                          icon: Icons.report_gmailerrorred_outlined,
                          tone: const _TileTone(
                            background: Color(0xFFFFF4F4),
                            border: Color(0xFFFBCACA),
                            icon: Color(0xFFB42318),
                          ),
                        ),
                        _MetricTile(
                          width: tileWidth,
                          label: 'Days Remaining',
                          value: _daysRemaining?.toString() ?? 'N/A',
                          helper: 'Until internship end date',
                          icon: Icons.calendar_month_outlined,
                          tone: const _TileTone(
                            background: Color(0xFFF5F8FF),
                            border: Color(0xFFD6E1FF),
                            icon: Color(0xFF325EA8),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInternshipSummary() {
    if (_isLoading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_profileError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _profileError!,
            style: const TextStyle(color: Color(0xFFB42318)),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loadDashboard,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      );
    }

    if (_profile == null) {
      return const Text(
        'No internship profile is active yet. Complete the profile to unlock progress tracking, adviser visibility, and report generation.',
        style: TextStyle(color: Color(0xFF4A6480), height: 1.4),
      );
    }

    final profile = _profile!;
    final supervisorAssigned =
        profile.supervisorName?.trim().isNotEmpty == true ||
        profile.supervisorId != null;
    final adviserAssigned = profile.adviserId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SummaryChip(
              icon: Icons.business_center_outlined,
              label: 'Profile Active',
              color: const Color(0xFF027A48),
              background: const Color(0xFFE8F7EE),
            ),
            _SummaryChip(
              icon: Icons.person_pin_circle_outlined,
              label: supervisorAssigned
                  ? 'Supervisor Assigned'
                  : 'No Supervisor',
              color: supervisorAssigned
                  ? const Color(0xFF027A48)
                  : const Color(0xFFB54708),
              background: supervisorAssigned
                  ? const Color(0xFFE8F7EE)
                  : const Color(0xFFFFF4E5),
            ),
            _SummaryChip(
              icon: Icons.school_outlined,
              label: adviserAssigned ? 'Adviser Assigned' : 'No Adviser',
              color: adviserAssigned
                  ? const Color(0xFF027A48)
                  : const Color(0xFFB54708),
              background: adviserAssigned
                  ? const Color(0xFFE8F7EE)
                  : const Color(0xFFFFF4E5),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SummaryRow(label: 'Company', value: profile.companyName),
        _SummaryRow(label: 'Required Hours', value: '${profile.requiredHours}'),
        _SummaryRow(
          label: 'Schedule',
          value:
              '${_formatDisplayDate(profile.startDate)} to ${_formatDisplayDate(profile.endDate)}',
        ),
        _SummaryRow(
          label: 'Supervisor',
          value: supervisorAssigned
              ? (profile.supervisorName?.trim().isNotEmpty == true
                    ? profile.supervisorName!
                    : 'Assigned')
              : 'Not assigned',
        ),
        _SummaryRow(
          label: 'Adviser',
          value: adviserAssigned ? 'Assigned' : 'Not assigned',
        ),
      ],
    );
  }

  Widget _buildProgressAndPaceSection() {
    final progressRatio = _requiredHours > 0
        ? (_approvedHours / _requiredHours).clamp(0.0, 1.0)
        : 0.0;

    final progressBadgeTone = switch (_paceDeltaAfterPending) {
      int value when value < 0 => (
        const Color(0xFFFFF4E5),
        const Color(0xFFB54708),
      ),
      int value when value > 0 => (
        const Color(0xFFE8F7EE),
        const Color(0xFF027A48),
      ),
      _ => (const Color(0xFFEAF2FF), const Color(0xFF325EA8)),
    };

    return DashboardInfoCard(
      title: 'Progress and Pace',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 640;
          final paceTileWidth = isCompact
              ? constraints.maxWidth
              : constraints.maxWidth >= 920
              ? (constraints.maxWidth - 36) / 4
              : (constraints.maxWidth - 12) / 2;

          final progressBadge = Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: progressBadgeTone.$1,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${(progressRatio * 100).round()}%',
              style: TextStyle(
                color: progressBadgeTone.$2,
                fontWeight: FontWeight.w800,
              ),
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompact) ...[
                Text(
                  _requiredHours > 0
                      ? 'Approved Hours: $_approvedHours / $_requiredHours hours'
                      : 'Approved Hours: $_approvedHours hours',
                  style: const TextStyle(
                    color: Color(0xFF102A56),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                progressBadge,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _requiredHours > 0
                            ? 'Approved Hours: $_approvedHours / $_requiredHours hours'
                            : 'Approved Hours: $_approvedHours hours',
                        style: const TextStyle(
                          color: Color(0xFF102A56),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    progressBadge,
                  ],
                ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 12,
                  value: progressRatio,
                  backgroundColor: const Color(0xFFD8E2EC),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF0F4C5C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 12,
              value: progressRatio,
              backgroundColor: const Color(0xFFD8E2EC),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF0F4C5C),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _PaceTile(
                label: 'Expected by Today',
                value: _expectedHoursByToday != null
                    ? '${_expectedHoursByToday!} h'
                    : 'N/A',
              ),
              _PaceTile(label: 'Approved', value: '$_approvedHours h'),
              _PaceTile(label: 'Pending Review', value: '$_pendingHours h'),
              _PaceTile(
                label: 'Pace After Pending',
                value: () {
                  final paceDelta = _paceDeltaAfterPending;
                  if (paceDelta == null) return 'N/A';
                  if (paceDelta < 0) return 'Behind by ${paceDelta.abs()} h';
                  if (paceDelta > 0) return 'Ahead by $paceDelta h';
                  return 'On pace';
                }(),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _PaceTile(
                    width: paceTileWidth,
                    label: 'Expected by Today',
                    value: _expectedHoursByToday != null
                        ? '${_expectedHoursByToday!} h'
                        : 'N/A',
                  ),
                  _PaceTile(
                    width: paceTileWidth,
                    label: 'Approved',
                    value: '$_approvedHours h',
                  ),
                  _PaceTile(
                    width: paceTileWidth,
                    label: 'Pending Review',
                    value: '$_pendingHours h',
                  ),
                  _PaceTile(
                    width: paceTileWidth,
                    label: 'Pace After Pending',
                    value: () {
                      final paceDelta = _paceDeltaAfterPending;
                      if (paceDelta == null) return 'N/A';
                      if (paceDelta < 0) return 'Behind by ${paceDelta.abs()} h';
                      if (paceDelta > 0) return 'Ahead by $paceDelta h';
                      return 'On pace';
                    }(),
                  ),
                ],
              ),
              if (_reportError != null) ...[
                const SizedBox(height: 14),
                Text(
                  _reportError!,
                  style: const TextStyle(color: Color(0xFFB42318)),
                ),
              ] else ...[
                const SizedBox(height: 12),
                Text(
                  () {
                    if (_requiredHours <= 0) {
                      return 'Progress tracking will improve once required hours are available.';
                    }

                    final approvedDelta = _paceDelta;
                    final pendingDelta = _paceDeltaAfterPending;
                    if (approvedDelta != null &&
                        pendingDelta != null &&
                        approvedDelta < 0 &&
                        _pendingHours > 0) {
                      final pendingStatus = pendingDelta < 0
                          ? 'behind by ${pendingDelta.abs()} hours'
                          : pendingDelta > 0
                          ? 'ahead by $pendingDelta hours'
                          : 'on pace';

                      return 'You are ${approvedDelta.abs()} approved hours behind today. Pending review ($_pendingHours h) could move you to $pendingStatus once reviewed.';
                    }

                    return 'Remaining: ${math.max(0, _requiredHours - _approvedHours)} hours';
                  }(),
                  style: const TextStyle(
                    color: Color(0xFF4A6480),
                    fontSize: 16,
                  ),
                ),
              ],
            ],
          ),
          if (_reportError != null) ...[
            const SizedBox(height: 14),
            Text(
              _reportError!,
              style: const TextStyle(color: Color(0xFFB42318)),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(() {
              if (_requiredHours <= 0) {
                return 'Progress tracking will improve once required hours are available.';
              }

              final approvedDelta = _paceDelta;
              final pendingDelta = _paceDeltaAfterPending;
              if (approvedDelta != null &&
                  pendingDelta != null &&
                  approvedDelta < 0 &&
                  _pendingHours > 0) {
                final pendingStatus = pendingDelta < 0
                    ? 'behind by ${pendingDelta.abs()} hours'
                    : pendingDelta > 0
                    ? 'ahead by $pendingDelta hours'
                    : 'on pace';

                return 'You are ${approvedDelta.abs()} approved hours behind today. Pending review ($_pendingHours h) could move you to $pendingStatus once reviewed.';
              }

              return 'Remaining: ${math.max(0, _requiredHours - _approvedHours)} hours';
            }(), style: const TextStyle(color: Color(0xFF4A6480), fontSize: 16)),
          ],
        ],
      ),
          );
        },
        ),
    );
  }

  Widget _buildRecentLogsSection() {
    return DashboardInfoCard(
      title: 'Recent Logs',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_logsError != null)
            Text(_logsError!, style: const TextStyle(color: Color(0xFFB42318)))
          else if (_recentLogs.isEmpty)
            const Text(
              'No logs submitted yet. Start with today\'s entry so your dashboard can reflect current activity.',
              style: TextStyle(color: Color(0xFF4A6480), height: 1.4),
            )
          else
            ..._recentLogs.asMap().entries.map((entry) {
              final index = entry.key;
              final log = entry.value;
              final actionLabel = switch (log.status.toUpperCase()) {
                'PENDING' => 'Edit in Logbook',
                'REJECTED' => 'Resubmit in Logbook',
                _ => 'View in Logbook',
              };

              return Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 640;

                      final details = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                _formatShortDate(log.date),
                                style: const TextStyle(
                                  color: Color(0xFF102A56),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              _StatusBadge(status: log.status),
                              Text(
                                '${log.hoursRendered} h',
                                style: const TextStyle(
                                  color: Color(0xFF4A6480),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            log.taskDescription,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF4A6480),
                              height: 1.35,
                            ),
                          ),
                        ],
                      );

                      final action = SizedBox(
                        width: isCompact ? double.infinity : null,
                        child: FilledButton.tonal(
                          onPressed: () => _openRoute(AppRoutes.logbook),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            minimumSize: const Size(48, 36),
                          ),
                          child: Text(actionLabel),
                        ),
                      );

                      return isCompact
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                details,
                                const SizedBox(height: 12),
                                action,
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: details),
                                const SizedBox(width: 12),
                                action,
                              ],
                            );
                    },
                  ),
                  if (index != _recentLogs.length - 1) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                  ],
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return DashboardInfoCard(
      title: 'Quick Actions',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 640;
          final actionWidth = isCompact
              ? constraints.maxWidth
              : constraints.maxWidth >= 920
              ? (constraints.maxWidth - 36) / 4
              : (constraints.maxWidth - 12) / 2;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: actionWidth,
                child: FilledButton.icon(
                  onPressed: () => _openRoute(AppRoutes.logbook),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Add Today\'s Log'),
                ),
              ),
              SizedBox(
                width: actionWidth,
                child: FilledButton.icon(
                  onPressed: () => _openRoute(AppRoutes.studentDtr),
                  icon: const Icon(Icons.punch_clock_rounded),
                  label: const Text('Continue DTR'),
                ),
              ),
              SizedBox(
                width: actionWidth,
                child: OutlinedButton.icon(
                  onPressed: () => _openRoute(AppRoutes.studentReport),
                  icon: const Icon(Icons.assessment_outlined),
                  label: const Text('View Full Report'),
                ),
              ),
              SizedBox(
                width: actionWidth,
                child: OutlinedButton.icon(
                  onPressed: () => _openRoute(AppRoutes.internshipProfile),
                  icon: const Icon(Icons.business_center_outlined),
                  label: const Text('Update Profile'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDashboardErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        border: Border.all(color: const Color(0xFFFBCACA)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: Color(0xFFB42318)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Unable to load student dashboard',
                  style: TextStyle(
                    color: Color(0xFF102A56),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _dashboardError ??
                'An unexpected error occurred. Please try again.',
            style: const TextStyle(color: Color(0xFFB42318), height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadDashboard,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final token = context.watch<AuthProvider>().token ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('InternTrack'),
        actions: [
          const SettingsShortcutButton(),
          NotificationBellButton(token: token),
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 640 ? 12.0 : 16.0;

            return ListView(
              padding: EdgeInsets.all(horizontalPadding),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1220),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 20),
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_dashboardError != null)
                          _buildDashboardErrorState()
                        else ...[
                          _buildNextActionSection(),
                          const SizedBox(height: 16),
                          _buildSummaryAndMetricsSection(),
                          const SizedBox(height: 16),
                          _buildProgressAndPaceSection(),
                          const SizedBox(height: 16),
                          _buildRecentLogsSection(),
                          const SizedBox(height: 16),
                          _buildQuickActionsSection(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF4A6480),
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Color(0xFF102A56),
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.width,
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.tone,
  });

  final double width;
  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final _TileTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.background,
        border: Border.all(color: tone.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone.icon, size: 20),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF4A6480),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF102A56),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            style: const TextStyle(
              color: Color(0xFF6B7F99),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _TileTone {
  const _TileTone({
    required this.background,
    required this.border,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color icon;
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaceTile extends StatelessWidget {
  const _PaceTile({required this.label, required this.value});
  const _PaceTile({
    required this.width,
    required this.label,
    required this.value,
  });

  final double width;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFD8E2EC)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF4A6480),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF102A56),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    final (background, foreground) = switch (normalized) {
      'APPROVED' => (const Color(0xFFE8F7EE), const Color(0xFF027A48)),
      'REJECTED' => (const Color(0xFFFEECEE), const Color(0xFFB42318)),
      _ => (const Color(0xFFFFF4E5), const Color(0xFFB54708)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
