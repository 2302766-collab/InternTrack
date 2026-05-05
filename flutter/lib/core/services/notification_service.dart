import '../../shared/models/app_notification.dart';
import '../../shared/models/notification_page.dart';
import '../exceptions/api_exception.dart';
import 'api_client.dart';
import 'base_service.dart';

class NotificationService extends BaseService {
  NotificationService([ApiClient? apiClient])
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<NotificationPage> fetchNotifications() async {
    try {
      return await _apiClient.get<NotificationPage>(
        path: '/notifications',
        converter: (payload) {
          if (payload is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid notification response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          final rawItems = payload['data'];
          final items = rawItems is List
              ? rawItems
                  .whereType<Map<String, dynamic>>()
                  .map(AppNotification.fromJson)
                  .toList()
              : <AppNotification>[];

          final meta = payload['meta'];

          return NotificationPage(
            notifications: items,
            unreadCount: meta is Map<String, dynamic>
                ? _parseInt(meta['unread_count'])
                : 0,
            hasMorePages:
                meta is Map<String, dynamic> && meta['has_more_pages'] == true,
          );
        },
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  Future<AppNotification> markAsRead({
    required int notificationId,
  }) async {
    try {
      return await _apiClient.patch<AppNotification>(
        path: '/notifications/$notificationId/read',
        converter: (payload) {
          if (payload is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Invalid notification response format.',
              errorType: ApiErrorType.unknown,
            );
          }

          final data = payload['data'];
          if (data is! Map<String, dynamic>) {
            throw ApiException(
              message: 'Notification data was missing.',
              errorType: ApiErrorType.unknown,
            );
          }

          try {
            return AppNotification.fromJson(data);
          } catch (e) {
            throw ApiException(
              message: 'Failed to parse notification.',
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

  int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
