import '../../shared/models/student_report.dart';
import '../exceptions/api_exception.dart';
import 'dtr_service.dart';
import 'api_client.dart';
import 'base_service.dart';

class InternReportingService extends BaseService {
  InternReportingService([ApiClient? apiClient])
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  String _endpointForRole({
    required String role,
    required int studentId,
  }) {
    final normalizedRole = role.toLowerCase();

    switch (normalizedRole) {
      case 'supervisor':
        return '/supervisor/students/$studentId';
      case 'adviser':
        return '/adviser/students/$studentId';
      default:
        throw ApiException(
          message: 'Unsupported role for intern reporting: $role',
          errorType: ApiErrorType.clientError,
          isRecoverable: false,
        );
    }
  }

  Future<StudentReportData> getReport({
    required String role,
    required int studentId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      return await _apiClient.get<StudentReportData>(
        path: '${_endpointForRole(role: role, studentId: studentId)}/report',
        queryParameters: <String, String>{
          if ((startDate ?? '').isNotEmpty) 'start_date': startDate!,
          if ((endDate ?? '').isNotEmpty) 'end_date': endDate!,
        },
        converter: (data) {
          if (data is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid report response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          final reportData = data['data'];
          if (reportData is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid report response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          try {
            return StudentReportData.fromJson(reportData);
          } catch (e) {
            throw ApiException(
              message: 'Failed to parse report data.',
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

  Future<DtrExportFile> exportDtr({
    required String role,
    required int studentId,
    required int month,
    required int year,
    required bool pdf,
  }) async {
    try {
      final format = pdf ? 'pdf' : 'excel';
      final fallbackFilename =
          'dtr_$year-${month.toString().padLeft(2, '0')}.${pdf ? 'pdf' : 'csv'}';
      final fallbackMimeType = pdf ? 'application/pdf' : 'text/csv';

      final response = await _apiClient.downloadResponse(
        path:
            '${_endpointForRole(role: role, studentId: studentId)}/dtr/export/$format',
        queryParameters: <String, dynamic>{
          'month': month,
          'year': year,
        },
      );

      return DtrExportFile(
        bytes: response.data ?? const <int>[],
        filename: _extractFilename(
          response.headers.value('content-disposition'),
          fallbackFilename,
        ),
        mimeType:
            response.headers.value('content-type') ?? fallbackMimeType,
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  String _extractFilename(String? contentDisposition, String fallback) {
    final match = RegExp(r'filename="([^"]+)"').firstMatch(
      contentDisposition ?? '',
    );
    if (match != null) {
      return match.group(1) ?? fallback;
    }

    return fallback;
  }
}
