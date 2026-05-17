import '../exceptions/api_exception.dart';
import '../services/api_client.dart';
import '../services/base_service.dart';
import '../../shared/models/app_user.dart';

/// Handles user authentication and token management
///
/// Uses centralized error handling through ApiClient and ApiException
/// All methods throw ApiException for consistency across the app
class AuthService extends BaseService {
  final ApiClient _apiClient;

  AuthService(this._apiClient);

  /// Registers a new user account
  ///
  /// Throws [ApiException] with:
  /// - ValidationError (422): Field-level validation errors in details
  /// - ClientError (400): Invalid request format
  /// - ServerError (5xx): Server-side errors
  /// - NetworkError/Timeout: Network connectivity issues
  Future<void> register({
    required String name,
    required String email,
    required String gender,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      await _apiClient.post<void>(
        path: '/auth/register',
        data: {
          'name': name,
          'email': email,
          'gender': gender,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
        converter: (_) {},
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  /// Logs in user with email and password
  ///
  /// Returns map with 'token' (access token) and 'user' (AppUser data)
  ///
  /// Throws [ApiException] with:
  /// - Unauthorized (401): Invalid credentials
  /// - ValidationError (422): Validation errors
  /// - NetworkError/Timeout: Network connectivity issues
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        path: '/auth/login',
        data: {'email': email, 'password': password},
        converter: (data) {
          if (data is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid response format from server',
              errorType: ApiErrorType.unknown,
            );
          }

          final responseData = data['data'] as Map<String, dynamic>?;
          if (responseData == null) {
            throw ApiException(
              message: 'No data in login response',
              errorType: ApiErrorType.unknown,
            );
          }

          final accessToken = responseData['access_token'];
          if (accessToken is! String || accessToken.isEmpty) {
            throw ApiException(
              message: 'No access token in login response',
              errorType: ApiErrorType.unknown,
            );
          }

          return {'token': accessToken, 'user': responseData['user']};
        },
      );

      return response;
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  /// Fetches the authenticated user's profile
  ///
  /// Throws [ApiException] with:
  /// - Unauthorized (401): Token expired or invalid
  /// - ServerError (5xx): Server-side errors
  /// - NetworkError/Timeout: Network connectivity issues
  Future<AppUser> getAuthenticatedUser() async {
    try {
      final user = await _apiClient.get<AppUser>(
        path: '/auth/me',
        converter: (data) {
          if (data is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid user response format',
              errorType: ApiErrorType.unknown,
            );
          }

          final payload = data['data'];
          Map<String, dynamic>? userData;
          if (payload is Map<String, dynamic>) {
            final nestedUser = payload['user'];
            if (nestedUser is Map<String, dynamic>) {
              userData = nestedUser;
            } else {
              userData = payload;
            }
          }

          if (userData == null) {
            throw ApiException(
              message: 'No user data in response',
              errorType: ApiErrorType.unknown,
            );
          }

          try {
            return AppUser.fromJson(userData);
          } catch (e) {
            throw ApiException(
              message: 'Failed to parse user data',
              errorType: ApiErrorType.unknown,
              originalError: e,
            );
          }
        },
      );

      return user;
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  /// Revokes the current access token on the server.
  ///
  /// Throws [ApiException] if the request fails. Callers may still choose to
  /// clear the local session when the server token has already expired.
  Future<void> logout() async {
    try {
      await _apiClient.post<void>(path: '/auth/logout', converter: (_) {});
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }
}
