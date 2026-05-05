import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../../shared/models/log_attachment.dart';
import '../../shared/models/log_entry.dart';
import '../exceptions/api_exception.dart';
import 'api_client.dart';
import 'base_service.dart';

class LogbookAttachmentFile {
  final List<int> bytes;
  final String filename;
  final String mimeType;

  const LogbookAttachmentFile({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });
}

class LogbookService extends BaseService {
  LogbookService([ApiClient? apiClient])
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<LogEntryItem>> getLogs() async {
    try {
      return await _apiClient.get<List<LogEntryItem>>(
        path: '/student/logs',
        converter: (data) {
          if (data is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid logs response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          final logs = data['data'];
          if (logs is! List) {
            return <LogEntryItem>[];
          }

          try {
            return logs
                .whereType<Map<String, dynamic>>()
                .map(LogEntryItem.fromJson)
                .toList();
          } catch (e) {
            throw ApiException(
              message: 'Failed to parse logs.',
              errorType: ApiErrorType.unknown,
              originalError: e,
            );
          }
        },
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  Future<LogEntryItem> getLog(int id) async {
    try {
      return await _apiClient.get<LogEntryItem>(
        path: '/student/logs/$id',
        converter: (data) => _parseLogEntry(data, 'Invalid log details response format.'),
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  Future<LogEntryItem> createLog({
    required String date,
    required int hoursRendered,
    required String taskDescription,
  }) async {
    try {
      return await _apiClient.post<LogEntryItem>(
        path: '/student/logs',
        data: {
          'date': date,
          'hours_rendered': hoursRendered,
          'task_description': taskDescription,
        },
        converter: (data) =>
            _parseLogEntry(data, 'Invalid create log response format.'),
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  Future<LogEntryItem> updateLog({
    required int id,
    required String date,
    required int hoursRendered,
    required String taskDescription,
  }) async {
    try {
      return await _apiClient.put<LogEntryItem>(
        path: '/student/logs/$id',
        data: {
          'date': date,
          'hours_rendered': hoursRendered,
          'task_description': taskDescription,
        },
        converter: (data) =>
            _parseLogEntry(data, 'Invalid update log response format.'),
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  Future<LogAttachment> uploadAttachment({
    required int logId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: _mediaTypeFor(mimeType, fileName),
        ),
      });

      return await _apiClient.post<LogAttachment>(
        path: '/student/logs/$logId/attachments',
        data: formData,
        converter: (data) {
          if (data is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid attachment upload response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          final attachmentData = data['data'];
          if (attachmentData is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid attachment upload response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          try {
            return LogAttachment.fromJson(attachmentData);
          } catch (e) {
            throw ApiException(
              message: 'Failed to parse attachment.',
              errorType: ApiErrorType.unknown,
              originalError: e,
            );
          }
        },
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  Future<LogbookAttachmentFile> downloadAttachment({
    required int logId,
    required int attachmentId,
  }) async {
    try {
      final response = await _apiClient.downloadResponse(
        path: '/student/logs/$logId/attachments/$attachmentId',
      );

      return LogbookAttachmentFile(
        bytes: response.data ?? const <int>[],
        filename: _extractFilename(
          response.headers.value('content-disposition'),
          'attachment_$attachmentId',
        ),
        mimeType:
            response.headers.value('content-type') ??
            'application/octet-stream',
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  MediaType _mediaTypeFor(String mimeType, String fileName) {
    final normalizedMimeType = mimeType.trim().toLowerCase();
    if (normalizedMimeType.contains('/')) {
      final parts = normalizedMimeType.split('/');
      return MediaType(parts.first, parts.sublist(1).join('/'));
    }

    final normalizedFileName = fileName.toLowerCase();
    if (normalizedFileName.endsWith('.jpg') ||
        normalizedFileName.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }

    if (normalizedFileName.endsWith('.png')) {
      return MediaType('image', 'png');
    }

    if (normalizedFileName.endsWith('.pdf')) {
      return MediaType('application', 'pdf');
    }

    return MediaType('application', 'octet-stream');
  }

  String _extractFilename(String? contentDisposition, String fallback) {
    final match = RegExp(
      r'filename="([^"]+)"',
    ).firstMatch(contentDisposition ?? '');
    if (match != null && (match.group(1) ?? '').isNotEmpty) {
      return match.group(1)!;
    }

    return fallback;
  }

  LogEntryItem _parseLogEntry(dynamic data, String invalidMessage) {
    if (data is! Map<String, dynamic>) {
      throw ApiException(
        message: invalidMessage,
        errorType: ApiErrorType.unknown,
      );
    }

    final logData = data['data'];
    if (logData is! Map<String, dynamic>) {
      throw ApiException(
        message: invalidMessage,
        errorType: ApiErrorType.unknown,
      );
    }

    try {
      return LogEntryItem.fromJson(logData);
    } catch (e) {
      throw ApiException(
        message: 'Failed to parse log entry.',
        errorType: ApiErrorType.unknown,
        originalError: e,
      );
    }
  }
}
