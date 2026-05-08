import '../../shared/models/intern_detail.dart';
import '../../shared/models/intern_list_item.dart';
import '../../shared/models/intern_list_page.dart';
import '../exceptions/api_exception.dart';
import '../services/api_client.dart';
import '../services/base_service.dart';

/// Service for managing intern lists and details
/// 
/// Fetches intern information with pagination support
/// Works for both supervisor and adviser roles
class InternListService extends BaseService {
  final ApiClient _apiClient;

  InternListService(this._apiClient);
  /// Gets role-specific endpoint
  String _endpointForRole(String role) {
    if (role.toLowerCase() == 'supervisor') {
      return '/supervisor/interns';
    } else if (role.toLowerCase() == 'adviser') {
      return '/adviser/interns';
    }

    throw ApiException(
      message: 'Unsupported role: $role',
      errorType: ApiErrorType.clientError,
      isRecoverable: false,
    );
  }

  /// Fetches all interns across all pages
  /// 
  /// Automatically paginates and aggregates results
  /// Throws [ApiException] if any page fetch fails
  Future<List<InternListItem>> getInternList({
    required String role,
  }) async {
    final interns = <InternListItem>[];
    var pageNumber = 1;
    var hasMorePages = true;

    while (hasMorePages) {
      try {
        final page = await getInternPage(
          role: role,
          page: pageNumber,
          perPage: 20,
        );

        interns.addAll(page.interns);
        hasMorePages = page.hasMorePages && pageNumber < page.lastPage;
        pageNumber += 1;
      } on ApiException catch (e) {
        handleApiError(e);
        rethrow;
      }
    }

    return interns;
  }

  /// Fetches a single page of interns
  /// 
  /// Throws [ApiException] if fetch fails
  Future<InternListPage> getInternPage({
    required String role,
    int page = 1,
    int perPage = 20,
    String search = '',
  }) async {
    try {
      final endpoint = _endpointForRole(role);
      final queryParameters = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };

      final trimmedSearch = search.trim();
      if (trimmedSearch.isNotEmpty) {
        queryParameters['search'] = trimmedSearch;
      }

      return await _apiClient.get<InternListPage>(
        path: endpoint,
        queryParameters: queryParameters,
        converter: (data) => _parseInternListResponse(data, page, perPage),
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  /// Fetches detailed information about a specific intern
  /// 
  /// Throws [ApiException] if fetch fails
  Future<InternDetailItem> getInternDetail({
    required String role,
    required int profileId,
  }) async {
    try {
      final endpoint = '${_endpointForRole(role)}/$profileId';

      return await _apiClient.get<InternDetailItem>(
        path: endpoint,
        converter: (data) => _parseInternDetailResponse(data),
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  /// Parses intern list response
  InternListPage _parseInternListResponse(
    dynamic data,
    int page,
    int perPage,
  ) {
    if (data is! Map<String, dynamic>) {
      throw ApiException(
        message: 'Invalid intern list response format',
        errorType: ApiErrorType.unknown,
      );
    }

    try {
      return InternListPage.fromJson(
        data,
        fallbackPage: page,
        fallbackPerPage: perPage,
      );
    } catch (e) {
      throw ApiException(
        message: 'Failed to parse intern list',
        errorType: ApiErrorType.unknown,
        originalError: e,
      );
    }
  }

  /// Parses intern detail response
  InternDetailItem _parseInternDetailResponse(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw ApiException(
        message: 'Invalid intern detail response format',
        errorType: ApiErrorType.unknown,
      );
    }

    final internData = data['data'] as Map<String, dynamic>?;
    if (internData == null) {
      throw ApiException(
        message: 'No intern data in response',
        errorType: ApiErrorType.unknown,
      );
    }

    try {
      return InternDetailItem.fromJson(internData);
    } catch (e) {
      throw ApiException(
        message: 'Failed to parse intern detail',
        errorType: ApiErrorType.unknown,
        originalError: e,
      );
    }
  }
}
