import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/dtr_service.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/utils/file_download_stub.dart'
    if (dart.library.html) '../../../../core/utils/file_download_web.dart'
    as file_download;
import '../../../../shared/models/daily_time_record.dart';
import '../../../../shared/models/monthly_dtr_summary.dart';
import '../../../../shared/widgets/notification_bell_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/student_scaffold.dart';

class StudentDtrScreen extends StatefulWidget {
  const StudentDtrScreen({super.key, this.dtrService});

  final DtrService? dtrService;

  @override
  State<StudentDtrScreen> createState() => _StudentDtrScreenState();
}

class _StudentDtrScreenState extends State<StudentDtrScreen> {
  static const Color _canvas = Color(0xFFF4F8FB);
  static const Color _ink = Color(0xFF102A56);
  static const Color _muted = Color(0xFF667085);
  static const Color _line = Color(0xFFD8E4EC);
  static const Color _heroStart = Color(0xFF0F2942);
  static const Color _heroEnd = Color(0xFF1B5B7A);

  late final DtrService _dtrService;

  Timer? _timer;
  DailyTimeRecord? _record;
  MonthlyDtrSummary? _monthlySummary;
  Duration _liveElapsed = Duration.zero;
  late DateTime _selectedMonth;
  bool _didLoad = false;
  bool _isLoading = true;
  bool _isMonthlyLoading = true;
  bool _isSubmitting = false;
  bool _isExportingPdf = false;
  bool _isExportingExcel = false;
  bool _isRequestingEdit = false;
  String? _errorMessage;
  String? _monthlyErrorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _dtrService = widget.dtrService ?? DtrService(context.read<ApiClient>());
    _loadPageData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadPageData() async {
    await Future.wait(<Future<void>>[_loadTodayRecord(), _loadMonthlyRecord()]);
  }

  Future<void> _loadTodayRecord() async {
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

  Future<void> _loadMonthlyRecord() async {
    final token = context.read<AuthProvider>().token ?? '';
    if (token.isEmpty) {
      setState(() {
        _isMonthlyLoading = false;
        _monthlyErrorMessage =
            'Missing authentication token. Please log in again.';
      });
      return;
    }

    setState(() {
      _isMonthlyLoading = true;
      _monthlyErrorMessage = null;
    });

    try {
      final summary = await _dtrService.getMonthlyRecord(
        month: _selectedMonth.month,
        year: _selectedMonth.year,
      );
      if (!mounted) return;
      setState(() {
        _monthlySummary = summary;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _monthlyErrorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isMonthlyLoading = false;
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
      await _reloadSelectedMonthIfNeeded();
      if (!mounted) return;

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

  Future<void> _reloadSelectedMonthIfNeeded() async {
    final now = DateTime.now();
    if (_selectedMonth.year == now.year && _selectedMonth.month == now.month) {
      await _loadMonthlyRecord();
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Select month',
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked == null) return;

    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month);
    });
    await _loadMonthlyRecord();
  }

  Future<void> _shiftMonth(int delta) async {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
    await _loadMonthlyRecord();
  }

  Future<void> _exportSelectedMonth({required bool pdf}) async {
    final token = context.read<AuthProvider>().token ?? '';
    if (token.isEmpty || _isExportingPdf || _isExportingExcel) {
      return;
    }

    setState(() {
      if (pdf) {
        _isExportingPdf = true;
      } else {
        _isExportingExcel = true;
      }
    });

    try {
      final file = pdf
          ? await _dtrService.exportPdf(
              month: _selectedMonth.month,
              year: _selectedMonth.year,
            )
          : await _dtrService.exportExcel(
              month: _selectedMonth.month,
              year: _selectedMonth.year,
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
          if (pdf) {
            _isExportingPdf = false;
          } else {
            _isExportingExcel = false;
          }
        });
      }
    }
  }

