import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/api_client.dart';
import '../../../../core/services/intern_reporting_service.dart';
import '../../../../core/utils/file_download_stub.dart'
    if (dart.library.html) '../../../../core/utils/file_download_web.dart'
    as file_download;
import '../../../../core/services/intern_list_service.dart';
import '../../../../core/services/supervisor_log_service.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/models/intern_detail.dart';
import '../../../../shared/models/intern_list_item.dart';
import '../../../../shared/models/log_entry.dart';
import '../../../../shared/models/supervisor_log_item.dart';
import '../../../../shared/widgets/dashboard_info_card.dart';
import '../../../../shared/widgets/progress_widget.dart';
import 'intern_report_screen.dart';
import 'supervisor_log_detail_screen.dart';

typedef RecentLogReviewScreenBuilder =
    Widget Function(
      BuildContext context,
      LogEntryItem log,
      SupervisorLogService service,
      String token,
      InternDetailItem intern,
    );

class InternDetailScreen extends StatefulWidget {
  final String token;
  final String role;
  final int profileId;
  final InternListItem? initialIntern;
  final InternListService? service;
  final SupervisorLogService? logService;
  final RecentLogReviewScreenBuilder? reviewScreenBuilder;

  const InternDetailScreen({
    super.key,
    required this.token,
    required this.role,
    required this.profileId,
    this.initialIntern,
    this.service,
    this.logService,
    this.reviewScreenBuilder,
  });

  @override
  State<InternDetailScreen> createState() => _InternDetailScreenState();
}

class _InternDetailScreenState extends State<InternDetailScreen> {
  late final InternListService _service;
  late final SupervisorLogService _logService;
  final InternReportingService _reportingService = InternReportingService();

  bool _isLoading = true;
  bool _isExportingPdf = false;
  bool _isExportingExcel = false;
  String? _errorMessage;
  InternDetailItem? _intern;
  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    final injectedService = widget.service;
    final injectedLogService = widget.logService;

