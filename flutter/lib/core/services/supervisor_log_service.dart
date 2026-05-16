import '../../shared/models/supervisor_log_item.dart';
import 'package:dio/dio.dart';
import '../exceptions/api_exception.dart';
import '../services/api_client.dart';
import '../services/base_service.dart';

/// Data model for supervisor log attachments
class SupervisorLogAttachmentFile {
  final List<int> bytes;
  final String filename;
  final String mimeType;

  const SupervisorLogAttachmentFile({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });
}

/// Service for managing supervisor/adviser logs
///
/// Handles fetching, approving, and rejecting student logs
/// Works for both 'supervisor' and 'adviser' roles
/// All methods throw [ApiException] for consistent error handling
class SupervisorLogService extends BaseService {
  final ApiClient _apiClient;
  final String _role;

  SupervisorLogService(this._apiClient, {String role = 'supervisor'})
    : _role = role.toLowerCase();

  String get _endpoint => '/$_role/logs';

  /// Fetches all pending logs for review
  ///
  /// Throws [ApiException] if fetch fails
  Future<List<SupervisorLogItem>> getPendingLogs() async {
    try {
      return await _apiClient.get<List<SupervisorLogItem>>(
        path: _endpoint,
        converter: (data) => _parsePendingLogsResponse(data),
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  /// Fetches detailed information about a specific log
  ///
  /// Throws [ApiException] if fetch fails
  Future<SupervisorLogItem> getLog(int id) async {
    try {
      return await _apiClient.get<SupervisorLogItem>(
        path: '$_endpoint/$id',
        converter: (data) => _parseLogResponse(data),
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  /// Approves a log entry (supervisor only)
  ///
  /// Throws [ApiException] if:
  /// - User is not a supervisor
  /// - Approval fails on server
  Future<SupervisorLogItem> approveLog({
    required int id,
    String? comment,
  }) async {
    if (_role != 'supervisor') {
      throw ApiException(
        message: 'Only supervisors can approve logs.',
        errorType: ApiErrorType.forbidden,
        isRecoverable: false,
      );
    }

    return _submitReview(id: id, action: 'approve', comment: comment);
  }

  /// Rejects a log entry with required comment (supervisor only)
  ///
  /// Throws [ApiException] if:
  /// - User is not a supervisor
  /// - Rejection fails on server
  Future<SupervisorLogItem> rejectLog({
    required int id,
    required String comment,
  }) async {
    if (_role != 'supervisor') {
      throw ApiException(
        message: 'Only supervisors can reject logs.',
        errorType: ApiErrorType.forbidden,
        isRecoverable: false,
      );
    }

    return _submitReview(id: id, action: 'reject', comment: comment);
  }

  /// Downloads an attachment from a log entry
  ///
  /// Returns SupervisorLogAttachmentFile with bytes and filename
  /// Throws [ApiException] if download fails
  Future<SupervisorLogAttachmentFile> downloadAttachment({
    required int logId,
    required int attachmentId,
  }) async {
    try {
      final response = await _apiClient.downloadResponse(
        path: '$_endpoint/$logId/attachments/$attachmentId',
      );

      final bytes = response.data ?? <int>[];
      final mimeType = _extractMimeType(response.headers.value('content-type'));
      final filename = _resolveAttachmentFilename(
        response.headers.value('content-disposition'),
        attachmentId,
        mimeType,
      );

      return SupervisorLogAttachmentFile(
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  String _resolveAttachmentFilename(
    String? contentDisposition,
    int attachmentId,
    String mimeType,
  ) {
    final rawFilename = _parseContentDispositionFilename(contentDisposition);
    final sanitized = _sanitizeFilename(rawFilename);
    return _finalFilename(sanitized, attachmentId, mimeType);
  }

  String _parseContentDispositionFilename(String? header) {
    if (header == null) {
      return '';
    }

    final filenameStarMatch = RegExp(
      r"filename\*\s*=\s*(?:UTF-8''|)[^;\r\n]+",
      caseSensitive: false,
    ).firstMatch(header);
    if (filenameStarMatch != null) {
      var raw = filenameStarMatch.group(0) ?? '';
      raw = raw.split('=').last.trim();
      raw = raw.replaceAll(RegExp(r'^"|"$'), '');

      final segments = raw.split("'");
      if (segments.length >= 3) {
        final encoded = segments.sublist(2).join("'");
        try {
          return Uri.decodeFull(encoded);
        } catch (_) {
          return encoded;
        }
      }

      try {
        return Uri.decodeFull(raw);
      } catch (_) {
        return raw;
      }
    }

    final filenameMatch = RegExp(
      r'filename\s*=\s*(?:"([^"]+)"|([^;\r\n]+))',
      caseSensitive: false,
    ).firstMatch(header);
    if (filenameMatch != null) {
      return filenameMatch.group(1)?.trim() ??
          filenameMatch.group(2)?.trim() ??
          '';
    }

    return '';
  }

  String _sanitizeFilename(String filename) {
    final cleaned = filename
        .replaceAll(RegExp(r'[\r\n]'), ' ')
        .replaceAll(RegExp(r'[\/]+'), '_')
        .replaceAll(RegExp(r'[:*?"<>|]+'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty) {
      return '';
    }

    return cleaned.length <= 255 ? cleaned : cleaned.substring(0, 255);
  }

  String _finalFilename(String filename, int attachmentId, String mimeType) {
    final extension = _extensionForMimeType(mimeType);
    if (filename.isEmpty) {
      return 'attachment_$attachmentId.${extension.isNotEmpty ? extension : 'bin'}';
    }

    if (_hasValidExtension(filename)) {
      return filename;
    }

    if (extension.isNotEmpty) {
      return '$filename.$extension';
    }

    return '$filename.bin';
  }

  bool _hasValidExtension(String filename) {
    final index = filename.lastIndexOf('.');
    if (index <= 0 || index == filename.length - 1) {
      return false;
    }

    final ext = filename.substring(index + 1);
    return ext.length <= 10;
  }

  String _extractMimeType(String? contentTypeHeader) {
    if (contentTypeHeader == null || contentTypeHeader.trim().isEmpty) {
      return 'application/octet-stream';
    }

    final mimeType = contentTypeHeader.split(';').first.trim();
    if (mimeType.isEmpty) {
      return 'application/octet-stream';
    }
    return mimeType;
  }

  String _extensionForMimeType(String mimeType) {
    const fallbackExtensions = {
      'application/pdf': 'pdf',
      'image/png': 'png',
      'image/jpeg': 'jpg',
      'text/csv': 'csv',
      'application/csv': 'csv',
    };

    return fallbackExtensions[mimeType.toLowerCase()] ?? '';
  }

  /// Submits a review (approve/reject) for a log
  Future<SupervisorLogItem> _submitReview({
    required int id,
    required String action,
    String? comment,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (comment != null && comment.isNotEmpty) {
        payload['comment'] = comment;
      }

      return await _apiClient.post<SupervisorLogItem>(
        path: '$_endpoint/$id/$action',
        data: payload.isEmpty ? null : payload,
        converter: (data) => _parseLogResponse(data),
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  /// Parses pending logs response
  List<SupervisorLogItem> _parsePendingLogsResponse(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw ApiException(
        message: 'Invalid logs response format',
        errorType: ApiErrorType.unknown,
      );
    }

    final logsData = data['data'];
    if (logsData is! List) {
      throw ApiException(
        message: 'Invalid logs data format',
        errorType: ApiErrorType.unknown,
      );
    }

    try {
      return logsData
          .whereType<Map<String, dynamic>>()
          .map(SupervisorLogItem.fromJson)
          .toList();
    } catch (e) {
      throw ApiException(
        message: 'Failed to parse logs',
        errorType: ApiErrorType.unknown,
        originalError: e,
      );
    }
  }

  /// Parses single log response
  SupervisorLogItem _parseLogResponse(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw ApiException(
        message: 'Invalid log response format',
        errorType: ApiErrorType.unknown,
      );
    }

    final logData = data['data'] as Map<String, dynamic>?;
    if (logData == null) {
      throw ApiException(
        message: 'No log data in response',
        errorType: ApiErrorType.unknown,
      );
    }

    try {
      return SupervisorLogItem.fromJson(logData);
    } catch (e) {
      throw ApiException(
        message: 'Failed to parse log data',
        errorType: ApiErrorType.unknown,
        originalError: e,
      );
    }
  }
}