  Future<void> _openEditRequestDialog() async {
    final record = _record;
    if (record == null ||
        record.id == null ||
        record.timeInAt == null ||
        record.lunchOutAt == null ||
        record.lunchInAt == null ||
        record.timeOutAt == null ||
        _isRequestingEdit) {
      return;
    }

    final request = await showDialog<_DtrEditRequestDraft>(
      context: context,
      builder: (dialogContext) {
        var timeIn = record.timeInAt!;
        var lunchOut = record.lunchOutAt!;
        var lunchIn = record.lunchInAt!;
        var timeOut = record.timeOutAt!;
        final reasonController = TextEditingController();
        String? error;

        Future<DateTime?> pickTime(
          DateTime initialValue,
          StateSetter setDialogState,
        ) async {
          final picked = await showTimePicker(
            context: dialogContext,
            initialTime: TimeOfDay.fromDateTime(initialValue),
          );
          if (picked == null) return null;

          final baseDate = DateTime.parse(record.date);
          return DateTime(
            baseDate.year,
            baseDate.month,
            baseDate.day,
            picked.hour,
            picked.minute,
          );
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            String display(DateTime value) =>
                DateFormat('hh:mm a').format(value);

            return AlertDialog(
              title: const Text('Request DTR Correction'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update the corrected punch times below. Admin will review this request before any change is applied.',
                    ),
                    const SizedBox(height: 14),
                    _buildTimePickerTile(
                      label: 'Time In',
                      value: display(timeIn),
                      onTap: () async {
                        final picked = await pickTime(timeIn, setDialogState);
                        if (picked == null) return;
                        setDialogState(() => timeIn = picked);
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildTimePickerTile(
                      label: 'Time Out AM',
                      value: display(lunchOut),
                      onTap: () async {
                        final picked = await pickTime(lunchOut, setDialogState);
                        if (picked == null) return;
                        setDialogState(() => lunchOut = picked);
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildTimePickerTile(
                      label: 'Time In PM',
                      value: display(lunchIn),
                      onTap: () async {
                        final picked = await pickTime(lunchIn, setDialogState);
                        if (picked == null) return;
                        setDialogState(() => lunchIn = picked);
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildTimePickerTile(
                      label: 'Time Out PM',
                      value: display(timeOut),
                      onTap: () async {
                        final picked = await pickTime(timeOut, setDialogState);
                        if (picked == null) return;
                        setDialogState(() => timeOut = picked);
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        hintText: 'Explain what was entered incorrectly.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: const TextStyle(color: Color(0xFFB42318)),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final reason = reasonController.text.trim();
                    if (reason.length < 5) {
                      setDialogState(() {
                        error = 'Reason must be at least 5 characters.';
                      });
                      return;
                    }

                    if (!(timeIn.isBefore(lunchOut) &&
                        lunchOut.isBefore(lunchIn) &&
                        lunchIn.isBefore(timeOut))) {
                      setDialogState(() {
                        error = 'Please keep the times in the correct order.';
                      });
                      return;
                    }

                    Navigator.of(dialogContext).pop(
                      _DtrEditRequestDraft(
                        timeInAt: timeIn,
                        lunchOutAt: lunchOut,
                        lunchInAt: lunchIn,
                        timeOutAt: timeOut,
                        reason: reason,
                      ),
                    );
                  },
                  child: const Text('Send Request'),
                ),
              ],
            );
          },
        );
      },
    );

    if (request == null) return;
    await _submitEditRequest(request);
  }

  Future<void> _submitEditRequest(_DtrEditRequestDraft request) async {
    final record = _record;
    if (record?.id == null || _isRequestingEdit) {
      return;
    }

    setState(() {
      _isRequestingEdit = true;
      _errorMessage = null;
    });

    try {
      await _dtrService.requestEdit(
        dailyTimeRecordId: record!.id!,
        timeInAt: request.timeInAt,
        lunchOutAt: request.lunchOutAt,
        lunchInAt: request.lunchInAt,
        timeOutAt: request.timeOutAt,
        reason: request.reason,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('DTR correction request sent to admin for review.'),
        ),
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
          _isRequestingEdit = false;
        });
      }
    }
  }

  void _syncTimer() {
    _timer?.cancel();

    final start = _activeSegmentStart(_record);
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
        _liveElapsed = DateTime.now().difference(start);
      });
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
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

