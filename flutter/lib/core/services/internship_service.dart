import '../../shared/models/internship_profile.dart';
import '../../shared/models/supervisor_option.dart';
import '../exceptions/api_exception.dart';
import 'api_client.dart';
import 'base_service.dart';

class InternshipService extends BaseService {
  InternshipService([ApiClient? apiClient])
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<InternshipProfile?> getInternshipProfile() async {
    try {
      return await _apiClient.get<InternshipProfile?>(
        path: '/student/internship',
        converter: (data) {
          if (data is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid internship profile response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          final profileData = data['data'];
          if (profileData == null) {
            return null;
          }
          if (profileData is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid internship profile response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          try {
            return InternshipProfile.fromJson(profileData);
          } catch (e) {
            throw ApiException(
              message: 'Failed to parse internship profile.',
              errorType: ApiErrorType.unknown,
              originalError: e,
            );
          }
        },
      );
    } on ApiException catch (e) {
      if (e.errorType == ApiErrorType.notFound) {
        return null;
      }
      handleApiError(e);
      rethrow;
    }
  }

  Future<InternshipProfile> createInternshipProfile({
    required String companyName,
    required String companyAddress,
    required int supervisorId,
    required int requiredHours,
    required String startDate,
    required String endDate,
  }) async {
    try {
      return await _apiClient.post<InternshipProfile>(
        path: '/student/internship',
        data: {
          'company_name': companyName,
          'company_address': companyAddress,
          'supervisor_id': supervisorId,
          'required_hours': requiredHours,
          'start_date': startDate,
          'end_date': endDate,
        },
        converter: (data) {
          if (data is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid internship profile response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          final profileData = data['data'];
          if (profileData is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid internship profile response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          try {
            return InternshipProfile.fromJson(profileData);
          } catch (e) {
            throw ApiException(
              message: 'Failed to parse internship profile.',
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

  Future<InternshipProfile> updateInternshipProfile({
    required String companyName,
    required String companyAddress,
    required int requiredHours,
    required String startDate,
    required String endDate,
  }) async {
    try {
      return await _apiClient.patch<InternshipProfile>(
        path: '/student/internship',
        data: {
          'company_name': companyName,
          'company_address': companyAddress,
          'required_hours': requiredHours,
          'start_date': startDate,
          'end_date': endDate,
        },
        converter: (data) {
          if (data is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid internship profile response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          final profileData = data['data'];
          if (profileData is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid internship profile response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          try {
            return InternshipProfile.fromJson(profileData);
          } catch (e) {
            throw ApiException(
              message: 'Failed to parse internship profile.',
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

  Future<List<SupervisorOption>> getSupervisors() async {
    try {
      return await _apiClient.get<List<SupervisorOption>>(
        path: '/student/supervisors',
        converter: (data) {
          if (data is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid supervisors response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          final supervisorData = data['data'];
          if (supervisorData is! List) {
            return <SupervisorOption>[];
          }

          try {
            return supervisorData
                .whereType<Map<String, dynamic>>()
                .map(SupervisorOption.fromJson)
                .toList();
          } catch (e) {
            throw ApiException(
              message: 'Failed to parse supervisors.',
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
