import '../../shared/models/app_user.dart';
import '../exceptions/api_exception.dart';
import 'api_client.dart';
import 'base_service.dart';

class AdminUserManagementService extends BaseService {
  AdminUserManagementService([ApiClient? apiClient])
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<AppUser>> fetchManagedUsers() async {
    try {
      return await _apiClient.get<List<AppUser>>(
        path: '/admin/users',
        converter: (payload) {
          if (payload is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid managed users response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          final rawData = payload['data'];
          return rawData is List
              ? rawData
                    .whereType<Map<String, dynamic>>()
                    .map(AppUser.fromJson)
                    .toList()
              : <AppUser>[];
        },
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  Future<AppUser> createManagedUser({
    required String name,
    required String email,
    required String gender,
    required String password,
    required String role,
  }) async {
    try {
      return await _apiClient.post<AppUser>(
        path: '/admin/users',
        data: {
          'name': name,
          'email': email,
          'gender': gender,
          'password': password,
          'password_confirmation': password,
          'role': role,
        },
        converter: (payload) {
          if (payload is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid create user response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          final data = payload['data'];
          if (data is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid user data format.',
              errorType: ApiErrorType.unknown,
            );
          }

          return AppUser.fromJson(data);
        },
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  Future<AppUser> deleteManagedUser(int userId) async {
    try {
      return await _apiClient.delete<AppUser>(
        path: '/admin/users/$userId',
        converter: (payload) {
          if (payload is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid delete user response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          final data = payload['data'];
          if (data is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid removed user data format.',
              errorType: ApiErrorType.unknown,
            );
          }

          return AppUser.fromJson(data);
        },
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }
}
