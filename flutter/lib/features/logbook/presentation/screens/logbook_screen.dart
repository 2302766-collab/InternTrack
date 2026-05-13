import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/services/logbook_service.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/file_picker_helper_stub.dart'
    if (dart.library.html) '../../../../core/utils/file_picker_helper_web.dart'
    as file_picker;
import '../../../../shared/models/log_entry.dart';
<<<<<<< HEAD
import '../../../auth/presentation/providers/auth_provider.dart';
=======
import '../../../student/presentation/widgets/student_scaffold.dart';
>>>>>>> 9cd14a8a927dbbdc423a70fbc3c89bd066c82bb3
import 'log_detail_screen.dart';
import 'log_edit_screen.dart';
import 'log_submission_screen.dart';

enum _LogFilter { all, pending, approved, rejected }

class LogbookScreen extends StatefulWidget {
  const LogbookScreen({super.key, this.initialFocusLogId});

  /// When non-null, opens this log’s detail after the list loads (if still present).
  final int? initialFocusLogId;

  @override
  State<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends State<LogbookScreen> {
  static const int _maxAttachmentBytes = 5 * 1024 * 1024;
  static const int _pageSize = 8;
  static const List<String> _allowedExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'pdf',
  ];

  late final LogbookService _service;

  bool _isReady = false;
  bool _isLoading = true;
  String? _errorMessage;
  bool _needsProfile = false;
  String _token = '';
  _LogFilter _selectedFilter = _LogFilter.all;
  int _visibleLogCount = _pageSize;

