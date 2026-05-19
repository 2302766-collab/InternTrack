import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/dtr_service.dart';
import '../../../../core/services/internship_service.dart';
import '../../../../core/services/logbook_service.dart';
import '../../../../core/services/student_report_service.dart';
import '../../../../core/theme/ocean_breeze_palette.dart';
import '../../../../shared/models/daily_time_record.dart';
import '../../../../shared/models/internship_profile.dart';
import '../../../../shared/models/log_entry.dart';
import '../../../../shared/models/student_report.dart';
import '../../../../shared/widgets/dashboard_info_card.dart';
import '../../../../shared/widgets/dashboard_refresh_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/student_scaffold.dart';

enum _StudentDashboardSection { profile, dtr, report, logs }

class StudentDashboardScreen extends StatefulWidget {
  final String userName;
  final String? companyName;
  final int? requiredHours;
  final InternshipService? internshipService;
  final DtrService? dtrService;
  final LogbookService? logbookService;
  final StudentReportService? reportService;
  final DateTime Function()? clock;

  const StudentDashboardScreen({
    super.key,
    required this.userName,
    this.companyName,
    this.requiredHours,
    this.internshipService,
    this.dtrService,
    this.logbookService,
    this.reportService,
    this.clock,
  });

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  static const Color _canvasColor = OceanBreezePalette.canvas;
  static const Color _headlineColor = OceanBreezePalette.textPrimary;
  static const Color _bodyColor = OceanBreezePalette.textSecondary;
  static const Color _heroStart = OceanBreezePalette.midnight;
  static const Color _heroEnd = OceanBreezePalette.deepSea;
  static const Color _accentPrimary = OceanBreezePalette.deepSea;
  static const Color _accentSecondary = OceanBreezePalette.tide;

  late final InternshipService _internshipService;
  late final DtrService _dtrService;
  late final LogbookService _logbookService;
  late final StudentReportService _reportService;
  Timer? _liveTimer;

  InternshipProfile? _profile;
  DailyTimeRecord? _dtrRecord;
  StudentReportData? _report;
  List<LogEntryItem> _logs = <LogEntryItem>[];

  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _didLoadDashboard = false;
  bool _hasCompletedFirstLoad = false;
  bool _isDtrSubmitting = false;
  String? _dashboardError;
  DateTime? _lastUpdated;
  Duration _liveElapsed = Duration.zero;

  final Map<_StudentDashboardSection, bool> _sectionLoading =
      <_StudentDashboardSection, bool>{
        _StudentDashboardSection.profile: false,
        _StudentDashboardSection.dtr: false,
        _StudentDashboardSection.report: false,
        _StudentDashboardSection.logs: false,
      };

  final Map<_StudentDashboardSection, String?> _sectionErrors =
      <_StudentDashboardSection, String?>{
        _StudentDashboardSection.profile: null,
        _StudentDashboardSection.dtr: null,
        _StudentDashboardSection.report: null,
        _StudentDashboardSection.logs: null,
      };

