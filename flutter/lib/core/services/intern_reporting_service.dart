import '../../shared/models/student_report.dart';
import '../exceptions/api_exception.dart';
import 'dtr_service.dart';
import 'api_client.dart';
import 'base_service.dart';

class InternReportingService extends BaseService {
  InternReportingService([ApiClient? apiClient])
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  String _reportEndpointForRole({
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

  String _dtrEndpointForRole({required String role, required int studentId}) {
    final normalizedRole = role.toLowerCase();

    switch (normalizedRole) {
      case 'supervisor':
        return '/supervisor/students/$studentId';
      case 'adviser':
        return '/adviser/students/$studentId';
      case 'admin':
        return '/admin/students/$studentId';
      default:
        throw ApiException(
          message: 'Unsupported role for DTR export: $role',
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
        path:
            '${_reportEndpointForRole(role: role, studentId: studentId)}/report',
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
    int? month,
    int? year,
    DateTime? startDate,
    DateTime? endDate,
    required bool pdf,
  }) async {
    final queryParameters = _buildExportQueryParameters(
      month: month,
      year: year,
      startDate: startDate,
      endDate: endDate,
    );
    final resolvedYear = year ?? startDate!.year;
    final resolvedMonth = month ?? startDate!.month;

    try {
      final format = pdf ? 'pdf' : 'excel';
      final fallbackFilename =
          'dtr_$resolvedYear-${resolvedMonth.toString().padLeft(2, '0')}.${pdf ? 'pdf' : 'csv'}';
      final fallbackMimeType = pdf ? 'application/pdf' : 'text/csv';

      final response = await _apiClient.downloadResponse(
        path:
            '${_dtrEndpointForRole(role: role, studentId: studentId)}/dtr/export/$format',
        queryParameters: queryParameters,
      );

      return DtrExportFile(
        bytes: response.data ?? const <int>[],
        filename: _extractFilename(
          response.headers.value('content-disposition'),
          fallbackFilename,
        ),
        mimeType: response.headers.value('content-type') ?? fallbackMimeType,
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  Map<String, dynamic> _buildExportQueryParameters({
    int? month,
    int? year,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final hasDateRange = startDate != null || endDate != null;

    if (hasDateRange) {
      if (startDate == null || endDate == null) {
        throw ApiException(
          message:
              'Both start and end dates are required for filtered exports.',
          errorType: ApiErrorType.clientError,
          isRecoverable: false,
        );
      }

      return <String, dynamic>{
        'start_date': _formatDate(startDate),
        'end_date': _formatDate(endDate),
      };
    }

    if (month == null || year == null) {
      throw ApiException(
        message: 'Month and year are required when no date range is provided.',
        errorType: ApiErrorType.clientError,
        isRecoverable: false,
      );
    }

    return <String, dynamic>{'month': month, 'year': year};
  }

  String _extractFilename(String? contentDisposition, String fallback) {
    final match = RegExp(
      r'filename="([^"]+)"',
    ).firstMatch(contentDisposition ?? '');
    if (match != null) {
      return match.group(1) ?? fallback;
    }

    return fallback;
  }

  String _formatDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
