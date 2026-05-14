import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/services/supervisor_log_service.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/file_download_stub.dart'
    if (dart.library.html) '../../../../core/utils/file_download_web.dart'
    as file_download;
import '../../../../shared/utils/session_expired_handler.dart';
import '../../../../shared/models/log_attachment.dart';
import '../../../../shared/models/log_review_action.dart';
import '../../../../shared/models/supervisor_log_item.dart';

enum _ActiveAction { approve, reject }

class SupervisorLogDetailScreen extends StatefulWidget {
  final String token;
  final int logId;
  final SupervisorLogService service;
  final SupervisorLogItem? initialLog;
  final bool readOnly;
  final String? title;
  final String? readOnlyMessage;

  const SupervisorLogDetailScreen({
    super.key,
    required this.token,
    required this.logId,
    required this.service,
    this.initialLog,
    this.readOnly = false,
    this.title,
    this.readOnlyMessage,
  });

  @override
  State<SupervisorLogDetailScreen> createState() =>
      _SupervisorLogDetailScreenState();
}

class _SupervisorLogDetailScreenState extends State<SupervisorLogDetailScreen> {
  late SupervisorLogItem _log;
  late final TextEditingController _commentController;
  String? _commentError;

  bool _isLoading = true;
  bool _isSubmitting = false;
  _ActiveAction? _activeAction;
  String? _errorMessage;
  final Map<int, SupervisorLogAttachmentFile> _attachmentFiles =
      <int, SupervisorLogAttachmentFile>{};
  final Map<int, String> _attachmentErrors = <int, String>{};
  final Set<int> _loadingAttachmentIds = <int>{};

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _log =
        widget.initialLog ??
        const SupervisorLogItem(
          id: 0,
          internshipProfileId: 0,
          studentName: 'Student',
          date: '',
          hoursRendered: 0,
          taskDescription: '',
          status: 'PENDING',
          attachments: <LogAttachment>[],
          attachmentsCount: 0,
          reviewHistory: <LogReviewActionItem>[],
        );
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final log = await widget.service.getLog(widget.logId);
      if (!mounted) return;