  String? get _profileError => _sectionErrors[_StudentDashboardSection.profile];
  String? get _dtrError => _sectionErrors[_StudentDashboardSection.dtr];
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
    _dtrService = widget.dtrService ?? DtrService(context.read<ApiClient>());
    _logbookService = widget.logbookService ?? context.read<LogbookService>();
    _reportService =
        widget.reportService ?? context.read<StudentReportService>();
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
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
        _isRefreshing = false;
        _hasCompletedFirstLoad = true;
        _dashboardError = 'Your session has expired. Please log in again.';
        _sectionErrors[_StudentDashboardSection.profile] = null;
        _sectionErrors[_StudentDashboardSection.dtr] = null;
        _sectionErrors[_StudentDashboardSection.report] = null;
        _sectionErrors[_StudentDashboardSection.logs] = null;
        _sectionLoading[_StudentDashboardSection.profile] = false;
        _sectionLoading[_StudentDashboardSection.dtr] = false;
        _sectionLoading[_StudentDashboardSection.report] = false;
        _sectionLoading[_StudentDashboardSection.logs] = false;
      });
      return;
    }

    final showFullScreenLoader = !_hasCompletedFirstLoad;

    setState(() {
      _isInitialLoading = showFullScreenLoader;
      _isRefreshing = !showFullScreenLoader;
      _dashboardError = null;
      _sectionErrors[_StudentDashboardSection.profile] = null;
      _sectionErrors[_StudentDashboardSection.dtr] = null;
      _sectionErrors[_StudentDashboardSection.report] = null;
      _sectionErrors[_StudentDashboardSection.logs] = null;
      _sectionLoading[_StudentDashboardSection.profile] = true;
      _sectionLoading[_StudentDashboardSection.dtr] = true;
      _sectionLoading[_StudentDashboardSection.report] = true;
      _sectionLoading[_StudentDashboardSection.logs] = true;
    });

    var successfulSections = 0;

    final profileResult = await _refreshProfileSection(markLoading: false);
    if (!mounted) return;

    if (profileResult.succeeded) {
      successfulSections += 1;
    }

    final dtrResult = await _refreshDtrSection(markLoading: false);
    if (!mounted) return;

    if (dtrResult.succeeded) {
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
        _dashboardError = null;
      } else {
        _dashboardError = _profileError ?? 'Unable to load student dashboard.';
      }
    });
  }

  Future<void> _refreshSection(_StudentDashboardSection section) async {
    if (_sectionLoading[section] == true) return;

    setState(() {
      _sectionLoading[section] = true;
      _dashboardError = null;
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
      case _StudentDashboardSection.dtr:
        succeeded = (await _refreshDtrSection(markLoading: false)).succeeded;
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
        _dashboardError = null;
      }
    });
  }

  Future<_SectionRefreshResult<DailyTimeRecord>> _refreshDtrSection({
    bool markLoading = true,
  }) async {
    if (markLoading && mounted) {
      setState(() {
        _sectionLoading[_StudentDashboardSection.dtr] = true;
      });
    }

    try {
      final record = await _dtrService.getTodayRecord();
      if (!mounted) {
        return _SectionRefreshResult<DailyTimeRecord>.failure();
      }

      setState(() {
        _dtrRecord = record;
        _sectionErrors[_StudentDashboardSection.dtr] = null;
        _sectionLoading[_StudentDashboardSection.dtr] = false;
      });
      _syncLiveTimer();

      return _SectionRefreshResult<DailyTimeRecord>.success(record);
    } catch (e) {
      if (!mounted) {
        return _SectionRefreshResult<DailyTimeRecord>.failure();
      }

      setState(() {
        _sectionErrors[_StudentDashboardSection.dtr] = _userFacingErrorMessage(
          e,
        );
        _sectionLoading[_StudentDashboardSection.dtr] = false;
      });

      return _SectionRefreshResult<DailyTimeRecord>.failure();
    }
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
      if (!mounted) {
        return _SectionRefreshResult<InternshipProfile?>.failure();
      }

      setState(() {
        _profile = profile;
        _sectionErrors[_StudentDashboardSection.profile] = null;
        _sectionLoading[_StudentDashboardSection.profile] = false;
      });

      return _SectionRefreshResult<InternshipProfile?>.success(profile);
    } catch (e) {
      if (!mounted) {
        return _SectionRefreshResult<InternshipProfile?>.failure();
      }

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
          _report = null;
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
      if (!mounted) {
        return _SectionRefreshResult<StudentReportData>.failure();
      }

      setState(() {
        _report = report;
        _sectionErrors[_StudentDashboardSection.report] = null;
        _sectionLoading[_StudentDashboardSection.report] = false;
      });

      return _SectionRefreshResult<StudentReportData>.success(report);
    } catch (e) {
      if (!mounted) {
        return _SectionRefreshResult<StudentReportData>.failure();
      }

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
          _logs = <LogEntryItem>[];
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
      if (!mounted) {
        return _SectionRefreshResult<List<LogEntryItem>>.failure();
      }

      setState(() {
        _logs = _sortLogsNewestFirst(logs);
        _sectionErrors[_StudentDashboardSection.logs] = null;
        _sectionLoading[_StudentDashboardSection.logs] = false;
      });

      return _SectionRefreshResult<List<LogEntryItem>>.success(logs);
    } catch (e) {
      if (!mounted) {
        return _SectionRefreshResult<List<LogEntryItem>>.failure();
      }

      setState(() {
        _sectionErrors[_StudentDashboardSection.logs] = _userFacingErrorMessage(
          e,
        );
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

  bool get _isBehindPace {
    final deltaAfterPending = _paceDeltaAfterPending;
    return deltaAfterPending != null && deltaAfterPending < 0;
  }

  bool get _profileComplete => _profile != null;

  String _formatPunchTime(DateTime? value) {
    if (value == null) return '--:--';
    return DateFormat('hh:mm a').format(value);
  }

  String _dtrActionLabel(String? nextAction) {
    return switch (nextAction) {
      'TIME_IN' => 'Time In',
      'LUNCH_OUT' => 'Time Out',
      'LUNCH_IN' => 'Time In',
      'TIME_OUT' => 'Time Out',
      _ => 'Completed',
    };
  }

  String _dtrStatusHeadline(DailyTimeRecord? record) {
    if (record == null) {
      return 'Attendance not loaded yet';
    }

    return switch (record.status) {
      'WORKING' => 'You are timed in',
      'ON_BREAK' => 'You are timed out',
      'COMPLETED' => 'Today is complete',
      _ => 'Ready to time in',
    };
  }

  String _dtrStatusDescription(DailyTimeRecord? record) {
    if (record == null) {
      return 'Open your DTR to start tracking attendance for today.';
    }

    return switch (record.status) {
      'WORKING' when record.lunchInAt == null =>
        'Your morning session is active. Use Time Out when you start your break.',
      'WORKING' =>
        'Your afternoon session is active. Use Time Out when you finish your day.',
      'ON_BREAK' => 'You are currently timed out. Use Time In when you return.',
      'COMPLETED' =>
        'Your punches for today are complete. You can still open the full DTR for details.',
      _ => 'Time in from the dashboard so attendance starts right away.',
    };
  }

  Future<void> _handleDtrAction() async {
    final token = context.read<AuthProvider>().token ?? '';
    final record = _dtrRecord;
    if (token.isEmpty ||
        record == null ||
        record.nextAction == null ||
        _isDtrSubmitting) {
      return;
    }

    setState(() {
      _isDtrSubmitting = true;
      _sectionErrors[_StudentDashboardSection.dtr] = null;
      _dashboardError = null;
    });

    try {
      late final DailyTimeRecord updatedRecord;
      switch (record.nextAction) {
        case 'TIME_IN':
          updatedRecord = await _dtrService.timeIn();
          break;
        case 'LUNCH_OUT':
          updatedRecord = await _dtrService.lunchOut();
          break;
        case 'LUNCH_IN':
          updatedRecord = await _dtrService.lunchIn();
          break;
        case 'TIME_OUT':
          updatedRecord = await _dtrService.timeOut();
          break;
        default:
          throw ApiException(
            message: 'No valid attendance action is available.',
            errorType: ApiErrorType.clientError,
          );
      }

      if (!mounted) return;

      setState(() {
        _dtrRecord = updatedRecord;
        _sectionErrors[_StudentDashboardSection.dtr] = null;
        _lastUpdated = _now();
      });
      _syncLiveTimer();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_dtrActionLabel(record.nextAction)} recorded at ${_formatPunchTime(_lastRecordedPunch(updatedRecord))}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final message = _userFacingErrorMessage(e);
      setState(() {
        _sectionErrors[_StudentDashboardSection.dtr] = message;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isDtrSubmitting = false;
        });
      }
    }
  }

  DateTime? _lastRecordedPunch(DailyTimeRecord record) {
    return record.timeOutAt ??
        record.lunchInAt ??
        record.lunchOutAt ??
        record.timeInAt;
  }

  void _syncLiveTimer() {
    _liveTimer?.cancel();

    final start = _activeSegmentStart(_dtrRecord);
    if (start == null) {
      if (!mounted) return;
      setState(() {
        _liveElapsed = Duration.zero;
      });
      return;
    }

    void tick() {
      if (!mounted) return;
      setState(() {
        _liveElapsed = _now().difference(start);
      });
    }

    tick();
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  DateTime? _activeSegmentStart(DailyTimeRecord? record) {
    if (record == null || record.status != 'WORKING') return null;
    if (record.lunchInAt != null && record.timeOutAt == null) {
      return record.lunchInAt;
    }
    if (record.timeInAt != null && record.lunchOutAt == null) {
      return record.timeInAt;
    }
    return null;
  }

  String _dtrStatusChipLabel(String? status) {
    return switch (status) {
      'WORKING' => 'Timed In',
      'ON_BREAK' => 'Break',
      'COMPLETED' => 'Complete',
      _ => 'No Record',
    };
  }

  String _formatLiveDuration(Duration duration) {
    final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  String _formatHeaderDate() {
    final parsed = DateTime.tryParse(_dtrRecord?.date ?? '');
    final value = parsed ?? _today;
    return DateFormat('EEEE, MMMM d').format(value);
  }

  String _formatTotalMinutes(int minutes) {
    final safeMinutes = minutes < 0 ? 0 : minutes;
    final hours = safeMinutes ~/ 60;
    final remainder = safeMinutes % 60;
    return '$hours h ${remainder.toString().padLeft(2, '0')} m';
  }

  String _timerHint(DailyTimeRecord? record) {
    if (record == null) return 'Time in to start tracking your attendance.';

    return switch (record.status) {
      'WORKING' when record.lunchInAt == null =>
        'Morning session is running now.',
      'WORKING' => 'Afternoon session is running now.',
      'ON_BREAK' => 'Timer is paused while you are on break.',
      'COMPLETED' => 'Your attendance for today is already complete.',
      _ => 'Use the attendance section below to start your record.',
    };
  }

  String get _attentionChipLabel {
    if (!_profileComplete) return 'Profile Incomplete';
    if (!_hasTodayLog) return 'Action Needed';
    if (_pendingLogsCount > 0) return 'For Review';
    if (_isBehindPace) return 'Needs Recovery';
    return 'On Track';
  }

  (Color, Color) get _attentionChipColors {
    if (!_profileComplete) {
      return (OceanBreezePalette.surfaceMuted, _heroStart);
    }
    if (!_hasTodayLog || _pendingLogsCount > 0 || ((_paceDelta ?? 0) < 0)) {
      return (OceanBreezePalette.surfaceSoft, _accentPrimary);
    }
    return (OceanBreezePalette.mist, _accentSecondary);
  }

  List<LogEntryItem> get _recentLogs => _logs.take(4).toList();

  DateTime get _today {
    final now = _now();
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

  String _formatLogDescription(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Activity details not provided.';
    }

    final looksLikeSeedValue =
        RegExp(r'^\d{1,2}:\d{2}$').hasMatch(trimmed) ||
        RegExp(r'^\d{2}/\d{2}$').hasMatch(trimmed) ||
        RegExp(r'^\d+(st|nd|rd|th)$', caseSensitive: false).hasMatch(trimmed);

    if (looksLikeSeedValue) {
      return 'Activity details not provided.';
    }

    return trimmed;
  }

  List<LogEntryItem> _sortLogsNewestFirst(List<LogEntryItem> logs) {
    final sorted = List<LogEntryItem>.from(logs);
    sorted.sort((a, b) {
      final aDate = DateTime.tryParse(a.date);
      final bDate = DateTime.tryParse(b.date);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return sorted;
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
      return 'Add your profile details to unlock tracking and reports.';
    }
    if (!_hasTodayLog) {
      return 'Today\'s log is still missing.';
    }
    if (_pendingLogsCount > 0) {
      return 'Recent submissions are waiting for supervisor review.';
    }
    final paceDelta = _paceDeltaAfterPending;
    if (paceDelta != null && paceDelta < 0) {
      return 'You are ${paceDelta.abs()} hours behind target pace.';
    }
    return 'Everything is on track for now.';
  }

  Color get _nextActionColor {
    if (_profile == null) {
      return _heroStart;
    }
    if (!_hasTodayLog) {
      return _accentPrimary;
    }
    if (_pendingLogsCount > 0 || _isBehindPace) {
      return _accentPrimary;
    }
    return _accentSecondary;
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final record = _dtrRecord;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 640;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isCompact ? 18 : 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_heroStart, _heroEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26124073),
                blurRadius: 28,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student Dashboard',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: isCompact ? 18 : 20,
                ),
              ),
              const SizedBox(height: 14),
              _buildHeaderTimerContent(theme, record, isCompact),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderTimerContent(
    ThemeData theme,
    DailyTimeRecord? record,
    bool isCompact,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Live Timer',
              style: theme.textTheme.titleMedium?.copyWith(
                color: const Color(0xFFD7EBF7),
                fontWeight: FontWeight.w700,
                fontSize: isCompact ? 14 : 15,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _dtrStatusChipLabel(record?.status),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _formatLiveDuration(_liveElapsed),
          style: theme.textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: isCompact ? 30 : 36,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _formatHeaderDate(),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: const Color(0xFFD7EBF7),
            fontSize: isCompact ? 13 : 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _timerHint(record),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: const Color(0xFFD7EBF7),
            height: 1.4,
            fontSize: isCompact ? 13 : 14,
          ),
        ),
        if (record != null) ...[
          const SizedBox(height: 10),
          Text(
            'Total rendered time: ${_formatTotalMinutes(record.totalWorkMinutes)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: isCompact ? 12 : 13,
            ),
          ),
        ],
        const SizedBox(height: 10),
        DefaultTextStyle(
          style: TextStyle(color: Colors.white.withValues(alpha: 0.84)),
          child: DashboardRefreshStatus(
            lastUpdated: _lastUpdated,
            isRefreshing: _isRefreshing,
            pullToRefreshLabel: '',
            refreshingLabel: 'Refreshing student dashboard...',
          ),
        ),
      ],
    );
  }

  Widget _buildNextActionSection() {
    return DashboardInfoCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 640;

          final attentionChip = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    color: _headlineColor,
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
                          color: _headlineColor,
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
                style: const TextStyle(color: _bodyColor, height: 1.4),
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
                        child: Icon(
                          _primaryActionIcon,
                          color: _nextActionColor,
                        ),
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
                        child: Icon(
                          _primaryActionIcon,
                          color: _nextActionColor,
                        ),
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

  Widget _buildAttendanceSection() {
    final isLoading = _isSectionLoading(_StudentDashboardSection.dtr);
    final record = _dtrRecord;
    final canSubmit = record?.nextAction != null && !_isDtrSubmitting;

    Widget punchTile({
      required String label,
      required DateTime? value,
      required IconData icon,
      required Color iconColor,
      required Color backgroundColor,
    }) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: _bodyColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatPunchTime(value),
                    style: const TextStyle(
                      color: _headlineColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return DashboardInfoCard(
      title: 'Attendance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF4FAFB),
              border: Border.all(color: const Color(0xFFD6ECEF)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dtrStatusHeadline(record),
                  style: const TextStyle(
                    color: _headlineColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _dtrStatusDescription(record),
                  style: const TextStyle(color: _bodyColor, height: 1.4),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 640;
                    return isCompact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FilledButton.icon(
                                onPressed: canSubmit ? _handleDtrAction : null,
                                icon: _isDtrSubmitting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.fingerprint_rounded),
                                label: Text(
                                  _isDtrSubmitting
                                      ? 'Saving...'
                                      : _dtrActionLabel(record?.nextAction),
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _openRoute(AppRoutes.studentDtr),
                                icon: const Icon(Icons.punch_clock_rounded),
                                label: const Text('Open Full DTR'),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              FilledButton.icon(
                                onPressed: canSubmit ? _handleDtrAction : null,
                                icon: _isDtrSubmitting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.fingerprint_rounded),
                                label: Text(
                                  _isDtrSubmitting
                                      ? 'Saving...'
                                      : _dtrActionLabel(record?.nextAction),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _openRoute(AppRoutes.studentDtr),
                                icon: const Icon(Icons.punch_clock_rounded),
                                label: const Text('Open Full DTR'),
                              ),
                            ],
                          );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 640;
              final tileWidth = isCompact
                  ? constraints.maxWidth
                  : constraints.maxWidth >= 920
                  ? (constraints.maxWidth - 36) / 4
                  : (constraints.maxWidth - 12) / 2;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: punchTile(
                      label: 'First Time In',
                      value: record?.timeInAt,
                      icon: Icons.login_rounded,
                      iconColor: const Color(0xFF027A48),
                      backgroundColor: const Color(0xFFF3FBF7),
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: punchTile(
                      label: 'First Time Out',
                      value: record?.lunchOutAt,
                      icon: Icons.logout_rounded,
                      iconColor: const Color(0xFFB54708),
                      backgroundColor: const Color(0xFFFFF8ED),
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: punchTile(
                      label: 'Second Time In',
                      value: record?.lunchInAt,
                      icon: Icons.login_rounded,
                      iconColor: const Color(0xFF027A48),
                      backgroundColor: const Color(0xFFF3FBF7),
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: punchTile(
                      label: 'Final Time Out',
                      value: record?.timeOutAt,
                      icon: Icons.logout_rounded,
                      iconColor: const Color(0xFFB54708),
                      backgroundColor: const Color(0xFFFFF8ED),
                    ),
                  ),
                ],
              );
            },
          ),
          if (_dtrError != null) ...[
            const SizedBox(height: 14),
            DashboardInlineNotice(
              message: _dtrError!,
              onRetry: () => _refreshSection(_StudentDashboardSection.dtr),
            ),
          ] else if (isLoading)
            _buildSectionRefreshingHint('Refreshing today\'s attendance...'),
        ],
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
          : LayoutBuilder(
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
                            if (paceDelta < 0) {
                              return 'Behind by ${paceDelta.abs()} h';
                            }
                            if (paceDelta > 0) {
                              return 'Ahead by $paceDelta h';
                            }
                            return 'On pace';
                          }(),
                        ),
                      ],
                    ),
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
                    if (_reportError != null) ...[
                      const SizedBox(height: 14),
                      DashboardInlineNotice(
                        message: _reportError!,
                        onRetry: () =>
                            _refreshSection(_StudentDashboardSection.report),
                      ),
                    ] else if (isLoading)
                      _buildSectionRefreshingHint(
                        'Refreshing progress metrics...',
                      ),
                  ],
                );
              },
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
                            _formatLogDescription(log.taskDescription),
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
                  label: const Text('Open Full DTR'),
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
                    color: _headlineColor,
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
    context.watch<AuthProvider>();

    return StudentScaffold(
      currentRoute: AppRoutes.studentDashboard,
      backgroundColor: _canvasColor,
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 640
                ? 14.0
                : constraints.maxWidth < 1024
                ? 20.0
                : 28.0;
            final verticalPadding = constraints.maxWidth < 900 ? 16.0 : 24.0;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                verticalPadding,
                horizontalPadding,
                verticalPadding,
              ),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    if (_isInitialLoading && !_hasCompletedFirstLoad)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_dashboardError != null &&
                        _profile == null &&
                        _report == null &&
                        _logs.isEmpty)
                      _buildDashboardErrorState()
                    else ...[
                      _buildAttendanceSection(),
                      const SizedBox(height: 16),
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
            color: OceanBreezePalette.textSecondary,
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: OceanBreezePalette.textPrimary,
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
  const _PaceTile({this.width, required this.label, required this.value});

  final double? width;
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