  final Set<int> _uploadingLogIds = <int>{};
  List<LogEntryItem> _logs = <LogEntryItem>[];
  bool _handledInitialLogFocus = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_isReady) return;

    _isReady = true;
    _service = context.read<LogbookService>();
    _token = context.read<AuthProvider>().token ?? '';
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    if (_token.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Missing authentication token. Please login again.';
        _needsProfile = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _needsProfile = false;
    });

    try {
      final logs = await _service.getLogs();
      if (!mounted) return;

      setState(() {
        _logs = _sortLogsNewestFirst(logs);
        _visibleLogCount = _pageSize;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.message;
        _needsProfile =
            e.statusCode == 404 && e.message.toLowerCase().contains('profile');
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _needsProfile = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scheduleFocusLogIfNeeded();
      }
    }
  }

  void _scheduleFocusLogIfNeeded() {
    if (_handledInitialLogFocus) return;
    final id = widget.initialFocusLogId;
    if (id == null) return;
    _handledInitialLogFocus = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      LogEntryItem? found;
      for (final log in _logs) {
        if (log.id == id) {
          found = log;
          break;
        }
      }
      if (found != null) {
        _openLogDetails(found);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('That log is no longer available.'),
          ),
        );
      }
    });
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

  List<LogEntryItem> get _filteredLogs {
    switch (_selectedFilter) {
      case _LogFilter.pending:
        return _logs.where((log) => log.status.toUpperCase() == 'PENDING').toList();
      case _LogFilter.approved:
        return _logs.where((log) => log.status.toUpperCase() == 'APPROVED').toList();
      case _LogFilter.rejected:
        return _logs.where((log) => log.status.toUpperCase() == 'REJECTED').toList();
      case _LogFilter.all:
        return _logs;
    }
  }

  List<LogEntryItem> get _visibleLogs =>
      _filteredLogs.take(_visibleLogCount).toList();

  int get _approvedCount =>
      _logs.where((log) => log.status.toUpperCase() == 'APPROVED').length;

  int get _pendingCount =>
      _logs.where((log) => log.status.toUpperCase() == 'PENDING').length;

  int get _rejectedCount =>
      _logs.where((log) => log.status.toUpperCase() == 'REJECTED').length;

  int get _totalHours =>
      _logs.fold(0, (sum, log) => sum + log.hoursRendered);

  void _selectFilter(_LogFilter filter) {
    setState(() {
      _selectedFilter = filter;
      _visibleLogCount = _pageSize;
    });
  }

  void _showMoreLogs() {
    setState(() {
      _visibleLogCount = (_visibleLogCount + _pageSize).clamp(
        0,
        _filteredLogs.length,
      );
    });
  }

  String? _validateSelectedFileName(String fileName, int bytesLength) {
    final name = fileName.toLowerCase();
    final hasAllowedExt = _allowedExtensions.any(
      (ext) => name.endsWith('.$ext') || name.endsWith(ext),
    );
    if (!hasAllowedExt) {
      return 'Only JPG, PNG, or PDF files are allowed.';
    }

    if (bytesLength > _maxAttachmentBytes) {
      return 'File must be 5MB or smaller.';
    }

    return null;
  }

  String _formatTaskDescription(String value) {
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

  String _monthGroupLabel(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return 'Unknown Month';
    return DateFormatter.formatMonthYear(parsed);
  }

  String? _rejectionReason(LogEntryItem log) {
    final items = log.reviewHistory.reversed;
    for (final item in items) {
      if (item.action.toUpperCase().contains('REJECT') && item.hasComment) {
        return item.comment!.trim();
      }
    }

    for (final item in items) {
      if (item.hasComment) {
        return item.comment!.trim();
      }
    }

    return null;
  }

  Future<void> _showFeedbackDialog(LogEntryItem log) async {
    final feedback = _rejectionReason(log);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Review Feedback'),
          content: Text(
            feedback ?? 'No written feedback is available for this log yet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openCreateLogScreen() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LogSubmissionScreen(token: _token, service: _service),
      ),
    );

    if (created == true) {
      await _loadLogs();
    }
  }

  Future<void> _openLogDetails(LogEntryItem log) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LogDetailScreen(
          logId: log.id,
          initialLog: log,
          service: _service,
        ),
      ),
    );

    if (updated == true) {
      await _loadLogs();
    }
  }

  Future<void> _openEditLog(LogEntryItem log) async {
    if (!log.isPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only pending logs can be edited.')),
      );
      return;
    }

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LogEditScreen(log: log, service: _service),
      ),
    );

    if (updated == true) {
      await _loadLogs();
    }
  }

  Future<void> _pickAndUploadAttachment(LogEntryItem log) async {
    if (!log.isPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attachments can only be uploaded for PENDING logs.'),
        ),
      );
      return;
    }

    final selected = await file_picker.pickSingleFile(
      allowedExtensions: _allowedExtensions,
    );

    if (selected == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No file selected.')));
      return;
    }

    final validationError = _validateSelectedFileName(
      selected.name,
      selected.bytes.length,
    );
    if (validationError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    setState(() {
      _uploadingLogIds.add(log.id);
    });

    try {
      await _service.uploadAttachment(
        logId: log.id,
        bytes: selected.bytes,
        fileName: selected.name,
        mimeType: selected.mimeType,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attachment uploaded successfully.')),
      );
      await _loadLogs();
    } on ApiException catch (e) {
      if (!mounted) return;
      final fieldErrors = e.details ?? const <String, dynamic>{};
      final firstField = fieldErrors.values.isNotEmpty
          ? fieldErrors.values.first
          : null;
      final message = firstField is List && firstField.isNotEmpty
          ? firstField.first.toString()
          : e.message;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingLogIds.remove(log.id);
        });
      }
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return const Color(0xFF039855);
      case 'REJECTED':
        return const Color(0xFFD92D20);
      case 'PENDING':
        return const Color(0xFFB54708);
      default:
        return const Color(0xFF667085);
    }
  }

  Color _statusBackground(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return const Color(0xFFE8F7ED);
      case 'REJECTED':
        return const Color(0xFFFDECEC);
      case 'PENDING':
        return const Color(0xFFFFF4E5);
      default:
        return const Color(0xFFF2F4F7);
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _errorMessage ?? 'Failed to load logs.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (_needsProfile) ...[
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.internshipProfile);
              },
              child: const Text('Create Internship Profile'),
            ),
            const SizedBox(height: 8),
          ],
          ElevatedButton(onPressed: _loadLogs, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE6F2)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 640;

          final actionButtons = Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _needsProfile ? null : _openCreateLogScreen,
                icon: const Icon(Icons.add),
                label: const Text('Add Log'),
              ),
              OutlinedButton.icon(
                onPressed: _loadLogs,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          );

          return isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Logbook',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF102A56),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Track, edit, and submit your daily internship logs.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF4A6480),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    actionButtons,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Logbook',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF102A56),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Track, edit, and submit your daily internship logs.',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF4A6480),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    actionButtons,
                  ],
                );
        },
      ),
    );
  }

  Widget _buildSummaryTile({
    required String label,
    required String value,
    required Color background,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A6480),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF102A56),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 900
            ? (constraints.maxWidth - 48) / 5
            : constraints.maxWidth >= 560
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: itemWidth,
              child: _buildSummaryTile(
                label: 'Total Logs',
                value: '${_logs.length}',
                background: const Color(0xFFF8FAFC),
                border: const Color(0xFFD8E2EC),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildSummaryTile(
                label: 'Approved',
                value: '$_approvedCount',
                background: const Color(0xFFF3FBF7),
                border: const Color(0xFFD5ECDC),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildSummaryTile(
                label: 'Pending',
                value: '$_pendingCount',
                background: const Color(0xFFFFF8ED),
                border: const Color(0xFFF8E5C1),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildSummaryTile(
                label: 'Rejected',
                value: '$_rejectedCount',
                background: const Color(0xFFFFF4F4),
                border: const Color(0xFFF2D6D6),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildSummaryTile(
                label: 'Total Hours',
                value: '$_totalHours h',
                background: const Color(0xFFF5F8FF),
                border: const Color(0xFFDCE5F8),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar() {
    Widget filterChip(_LogFilter filter, String label) {
      final isSelected = _selectedFilter == filter;
      return ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _selectFilter(filter),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        filterChip(_LogFilter.all, 'All'),
        filterChip(_LogFilter.pending, 'Pending'),
        filterChip(_LogFilter.approved, 'Approved'),
        filterChip(_LogFilter.rejected, 'Rejected'),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No logs submitted yet.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF102A56),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start by adding your first daily log.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF4A6480),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _needsProfile ? null : _openCreateLogScreen,
              icon: const Icon(Icons.add),
              label: const Text('Add Log'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No ${_selectedFilter.name} logs found.',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF102A56),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try another filter to view more log entries.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF4A6480),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogStatusBadge(LogEntryItem log) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _statusBackground(log.status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        log.status.toUpperCase(),
        style: TextStyle(
          color: _statusColor(log.status),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildFeedbackChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.feedback_outlined, size: 16, color: Color(0xFFD92D20)),
          SizedBox(width: 6),
          Text(
            'Feedback available',
            style: TextStyle(
              color: Color(0xFFD92D20),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProofStatusChip(bool hasAttachment) {
    if (!hasAttachment) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'Proof missing',
          style: TextStyle(
            color: Color(0xFFB54708),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F8EC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 16, color: Color(0xFF039855)),
          SizedBox(width: 6),
          Text(
            'Proof attached',
            style: TextStyle(
              color: Color(0xFF039855),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(LogEntryItem log) {
    final isUploading = _uploadingLogIds.contains(log.id);
    final hasAttachment = log.attachmentsCount > 0;
    final rejectionReason = _rejectionReason(log);
    final isRejected = log.status.toUpperCase() == 'REJECTED';
    final isApproved = log.status.toUpperCase() == 'APPROVED';

    final actions = <Widget>[
      OutlinedButton(
        onPressed: () => _openLogDetails(log),
        child: Text(isApproved ? 'View Proof' : 'Details'),
      ),
      if (log.isPending)
        OutlinedButton(
          onPressed: () => _openEditLog(log),
          child: const Text('Edit'),
        ),
      if (isRejected)
        OutlinedButton(
          onPressed: () => _showFeedbackDialog(log),
          child: const Text('View Feedback'),
        ),
      if (log.isPending && !hasAttachment)
        FilledButton.icon(
          onPressed: isUploading ? null : () => _pickAndUploadAttachment(log),
          icon: isUploading
              ? const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.attach_file),
          label: Text(isUploading ? 'Uploading...' : 'Upload Proof'),
        ),
    ];

    return Card(
      child: InkWell(
        onTap: () => _openLogDetails(log),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormatter.formatApiDate(log.date),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF102A56),
                              ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildLogStatusBadge(log),
                            Text(
                              '${log.hoursRendered} hour${log.hoursRendered == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: Color(0xFF4A6480),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Attachments: ${log.attachmentsCount}',
                              style: const TextStyle(color: Color(0xFF6B7F99)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Task: ${_formatTaskDescription(log.taskDescription)}',
                style: const TextStyle(
                  color: Color(0xFF102A56),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              if (isRejected && rejectionReason != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Reason: $rejectionReason',
                  style: const TextStyle(
                    color: Color(0xFFD92D20),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...actions,
                  if (log.isPending && hasAttachment)
                    _buildProofStatusChip(true),
                  if (log.isPending && !hasAttachment) _buildProofStatusChip(false),
                  if (isRejected && rejectionReason != null)
                    _buildFeedbackChip(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogListSection() {
    if (_logs.isEmpty) {
      return _buildEmptyState();
    }

    if (_filteredLogs.isEmpty) {
      return _buildFilterEmptyState();
    }

    final widgets = <Widget>[];
    String? lastMonth;

    for (final log in _visibleLogs) {
      final currentMonth = _monthGroupLabel(log.date);
      if (currentMonth != lastMonth) {
        if (widgets.isNotEmpty) {
          widgets.add(const SizedBox(height: 4));
        }
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 6),
            child: Text(
              currentMonth,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF102A56),
              ),
            ),
          ),
        );
        lastMonth = currentMonth;
      }

      widgets.add(_buildLogCard(log));
      widgets.add(const SizedBox(height: 12));
    }

    if (_visibleLogs.isNotEmpty) {
      widgets.removeLast();
    }

    if (_visibleLogCount < _filteredLogs.length) {
      widgets.add(const SizedBox(height: 16));
      widgets.add(
        Center(
          child: OutlinedButton.icon(
            onPressed: _showMoreLogs,
            icon: const Icon(Icons.expand_more),
            label: Text(
              'Load More (${_filteredLogs.length - _visibleLogCount} remaining)',
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildContentList() {
    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSection(),
                  const SizedBox(height: 20),
                  _buildSummarySection(),
                  const SizedBox(height: 20),
                  _buildFilterBar(),
                  const SizedBox(height: 20),
                  _buildLogListSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StudentScaffold(
      currentRoute: AppRoutes.logbook,
      appBar: AppBar(
        title: const Text('My Logbook'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorState()
          : _buildContentList(),
    );
  }
}
