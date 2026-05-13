import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/dtr_service.dart';
import '../../../../core/utils/file_download_stub.dart'
    if (dart.library.html) '../../../../core/utils/file_download_web.dart'
    as file_download;
import '../../../../shared/models/daily_time_record.dart';
import '../../../../shared/widgets/dtr_export_dialog.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/student_scaffold.dart';

class StudentDtrScreen extends StatefulWidget {
  const StudentDtrScreen({super.key, this.dtrService});

  final DtrService? dtrService;

  @override
  State<StudentDtrScreen> createState() => _StudentDtrScreenState();
}

class _StudentDtrScreenState extends State<StudentDtrScreen> {
  late final DtrService _dtrService;

  Timer? _timer;
  DailyTimeRecord? _record;
  Duration _liveElapsed = Duration.zero;
  late DateTime _exportStartDate;
  late DateTime _exportEndDate;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isExporting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _exportStartDate = DateTime(now.year, now.month, 1);
    _exportEndDate = DateTime(now.year, now.month + 1, 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading && _record == null && _errorMessage == null) {
      _dtrService = widget.dtrService ?? DtrService(context.read<ApiClient>());
      _loadRecord();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadRecord() async {
    final token = context.read<AuthProvider>().token ?? '';
    if (token.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Missing authentication token. Please log in again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final record = await _dtrService.getTodayRecord();
      if (!mounted) return;

      setState(() {
        _record = record;
      });
      _syncTimer();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitPunch() async {
    final token = context.read<AuthProvider>().token ?? '';
    final record = _record;
    if (token.isEmpty ||
        record == null ||
        record.nextAction == null ||
        _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
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
            message: 'No valid punch action is available.',
            errorType: ApiErrorType.clientError,
          );
      }

      if (!mounted) return;

      setState(() {
        _record = updatedRecord;
      });
      _syncTimer();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_successMessageFor(updatedRecord))),
      );
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _errorMessage = message;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _openExportDialog() async {
    if (_isExporting) {
      return;
    }

    final selection = await showDtrExportDialog(
      context,
      initialStartDate: _exportStartDate,
      initialEndDate: _exportEndDate,
      title: 'Export Dialog',
      description:
          'Choose a date range within one month. The PDF and Excel-compatible CSV layout stays the same.',
    );

    if (selection == null || !mounted) {
      return;
    }

    setState(() {
      _exportStartDate = selection.startDate;
      _exportEndDate = selection.endDate;
    });

    await _exportMonthly(
      pdf: selection.pdf,
      startDate: selection.startDate,
      endDate: selection.endDate,
    );
  }

