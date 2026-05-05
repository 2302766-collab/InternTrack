import '../../shared/models/supervisor_dashboard_summary.dart';
import '../exceptions/api_exception.dart';
import 'api_client.dart';
import 'base_service.dart';

class SupervisorDashboardService extends BaseService {
  SupervisorDashboardService([ApiClient? apiClient])
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<SupervisorDashboardSummary> getSummary() async {
    try {
      return await _apiClient.get<SupervisorDashboardSummary>(
        path: '/supervisor/dashboard',
        converter: (data) {
          if (data is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid supervisor dashboard response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          final summaryData = data['data'];
          if (summaryData is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid supervisor dashboard response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          try {
            return SupervisorDashboardSummary.fromJson(summaryData);
          } catch (e) {
            throw ApiException(
              message: 'Failed to parse supervisor dashboard metrics.',
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
