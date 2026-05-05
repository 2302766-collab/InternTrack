import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/notification_service.dart';
import '../models/app_notification.dart';

class NotificationBellButton extends StatefulWidget {
  final String token;

  const NotificationBellButton({
    super.key,
    required this.token,
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
      builder: (context) {
        return _NotificationSheet(
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
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.notifications_none_rounded),
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
  final String? errorMessage;
  final bool isLoading;
  final List<AppNotification> notifications;
  final int unreadCount;
  final Future<void> Function(int notificationId) onMarkAsRead;

  const _NotificationSheet({
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
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _markingIds.remove(notificationId);
        });
      }
    }
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

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: notification.isRead
                              ? Colors.white
                              : const Color(0xFFF5F9FF),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: notification.isRead
                                ? const Color(0xFFE4E7EC)
                                : const Color(0xFFBFDBFE),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                    _formatTimestamp(notification.createdAt),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF667085),
                                    ),
                                  ),
                                ),
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
                                        : () => _handleMarkAsRead(notification.id),
                                    child: isMarking
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Mark as read'),
                                  ),
                              ],
                            ),
                          ],
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