  Future<void> _exportMonthly({
    required bool pdf,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final token = context.read<AuthProvider>().token ?? '';
    if (token.isEmpty || _isExporting) {
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final file = pdf
          ? await _dtrService.exportPdf(startDate: startDate, endDate: endDate)
          : await _dtrService.exportExcel(
              startDate: startDate,
              endDate: endDate,
            );

      if (!mounted) return;

      final downloaded = await file_download.downloadBytes(
        bytes: file.bytes,
        filename: file.filename,
        mimeType: file.mimeType,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? '${pdf ? 'PDF' : 'Excel'} export downloaded successfully.'
                : 'Export is ready, but direct download is only available on web in this build.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  String _successMessageFor(DailyTimeRecord record) {
    return switch (record.status) {
      'WORKING' when record.lunchInAt == null =>
        'Time In recorded successfully at ${_formatTime(record.timeInAt)}.',
      'ON_BREAK' =>
        'Time Out recorded successfully at ${_formatTime(record.lunchOutAt)}.',
      'WORKING' =>
        'Time In recorded successfully at ${_formatTime(record.lunchInAt)}.',
      'COMPLETED' =>
        'Time Out recorded successfully. Your total rendered time is ${_formatMinutes(record.totalWorkMinutes)}.',
      _ => 'Attendance updated successfully.',
    };
  }

  void _syncTimer() {
    _timer?.cancel();

    final start = _activeSegmentStart(_record);
    if (start == null) {
      if (mounted) {
        setState(() {
          _liveElapsed = Duration.zero;
        });
      }
      return;
    }

    void tick() {
      if (!mounted) return;
      setState(() {
        _liveElapsed = DateTime.now().difference(start);
      });
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  DateTime? _activeSegmentStart(DailyTimeRecord? record) {
    if (record == null || record.status != 'WORKING') {
      return null;
    }

    if (record.lunchInAt != null && record.timeOutAt == null) {
      return record.lunchInAt;
    }

    if (record.timeInAt != null && record.lunchOutAt == null) {
      return record.timeInAt;
    }

    return null;
  }

  String _formatDate(String rawDate) {
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) {
      return rawDate;
    }

    return DateFormat('MMMM d, yyyy').format(parsed);
  }

  String _formatTime(DateTime? value) {
    if (value == null) {
      return 'Not recorded';
    }

    return DateFormat('h:mm:ss a').format(value);
  }

  String _formatMinutes(int minutes) {
    final safeMinutes = minutes < 0 ? 0 : minutes;
    final hours = safeMinutes ~/ 60;
    final remainder = safeMinutes % 60;
    return '$hours hour${hours == 1 ? '' : 's'} $remainder minute${remainder == 1 ? '' : 's'}';
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  int _displayedFirstMinutes(DailyTimeRecord record) {
    if (record.firstWorkMinutes > 0) {
      return record.firstWorkMinutes;
    }

    if (record.status == 'WORKING' &&
        record.timeInAt != null &&
        record.lunchOutAt == null) {
      return _liveElapsed.inMinutes;
    }

    return 0;
  }

  int _displayedSecondMinutes(DailyTimeRecord record) {
    if (record.secondWorkMinutes > 0) {
      return record.secondWorkMinutes;
    }

    if (record.status == 'WORKING' &&
        record.lunchInAt != null &&
        record.timeOutAt == null) {
      return _liveElapsed.inMinutes;
    }

    return 0;
  }

  int _displayedTotalMinutes(DailyTimeRecord record) {
    final savedTotal = record.totalWorkMinutes;

    if (record.status != 'WORKING') {
      return savedTotal;
    }

    if (record.lunchInAt != null && record.timeOutAt == null) {
      return record.firstWorkMinutes + _liveElapsed.inMinutes;
    }

    if (record.timeInAt != null && record.lunchOutAt == null) {
      return _liveElapsed.inMinutes;
    }

    return savedTotal;
  }

  Color _statusColor(String status) {
    return switch (status) {
      'WORKING' => const Color(0xFF0F766E),
      'ON_BREAK' => const Color(0xFFB54708),
      'COMPLETED' => const Color(0xFF039855),
      _ => const Color(0xFF667085),
    };
  }

  Color _statusBackground(String status) {
    return switch (status) {
      'WORKING' => const Color(0xFFDFF7F3),
      'ON_BREAK' => const Color(0xFFFFF3DB),
      'COMPLETED' => const Color(0xFFE7F8EC),
      _ => const Color(0xFFF2F4F7),
    };
  }

  String _statusDisplayLabel(String status) {
    return switch (status) {
      'WORKING' => 'Timed In',
      'ON_BREAK' => 'Timed Out',
      'COMPLETED' => 'Completed',
      _ => 'Not Started',
    };
  }

  String _statusHeadline(DailyTimeRecord record) {
    return switch (record.status) {
      'WORKING' => 'Timed In',
      'ON_BREAK' => 'Timed Out',
      'COMPLETED' => 'Completed',
      _ => 'Not Started',
    };
  }

  String _statusDescription(DailyTimeRecord record) {
    return switch (record.status) {
      'WORKING' when record.lunchInAt == null =>
        'You are currently timed in. Press Time Out when you start your break.',
      'WORKING' =>
        'You are currently timed in. Press Time Out when you finish your day.',
      'ON_BREAK' =>
        'You are currently timed out. Press Time In when you return.',
      'COMPLETED' => 'Your DTR for today is complete.',
      _ => 'You have not timed in yet. Press Time In to start your day.',
    };
  }

  Widget _buildStatusCard(DailyTimeRecord record) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Attendance Status',
                  style: TextStyle(fontSize: 15, color: Color(0xFF667085)),
                ),
                const SizedBox(height: 10),
                Text(
                  _statusHeadline(record),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF102A56),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusDescription(record),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _statusBackground(record.status),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusDisplayLabel(record.status),
                    style: TextStyle(
                      color: _statusColor(record.status),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: _statusBackground(record.status),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              switch (record.status) {
                'WORKING' => Icons.play_circle_fill_rounded,
                'ON_BREAK' => Icons.coffee_rounded,
                'COMPLETED' => Icons.task_alt_rounded,
                _ => Icons.schedule_rounded,
              },
              color: _statusColor(record.status),
              size: 34,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTimerCard(DailyTimeRecord record) {
    final isRunning = record.status == 'WORKING';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF102A56), Color(0xFF1D4E89)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Timer',
            style: TextStyle(fontSize: 15, color: Color(0xFFD8E7FF)),
          ),
          const SizedBox(height: 10),
          Text(
            _formatDuration(_liveElapsed),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isRunning
                ? 'Timer is running while you are actively working.'
                : record.status == 'ON_BREAK'
                ? 'Timer paused while you are timed out.'
                : record.status == 'COMPLETED'
                ? 'Daily time record has been completed.'
                : 'Time in to start tracking your rendered hours.',
            style: const TextStyle(fontSize: 14, color: Color(0xFFD8E7FF)),
          ),
        ],
      ),
    );
  }

