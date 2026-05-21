import '../../shared/models/edit_request.dart';
import '../exceptions/api_exception.dart';
import 'api_client.dart';
import 'base_service.dart';

class EditRequestService extends BaseService {
  EditRequestService([ApiClient? apiClient])
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<EditRequestItem> requestLogEdit({
    required int logId,
    required String date,
    required int hoursRendered,
    required String taskDescription,
    required String reason,
  }) async {
    try {
      return await _apiClient.post<EditRequestItem>(
        path: '/student/logs/$logId/edit-request',
        data: {
          'date': date,
          'hours_rendered': hoursRendered,
          'task_description': taskDescription,
          'reason': reason,
        },
        converter: _parseEditRequest,
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  Future<EditRequestItem> requestDtrEdit({
    int? dailyTimeRecordId,
    required String date,
    String? timeInAt,
    String? lunchOutAt,
    String? lunchInAt,
    String? timeOutAt,
    required String reason,
  }) async {
    try {
      return await _apiClient.post<EditRequestItem>(
        path: '/student/dtr/edit-request',
        data: {
          'daily_time_record_id': dailyTimeRecordId,
          'date': date,
          'time_in_at': timeInAt,
          'lunch_out_at': lunchOutAt,
          'lunch_in_at': lunchInAt,
          'time_out_at': timeOutAt,
          'reason': reason,
        },
        converter: _parseEditRequest,
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  Future<List<EditRequestItem>> fetchAdminEditRequests() async {
    return _fetchPendingRequests(path: '/admin/edit-requests');
  }

  Future<List<EditRequestItem>> fetchSupervisorEditRequests() async {
    return _fetchPendingRequests(path: '/supervisor/edit-requests');
  }

  Future<EditRequestItem> approveRequest({
    required int requestId,
    String? comment,
    String role = 'admin',
  }) async {
    try {
      return await _apiClient.patch<EditRequestItem>(
        path: '/$role/edit-requests/$requestId/approve',
        data: {
          if ((comment ?? '').trim().isNotEmpty) 'comment': comment!.trim(),
        },
        converter: _parseEditRequest,
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  Future<EditRequestItem> rejectRequest({
    required int requestId,
    required String comment,
    String role = 'admin',
  }) async {
    try {
      return await _apiClient.patch<EditRequestItem>(
        path: '/$role/edit-requests/$requestId/reject',
        data: {'comment': comment.trim()},
        converter: _parseEditRequest,
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  Future<List<EditRequestItem>> _fetchPendingRequests({
    required String path,
  }) async {
    try {
      return await _apiClient.get<List<EditRequestItem>>(
        path: path,
        converter: (payload) {
          if (payload is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid edit request response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          final data = payload['data'];
          if (data is! List) {
            return <EditRequestItem>[];
          }

          return data
              .whereType<Map<String, dynamic>>()
              .map(EditRequestItem.fromJson)
              .toList();
        },
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  EditRequestItem _parseEditRequest(dynamic payload) {
    if (payload is! Map<String, dynamic>) {
      throw ApiException(
        message: 'Invalid edit request response format.',
        errorType: ApiErrorType.unknown,
      );
    }

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException(
        message: 'Invalid edit request data format.',
        errorType: ApiErrorType.unknown,
      );
    }

    return EditRequestItem.fromJson(data);
  }
}
