import 'package:flutter/material.dart';

import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/services/intern_reporting_service.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/models/student_report.dart';
import '../../../../shared/utils/session_expired_handler.dart';
import '../../../../shared/widgets/dashboard_info_card.dart';

class InternReportScreen extends StatefulWidget {
  final String token;
  final String role;
  final int studentId;
  final String studentName;

  const InternReportScreen({
    super.key,
    required this.token,
    required this.role,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<InternReportScreen> createState() => _InternReportScreenState();
}

class _InternReportScreenState extends State<InternReportScreen> {
  final InternReportingService _reportService = InternReportingService();

  Future<StudentReportData>? _reportFuture;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  void _loadReport() {
    final future = _reportService
        .getReport(
          role: widget.role,
          studentId: widget.studentId,
          startDate: _toApiDate(_startDate),
          endDate: _toApiDate(_endDate),
        )
        .catchError((error) async {
          if (error is ApiException &&
              (error.statusCode == 401 ||
                  error.errorType == ApiErrorType.unauthorized)) {
            await handleExpiredSession(context);
          }

          throw error;
        });

    setState(() {
      _reportFuture = future;
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _startDate = picked;
      if (_endDate != null && picked.isAfter(_endDate!)) {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _endDate = picked;
    });
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadReport();
  }

  String? _toApiDate(DateTime? value) {
    if (value == null) return null;
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final roleTitle = widget.role.isNotEmpty
        ? '${widget.role[0].toUpperCase()}${widget.role.substring(1).toLowerCase()}'
        : 'Intern';

    return Scaffold(
      appBar: AppBar(
        title: Text('$roleTitle Report'),
      ),
      body: FutureBuilder<StudentReportData>(
        future: _reportFuture,
        builder: (context, snapshot) {
          return RefreshIndicator(
            onRefresh: () async {
              _loadReport();
              await _reportFuture;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DashboardInfoCard(
                  title: 'Filter Range',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickStartDate,
                            icon: const Icon(Icons.calendar_month),
                            label: Text(
                              _startDate == null
                                  ? 'Start Date'
                                  : DateFormatter.formatDateOnly(_startDate!),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _pickEndDate,
                            icon: const Icon(Icons.event),
                            label: Text(
                              _endDate == null
                                  ? 'End Date'
                                  : DateFormatter.formatDateOnly(_endDate!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: _loadReport,
                            icon: const Icon(Icons.filter_alt),
                            label: const Text('Apply Filters'),
                          ),
                          TextButton(
                            onPressed: _clearFilters,
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  _ReportErrorState(
                    message: snapshot.error.toString().replaceFirst(
                      'Exception: ',
                      '',
                    ),
                    onRetry: _loadReport,
                  )
                else if (snapshot.hasData)
                  ..._buildReportContent(snapshot.data!, widget.studentName)
                else
                  _ReportErrorState(
                    message: 'No report data available.',
                    onRetry: _loadReport,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildReportContent(
    StudentReportData report,
    String fallbackName,
  ) {
    return [
      DashboardInfoCard(
        title: 'Report Summary',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoLine(
              label: 'Student',
              value: report.student.name.isEmpty ? fallbackName : report.student.name,
            ),
            _InfoLine(
              label: 'Supervisor',
              value: report.supervisor.name.isEmpty
                  ? 'Not assigned yet'
                  : report.supervisor.name,
            ),
            _InfoLine(
              label: 'Range',
              value: _dateRangeLabel(report.dateRange),
            ),
            const Divider(height: 24),
            _InfoLine(
              label: 'Approved Hours',
              value: '${report.summary.totalApprovedHours} hrs',
            ),
            _InfoLine(
              label: 'Required Hours',
              value: '${report.summary.requiredHours} hrs',
            ),
            _InfoLine(
              label: 'Completion',
              value:
                  '${report.summary.completionPercentage.toStringAsFixed(1)}%',
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      DashboardInfoCard(
        title: 'Approved Logs',
        child: report.logs.isEmpty
            ? const Text('No approved logs found for the selected date range.')
            : Column(
                children: report.logs.map((log) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD8E2EC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormatter.formatApiDate(log.date),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(log.taskDescription),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _MetaChip(
                              icon: Icons.schedule,
                              label: '${log.hoursRendered} hrs',
                            ),
                            _MetaChip(
                              icon: Icons.verified,
                              label: log.status,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    ];
  }

  String _dateRangeLabel(StudentReportDateRange dateRange) {
    final start = dateRange.startDate;
    final end = dateRange.endDate;

    if ((start ?? '').isEmpty && (end ?? '').isEmpty) {
      return 'All approved logs';
    }

    final startText = (start ?? '').isEmpty
        ? 'Beginning'
        : DateFormatter.formatApiDate(start!);
    final endText =
        (end ?? '').isEmpty ? 'Latest' : DateFormatter.formatApiDate(end!);

    return '$startText to $endText';
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0F4C5C)),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _ReportErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ReportErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardInfoCard(
      title: 'Report Error',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(color: Color(0xFFB42318)),
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
