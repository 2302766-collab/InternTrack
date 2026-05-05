import '../exceptions/api_exception.dart';
import '../../../shared/models/adviser_info.dart';
import '../../../shared/models/student_adviser_assignment.dart';
import 'api_client.dart';
import 'base_service.dart';

class AdviserManagementService extends BaseService {
  AdviserManagementService([ApiClient? apiClient])
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Get all available advisers
  Future<List<AdviserInfo>> fetchAdvisers() async {
    try {
      return await _apiClient.get<List<AdviserInfo>>(
        path: '/admin/advisers',
        converter: (payload) {
          if (payload is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid advisers response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          final rawData = payload['data'];
          final advisers = rawData is List
              ? rawData
                  .whereType<Map<String, dynamic>>()
                  .map(AdviserInfo.fromJson)
                  .toList()
              : <AdviserInfo>[];

          return advisers;
        },
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  /// Get current adviser for a student
  Future<StudentAdviserAssignment> getStudentAdviser(int studentId) async {
    try {
      return await _apiClient.get<StudentAdviserAssignment>(
        path: '/admin/students/$studentId/adviser',
        converter: (payload) {
          if (payload is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid student adviser response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          final data = payload['data'];
          if (data is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid student adviser data format.',
              errorType: ApiErrorType.unknown,
            );
          }

          return StudentAdviserAssignment.fromJson(data);
        },
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  /// Assign or update adviser for a student
  Future<StudentAdviserAssignment> assignAdviser({
    required int studentId,
    int? adviserId,
  }) async {
    try {
      return await _apiClient.patch<StudentAdviserAssignment>(
        path: '/admin/students/$studentId/assign-adviser',
        data: {
          'adviser_id': adviserId,
        },
        converter: (payload) {
          if (payload is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid assign adviser response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          final data = payload['data'];
          if (data is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid assignment data format.',
              errorType: ApiErrorType.unknown,
            );
          }

          return StudentAdviserAssignment.fromJson(data);
        },
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }
}
