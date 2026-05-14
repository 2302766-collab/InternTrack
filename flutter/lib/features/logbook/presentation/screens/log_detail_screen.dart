import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/services/logbook_service.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/file_download_stub.dart'
    if (dart.library.html) '../../../../core/utils/file_download_web.dart'
    as file_download;
import '../../../../shared/models/log_attachment.dart';
import '../../../../shared/models/log_entry.dart';
import 'log_edit_screen.dart';

class LogDetailScreen extends StatefulWidget {
  final int logId;
  final LogbookService service;
  final LogEntryItem? initialLog;

  const LogDetailScreen({
    super.key,
    required this.logId,
    required this.service,
    this.initialLog,
  });

  @override
  State<LogDetailScreen> createState() => _LogDetailScreenState();
}

class _LogDetailScreenState extends State<LogDetailScreen> {
  late LogEntryItem _log;
  bool _isLoading = true;
  String? _error;

  final Map<int, LogbookAttachmentFile> _attachmentFiles =
      <int, LogbookAttachmentFile>{};
  final Map<int, String> _attachmentErrors = <int, String>{};
  final Set<int> _loadingAttachmentIds = <int>{};

  @override
  void initState() {
    super.initState();
    _log =
        widget.initialLog ??
        LogEntryItem(
          id: widget.logId,
          internshipProfileId: 0,
          date: '',
          hoursRendered: 0,
          taskDescription: '',
          status: '',
          attachments: const [],
          attachmentsCount: 0,
          reviewHistory: const [],
        );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fresh = await widget.service.getLog(widget.logId);
      if (!mounted) return;

      setState(() {
        _log = fresh;
      });
      _prefetchImageAttachments();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
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

  Future<LogbookAttachmentFile?> _ensureAttachmentFile(
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
    } catch (e) {
      if (!mounted) return null;
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _attachmentErrors[attachment.id] = message;
      });

