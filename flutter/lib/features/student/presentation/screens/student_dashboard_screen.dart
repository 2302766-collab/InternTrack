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
import '../../../../shared/widgets/dashboard_refresh_widgets.dart';
import '../../../../shared/widgets/notification_bell_button.dart';
import '../../../../shared/widgets/settings_shortcut_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/student_scaffold.dart';

enum _StudentDashboardSection { profile, report, logs }

class StudentDashboardScreen extends StatefulWidget {
  final String userName;
  final String? companyName;
  final int? requiredHours;
  final InternshipService? internshipService;
  final LogbookService? logbookService;
  final StudentReportService? reportService;
  final DateTime Function()? clock;

  const StudentDashboardScreen({
    super.key,
    required this.userName,
    this.companyName,
    this.requiredHours,
    this.internshipService,
    this.logbookService,
    this.reportService,
    this.clock,
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

  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _didLoadDashboard = false;
  bool _hasCompletedFirstLoad = false;
  DateTime? _lastUpdated;
  final Map<_StudentDashboardSection, bool> _sectionLoading =
      <_StudentDashboardSection, bool>{
        _StudentDashboardSection.profile: false,
        _StudentDashboardSection.report: false,
        _StudentDashboardSection.logs: false,
      };
  final Map<_StudentDashboardSection, String?> _sectionErrors =
      <_StudentDashboardSection, String?>{
        _StudentDashboardSection.profile: null,
        _StudentDashboardSection.report: null,
        _StudentDashboardSection.logs: null,
      };

  String? get _profileError => _sectionErrors[_StudentDashboardSection.profile];
  String? get _reportError => _sectionErrors[_StudentDashboardSection.report];
  String? get _logsError => _sectionErrors[_StudentDashboardSection.logs];

  DateTime _now() => (widget.clock ?? DateTime.now)();

  String _userFacingErrorMessage(Object error) {
    if (error is ApiException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

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
    if (_isRefreshing) return;

    final token = context.read<AuthProvider>().token ?? '';
    if (token.isEmpty) {
      setState(() {
        _isInitialLoading = false;
        _hasCompletedFirstLoad = true;
        _sectionErrors[_StudentDashboardSection.profile] =
            'Unable to load student dashboard.';
      });
      return;
    }

    final showFullScreenLoader = !_hasCompletedFirstLoad;

    setState(() {
      _isInitialLoading = showFullScreenLoader;
      _isRefreshing = !showFullScreenLoader;
      _sectionLoading[_StudentDashboardSection.profile] = true;
      _sectionLoading[_StudentDashboardSection.report] = true;
      _sectionLoading[_StudentDashboardSection.logs] = true;
    });

    var successfulSections = 0;
    final profileResult = await _refreshProfileSection(markLoading: false);
    if (!mounted) return;

    if (profileResult.succeeded) {
      successfulSections += 1;
    }

    if (profileResult.value == null && profileResult.succeeded) {
      setState(() {
        _report = null;
        _logs = <LogEntryItem>[];
        _sectionErrors[_StudentDashboardSection.report] = null;
        _sectionErrors[_StudentDashboardSection.logs] = null;
        _sectionLoading[_StudentDashboardSection.report] = false;
        _sectionLoading[_StudentDashboardSection.logs] = false;
      });
    } else if (profileResult.value != null || _profile != null) {
      final results = await Future.wait<_SectionRefreshResult<dynamic>>([
        _refreshReportSection(markLoading: false),
        _refreshLogsSection(markLoading: false),
      ]);

      successfulSections += results.where((result) => result.succeeded).length;
    } else {
      setState(() {
        _sectionLoading[_StudentDashboardSection.report] = false;
        _sectionLoading[_StudentDashboardSection.logs] = false;
      });
    }

    if (!mounted) return;

    setState(() {
      _isInitialLoading = false;
      _isRefreshing = false;
      _hasCompletedFirstLoad = true;
      if (successfulSections > 0) {
        _lastUpdated = _now();
      }
    });
  }

  Future<void> _refreshSection(_StudentDashboardSection section) async {
    if (_sectionLoading[section] == true) return;

    setState(() {
      _sectionLoading[section] = true;
    });

    var succeeded = false;

    switch (section) {
      case _StudentDashboardSection.profile:
        final result = await _refreshProfileSection(markLoading: false);
        succeeded = result.succeeded;
        if (result.succeeded && mounted) {
          if (result.value == null) {
            setState(() {
              _report = null;
              _logs = <LogEntryItem>[];
              _sectionErrors[_StudentDashboardSection.report] = null;
              _sectionErrors[_StudentDashboardSection.logs] = null;
              _sectionLoading[_StudentDashboardSection.report] = false;
              _sectionLoading[_StudentDashboardSection.logs] = false;
            });
          } else {
            setState(() {
              _sectionLoading[_StudentDashboardSection.report] = true;
              _sectionLoading[_StudentDashboardSection.logs] = true;
            });
            final dependentResults =
                await Future.wait<_SectionRefreshResult<dynamic>>([
                  _refreshReportSection(markLoading: false),
                  _refreshLogsSection(markLoading: false),
                ]);
            succeeded =
                dependentResults.any((item) => item.succeeded) || succeeded;
          }
        }
        break;
      case _StudentDashboardSection.report:
        succeeded = (await _refreshReportSection(markLoading: false)).succeeded;
        break;
      case _StudentDashboardSection.logs:
        succeeded = (await _refreshLogsSection(markLoading: false)).succeeded;
        break;
    }

    if (!mounted) return;

    setState(() {
      if (succeeded) {
        _lastUpdated = _now();
      }
    });
  }

  Future<_SectionRefreshResult<InternshipProfile?>> _refreshProfileSection({
    bool markLoading = true,
  }) async {
    if (markLoading && mounted) {
      setState(() {
        _sectionLoading[_StudentDashboardSection.profile] = true;
      });
    }

    try {
      final profile = await _internshipService.getInternshipProfile();
      if (!mounted) return _SectionRefreshResult<InternshipProfile?>.failure();

      setState(() {
        _profile = profile;
        _sectionErrors[_StudentDashboardSection.profile] = null;
        _sectionLoading[_StudentDashboardSection.profile] = false;
      });

      return _SectionRefreshResult<InternshipProfile?>.success(profile);
    } catch (e) {
      if (!mounted) return _SectionRefreshResult<InternshipProfile?>.failure();

      setState(() {
        _sectionErrors[_StudentDashboardSection.profile] =
            _userFacingErrorMessage(e);
        _sectionLoading[_StudentDashboardSection.profile] = false;
      });

      return _SectionRefreshResult<InternshipProfile?>.failure();
    }
  }

  Future<_SectionRefreshResult<StudentReportData>> _refreshReportSection({
    bool markLoading = true,
  }) async {
    if (_profile == null) {
      if (mounted) {
        setState(() {
          _sectionErrors[_StudentDashboardSection.report] = null;
          _sectionLoading[_StudentDashboardSection.report] = false;
        });
      }

      return _SectionRefreshResult<StudentReportData>.failure();
    }

    if (markLoading && mounted) {
      setState(() {
        _sectionLoading[_StudentDashboardSection.report] = true;
      });
    }

    try {
      final report = await _reportService.getReport();
      if (!mounted) return _SectionRefreshResult<StudentReportData>.failure();

      setState(() {
        _report = report;
        _sectionErrors[_StudentDashboardSection.report] = null;
        _sectionLoading[_StudentDashboardSection.report] = false;
      });

      return _SectionRefreshResult<StudentReportData>.success(report);
    } catch (e) {
      if (!mounted) return _SectionRefreshResult<StudentReportData>.failure();

      setState(() {
        _sectionErrors[_StudentDashboardSection.report] =
            _userFacingErrorMessage(e);
        _sectionLoading[_StudentDashboardSection.report] = false;
      });

      return _SectionRefreshResult<StudentReportData>.failure();
    }
  }

  Future<_SectionRefreshResult<List<LogEntryItem>>> _refreshLogsSection({
    bool markLoading = true,
  }) async {
    if (_profile == null) {
      if (mounted) {
        setState(() {
          _sectionErrors[_StudentDashboardSection.logs] = null;
          _sectionLoading[_StudentDashboardSection.logs] = false;
        });
      }

      return _SectionRefreshResult<List<LogEntryItem>>.failure();
    }

    if (markLoading && mounted) {
      setState(() {
        _sectionLoading[_StudentDashboardSection.logs] = true;
      });
    }

    try {
      final logs = await _logbookService.getLogs();
      if (!mounted) return _SectionRefreshResult<List<LogEntryItem>>.failure();

      setState(() {
        _logs = logs;
        _sectionErrors[_StudentDashboardSection.logs] = null;
        _sectionLoading[_StudentDashboardSection.logs] = false;
      });

      return _SectionRefreshResult<List<LogEntryItem>>.success(logs);
    } catch (e) {
      if (!mounted) return _SectionRefreshResult<List<LogEntryItem>>.failure();

      setState(() {
        _sectionErrors[_StudentDashboardSection.logs] =
            _userFacingErrorMessage(e);
        _sectionLoading[_StudentDashboardSection.logs] = false;
      });

      return _SectionRefreshResult<List<LogEntryItem>>.failure();
    }
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

  bool get _profileComplete => _profile != null;

  String get _attentionChipLabel {
    if (!_profileComplete) return 'Profile Incomplete';
    if (!_hasTodayLog) return 'Action Needed';
    if (_pendingLogsCount > 0) return 'For Review';
    if ((_paceDelta ?? 0) < 0) return 'Needs Recovery';
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

  bool _isSectionLoading(_StudentDashboardSection section) {
    return _sectionLoading[section] ?? false;
  }

  Widget _buildSectionRefreshingHint(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7F99),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        DashboardSkeletonBlock(height: 30, width: 160, radius: 999),
        SizedBox(height: 14),
        DashboardSkeletonBlock(height: 16),
        SizedBox(height: 10),
        DashboardSkeletonBlock(height: 16, width: 220),
        SizedBox(height: 10),
        DashboardSkeletonBlock(height: 16, width: 250),
        SizedBox(height: 10),
        DashboardSkeletonBlock(height: 16, width: 180),
      ],
    );
  }

  Widget _buildProgressSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        DashboardSkeletonBlock(height: 24, width: 240),
        SizedBox(height: 14),
        DashboardSkeletonBlock(height: 12, radius: 999),
        SizedBox(height: 16),
        DashboardSkeletonBlock(height: 64),
        SizedBox(height: 12),
        DashboardSkeletonBlock(height: 16, width: 220),
      ],
    );
  }

  Widget _buildLogsSkeleton() {
    return Column(
      children: const [
        DashboardSkeletonBlock(height: 72),
        SizedBox(height: 12),
        DashboardSkeletonBlock(height: 72),
        SizedBox(height: 12),
        DashboardSkeletonBlock(height: 72),
      ],
    );
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

    if ((_paceDelta ?? 0) < 0) {
      _openRoute(AppRoutes.studentDtr);
      return;
    }

    _openRoute(AppRoutes.studentReport);
  }

  String get _primaryActionLabel {
    if (_profile == null) return 'Complete Internship Profile';
    if (!_hasTodayLog) return 'Add Today\'s Log';
    if (_pendingLogsCount > 0) return 'Review Pending Logs';
    if ((_paceDelta ?? 0) < 0) return 'Continue Daily Time Record';
    return 'View Full Report';
  }

  IconData get _primaryActionIcon {
    if (_profile == null) return Icons.business_center_outlined;
    if (!_hasTodayLog) return Icons.edit_note;
    if (_pendingLogsCount > 0) return Icons.pending_actions_outlined;
    if ((_paceDelta ?? 0) < 0) return Icons.punch_clock_rounded;
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
    if ((_paceDelta ?? 0) < 0) {
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
    final paceDelta = _paceDelta;
    if (paceDelta != null && paceDelta < 0) {
      return 'You are ${paceDelta.abs()} hours behind the expected pace for this point in your internship schedule.';
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
    if (_pendingLogsCount > 0 || ((_paceDelta ?? 0) < 0)) {
      return const Color(0xFFB54708);
    }
    return const Color(0xFF027A48);
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome, ${widget.userName}',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: const Color(0xFF102A56),
            fontWeight: FontWeight.w800,
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
        DashboardRefreshStatus(
          lastUpdated: _lastUpdated,
          isRefreshing: _isRefreshing,
          pullToRefreshLabel: 'Pull down to refresh dashboard data',
          refreshingLabel: 'Refreshing student dashboard...',
        ),
      ],
    );
  }

  Widget _buildNextActionSection() {
    return DashboardInfoCard(
      title: 'Next Action',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _nextActionColor.withValues(alpha: 0.08),
          border: Border.all(color: _nextActionColor.withValues(alpha: 0.18)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      Container(
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
                      ),
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
                  FilledButton.icon(
                    onPressed: _handlePrimaryAction,
                    icon: Icon(_primaryActionIcon),
                    label: Text(_primaryActionLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final isLoading = _isSectionLoading(_StudentDashboardSection.profile);

    if (isLoading &&
        _profile == null &&
        (_profileError != null || !_hasCompletedFirstLoad)) {
      return _buildSummarySkeleton();
    }

    if (_profileError != null && _profile == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardInlineNotice(
            message: _profileError!,
            onRetry: _loadDashboard,
          ),
        ],
      );
    }

    if (_profile == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No internship profile is active yet. Complete the profile to unlock progress tracking, adviser visibility, and report generation.',
            style: TextStyle(color: Color(0xFF4A6480), height: 1.4),
          ),
          if (isLoading)
            _buildSectionRefreshingHint('Checking internship profile...'),
        ],
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
        if (_profileError != null) ...[
          const SizedBox(height: 12),
          DashboardInlineNotice(
            message: _profileError!,
            onRetry: () => _refreshSection(_StudentDashboardSection.profile),
          ),
        ] else if (isLoading)
          _buildSectionRefreshingHint('Refreshing internship profile...'),
      ],
    );
  }

  Widget _buildProgressAndPaceSection() {
    final isLoading = _isSectionLoading(_StudentDashboardSection.report);
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
      child: _profile != null && _report == null && isLoading
          ? _buildProgressSkeleton()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    Container(
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
                    _PaceTile(
                      label: 'Pending Review',
                      value: '$_pendingHours h',
                    ),
                    _PaceTile(
                      label: 'Pace After Pending',
                      value: () {
                        final paceDelta = _paceDeltaAfterPending;
                        if (paceDelta == null) return 'N/A';
                        if (paceDelta < 0) {
                          return 'Behind by ${paceDelta.abs()} h';
                        }
                        if (paceDelta > 0) return 'Ahead by $paceDelta h';
                        return 'On pace';
                      }(),
                    ),
                  ],
                ),
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
                if (_reportError != null) ...[
                  const SizedBox(height: 14),
                  DashboardInlineNotice(
                    message: _reportError!,
                    onRetry: () =>
                        _refreshSection(_StudentDashboardSection.report),
                  ),
                ] else if (isLoading)
                  _buildSectionRefreshingHint('Refreshing progress metrics...'),
              ],
            ),
    );
  }

  Widget _buildRecentLogsSection() {
    final isLoading = _isSectionLoading(_StudentDashboardSection.logs);

    return DashboardInfoCard(
      title: 'Recent Logs',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading && _logs.isEmpty && _profile != null)
            _buildLogsSkeleton()
          else if (_logsError != null && _logs.isEmpty)
            DashboardInlineNotice(
              message: _logsError!,
              onRetry: () => _refreshSection(_StudentDashboardSection.logs),
            )
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _formatShortDate(log.date),
                                  style: const TextStyle(
                                    color: Color(0xFF102A56),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _StatusBadge(status: log.status),
                                const SizedBox(width: 10),
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
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonal(
                        onPressed: () => _openRoute(AppRoutes.logbook),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          minimumSize: const Size(48, 36),
                        ),
                        child: Text(actionLabel),
                      ),
                    ],
                  ),
                  if (index != _recentLogs.length - 1) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                  ],
                ],
              );
            }),
          if (_logsError != null && _logs.isNotEmpty) ...[
            const SizedBox(height: 14),
            DashboardInlineNotice(
              message: _logsError!,
              onRetry: () => _refreshSection(_StudentDashboardSection.logs),
            ),
          ] else if (isLoading)
            _buildSectionRefreshingHint('Refreshing recent logs...'),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return DashboardInfoCard(
      title: 'Quick Actions',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.icon(
            onPressed: () => _openRoute(AppRoutes.logbook),
            icon: const Icon(Icons.edit_note),
            label: const Text('Add Today\'s Log'),
          ),
          FilledButton.icon(
            onPressed: () => _openRoute(AppRoutes.studentDtr),
            icon: const Icon(Icons.punch_clock_rounded),
            label: const Text('Continue DTR'),
          ),
          OutlinedButton.icon(
            onPressed: () => _openRoute(AppRoutes.studentReport),
            icon: const Icon(Icons.assessment_outlined),
            label: const Text('View Full Report'),
          ),
          OutlinedButton.icon(
            onPressed: () => _openRoute(AppRoutes.internshipProfile),
            icon: const Icon(Icons.business_center_outlined),
            label: const Text('Update Profile'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final token = context.watch<AuthProvider>().token ?? '';

    return StudentScaffold(
      currentRoute: AppRoutes.studentDashboard,
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
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1220),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 20),
                    if (_isInitialLoading && !_hasCompletedFirstLoad)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      )
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

class _SectionRefreshResult<T> {
  const _SectionRefreshResult._({required this.succeeded, this.value});

  final bool succeeded;
  final T? value;

  factory _SectionRefreshResult.success(T? value) {
    return _SectionRefreshResult<T>._(succeeded: true, value: value);
  }

  factory _SectionRefreshResult.failure() {
    return _SectionRefreshResult<T>._(succeeded: false);
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

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
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