  Widget _buildPunchRow({
    required String label,
    required DateTime? timestamp,
    required bool isNext,
    String? actionLabel,
    VoidCallback? onAction,
    bool isSubmitting = false,
  }) {
    final isDone = timestamp != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isDone || isNext ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNext ? const Color(0xFF0F4C5C) : const Color(0xFFE4E7EC),
          width: isNext ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDone
                  ? const Color(0xFFE7F8EC)
                  : isNext
                  ? const Color(0xFFD9F0F4)
                  : const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isDone
                  ? Icons.check_rounded
                  : isNext
                  ? Icons.play_arrow_rounded
                  : Icons.lock_outline_rounded,
              color: isDone
                  ? const Color(0xFF039855)
                  : isNext
                  ? const Color(0xFF0F4C5C)
                  : const Color(0xFF98A2B3),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDone || isNext
                        ? const Color(0xFF102A56)
                        : const Color(0xFF98A2B3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(timestamp),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDone || isNext
                        ? const Color(0xFF667085)
                        : const Color(0xFF98A2B3),
                  ),
                ),
              ],
            ),
          ),
          if (isDone)
            const Text(
              'Recorded',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF039855),
              ),
            )
          else if (isNext)
            FilledButton.icon(
              onPressed: isSubmitting ? null : onAction,
              icon: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.fingerprint_rounded),
              label: Text(isSubmitting ? 'Saving...' : (actionLabel ?? label)),
            )
          else
            const Text(
              'Locked',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF98A2B3),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(DailyTimeRecord record) {
    final first = _displayedFirstMinutes(record);
    final second = _displayedSecondMinutes(record);
    final total = _displayedTotalMinutes(record);

    Widget summaryItem(String label, String detail, int minutes) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF667085)),
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF98A2B3),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatMinutes(minutes),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF102A56),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rendered Time Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF102A56),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              summaryItem('First Segment', 'Time In -> Time Out', first),
              const SizedBox(width: 12),
              summaryItem('Second Segment', 'Time In -> Time Out', second),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFEDF7F8),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Rendered Time',
                  style: TextStyle(fontSize: 13, color: Color(0xFF52737B)),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatMinutes(total),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F4C5C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _actionLabel(String? nextAction) {
    return switch (nextAction) {
      'TIME_IN' => 'Time In',
      'LUNCH_OUT' => 'Time Out',
      'LUNCH_IN' => 'Time In',
      'TIME_OUT' => 'Time Out',
      _ => 'Completed',
    };
  }

  Widget _buildExportCard() {
    final rangeLabel =
        '${DateFormat('MMM d, yyyy').format(_exportStartDate)} - '
        '${DateFormat('MMM d, yyyy').format(_exportEndDate)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DTR Export',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF102A56),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Download your formal Daily Time Record sheet in PDF or Excel-compatible CSV format with an optional date filter.',
            style: TextStyle(fontSize: 14, color: Color(0xFF667085)),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD0D5DD)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected range',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475467),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rangeLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF102A56),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _isExporting ? null : _openExportDialog,
                icon: _isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.file_download_outlined),
                label: Text(
                  _isExporting ? 'Exporting...' : 'Open Export Dialog',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;

    return StudentScaffold(
      currentRoute: AppRoutes.studentDtr,
      appBar: AppBar(title: const Text('Daily Time Record')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && record == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF475467)),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadRecord,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : record == null
          ? const SizedBox.shrink()
          : RefreshIndicator(
              onRefresh: _loadRecord,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1020),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(record.date),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF102A56),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Track your daily attendance by completing each punch in order.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF667085),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildStatusCard(record),
                          const SizedBox(height: 16),
                          _buildLiveTimerCard(record),
                          const SizedBox(height: 16),
                          const Text(
                            'Punch Sequence',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF102A56),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Complete each step in order to calculate your rendered time.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF667085),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildPunchRow(
                            label: 'Time In',
                            timestamp: record.timeInAt,
                            isNext: record.nextAction == 'TIME_IN',
                            actionLabel: _actionLabel(record.nextAction),
                            onAction: _submitPunch,
                            isSubmitting: _isSubmitting &&
                                record.nextAction == 'TIME_IN',
                          ),
                          const SizedBox(height: 10),
                          _buildPunchRow(
                            label: 'Time Out',
                            timestamp: record.lunchOutAt,
                            isNext: record.nextAction == 'LUNCH_OUT',
                            actionLabel: _actionLabel(record.nextAction),
                            onAction: _submitPunch,
                            isSubmitting: _isSubmitting &&
                                record.nextAction == 'LUNCH_OUT',
                          ),
                          const SizedBox(height: 10),
                          _buildPunchRow(
                            label: 'Time In',
                            timestamp: record.lunchInAt,
                            isNext: record.nextAction == 'LUNCH_IN',
                            actionLabel: _actionLabel(record.nextAction),
                            onAction: _submitPunch,
                            isSubmitting: _isSubmitting &&
                                record.nextAction == 'LUNCH_IN',
                          ),
                          const SizedBox(height: 10),
                          _buildPunchRow(
                            label: 'Time Out',
                            timestamp: record.timeOutAt,
                            isNext: record.nextAction == 'TIME_OUT',
                            actionLabel: _actionLabel(record.nextAction),
                            onAction: _submitPunch,
                            isSubmitting: _isSubmitting &&
                                record.nextAction == 'TIME_OUT',
                          ),
                          const SizedBox(height: 16),
                          _buildSummaryCard(record),
                          const SizedBox(height: 16),
                          _buildExportCard(),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: Color(0xFFB42318)),
                            ),
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