      if (!silent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
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

  IconData _statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return Icons.check_circle_rounded;
      case 'REJECTED':
        return Icons.cancel_rounded;
      case 'PENDING':
        return Icons.schedule_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }

    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    }

    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }

  String _shortFileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isNotEmpty ? parts.last : path;
  }

  String _friendlyAttachmentName(LogAttachment attachment, int index) {
    final extension = attachment.fileType.trim().toLowerCase();
    if (extension.isEmpty) {
      return 'Proof Attachment ${index + 1}';
    }

    return 'Proof Attachment ${index + 1}.$extension';
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

  String _statusDescription(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return 'This log has been approved by your supervisor.';
      case 'REJECTED':
        return 'This log needs correction before it can be accepted.';
      case 'PENDING':
        return 'This log is waiting for supervisor review.';
      default:
        return 'Status information is currently unavailable.';
    }
  }

  String _formatTaskDescription(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Activity details were not provided for this submission.';
    }

    final looksLikeSeedValue =
        RegExp(r'^\d{1,2}:\d{2}$').hasMatch(trimmed) ||
        RegExp(r'^\d{2}/\d{2}$').hasMatch(trimmed) ||
        RegExp(r'^\d+(st|nd|rd|th)$', caseSensitive: false).hasMatch(trimmed);

    if (looksLikeSeedValue) {
      return 'Activity details were not provided for this submission.';
    }

    return trimmed;
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

  Widget _buildSectionCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
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
      child: child,
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF102A56),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 14, color: Color(0xFF667085)),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return _buildSectionCard(
      padding: const EdgeInsets.all(24),
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
                    const Text(
                      'Daily Log Entry',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      DateFormatter.formatApiDate(_log.date),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF102A56),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Submitted ${_formatTimestamp(_log.submittedAt)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _statusDescription(_log.status),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Color(0xFF344054),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _statusBackground(_log.status),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _statusIcon(_log.status),
                      size: 16,
                      color: _statusColor(_log.status),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _log.status.toUpperCase(),
                      style: TextStyle(
                        color: _statusColor(_log.status),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth >= 760
                  ? (constraints.maxWidth - 24) / 3
                  : constraints.maxWidth >= 520
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _buildMetricPanel(
                      label: 'Hours Rendered',
                      value: '${_log.hoursRendered} h',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildMetricPanel(
                      label: 'Attachments',
                      value: '${_log.attachments.length}',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildMetricPanel(
                      label: 'Review Events',
                      value: '${_log.reviewHistory.length}',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPanel({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: _SummaryMetric(label: label, value: value),
    );
  }

  Widget _buildTaskDescriptionCard() {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: 'Work Summary',
            subtitle: 'A quick view of what was accomplished for this day.',
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FBFD),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFDCE6F2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Task Completed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatTaskDescription(_log.taskDescription),
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Color(0xFF344054),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterButtons({Widget? primary, Widget? secondary}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 560;
        final buttons = <Widget>[
          ?secondary,
          ?primary,
        ];

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                SizedBox(width: double.infinity, child: buttons[i]),
                if (i != buttons.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.end,
          children: buttons,
        );
      },
    );
  }

  Widget _buildBackToLogbookButton() {
    return OutlinedButton.icon(
      onPressed: () => Navigator.maybePop(context, true),
      icon: const Icon(Icons.arrow_back_rounded),
      label: const Text('Back to Logbook'),
    );
  }

  Widget _buildReviewHistorySection() {
    if (_log.reviewHistory.isEmpty) {
      return _buildSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: 'Review History',
              subtitle: 'Feedback and approval activity for this submission.',
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                  border: Border.fromBorderSide(
                    BorderSide(color: Color(0xFFE4E7EC)),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.mark_email_read_outlined,
                        color: Color(0xFF98A2B3),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _log.isPending
                              ? 'No supervisor feedback yet. This log is still waiting for review.'
                              : 'No supervisor feedback is available for this submission yet.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF667085),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: 'Review History',
            subtitle: 'Feedback and approval activity for this submission.',
          ),
          const SizedBox(height: 18),
          ..._log.reviewHistory.asMap().entries.map((entry) {
            final index = entry.key;
            final action = entry.value;
            final actionColor = _statusColor(action.action);
            final isLast = index == _log.reviewHistory.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 28,
                      child: Column(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: actionColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: actionColor.withValues(alpha: 0.22),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              _statusIcon(action.action),
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                color: const Color(0xFFD0D5DD),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE4E7EC)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0F0F172A),
                              blurRadius: 14,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusBackground(action.action),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _statusIcon(action.action),
                                        size: 14,
                                        color: actionColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatActionLabel(action.action),
                                        style: TextStyle(
                                          color: actionColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _formatTimestamp(action.actedAt),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF667085),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Reviewed by',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                                color: Color(0xFF667085),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              action.supervisorName ?? 'Supervisor',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF102A56),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                action.hasComment
                                    ? action.comment!.trim()
                                    : 'No comment added',
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: Color(0xFF344054),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview(LogAttachment attachment) {
    final file = _attachmentFiles[attachment.id];
    final error = _attachmentErrors[attachment.id];
    final isLoading = _loadingAttachmentIds.contains(attachment.id);

    if (!_isImageAttachment(attachment)) {
      return Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Icon(
          _isPdfAttachment(attachment)
              ? Icons.picture_as_pdf_rounded
              : Icons.insert_drive_file_rounded,
          size: 34,
          color: _isPdfAttachment(attachment)
              ? const Color(0xFFD92D20)
              : const Color(0xFF667085),
        ),
      );
    }

    if (file != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE4E7EC)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Image.memory(
            Uint8List.fromList(file.bytes),
            width: 84,
            height: 84,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: error != null
            ? const Color(0xFFFDECEC)
            : const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: error != null
              ? const Color(0xFFF3B5AE)
              : const Color(0xFFE4E7EC),
        ),
      ),
      child: isLoading
          ? const Padding(
              padding: EdgeInsets.all(24),
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

  Widget _buildAttachmentItem(LogAttachment attachment, int index) {
    final isImage = _isImageAttachment(attachment);
    final isPdf = _isPdfAttachment(attachment);
    final originalName = _shortFileName(attachment.filePath);
    final displayName = _friendlyAttachmentName(attachment, index);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAttachmentPreview(attachment),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F4F7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            attachment.fileType.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475467),
                            ),
                          ),
                        ),
                        if (isImage || isPdf)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF8FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isImage
                                  ? 'Preview ready'
                                  : 'Browser view available',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF175CD3),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF102A56),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Original file: $originalName',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${attachment.fileType.toUpperCase()} | ${_formatFileSize(attachment.fileSize)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF667085),
                      ),
                    ),
                    if ((attachment.createdAt ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Uploaded ${_formatTimestamp(attachment.createdAt)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ],
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
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (isImage)
                  ElevatedButton.icon(
                    onPressed: () => _previewImage(attachment),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Preview'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEFF8FF),
                      foregroundColor: const Color(0xFF175CD3),
                      elevation: 0,
                    ),
                  ),
                if (isPdf)
                  ElevatedButton.icon(
                    onPressed: () => _previewPdf(attachment),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('View'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF4E5),
                      foregroundColor: const Color(0xFFB54708),
                      elevation: 0,
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _downloadAttachment(attachment),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection() {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: 'Attachments (${_log.attachments.length})',
            subtitle:
                'Preview uploaded proof, open supported files, or download originals.',
          ),
          const SizedBox(height: 14),
          if (_log.attachments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE4E7EC)),
              ),
              child: const Text(
                'No attachments uploaded yet.',
                style: TextStyle(fontSize: 14, color: Color(0xFF667085)),
              ),
            )
          else
            ..._log.attachments.asMap().entries.map(
              (entry) => _buildAttachmentItem(entry.value, entry.key),
            ),
        ],
      ),
    );
  }

  Widget _buildFooterAction() {
    if (_log.isPending) {
      return _buildSectionCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF8FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.edit_note_rounded,
                color: Color(0xFF175CD3),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Need to make changes?',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF102A56),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'You can still update this log while it is pending supervisor review.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFF344054),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildFooterButtons(
                    secondary: _buildBackToLogbookButton(),
                    primary: FilledButton.icon(
                      onPressed: _openEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit Log'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _buildSectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _statusBackground(_log.status),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              color: _statusColor(_log.status),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _log.status.toUpperCase() == 'APPROVED'
                      ? 'Log approved'
                      : _log.status.toUpperCase() == 'REJECTED'
                      ? 'Log needs correction'
                      : 'Editing locked',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF102A56),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _log.status.toUpperCase() == 'APPROVED'
                      ? 'This log has been accepted and can no longer be edited.'
                      : _log.status.toUpperCase() == 'REJECTED'
                      ? 'Please review the supervisor feedback above. This entry cannot be edited here because only pending logs can be updated.'
                      : 'Editing is disabled because this log is no longer pending review.',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF344054),
                  ),
                ),
                const SizedBox(height: 14),
                _buildFooterButtons(primary: _buildBackToLogbookButton()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEdit() async {
    if (!_log.isPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot edit non-pending logs.')),
      );
      return;
    }

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LogEditScreen(log: _log, service: widget.service),
      ),
    );

    if (updated == true) {
      await _load();
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1020),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCard(),
              const SizedBox(height: 16),
              _buildTaskDescriptionCard(),
              const SizedBox(height: 16),
              _buildReviewHistorySection(),
              const SizedBox(height: 16),
              _buildAttachmentsSection(),
              const SizedBox(height: 20),
              _buildFooterAction(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Details'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _buildContent(),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
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
    );
  }
}