      setState(() {
        _log = log;
      });
      _prefetchImageAttachments();
    } on ApiException catch (e) {
      if (!mounted) return;

      if (e.statusCode == 401 || e.errorType == ApiErrorType.unauthorized) {
        await handleExpiredSession(context);
        return;
      }

      setState(() {
        _errorMessage = _readErrorMessage(e);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = _readErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _prefetchImageAttachments() async {
    for (final attachment in _log.attachments.where(_isImageAttachment)) {
      await _ensureAttachmentFile(attachment, silent: true);
    }
  }

  Future<SupervisorLogAttachmentFile?> _ensureAttachmentFile(
    LogAttachment attachment, {
    bool silent = false,
  }) async {
    final cached = _attachmentFiles[attachment.id];
    if (cached != null) {
      return cached;
    }

    if (_loadingAttachmentIds.contains(attachment.id)) {
      return null;
    }

    setState(() {
      _loadingAttachmentIds.add(attachment.id);
      _attachmentErrors.remove(attachment.id);
    });

    try {
      final file = await widget.service.downloadAttachment(
        logId: _log.id,
        attachmentId: attachment.id,
      );

      if (!mounted) return file;

      setState(() {
        _attachmentFiles[attachment.id] = file;
      });

      return file;
    } on ApiException catch (e) {
      if (!mounted) return null;

      if (e.statusCode == 401 || e.errorType == ApiErrorType.unauthorized) {
        await handleExpiredSession(context);
        return null;
      }

      final resolvedMessage = _readErrorMessage(e);
      setState(() {
        _attachmentErrors[attachment.id] = resolvedMessage;
      });

      if (!silent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(resolvedMessage)));
      }

      return null;
    } catch (e) {
      if (!mounted) return null;

      final resolvedMessage = _readErrorMessage(e);
      setState(() {
        _attachmentErrors[attachment.id] = resolvedMessage;
      });

      if (!silent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(resolvedMessage)));
      }

      return null;
    } finally {
      if (mounted) {
        setState(() {
          _loadingAttachmentIds.remove(attachment.id);
        });
      }
    }
  }

  Future<void> _approve() async {
    if (widget.readOnly) return;
    if (_isSubmitting || !_log.isPending) return;

    setState(() {
      _commentError = null;
    });
    await _submitReview(approve: true);
  }

  Future<void> _reject() async {
    if (widget.readOnly) return;
    if (_isSubmitting || !_log.isPending) return;

    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      setState(() {
        _commentError = 'Comment is required for rejection.';
      });
      return;
    }

    setState(() {
      _commentError = null;
    });
    await _submitReview(approve: false);
  }

  Future<void> _submitReview({required bool approve}) async {
    if (widget.readOnly) return;
    if (_isSubmitting || !_log.isPending) return;

    setState(() {
      _isSubmitting = true;
      _activeAction = approve ? _ActiveAction.approve : _ActiveAction.reject;
    });

    try {
      final updated = approve
          ? await widget.service.approveLog(
              id: widget.logId,
              comment: _commentController.text.trim().isEmpty
                  ? null
                  : _commentController.text.trim(),
            )
          : await widget.service.rejectLog(
              id: widget.logId,
              comment: _commentController.text.trim(),
            );

      if (!mounted) return;

      setState(() {
        _log = updated;
      });

      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Log approved successfully.'
                : 'Log rejected successfully.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;

      if (e.statusCode == 401 || e.errorType == ApiErrorType.unauthorized) {
        await handleExpiredSession(context);
        return;
      }

      final commentErrors = _fieldErrorsFor(e, 'comment');
      if (commentErrors != null && commentErrors.isNotEmpty) {
        setState(() {
          _commentError = commentErrors.first;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            commentErrors != null && commentErrors.isNotEmpty
                ? commentErrors.first
                : _readErrorMessage(e),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_readErrorMessage(e))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _activeAction = null;
        });
      }
    }
  }

  List<String>? _fieldErrorsFor(ApiException exception, String field) {
    final details = exception.details;
    if (details == null) {
      return null;
    }

    final direct = details[field];
    if (direct is List) {
      return direct.map((item) => item.toString()).toList();
    }

    final nestedData = details['data'];
    if (nestedData is Map<String, dynamic>) {
      final nestedErrors = nestedData['errors'];
      if (nestedErrors is Map<String, dynamic>) {
        final nestedField = nestedErrors[field];
        if (nestedField is List) {
          return nestedField.map((item) => item.toString()).toList();
        }
      }
    }

    return null;
  }

  String _readErrorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString().replaceFirst('Exception: ', '');
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

  String _formatTimestamp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Not available';
    }

    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }

    return DateFormatter.formatTimestamp(parsed.toLocal());
  }

  String _formatLogDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('MMM d').format(parsed.toLocal());
  }

  String _formatHours(int hours) {
    return hours == 1 ? '1 hr' : '$hours hrs';
  }

  String _shortFileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isNotEmpty ? parts.last : path;
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }

    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _formatActionLabel(String action) {
    switch (action.toUpperCase()) {
      case 'APPROVED':
        return 'Approved';
      case 'REJECTED':
        return 'Rejected';
      default:
        return action;
    }
  }

  bool _isImageAttachment(LogAttachment attachment) {
    final type = attachment.fileType.toLowerCase();
    return type == 'jpg' || type == 'jpeg' || type == 'png';
  }

  bool _isPdfAttachment(LogAttachment attachment) {
    return attachment.fileType.toLowerCase() == 'pdf';
  }

  Future<void> _previewImage(LogAttachment attachment) async {
    final file = await _ensureAttachmentFile(attachment);
    if (!mounted || file == null) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _shortFileName(file.filename),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF102A56),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: InteractiveViewer(
                    child: Image.memory(
                      Uint8List.fromList(file.bytes),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _previewPdf(LogAttachment attachment) async {
    final file = await _ensureAttachmentFile(attachment);
    if (!mounted || file == null) return;

    final opened = await file_download.openBytesInNewTab(
      bytes: file.bytes,
      mimeType: file.mimeType,
    );

    if (!mounted) return;

    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'PDF preview is only available on web in this build. Use Download instead.',
          ),
        ),
      );
    }
  }

  Future<void> _openAttachment(LogAttachment attachment) async {
    if (_isImageAttachment(attachment)) {
      await _previewImage(attachment);
      return;
    }

    if (_isPdfAttachment(attachment)) {
      await _previewPdf(attachment);
      return;
    }

    await _downloadAttachment(attachment);
  }

  Future<void> _downloadAttachment(LogAttachment attachment) async {
    final file = await _ensureAttachmentFile(attachment);
    if (!mounted || file == null) return;

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
              ? 'Attachment downloaded successfully.'
              : 'Direct download is only available on web in this build.',
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview(LogAttachment attachment) {
    final file = _attachmentFiles[attachment.id];
    final error = _attachmentErrors[attachment.id];
    final isLoading = _loadingAttachmentIds.contains(attachment.id);

    if (!_isImageAttachment(attachment)) {
      return Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Icon(
          _isPdfAttachment(attachment)
              ? Icons.picture_as_pdf_rounded
              : Icons.insert_drive_file_rounded,
          size: 32,
          color: _isPdfAttachment(attachment)
              ? const Color(0xFFD92D20)
              : const Color(0xFF667085),
        ),
      );
    }

    if (file != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(
          Uint8List.fromList(file.bytes),
          width: 78,
          height: 78,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        color: error != null
            ? const Color(0xFFFDECEC)
            : const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: error != null
              ? const Color(0xFFF3B5AE)
              : const Color(0xFFE4E7EC),
        ),
      ),
      child: isLoading
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              error != null
                  ? Icons.broken_image_outlined
                  : Icons.image_outlined,
              color: error != null
                  ? const Color(0xFFD92D20)
                  : const Color(0xFF667085),
            ),
    );
  }

  Widget _buildAttachmentsSection() {
    if (_log.attachments.isEmpty) {
      return const Text('No attachments uploaded.');
    }

    return Column(
      children: _log.attachments.map((attachment) {
        final isImage = _isImageAttachment(attachment);
        final isPdf = _isPdfAttachment(attachment);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openAttachment(attachment),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAttachmentPreview(attachment),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _shortFileName(attachment.filePath),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF102A56),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${attachment.fileType.toUpperCase()} - ${_formatFileSize(attachment.fileSize)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (_attachmentErrors[attachment.id] != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _attachmentErrors[attachment.id]!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFD92D20),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (isImage)
                        ElevatedButton.icon(
                          onPressed: () => _previewImage(attachment),
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('Preview'),
                        ),
                      if (isPdf)
                        ElevatedButton.icon(
                          onPressed: () => _previewPdf(attachment),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('View PDF'),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => _downloadAttachment(attachment),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Download'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReviewHistory() {
    if (_log.reviewHistory.isEmpty) {
      return const Text('No review actions recorded yet.');
    }

    return Column(
      children: _log.reviewHistory.map((action) {
        final color = _statusColor(action.action);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(
                      label: Text(_formatActionLabel(action.action)),
                      backgroundColor: color.withAlpha((0.14 * 255).round()),
                      side: BorderSide(color: color),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatTimestamp(action.actedAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                Text(
                  'By: ${action.supervisorName ?? 'Supervisor'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  action.hasComment
                      ? action.comment!.trim()
                      : 'No comment was added.',
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.readOnly) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    size: 20,
                    color: Color(0xFF1D4ED8),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.readOnlyMessage ??
                          'Read-only view. Approval controls remain with the assigned supervisor.',
                      style: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  'Student: ${_log.studentName}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Chip(
                label: Text(_log.status),
                backgroundColor: _statusColor(
                  _log.status,
                ).withAlpha((0.14 * 255).round()),
                side: BorderSide(color: _statusColor(_log.status)),
              ),
            ],
          ),
          if ((_log.studentEmail ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_log.studentEmail!),
          ],
          if ((_log.companyName ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Company: ${_log.companyName}'),
          ],
          const SizedBox(height: 8),
          Text('Date: ${_formatLogDate(_log.date)}'),
          Text('Hours: ${_formatHours(_log.hoursRendered)}'),
          if ((_log.submittedAt ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Submitted: ${_formatTimestamp(_log.submittedAt)}'),
          ],
          const SizedBox(height: 12),
          const Text(
            'Task Description:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(_log.taskDescription),
          const SizedBox(height: 12),
          const Text(
            'Attachments:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          _buildAttachmentsSection(),
          const SizedBox(height: 16),
          const Text(
            'Review History',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          _buildReviewHistory(),
          const SizedBox(height: 16),
          if (!widget.readOnly) ...[
            TextField(
              controller: _commentController,
              maxLines: 4,
              enabled: !_isSubmitting && _log.isPending,
              onChanged: (_) {
                if (_commentError != null) {
                  setState(() {
                    _commentError = null;
                  });
                }
              },
              decoration: InputDecoration(
                labelText: 'Rejection Comment (required if reject)',
                alignLabelWithHint: true,
                hintText: 'Add feedback for the student',
                errorText: _commentError,
              ),
            ),
            const SizedBox(height: 16),
            if (!_log.isPending) ...[
              const Row(
                children: [
                  Icon(Icons.lock_outline, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('This log has already been reviewed.')),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: !_log.isPending || _isSubmitting
                        ? null
                        : _approve,
                    icon: _activeAction == _ActiveAction.approve
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('APPROVE'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: !_log.isPending || _isSubmitting
                        ? null
                        : _reject,
                    icon: _activeAction == _ActiveAction.reject
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_outlined),
                    label: const Text('REJECT'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title ?? (widget.readOnly ? 'Log Details' : 'Review Log'),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : _buildBody(),
    );
  }
}
