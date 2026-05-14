import '../../shared/models/student_supervisor_assignment.dart';
import '../../shared/models/supervisor_option.dart';
import '../exceptions/api_exception.dart';
import 'api_client.dart';
import 'base_service.dart';

class SupervisorManagementService extends BaseService {
  SupervisorManagementService([ApiClient? apiClient])
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<SupervisorOption>> fetchSupervisors() async {
    try {
      return await _apiClient.get<List<SupervisorOption>>(
        path: '/admin/supervisors',
        converter: (payload) {
          if (payload is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid supervisors response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          final rawData = payload['data'];
          return rawData is List
              ? rawData
                    .whereType<Map<String, dynamic>>()
                    .map(SupervisorOption.fromJson)
                    .toList()
              : <SupervisorOption>[];
        },
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  Future<StudentSupervisorAssignment> getStudentSupervisor(
    int studentId,
  ) async {
    try {
      return await _apiClient.get<StudentSupervisorAssignment>(
        path: '/admin/students/$studentId/supervisor',
        converter: (payload) {
          if (payload is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid student supervisor response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          final data = payload['data'];
          if (data is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid student supervisor data format.',
              errorType: ApiErrorType.unknown,
            );
          }

          return StudentSupervisorAssignment.fromJson(data);
        },
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  Future<StudentSupervisorAssignment> assignSupervisor({
    required int studentId,
    int? supervisorId,
  }) async {
    try {
      return await _apiClient.patch<StudentSupervisorAssignment>(
        path: '/admin/students/$studentId/assign-supervisor',
        data: {'supervisor_id': supervisorId},
        converter: (payload) {
          if (payload is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid assign supervisor response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          final data = payload['data'];
          if (data is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid supervisor assignment data format.',
              errorType: ApiErrorType.unknown,
            );
          }

          return StudentSupervisorAssignment.fromJson(data);
        },
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }
}
