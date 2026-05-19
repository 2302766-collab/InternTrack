import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/dtr_service.dart';
import '../../../../core/utils/file_download_stub.dart'
    if (dart.library.html) '../../../../core/utils/file_download_web.dart'
    as file_download;
import '../../../../shared/models/daily_time_record.dart';
import '../../../../shared/models/monthly_dtr_summary.dart';
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

  late final DtrService _dtrService;

  DailyTimeRecord? _record;
  MonthlyDtrSummary? _monthlySummary;
  late DateTime _selectedMonth;
  bool _didLoad = false;
  bool _isLoading = true;
  bool _isMonthlyLoading = true;
  bool _isExportingPdf = false;
  bool _isExportingExcel = false;
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
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            side: const BorderSide(color: _line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
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
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF134B63),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
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

  String _weekdayLabel(MonthlyDtrSummary summary, MonthlyDtrRow row) {
    final date = DateTime(summary.year, summary.month, row.day);
    return DateFormat('EEE, MMM d').format(date);
  }

  String _timeText(String value) => value.trim().isEmpty ? '--' : value.trim();

  String _undertimeText(MonthlyDtrRow row) {
    final hours = int.tryParse(row.undertimeHours) ?? 0;
    final minutes = int.tryParse(row.undertimeMinutes) ?? 0;
    if (hours == 0 && minutes == 0) {
      return '--';
    }

    final parts = <String>[];
    if (hours > 0) {
      parts.add('${hours}h');
    }
    if (minutes > 0) {
      parts.add('${minutes}m');
    }
    return parts.join(' ');
  }

  Widget _buildTable(MonthlyDtrSummary summary) {
    const dayWidth = 78.0;
    const dateWidth = 136.0;
    const timeWidth = 112.0;
    const undertimeWidth = 112.0;
    const statusWidth = 156.0;

    Widget headerCell(String label, double width, {Alignment? alignment}) {
      return Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        alignment: alignment ?? Alignment.centerLeft,
        decoration: const BoxDecoration(
          color: Color(0xFFF2F6FA),
          border: Border(
            bottom: BorderSide(color: _line),
            right: BorderSide(color: _line),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: _muted,
            letterSpacing: 0.4,
          ),
        ),
      );
    }

    Widget bodyCell({
      required Widget child,
      required double width,
      bool shaded = false,
      Alignment? alignment,
      bool showRightBorder = true,
    }) {
      return Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        alignment: alignment ?? Alignment.centerLeft,
        decoration: BoxDecoration(
          color: shaded ? const Color(0xFFFAFCFE) : Colors.white,
          border: Border(
            bottom: const BorderSide(color: _line),
            right: showRightBorder
                ? const BorderSide(color: _line)
                : BorderSide.none,
          ),
        ),
        child: child,
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            children: [
              Row(
                children: [
                  headerCell('DAY', dayWidth),
                  headerCell('DATE', dateWidth),
                  headerCell('AM IN', timeWidth, alignment: Alignment.center),
                  headerCell('AM OUT', timeWidth, alignment: Alignment.center),
                  headerCell('PM IN', timeWidth, alignment: Alignment.center),
                  headerCell('PM OUT', timeWidth, alignment: Alignment.center),
                  headerCell(
                    'UNDERTIME',
                    undertimeWidth,
                    alignment: Alignment.center,
                  ),
                  headerCell(
                    'STATUS',
                    statusWidth,
                    alignment: Alignment.center,
                  ),
                ],
              ),
              for (final row in summary.rows)
                Row(
                  children: [
                    bodyCell(
                      width: dayWidth,
                      shaded: row.day.isEven,
                      alignment: Alignment.center,
                      child: Text(
                        row.day.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                    ),
                    bodyCell(
                      width: dateWidth,
                      shaded: row.day.isEven,
                      child: Text(
                        _weekdayLabel(summary, row),
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    bodyCell(
                      width: timeWidth,
                      shaded: row.day.isEven,
                      alignment: Alignment.center,
                      child: Text(_timeText(row.amArrival)),
                    ),
                    bodyCell(
                      width: timeWidth,
                      shaded: row.day.isEven,
                      alignment: Alignment.center,
                      child: Text(_timeText(row.amDeparture)),
                    ),
                    bodyCell(
                      width: timeWidth,
                      shaded: row.day.isEven,
                      alignment: Alignment.center,
                      child: Text(_timeText(row.pmArrival)),
                    ),
                    bodyCell(
                      width: timeWidth,
                      shaded: row.day.isEven,
                      alignment: Alignment.center,
                      child: Text(_timeText(row.pmDeparture)),
                    ),
                    bodyCell(
                      width: undertimeWidth,
                      shaded: row.day.isEven,
                      alignment: Alignment.center,
                      child: Text(
                        _undertimeText(row),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    bodyCell(
                      width: statusWidth,
                      shaded: row.day.isEven,
                      alignment: Alignment.center,
                      showRightBorder: false,
                      child: Center(child: _buildIndicatorChip(row)),
                    ),
                  ],
                ),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
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
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 4),
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
