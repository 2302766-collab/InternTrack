import '../../shared/models/admin_dashboard_summary.dart';
import '../exceptions/api_exception.dart';
import 'api_client.dart';
import 'base_service.dart';

class AdminDashboardService extends BaseService {
  AdminDashboardService([ApiClient? apiClient])
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<AdminDashboardSummary> getSummary() async {
    try {
      return await _apiClient.get<AdminDashboardSummary>(
        path: '/admin/dashboard',
        converter: (data) {
          if (data is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid admin dashboard response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          final summaryData = data['data'];
          if (summaryData is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid admin dashboard response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          try {
            return AdminDashboardSummary.fromJson(summaryData);
          } catch (e) {
            throw ApiException(
              message: 'Failed to parse admin dashboard metrics.',
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
