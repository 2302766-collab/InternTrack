import '../../shared/models/admin_student_summary.dart';
import '../../shared/models/admin_students_page.dart';
import '../exceptions/api_exception.dart';
import 'api_client.dart';
import 'base_service.dart';

class AdminStudentService extends BaseService {
  AdminStudentService([ApiClient? apiClient])
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<AdminStudentsPage> fetchStudents({
    required int page,
    int perPage = 10,
  }) async {
    try {
      return await _apiClient.get<AdminStudentsPage>(
        path: '/admin/students',
        queryParameters: <String, dynamic>{
          'page': page,
          'per_page': perPage,
        },
        converter: (payload) {
          if (payload is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid admin students response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          final rawData = payload['data'];
          final students = rawData is List
              ? rawData
                  .whereType<Map<String, dynamic>>()
                  .map(AdminStudentSummary.fromJson)
                  .toList()
              : <AdminStudentSummary>[];

          final meta = payload['meta'];
          if (meta is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Pagination metadata is missing.',
              errorType: ApiErrorType.unknown,
            );
          }

          return AdminStudentsPage(
            students: students,
            currentPage: (meta['current_page'] as num?)?.toInt() ?? page,
            perPage: (meta['per_page'] as num?)?.toInt() ?? perPage,
            total: (meta['total'] as num?)?.toInt() ?? students.length,
            lastPage: (meta['last_page'] as num?)?.toInt() ?? 1,
            hasMorePages: meta['has_more_pages'] == true,
          );
        },
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }
}