    if (injectedService != null && injectedLogService != null) {
      _service = injectedService;
      _logService = injectedLogService;
    } else {
      final apiClient = context.read<ApiClient>();
      _service = injectedService ?? InternListService(apiClient);
      _logService =
          injectedLogService ??
          SupervisorLogService(
            apiClient,
            role: widget.role.toLowerCase(),
          );
    }
    _loadIntern();
  }

  Future<void> _loadIntern() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final intern = await _service.getInternDetail(
        role: widget.role,
        profileId: widget.profileId,
      );

      if (!mounted) return;

      setState(() {
        _intern = intern;
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

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'PENDING':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  Future<void> _openReport(InternDetailItem intern) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InternReportScreen(
          token: widget.token,
          role: widget.role,
          studentId: intern.studentId,
          studentName: intern.studentName,
        ),
      ),
    );
  }

  Future<void> _openRecentLog(InternDetailItem intern, LogEntryItem log) async {
    final reviewScreenBuilder =
        widget.reviewScreenBuilder ?? _defaultReviewScreenBuilder;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => reviewScreenBuilder(
          context,
          log,
          _logService,
          widget.token,
          intern,
        ),
      ),
    );

    if (updated == true && mounted) {
      await _loadIntern();
    }
  }

  Future<void> _exportDtr({
    required InternDetailItem intern,
    required bool pdf,
    required int month,
    required int year,
  }) async {
    if ((pdf && _isExportingPdf) || (!pdf && _isExportingExcel)) {
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
      final file = await _reportingService.exportDtr(
        role: widget.role,
        studentId: intern.studentId,
        month: month,
        year: year,
        pdf: pdf,
      );

      if (!mounted) return;

      final handled = pdf
          ? await file_download.openBytesInNewTab(
              bytes: file.bytes,
              mimeType: file.mimeType,
            )
          : await file_download.downloadBytes(
              bytes: file.bytes,
              filename: file.filename,
              mimeType: file.mimeType,
            );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            handled
                ? (pdf
                      ? 'DTR PDF opened successfully.'
                      : 'DTR export downloaded successfully.')
                : 'Export is ready, but direct file actions are only available on web in this build.',
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

  Widget _buildActionsCard(InternDetailItem intern) {
    final titlePrefix = widget.role.isNotEmpty
        ? '${widget.role[0].toUpperCase()}${widget.role.substring(1).toLowerCase()}'
        : 'Intern';
    final selectedDate = DateTime(_selectedYear, _selectedMonth);
    final monthOptions = List<int>.generate(12, (i) => i + 1);
    final currentYear = DateTime.now().year;
    final yearOptions =
        List<int>.generate(5, (i) => currentYear - 4 + i);

    return DashboardInfoCard(
      title: '$titlePrefix Tools',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Open the approved log report or export DTR for ${intern.studentName}.',
            style: const TextStyle(color: Color(0xFF526072)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedMonth,
                  decoration: const InputDecoration(
                    labelText: 'Month',
                  ),
                  items: monthOptions
                      .map(
                        (month) => DropdownMenuItem<int>(
                          value: month,
                          child: Text(
                            DateFormat('MMMM')
                                .format(DateTime(2000, month)),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (_isExportingPdf || _isExportingExcel)
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedMonth = value;
                          });
                        },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedYear,
                  decoration: const InputDecoration(
                    labelText: 'Year',
                  ),
                  items: yearOptions
                      .map(
                        (year) => DropdownMenuItem<int>(
                          value: year,
                          child: Text('$year'),
                        ),
                      )
                      .toList(),
                  onChanged: (_isExportingPdf || _isExportingExcel)
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedYear = value;
                          });
                        },
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
                onPressed: () => _openReport(intern),
                icon: const Icon(Icons.assessment_outlined),
                label: const Text('View Report'),
              ),
              OutlinedButton.icon(
                onPressed: _isExportingPdf
                    ? null
                    : () => _exportDtr(
                          intern: intern,
                          pdf: true,
                          month: _selectedMonth,
                          year: _selectedYear,
                        ),
                icon: _isExportingPdf
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: Text(
                  _isExportingPdf
                      ? 'Opening...'
                      : 'Open ${DateFormatter.formatMonthYear(selectedDate)} DTR PDF',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isExportingExcel
                    ? null
                    : () => _exportDtr(
                          intern: intern,
                          pdf: false,
                          month: _selectedMonth,
                          year: _selectedYear,
                        ),
                icon: _isExportingExcel
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.table_chart_outlined),
                label: Text(
                  _isExportingExcel
                      ? 'Downloading...'
                      : 'Download ${DateFormatter.formatMonthYear(selectedDate)} DTR CSV',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _errorMessage ?? 'Failed to load intern details.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadIntern, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int value, Color color) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: color.withAlpha((0.12 * 255).round()),
      side: BorderSide(color: color),
    );
  }

  Widget _buildRecentLogCard(InternDetailItem intern, int index) {
    final log = intern.recentLogs[index];
    final statusColor = _statusColor(log.status);
    final role = widget.role.toLowerCase();
    final isLogDetailContext = role == 'supervisor' || role == 'adviser';
    final canOpenLog = isLogDetailContext && log.id > 0;
    final actionLabel = role == 'supervisor' && log.isPending
        ? 'Review Log'
        : 'View Log';
    final borderColor = canOpenLog
        ? const Color(0xFFBFD7FF)
        : const Color(0xFFE4E7EC);
    final backgroundColor = canOpenLog
        ? const Color(0xFFF8FBFF)
        : const Color(0xFFF9FAFB);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Ink(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          mouseCursor: canOpenLog
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onTap: canOpenLog ? () => _openRecentLog(intern, log) : null,
          hoverColor: canOpenLog ? const Color(0xFFEFF6FF) : Colors.transparent,
          splashColor: canOpenLog
              ? const Color(0xFFDCEBFF)
              : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        log.date,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Chip(
                      label: Text(log.status),
                      backgroundColor: statusColor.withAlpha(
                        (0.12 * 255).round(),
                      ),
                      side: BorderSide(color: statusColor),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Hours: ${log.hoursRendered}'),
                Text('Attachments: ${log.attachmentsCount}'),
                const SizedBox(height: 6),
                Text(
                  log.taskDescription,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isLogDetailContext) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        canOpenLog
                            ? Icons.rate_review_outlined
                            : Icons.lock_outline,
                        size: 18,
                        color: canOpenLog
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF98A2B3),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        canOpenLog ? actionLabel : 'Log unavailable',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: canOpenLog
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFF667085),
                        ),
                      ),
                      if (canOpenLog) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF1D4ED8),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _defaultReviewScreenBuilder(
    BuildContext context,
    LogEntryItem log,
    SupervisorLogService service,
    String token,
    InternDetailItem intern,
  ) {
    return SupervisorLogDetailScreen(
      token: token,
      logId: log.id,
      readOnly: widget.role.toLowerCase() == 'adviser',
      title: widget.role.toLowerCase() == 'adviser' ? 'Log Details' : null,
      readOnlyMessage:
          'Read-only adviser view. Approval controls remain with the assigned supervisor.',
      initialLog: SupervisorLogItem(
        id: log.id,
        internshipProfileId: log.internshipProfileId,
        studentName: intern.studentName,
        studentEmail: intern.studentEmail,
        companyName: intern.companyName,
        date: log.date,
        hoursRendered: log.hoursRendered,
        taskDescription: log.taskDescription,
        status: log.status,
        submittedAt: log.submittedAt,
        attachments: const [],
        attachmentsCount: log.attachmentsCount,
        reviewHistory: const [],
      ),
      service: service,
    );
  }

  Widget _buildBody(InternDetailItem intern) {
    final roleTitle = widget.role.isNotEmpty
        ? '${widget.role[0].toUpperCase()}${widget.role.substring(1).toLowerCase()}'
        : 'Role';

    return RefreshIndicator(
      onRefresh: _loadIntern,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DashboardInfoCard(
            title: '$roleTitle Intern Overview',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  intern.studentName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (intern.studentEmail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(intern.studentEmail),
                ],
                const SizedBox(height: 10),
                Text('Company: ${intern.companyName}'),
                if (intern.companyAddress.isNotEmpty)
                  Text('Address: ${intern.companyAddress}'),
                if ((intern.startDate ?? '').isNotEmpty &&
                    (intern.endDate ?? '').isNotEmpty)
                  Text(
                    'Internship Dates: ${intern.startDate} to ${intern.endDate}',
                  ),
                const SizedBox(height: 8),
                Text(
                  'Supervisor: ${intern.supervisorName?.trim().isNotEmpty == true ? intern.supervisorName : intern.supervisorId?.toString() ?? "Not assigned"}',
                ),
                Text(
                  'Adviser: ${intern.adviserName?.trim().isNotEmpty == true ? intern.adviserName : intern.adviserId?.toString() ?? "Not assigned"}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DashboardInfoCard(
            title: 'Progress Snapshot',
            child: ProgressWidget(
              totalHours: intern.requiredHours,
              completedHours: intern.completedHours,
            ),
          ),
          const SizedBox(height: 16),
          _buildActionsCard(intern),
          const SizedBox(height: 16),
          DashboardInfoCard(
            title: 'Log Status Summary',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatChip('Total Logs', intern.totalLogs, Colors.blueGrey),
                _buildStatChip('Pending', intern.pendingLogs, Colors.amber),
                _buildStatChip('Approved', intern.approvedLogs, Colors.green),
                _buildStatChip('Rejected', intern.rejectedLogs, Colors.red),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DashboardInfoCard(
            title: 'Recent Log Activity',
            child: intern.recentLogs.isEmpty
                ? const Text('No log activity recorded yet.')
                : Column(
                    children: List.generate(
                      intern.recentLogs.length,
                      (index) => _buildRecentLogCard(intern, index),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fallbackTitle = widget.initialIntern?.studentName ?? 'Intern Details';

    return Scaffold(
      appBar: AppBar(
        title: Text(fallbackTitle),
        actions: [
          IconButton(
            onPressed: _loadIntern,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorState()
          : _intern == null
          ? const Center(child: Text('No intern details available.'))
          : _buildBody(_intern!),
    );
  }
}
