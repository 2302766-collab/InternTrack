import '../../shared/models/supervisor_log_item.dart';
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

    return _submitReview(
      id: id,
      action: 'approve',
      comment: comment,
    );
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

    return _submitReview(
      id: id,
      action: 'reject',
      comment: comment,
    );
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
      final mimeType =
          response.headers.value('content-type') ?? 'application/octet-stream';
      final filename = _extractFilename(
        response.headers.value('content-disposition'),
        attachmentId,
        mimeType,
      );

      return SupervisorLogAttachmentFile(
        bytes: response.data ?? const <int>[],
        filename: filename,
        mimeType: mimeType,
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  String _extractFilename(
    String? contentDisposition,
    int attachmentId,
    String mimeType,
  ) {
    final raw = contentDisposition ?? '';
    final utf8Match = RegExp(r'''filename\*\s*=\s*UTF-8''([^;]+)''').firstMatch(
      raw,
    );
    if (utf8Match != null) {
      final encoded = utf8Match.group(1) ?? '';
      final decoded = Uri.decodeComponent(encoded).trim();
      if (decoded.isNotEmpty) {
        return decoded;
      }
    }

    final quotedMatch = RegExp(r'''filename\s*=\s*"([^"]+)"''').firstMatch(raw);
    if (quotedMatch != null) {
      final value = quotedMatch.group(1)?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    final plainMatch = RegExp(r'''filename\s*=\s*([^;]+)''').firstMatch(raw);
    if (plainMatch != null) {
      final value = plainMatch.group(1)?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    return 'attachment_$attachmentId${_extensionForMimeType(mimeType)}';
  }

  String _extensionForMimeType(String mimeType) {
    final normalized = mimeType.toLowerCase();
    if (normalized.contains('pdf')) return '.pdf';
    if (normalized.contains('png')) return '.png';
    if (normalized.contains('jpeg') || normalized.contains('jpg')) return '.jpg';
    if (normalized.contains('csv')) return '.csv';
    return '.bin';
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