  String _formatTime(DateTime? value) {
    if (value == null) return '--';
    return DateFormat('h:mm a').format(value);
  }

  String _formatHeaderDate() {
    final record = _record;
    final parsed = DateTime.tryParse(record?.date ?? '');
    if (parsed == null) {
      return DateFormat('EEEE, MMMM d').format(DateTime.now());
    }
    return DateFormat('EEEE, MMMM d').format(parsed);
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  String _formatMinutes(int minutes) {
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
      _ => 'Use the buttons below to start your attendance.',
    };
  }

  Color _statusColor(String? status) {
    return switch (status) {
      'WORKING' => const Color(0xFF0F766E),
      'ON_BREAK' => const Color(0xFFB54708),
      'COMPLETED' => const Color(0xFF039855),
      _ => const Color(0xFF667085),
    };
  }

  Color _statusBackground(String? status) {
    return switch (status) {
      'WORKING' => const Color(0xFFDFF7F3),
      'ON_BREAK' => const Color(0xFFFFF3DB),
      'COMPLETED' => const Color(0xFFE7F8EC),
      _ => const Color(0xFFF2F4F7),
    };
  }

  String _statusLabel(String? status) {
    return switch (status) {
      'WORKING' => 'Timed In',
      'ON_BREAK' => 'Break',
      'COMPLETED' => 'Complete',
      _ => 'No Record',
    };
  }

  ImageProvider<Object>? _avatarImage(AuthProvider authProvider) {
    final avatarBase64 = authProvider.user?.avatarBase64 ?? '';
    if (avatarBase64.isEmpty) return null;

    try {
      return MemoryImage(base64Decode(avatarBase64));
    } catch (_) {
      return null;
    }
  }

