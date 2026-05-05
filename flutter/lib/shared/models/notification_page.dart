import 'app_notification.dart';

class NotificationPage {
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool hasMorePages;

  const NotificationPage({
    required this.notifications,
    required this.unreadCount,
    required this.hasMorePages,
  });
}
