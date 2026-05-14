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
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../student/presentation/widgets/student_scaffold.dart';
import 'log_detail_screen.dart';
import 'log_edit_screen.dart';
import 'log_submission_screen.dart';

class LogbookScreen extends StatefulWidget {
  const LogbookScreen({super.key, this.initialFocusLogId});

  /// When non-null, opens this log’s detail after the list loads (if still present).
  final int? initialFocusLogId;

  @override
  State<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends State<LogbookScreen> {
  static const int _maxAttachmentBytes = 5 * 1024 * 1024;
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
          const SnackBar(content: Text('That log is no longer available.')),
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
        builder: (_) =>
            LogDetailScreen(logId: log.id, initialLog: log, service: _service),
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
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'PENDING':
        return Colors.amber;
      default:
        return Colors.grey;
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

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No logs yet. Tap the add button to submit your first daily log.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(LogEntryItem log) {
    final isUploading = _uploadingLogIds.contains(log.id);
    final hasAttachment = log.attachmentsCount > 0;

    return Card(
      child: InkWell(
        onTap: () => _openLogDetails(log),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormatter.formatApiDate(log.date),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Chip(
                    label: Text(log.status),
                    backgroundColor: _statusColor(
                      log.status,
                    ).withAlpha((0.14 * 255).round()),
                    side: BorderSide(color: _statusColor(log.status)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Hours: ${log.hoursRendered}'),
              const SizedBox(height: 4),
              Text(
                log.taskDescription,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Attachments: ${log.attachmentsCount}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => _openLogDetails(log),
                    child: const Text('Details'),
                  ),
                  if (log.isPending)
                    OutlinedButton(
                      onPressed: () => _openEditLog(log),
                      child: const Text('Edit'),
                    ),
                  if (log.isPending && !hasAttachment)
                    ElevatedButton.icon(
                      onPressed: isUploading
                          ? null
                          : () => _pickAndUploadAttachment(log),
                      icon: isUploading
                          ? const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.attach_file),
                      label: const Text('Upload Proof'),
                    ),
                  if (log.isPending && hasAttachment)
                    Chip(
                      avatar: const Icon(Icons.verified_rounded, size: 18),
                      label: const Text('Proof Attached'),
                      backgroundColor: const Color(0xFFE7F8EC),
                      side: const BorderSide(color: Color(0xFF039855)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentList() {
    final List<Widget> items = <Widget>[
      if (_logs.isEmpty) _buildEmptyState() else ..._logs.map(_buildLogCard),
    ];

    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (_, index) => items[index],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StudentScaffold(
      currentRoute: AppRoutes.logbook,
      appBar: AppBar(
        title: const Text('My Logs'),
        actions: [
          IconButton(
            onPressed: _needsProfile ? null : _openCreateLogScreen,
            tooltip: 'Add daily log',
            icon: const Icon(Icons.add),
          ),
          IconButton(
            onPressed: _loadLogs,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? _buildErrorState()
            : _buildContentList(),
      ),
    );
  }
}
