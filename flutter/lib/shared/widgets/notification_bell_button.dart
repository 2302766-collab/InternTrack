import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/exceptions/api_exception.dart';
import '../../core/services/notification_service.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/student/navigation/student_notification_routing.dart';
import '../../features/supervisor/presentation/screens/intern_list_screen.dart';
import '../../features/supervisor/presentation/screens/supervisor_log_queue_screen.dart';
import '../models/app_notification.dart';

class NotificationBellButton extends StatefulWidget {
  final String token;
  final Color? iconColor;

  const NotificationBellButton({
    super.key,
    required this.token,
    this.iconColor,
  });

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  late final NotificationService _notificationService;

  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;
  String? _loadedToken;
  int _unreadCount = 0;
  List<AppNotification> _notifications = <AppNotification>[];

  @override
  void initState() {
    super.initState();
    _notificationService = context.read<NotificationService>();
    _loadNotificationsIfNeeded();
  }

  @override
  void didUpdateWidget(covariant NotificationBellButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.token != widget.token) {
      _loadedToken = null;
      _hasLoaded = false;
      _errorMessage = null;
      _unreadCount = 0;
      _notifications = <AppNotification>[];
      _loadNotificationsIfNeeded();
    }
  }

  Future<void> _loadNotificationsIfNeeded({bool force = false}) async {
    final token = widget.token.trim();
    if (token.isEmpty || (_isLoading && !force)) {
      return;
    }

    if (!force && _hasLoaded && _loadedToken == token) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final page = await _notificationService.fetchNotifications();
      if (!mounted) return;

      setState(() {
        _loadedToken = token;
        _hasLoaded = true;
        _notifications = page.notifications;
        _unreadCount = page.unreadCount;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadedToken = token;
        _hasLoaded = true;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(int notificationId) async {
    final token = widget.token.trim();
    if (token.isEmpty) {
      return;
    }

    final index = _notifications.indexWhere(
      (notification) => notification.id == notificationId,
    );
    if (index == -1 || _notifications[index].isRead) {
      return;
    }

    final updated = await _notificationService.markAsRead(
      notificationId: notificationId,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _notifications = List<AppNotification>.from(_notifications)
        ..[index] = _notifications[index].copyWith(isRead: updated.isRead);
      _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
    });
  }

  Future<void> _openNotifications() async {
    await _loadNotificationsIfNeeded(force: true);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _NotificationSheet(
          hostContext: context,
          userRole: context.read<AuthProvider>().role,
          errorMessage: _errorMessage,
          isLoading: _isLoading,
          notifications: _notifications,
          unreadCount: _unreadCount,
          onMarkAsRead: _markAsRead,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: widget.token.trim().isEmpty ? null : _openNotifications,
          icon: _isLoading && !_hasLoaded
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color?>(
                      widget.iconColor,
                    ),
                  ),
                )
              : Icon(Icons.notifications_none_rounded, color: widget.iconColor),
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFD92D20),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.4),
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                _unreadCount > 99 ? '99+' : '$_unreadCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationSheet extends StatefulWidget {
  final BuildContext hostContext;
  final String userRole;
  final String? errorMessage;
  final bool isLoading;
  final List<AppNotification> notifications;
  final int unreadCount;
  final Future<void> Function(int notificationId) onMarkAsRead;

  const _NotificationSheet({
    required this.hostContext,
    required this.userRole,
    required this.errorMessage,
    required this.isLoading,
    required this.notifications,
    required this.unreadCount,
    required this.onMarkAsRead,
  });

  @override
  State<_NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<_NotificationSheet> {
  late List<AppNotification> _notifications;
  late int _unreadCount;
  final Set<int> _markingIds = <int>{};

  @override
  void initState() {
    super.initState();
    _notifications = List<AppNotification>.from(widget.notifications);
    _unreadCount = widget.unreadCount;
  }

  Future<void> _handleMarkAsRead(int notificationId) async {
    setState(() {
      _markingIds.add(notificationId);
    });

    try {
      await widget.onMarkAsRead(notificationId);
      if (!mounted) return;

      final index = _notifications.indexWhere(
        (notification) => notification.id == notificationId,
      );
      if (index != -1 && !_notifications[index].isRead) {
        setState(() {
          _notifications = List<AppNotification>.from(_notifications)
            ..[index] = _notifications[index].copyWith(isRead: true);
          _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _markingIds.remove(notificationId);
        });
      }
    }
  }

  Future<void> _handleNotificationTap(AppNotification notification) async {
    final quickLink = _resolveQuickLink(notification);
    if (quickLink == null) return;

    if (!notification.isRead) {
      try {
        await widget.onMarkAsRead(notification.id);
        if (!mounted) return;
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          setState(() {
            _notifications = List<AppNotification>.from(_notifications)
              ..[index] = _notifications[index].copyWith(isRead: true);
            _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
          });
        }
      } catch (e) {
        if (mounted) {
          final message = e is ApiException
              ? e.message
              : e.toString().replaceFirst('Exception: ', '');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    final host = widget.hostContext;
    if (!host.mounted) return;

    await quickLink.open(host);
  }

  _NotificationQuickLink? _resolveQuickLink(AppNotification notification) {
    final role = widget.userRole.trim().toLowerCase();
    switch (role) {
      case 'student':
        return _resolveStudentQuickLink(notification);
      case 'supervisor':
        return _resolveSupervisorQuickLink(notification);
      case 'adviser':
        return _resolveAdviserQuickLink(notification);
      case 'admin':
        return _resolveAdminQuickLink(notification);
      default:
        return null;
    }
  }

  _NotificationQuickLink? _resolveStudentQuickLink(
    AppNotification notification,
  ) {
    final route = StudentNotificationRoute.resolve(notification);
    if (route == null) {
      return null;
    }

    switch (route.kind) {
      case StudentNotificationRouteKind.logbook:
        return _NotificationQuickLink(
          label: 'Open logbook',
          open: (host) => _pushNamedIfNeeded(
            host,
            AppRoutes.logbook,
            arguments: LogbookNavArgs(logId: route.logId),
          ),
        );
      case StudentNotificationRouteKind.report:
        return _NotificationQuickLink(
          label: 'Open report',
          open: (host) => _pushNamedIfNeeded(host, AppRoutes.studentReport),
        );
      case StudentNotificationRouteKind.dtr:
        return _NotificationQuickLink(
          label: 'Open DTR',
          open: (host) => _pushNamedIfNeeded(host, AppRoutes.studentDtr),
        );
    }
  }

  _NotificationQuickLink? _resolveSupervisorQuickLink(
    AppNotification notification,
  ) {
    final normalized = _normalizedType(notification.type);
    final resourceType = _normalizedMeta(notification.meta?['resource_type']);
    final haystack = '${notification.title} ${notification.message}'
        .toLowerCase();

    if (normalized == 'edit_request_submitted') {
      if (resourceType == 'log') {
        return _NotificationQuickLink(
          label: 'Review logs',
          open: (host) => Navigator.of(host).push(
            MaterialPageRoute(
              builder: (_) => const SupervisorPendingLogsScreen(),
            ),
          ),
        );
      }

      return _NotificationQuickLink(
        label: 'View interns',
        open: (host) => Navigator.of(host).push(
          MaterialPageRoute(
            builder: (_) => const InternListScreen(role: 'supervisor'),
          ),
        ),
      );
    }

    if (haystack.contains('log')) {
      return _NotificationQuickLink(
        label: 'Review logs',
        open: (host) => Navigator.of(host).push(
          MaterialPageRoute(
            builder: (_) => const SupervisorPendingLogsScreen(),
          ),
        ),
      );
    }

    if (haystack.contains('intern') || haystack.contains('student')) {
      return _NotificationQuickLink(
        label: 'View interns',
        open: (host) => Navigator.of(host).push(
          MaterialPageRoute(
            builder: (_) => const InternListScreen(role: 'supervisor'),
          ),
        ),
      );
    }

    return null;
  }

  _NotificationQuickLink? _resolveAdviserQuickLink(
    AppNotification notification,
  ) {
    final haystack = '${notification.title} ${notification.message}'
        .toLowerCase();

    if (haystack.contains('intern') ||
        haystack.contains('student') ||
        haystack.contains('report') ||
        haystack.contains('log')) {
      return _NotificationQuickLink(
        label: 'View interns',
        open: (host) => Navigator.of(host).push(
          MaterialPageRoute(
            builder: (_) => const InternListScreen(role: 'adviser'),
          ),
        ),
      );
    }

    return null;
  }

  _NotificationQuickLink? _resolveAdminQuickLink(AppNotification notification) {
    final normalized = _normalizedType(notification.type);
    final haystack = '${notification.title} ${notification.message}'
        .toLowerCase();

    if (normalized == 'edit_request_submitted') {
      return _NotificationQuickLink(
        label: 'Open dashboard',
        open: (host) => _pushNamedIfNeeded(host, AppRoutes.adminDashboard),
      );
    }

    if (haystack.contains('adviser') ||
        haystack.contains('supervisor') ||
        haystack.contains('assign')) {
      return _NotificationQuickLink(
        label: 'Manage assignments',
        open: (host) =>
            _pushNamedIfNeeded(host, AppRoutes.studentAdviserAssignment),
      );
    }

    return null;
  }

  Future<void> _pushNamedIfNeeded(
    BuildContext host,
    String routeName, {
    Object? arguments,
  }) async {
    final currentRoute = ModalRoute.of(host)?.settings.name;
    if (currentRoute == routeName) {
      return;
    }

    await Navigator.of(host).pushNamed(routeName, arguments: arguments);
  }

  String _normalizedType(String? value) {
    return (value ?? '').trim().toLowerCase().replaceAll('-', '_');
  }

  String _normalizedMeta(Object? value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SizedBox(
        height: 520,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Notifications',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (_unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCEBFF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$_unreadCount unread',
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.isLoading && widget.notifications.isEmpty)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (widget.errorMessage != null && _notifications.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      widget.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF475467)),
                    ),
                  ),
                )
              else if (_notifications.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No notifications yet.',
                      style: TextStyle(color: Color(0xFF68768A)),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      final isMarking = _markingIds.contains(notification.id);
                      final quickLink = _resolveQuickLink(notification);

                      return Material(
                        color: notification.isRead
                            ? Colors.white
                            : const Color(0xFFF5F9FF),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: notification.isRead
                                ? const Color(0xFFE4E7EC)
                                : const Color(0xFFBFDBFE),
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: quickLink == null
                              ? null
                              : () => _handleNotificationTap(notification),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            notification.title,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF102A56),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            notification.message,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF475467),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    if (!notification.isRead)
                                      Container(
                                        width: 10,
                                        height: 10,
                                        margin: const EdgeInsets.only(top: 6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF1D4ED8),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _formatTimestamp(
                                          notification.createdAt,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF667085),
                                        ),
                                      ),
                                    ),
                                    if (quickLink != null) ...[
                                      TextButton.icon(
                                        onPressed: () => _handleNotificationTap(
                                          notification,
                                        ),
                                        icon: const Icon(
                                          Icons.open_in_new_rounded,
                                          size: 16,
                                        ),
                                        label: Text(quickLink.label),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    if (notification.isRead)
                                      const Text(
                                        'Read',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF039855),
                                        ),
                                      )
                                    else
                                      TextButton(
                                        onPressed: isMarking
                                            ? null
                                            : () => _handleMarkAsRead(
                                                notification.id,
                                              ),
                                        child: isMarking
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Text('Mark as read'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime? value) {
    if (value == null) {
      return 'Unknown date';
    }

    return DateFormat('MMM d, yyyy - h:mm a').format(value.toLocal());
  }
}

class _NotificationQuickLink {
  const _NotificationQuickLink({required this.label, required this.open});

  final String label;
  final Future<void> Function(BuildContext host) open;
}