  String _initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'ST';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length > 1 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _buildTopHeader(AuthProvider authProvider) {
    final themeController = context.watch<ThemeController>();
    final user = authProvider.user;
    final token = authProvider.token ?? '';
    final avatar = _avatarImage(authProvider);
    final displayName = user?.name.isNotEmpty == true ? user!.name : 'Student';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.studentDashboard),
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                'Student Dashboard',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Profile',
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.internshipProfile);
            },
            icon: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFE3EEF7),
              backgroundImage: avatar,
              child: avatar == null
                  ? Text(
                      _initialsFor(displayName),
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
          ),
          NotificationBellButton(token: token, iconColor: _ink),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                themeController.isDarkMode
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                color: _ink,
                size: 18,
              ),
              Switch(
                value: themeController.isDarkMode,
                onChanged: (value) {
                  context.read<ThemeController>().setDarkMode(value);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimerCard(DailyTimeRecord? record) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[_heroStart, _heroEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Live Timer',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD7EBF7),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(record?.status),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatDuration(_liveElapsed),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatHeaderDate(),
            style: const TextStyle(fontSize: 14, color: Color(0xFFD7EBF7)),
          ),
          const SizedBox(height: 6),
          Text(
            _timerHint(record),
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFFD7EBF7),
            ),
          ),
          if (record != null) ...[
            const SizedBox(height: 14),
            Text(
              'Total rendered time: ${_formatMinutes(record.totalWorkMinutes)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required DateTime? timestamp,
    required bool isNext,
    required bool isLocked,
  }) {
    final isDone = timestamp != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isNext ? const Color(0xFF1B5B7A) : _line,
          width: isNext ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isDone
                      ? const Color(0xFF039855)
                      : isNext
                      ? const Color(0xFF1B5B7A)
                      : const Color(0xFFD0D5DD),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: _muted)),
          const SizedBox(height: 16),
          Text(
            _formatTime(timestamp),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDone || isNext ? _ink : const Color(0xFF98A2B3),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isNext && !_isSubmitting ? _submitPunch : null,
              style: FilledButton.styleFrom(
                backgroundColor: isDone
                    ? const Color(0xFFE7F8EC)
                    : isNext
                    ? const Color(0xFF1B5B7A)
                    : const Color(0xFFEAEFF3),
                foregroundColor: isDone
                    ? const Color(0xFF027A48)
                    : isNext
                    ? Colors.white
                    : const Color(0xFF98A2B3),
              ),
              child: _isSubmitting && isNext
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isDone
                          ? 'Recorded'
                          : isLocked
                          ? 'Locked'
                          : 'Record',
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection(DailyTimeRecord? record) {
    final canRequestCorrection =
        record != null &&
        record.id != null &&
        record.status == 'COMPLETED' &&
        record.timeInAt != null &&
        record.lunchOutAt != null &&
        record.lunchInAt != null &&
        record.timeOutAt != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attendance Actions',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 760;
            final children = <Widget>[
              _buildActionTile(
                title: 'AM Time In',
                subtitle: 'Morning arrival',
                timestamp: record?.timeInAt,
                isNext: record?.nextAction == 'TIME_IN',
                isLocked:
                    record?.nextAction != 'TIME_IN' && record?.timeInAt == null,
              ),
              _buildActionTile(
                title: 'AM Time Out',
                subtitle: 'Morning departure',
                timestamp: record?.lunchOutAt,
                isNext: record?.nextAction == 'LUNCH_OUT',
                isLocked:
                    record?.nextAction != 'LUNCH_OUT' &&
                    record?.lunchOutAt == null,
              ),
              _buildActionTile(
                title: 'PM Time In',
                subtitle: 'Afternoon arrival',
                timestamp: record?.lunchInAt,
                isNext: record?.nextAction == 'LUNCH_IN',
                isLocked:
                    record?.nextAction != 'LUNCH_IN' &&
                    record?.lunchInAt == null,
              ),
              _buildActionTile(
                title: 'PM Time Out',
                subtitle: 'Afternoon departure',
                timestamp: record?.timeOutAt,
                isNext: record?.nextAction == 'TIME_OUT',
                isLocked:
                    record?.nextAction != 'TIME_OUT' &&
                    record?.timeOutAt == null,
              ),
            ];

            if (isCompact) {
              return Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i != children.length - 1) const SizedBox(height: 12),
                  ],
                ],
              );
            }

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: children[0]),
                    const SizedBox(width: 12),
                    Expanded(child: children[1]),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: children[2]),
                    const SizedBox(width: 12),
                    Expanded(child: children[3]),
                  ],
                ),
              ],
            );
          },
        ),
        if (canRequestCorrection) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _isRequestingEdit ? null : _openEditRequestDialog,
              icon: _isRequestingEdit
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.edit_calendar_rounded),
              label: Text(
                _isRequestingEdit ? 'Sending...' : 'Request DTR Correction',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTableToolbar(MonthlyDtrSummary? summary) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FBFD),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: _isMonthlyLoading ? null : () => _shiftMonth(-1),
                icon: const Icon(Icons.chevron_left_rounded),
                visualDensity: VisualDensity.compact,
              ),
              InkWell(
                onTap: _isMonthlyLoading ? null : _pickMonth,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Text(
                    summary?.monthYear ??
                        DateFormat('MMMM yyyy').format(_selectedMonth),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _isMonthlyLoading ? null : () => _shiftMonth(1),
                icon: const Icon(Icons.chevron_right_rounded),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _isExportingExcel
              ? null
              : () => _exportSelectedMonth(pdf: false),
          icon: _isExportingExcel
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.table_chart_rounded),
          label: Text(_isExportingExcel ? 'Exporting...' : 'Export Excel'),
        ),
        FilledButton.icon(
          onPressed: _isExportingPdf
              ? null
              : () => _exportSelectedMonth(pdf: true),
          icon: _isExportingPdf
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.picture_as_pdf_rounded),
          label: Text(_isExportingPdf ? 'Exporting...' : 'Export PDF'),
        ),
      ],
    );
  }

  Widget _buildScheduleMeta(MonthlyDtrSummary summary) {
    final items = <String>[
      if ((summary.companyName ?? '').trim().isNotEmpty)
        'Company: ${summary.companyName}',
      if (summary.regularDays.trim().isNotEmpty)
        'Regular Days: ${summary.regularDays}',
      if (summary.amSchedule.trim().isNotEmpty) 'AM: ${summary.amSchedule}',
      if (summary.pmSchedule.trim().isNotEmpty) 'PM: ${summary.pmSchedule}',
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBFD),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _line),
              ),
              child: Text(
                item,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildIndicatorChip(MonthlyDtrRow row) {
    final color = _statusColor(row.status);
    final background = _statusBackground(row.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            _statusLabel(row.status),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(MonthlyDtrSummary summary) {
    Widget headerCell(String label, double width) {
      return Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _line)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      );
    }

    Widget bodyCell({
      required Widget child,
      required double width,
      bool shaded = false,
    }) {
      return Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: shaded ? const Color(0xFFF8FBFD) : Colors.white,
          border: const Border(bottom: BorderSide(color: _line)),
        ),
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          children: [
            Row(
              children: [
                headerCell('Day', 72),
                headerCell('AM In', 124),
                headerCell('AM Out', 124),
                headerCell('PM In', 124),
                headerCell('PM Out', 124),
                headerCell('Indicator', 160),
              ],
            ),
            for (final row in summary.rows)
              Row(
                children: [
                  bodyCell(
                    width: 72,
                    shaded: row.day.isEven,
                    child: Text(
                      row.day.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  bodyCell(
                    width: 124,
                    shaded: row.day.isEven,
                    child: Text(row.amArrival.isEmpty ? '--' : row.amArrival),
                  ),
                  bodyCell(
                    width: 124,
                    shaded: row.day.isEven,
                    child: Text(
                      row.amDeparture.isEmpty ? '--' : row.amDeparture,
                    ),
                  ),
                  bodyCell(
                    width: 124,
                    shaded: row.day.isEven,
                    child: Text(row.pmArrival.isEmpty ? '--' : row.pmArrival),
                  ),
                  bodyCell(
                    width: 124,
                    shaded: row.day.isEven,
                    child: Text(
                      row.pmDeparture.isEmpty ? '--' : row.pmDeparture,
                    ),
                  ),
                  bodyCell(
                    width: 160,
                    shaded: row.day.isEven,
                    child: _buildIndicatorChip(row),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySection() {
    final summary = _monthlySummary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Time Record Table',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Monthly attendance view with AM and PM indicators.',
            style: TextStyle(fontSize: 14, color: _muted),
          ),
          const SizedBox(height: 16),
          _buildTableToolbar(summary),
          const SizedBox(height: 14),
          if (_isMonthlyLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_monthlyErrorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _monthlyErrorMessage!,
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _loadMonthlyRecord,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (summary == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No monthly DTR data available yet.',
                style: TextStyle(color: _muted),
              ),
            )
          else ...[
            _buildScheduleMeta(summary),
            if (summary.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                summary.notes,
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
            ],
            const SizedBox(height: 16),
            _buildTable(summary),
          ],
        ],
      ),
    );
  }

  Widget _buildTimePickerTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD0D5DD)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.schedule_rounded),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return StudentScaffold(
      currentRoute: AppRoutes.studentDtr,
      backgroundColor: _canvas,
      body: _isLoading && _record == null
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _record == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _muted),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadTodayRecord,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadPageData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopHeader(authProvider),
                          const SizedBox(height: 18),
                          _buildTimerCard(_record),
                          const SizedBox(height: 18),
                          _buildActionSection(_record),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: Color(0xFFB42318)),
                            ),
                          ],
                          const SizedBox(height: 18),
                          _buildMonthlySection(),
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

class _DtrEditRequestDraft {
  const _DtrEditRequestDraft({
    required this.timeInAt,
    required this.lunchOutAt,
    required this.lunchInAt,
    required this.timeOutAt,
    required this.reason,
  });

  final DateTime timeInAt;
  final DateTime lunchOutAt;
  final DateTime lunchInAt;
  final DateTime timeOutAt;
  final String reason;
}
