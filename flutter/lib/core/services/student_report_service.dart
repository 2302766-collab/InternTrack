import '../../shared/models/student_report.dart';
import '../exceptions/api_exception.dart';
import 'api_client.dart';
import 'base_service.dart';

class StudentReportService extends BaseService {
  StudentReportService([ApiClient? apiClient])
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<StudentReportData> getReport(
    {
    String? startDate,
    String? endDate,
  }) async {
    try {
      return await _apiClient.get<StudentReportData>(
        path: '/student/report',
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

}
