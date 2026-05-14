import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/supervisor_dashboard_service.dart';
import '../../../../core/services/supervisor_log_service.dart';
import '../../../../shared/models/supervisor_dashboard_summary.dart';
import '../../../../shared/models/supervisor_log_item.dart';
import '../../../../shared/widgets/dashboard_refresh_widgets.dart';
import '../../../../shared/widgets/notification_bell_button.dart';
import '../../../../shared/widgets/settings_shortcut_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'intern_list_screen.dart';
import 'supervisor_log_detail_screen.dart';
import 'supervisor_log_queue_screen.dart';

enum _SupervisorDashboardSection { summary, logs }

class SupervisorDashboardScreen extends StatefulWidget {
  final String userName;
  final SupervisorLogService? logService;
  final SupervisorDashboardService? dashboardService;
  final DateTime Function()? clock;

  const SupervisorDashboardScreen({
    super.key,
    required this.userName,
    this.logService,
    this.dashboardService,
    this.clock,
  });

  @override
  State<SupervisorDashboardScreen> createState() =>
      _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState extends State<SupervisorDashboardScreen> {
  static const double _maxContentWidth = 1360;

  late final SupervisorLogService _logService;
  late final SupervisorDashboardService _dashboardService;

  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _hasCompletedFirstLoad = false;
  DateTime? _lastUpdated;

  List<SupervisorLogItem> _pendingLogs = <SupervisorLogItem>[];
  SupervisorDashboardSummary? _dashboardSummary;

  final Map<_SupervisorDashboardSection, bool> _sectionLoading =
      <_SupervisorDashboardSection, bool>{
        _SupervisorDashboardSection.summary: false,
        _SupervisorDashboardSection.logs: false,
      };

  final Map<_SupervisorDashboardSection, String?> _sectionErrors =
      <_SupervisorDashboardSection, String?>{
        _SupervisorDashboardSection.summary: null,
        _SupervisorDashboardSection.logs: null,
      };

  String? get _summaryError => _sectionErrors[_SupervisorDashboardSection.summary];
  String? get _logsError => _sectionErrors[_SupervisorDashboardSection.logs];

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasCompletedFirstLoad &&
        _pendingLogs.isEmpty &&
        _dashboardSummary == null &&
        !_isRefreshing) {
      final apiClient = context.read<ApiClient>();
      _logService = widget.logService ?? SupervisorLogService(apiClient);
      _dashboardService =
          widget.dashboardService ?? SupervisorDashboardService(apiClient);
      _loadDashboardData();
    }
  }

  Future<void> _handleExpiredSession() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your session has expired. Please log in again.'),
      ),
    );

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<void> _loadDashboardData() async {
    if (_isRefreshing) return;

    final token = context.read<AuthProvider>().token ?? '';
    if (token.isEmpty) {
      setState(() {
        _isInitialLoading = false;
        _isRefreshing = false;
        _hasCompletedFirstLoad = true;
        _sectionErrors[_SupervisorDashboardSection.summary] =
            'Missing authentication token. Please log in again.';
        _sectionErrors[_SupervisorDashboardSection.logs] = null;
        _sectionLoading[_SupervisorDashboardSection.summary] = false;
        _sectionLoading[_SupervisorDashboardSection.logs] = false;
      });
      return;
    }

    final showFullScreenLoader = !_hasCompletedFirstLoad;

    setState(() {
      _isInitialLoading = showFullScreenLoader;
      _isRefreshing = !showFullScreenLoader;
      _sectionErrors[_SupervisorDashboardSection.summary] = null;
      _sectionErrors[_SupervisorDashboardSection.logs] = null;
      _sectionLoading[_SupervisorDashboardSection.summary] = true;
      _sectionLoading[_SupervisorDashboardSection.logs] = true;
    });

    final results = await Future.wait<_SupervisorSectionResult<dynamic>>([
      _refreshPendingLogs(markLoading: false),
      _refreshSummary(markLoading: false),
    ]);

    if (!mounted) return;

    final successfulSections =
        results.where((result) => result.succeeded).length;

    setState(() {
      _isInitialLoading = false;
      _isRefreshing = false;
      _hasCompletedFirstLoad = true;
      if (successfulSections > 0) {
        _lastUpdated = _now();
      }
    });
  }

  Future<void> _refreshSection(_SupervisorDashboardSection section) async {
    if (_sectionLoading[section] == true) return;

    setState(() {
      _sectionLoading[section] = true;
    });

    final result = switch (section) {
      _SupervisorDashboardSection.summary =>
        await _refreshSummary(markLoading: false),
      _SupervisorDashboardSection.logs =>
        await _refreshPendingLogs(markLoading: false),
    };

    if (!mounted) return;

    setState(() {
      if (result.succeeded) {
        _lastUpdated = _now();
      }
    });
  }

  Future<_SupervisorSectionResult<SupervisorDashboardSummary>> _refreshSummary({
    bool markLoading = true,
  }) async {
    if (markLoading && mounted) {
      setState(() {
        _sectionLoading[_SupervisorDashboardSection.summary] = true;
      });
    }

    try {
      final dashboardSummary = await _dashboardService.getSummary();
      if (!mounted) {
        return _SupervisorSectionResult<SupervisorDashboardSummary>.failure();
      }

      setState(() {
        _dashboardSummary = dashboardSummary;
        _sectionErrors[_SupervisorDashboardSection.summary] = null;
        _sectionLoading[_SupervisorDashboardSection.summary] = false;
      });

      return _SupervisorSectionResult<SupervisorDashboardSummary>.success(
        dashboardSummary,
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return _SupervisorSectionResult<SupervisorDashboardSummary>.failure();
      }

      if (e.statusCode == 401 || e.errorType == ApiErrorType.unauthorized) {
        await _handleExpiredSession();
        return _SupervisorSectionResult<SupervisorDashboardSummary>.failure();
      }

      setState(() {
        _sectionErrors[_SupervisorDashboardSection.summary] = e.message;
        _sectionLoading[_SupervisorDashboardSection.summary] = false;
      });

      return _SupervisorSectionResult<SupervisorDashboardSummary>.failure();
    } catch (e) {
      if (!mounted) {
        return _SupervisorSectionResult<SupervisorDashboardSummary>.failure();
      }

      setState(() {
        _sectionErrors[_SupervisorDashboardSection.summary] =
            e.toString().replaceFirst('Exception: ', '');
        _sectionLoading[_SupervisorDashboardSection.summary] = false;
      });

      return _SupervisorSectionResult<SupervisorDashboardSummary>.failure();
    }
  }

  Future<_SupervisorSectionResult<List<SupervisorLogItem>>> _refreshPendingLogs({
    bool markLoading = true,
  }) async {
    if (markLoading && mounted) {
      setState(() {
        _sectionLoading[_SupervisorDashboardSection.logs] = true;
      });
    }

    try {
      final pendingLogs = await _logService.getPendingLogs();
      if (!mounted) {
        return _SupervisorSectionResult<List<SupervisorLogItem>>.failure();
      }

      setState(() {
        _pendingLogs = pendingLogs;
        _sectionErrors[_SupervisorDashboardSection.logs] = null;
        _sectionLoading[_SupervisorDashboardSection.logs] = false;
      });

      return _SupervisorSectionResult<List<SupervisorLogItem>>.success(
        pendingLogs,
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return _SupervisorSectionResult<List<SupervisorLogItem>>.failure();
      }

      if (e.statusCode == 401 || e.errorType == ApiErrorType.unauthorized) {
        await _handleExpiredSession();
        return _SupervisorSectionResult<List<SupervisorLogItem>>.failure();
      }

      setState(() {
        _sectionErrors[_SupervisorDashboardSection.logs] = e.message;
        _sectionLoading[_SupervisorDashboardSection.logs] = false;
      });

      return _SupervisorSectionResult<List<SupervisorLogItem>>.failure();
    } catch (e) {
      if (!mounted) {
        return _SupervisorSectionResult<List<SupervisorLogItem>>.failure();
      }

      setState(() {
        _sectionErrors[_SupervisorDashboardSection.logs] =
            e.toString().replaceFirst('Exception: ', '');
        _sectionLoading[_SupervisorDashboardSection.logs] = false;
      });

      return _SupervisorSectionResult<List<SupervisorLogItem>>.failure();
    }
  }

  Future<void> _openPendingQueue() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SupervisorPendingLogsScreen(),
      ),
    );

    if (mounted) {
      await _loadDashboardData();
    }
  }

  Future<void> _openAssignedInterns() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const InternListScreen(role: 'supervisor'),
      ),
    );

    if (mounted) {
      await _loadDashboardData();
    }
  }

  Future<void> _openLogReview(SupervisorLogItem log) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SupervisorLogDetailScreen(
          logId: log.id,
          initialLog: log,
          service: _logService,
        ),
      ),
    );

    if (updated == true && mounted) {
      await _loadDashboardData();
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  String _initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'SV';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();

    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;

    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }

  bool _isSectionLoading(_SupervisorDashboardSection section) {
    return _sectionLoading[section] ?? false;
  }

  Widget _buildSectionRefreshingHint(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSkeleton() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: const [
        SizedBox(
          width: 320,
          child: DashboardSkeletonBlock(height: 108, radius: 24),
        ),
        SizedBox(
          width: 320,
          child: DashboardSkeletonBlock(height: 108, radius: 24),
        ),
        SizedBox(
          width: 320,
          child: DashboardSkeletonBlock(height: 108, radius: 24),
        ),
      ],
    );
  }

  Widget _buildLogsSkeleton() {
    return Column(
      children: const [
        DashboardSkeletonBlock(height: 110, radius: 20),
        SizedBox(height: 14),
        DashboardSkeletonBlock(height: 110, radius: 20),
        SizedBox(height: 14),
        DashboardSkeletonBlock(height: 110, radius: 20),
      ],
    );
  }

  Color _statusBg(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return const Color(0xFFD7F7E3);
      case 'REJECTED':
        return const Color(0xFFFDE0E0);
      case 'PENDING':
      default:
        return const Color(0xFFFFF0B3);
    }
  }

  Color _statusFg(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return const Color(0xFF039855);
      case 'REJECTED':
        return const Color(0xFFD92D20);
      case 'PENDING':
      default:
        return const Color(0xFFB54708);
    }
  }

  String _statusLabel(String status) {
    final normalized = status.trim();
    if (normalized.isEmpty) {
      return 'Unknown';
    }
    if (normalized.length == 1) {
      return normalized.toUpperCase();
    }
    return normalized[0].toUpperCase() + normalized.substring(1).toLowerCase();
  }

  Widget _buildHeader(AuthProvider authProvider) {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;
    final primaryTextColor = theme.colorScheme.onSurface;
    final secondaryTextColor =
        theme.textTheme.bodyMedium?.color ?? primaryTextColor;
    final dividerColor =
        theme.dividerTheme.color ?? theme.colorScheme.outlineVariant;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        final isCompact = constraints.maxWidth < 520;
        final horizontalPadding = isNarrow
            ? 16.0
            : constraints.maxWidth >= 1440
            ? 40.0
            : 28.0;
        final profileMaxWidth = constraints.maxWidth >= 1280 ? 420.0 : 360.0;

        final profileSection = Row(
          children: [
            const SettingsShortcutButton(),
            const SizedBox(width: 8),
            NotificationBellButton(token: authProvider.token ?? ''),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: isCompact
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Company Supervisor',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: secondaryTextColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFF06C167),
              child: Text(
                _initialsFor(authProvider.user?.name ?? widget.userName),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Supervisor Dashboard',
              style: TextStyle(
                fontSize: isNarrow ? (isCompact ? 20 : 24) : 28,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Review and manage student logs',
              style: TextStyle(
                fontSize: isCompact ? 13 : 14,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            DashboardRefreshStatus(
              lastUpdated: _lastUpdated,
              isRefreshing: _isRefreshing,
              pullToRefreshLabel: 'Pull down to refresh dashboard data',
              refreshingLabel: 'Refreshing supervisor dashboard...',
            ),
          ],
        );

        return Container(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            20,
          ),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(bottom: BorderSide(color: dividerColor)),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          onPressed: _logout,
                          icon: const Icon(Icons.arrow_back),
                          tooltip: 'Logout',
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: titleBlock),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: profileMaxWidth),
                      child: profileSection,
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: _logout,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Logout',
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: profileMaxWidth),
                      child: profileSection,
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accent,
    double? width,
  }) {
    final cardWidget = LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 22 : 28,
            vertical: isCompact ? 22 : 26,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isCompact ? 15 : 16,
                        color: const Color(0xFF355070),
                      ),
                    ),
                    SizedBox(height: isCompact ? 10 : 12),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: isCompact ? 32 : 40,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: isCompact ? 50 : 54,
                height: isCompact ? 50 : 54,
                decoration: BoxDecoration(
                  color: accent.withAlpha(28),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: isCompact ? 30 : 34),
              ),
            ],
          ),
        );
      },
    );

    if (width != null) {
      return SizedBox(width: width, child: cardWidget);
    }
    return Expanded(child: cardWidget);
  }

  Widget _buildActionBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 640;
        final actionWidth = isCompact
            ? constraints.maxWidth
            : constraints.maxWidth >= 920
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: actionWidth,
              child: ElevatedButton.icon(
                onPressed: _openAssignedInterns,
                icon: const Icon(Icons.groups_2_outlined),
                label: const Text('View Assigned Interns'),
              ),
            ),
            SizedBox(
              width: actionWidth,
              child: OutlinedButton.icon(
                onPressed: _openPendingQueue,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Review Pending Logs'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTableHeader() {
    const headerStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: Color(0xFF243B63),
      fontSize: 15,
    );

    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      child: Row(
        children: [
          Expanded(flex: 24, child: Text('Student', style: headerStyle)),
          Expanded(flex: 20, child: Text('Date', style: headerStyle)),
          Expanded(flex: 12, child: Text('Hours', style: headerStyle)),
          Expanded(flex: 28, child: Text('Task', style: headerStyle)),
          Expanded(flex: 12, child: Text('Proof', style: headerStyle)),
          Expanded(flex: 16, child: Text('Status', style: headerStyle)),
          Expanded(flex: 18, child: Text('Review', style: headerStyle)),
        ],
      ),
    );
  }

  Widget _buildLogCardRow(SupervisorLogItem log) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7EBF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF326DE6),
                child: Text(
                  _initialsFor(log.studentName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.studentName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF102A56),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(log.date),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF68768A),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _statusBg(log.status),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(log.status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _statusFg(log.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            log.taskDescription,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: Color(0xFF23395D)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: log.hasAttachments
                      ? const Color(0xFFE8F1FF)
                      : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${log.hasAttachments ? 'Attached' : 'None'} (Proof)',
                  style: TextStyle(
                    fontSize: 12,
                    color: log.hasAttachments
                        ? const Color(0xFF326DE6)
                        : const Color(0xFF667085),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${log.hoursRendered}h rendered',
                style: const TextStyle(fontSize: 12, color: Color(0xFF68768A)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openLogReview(log),
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Review Log'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogRow(SupervisorLogItem log) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE7EBF0))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 24,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: const Color(0xFF326DE6),
                  child: Text(
                    _initialsFor(log.studentName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    log.studentName,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF102A56),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 20,
            child: Text(
              _formatDate(log.date),
              style: const TextStyle(fontSize: 15, color: Color(0xFF23395D)),
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              '${log.hoursRendered}h',
              style: const TextStyle(fontSize: 15, color: Color(0xFF23395D)),
            ),
          ),
          Expanded(
            flex: 28,
            child: Text(
              log.taskDescription,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, color: Color(0xFF23395D)),
            ),
          ),
          Expanded(
            flex: 12,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: log.hasAttachments
                      ? const Color(0xFFE8F1FF)
                      : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  log.hasAttachments ? 'Attached' : 'None',
                  style: TextStyle(
                    color: log.hasAttachments
                        ? const Color(0xFF326DE6)
                        : const Color(0xFF667085),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 16,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _statusBg(log.status),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(log.status),
                  style: TextStyle(
                    color: _statusFg(log.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 18,
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _openLogReview(log),
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Review Log'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsPanel() {
    final isLoading = _isSectionLoading(_SupervisorDashboardSection.logs);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;

        return Container(
          decoration: BoxDecoration(
            color: isNarrow ? Colors.transparent : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: isNarrow
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x120F172A),
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isNarrow ? 0 : 28,
                  isNarrow ? 0 : 26,
                  isNarrow ? 0 : 28,
                  isNarrow ? 0 : 24,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Student Logs',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF102A56),
                        ),
                      ),
                    ),
                    if (!isNarrow)
                      TextButton.icon(
                        onPressed: _openPendingQueue,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open Queue'),
                      ),
                  ],
                ),
              ),
              if (!isNarrow) const Divider(height: 1, color: Color(0xFFE7EBF0)),
              if (!isNarrow) _buildTableHeader(),
              if (isLoading && _pendingLogs.isEmpty && _logsError == null)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 0 : 28,
                    vertical: 12,
                  ),
                  child: _buildLogsSkeleton(),
                )
              else if (_logsError != null && _pendingLogs.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 0 : 28,
                    vertical: 12,
                  ),
                  child: DashboardInlineNotice(
                    message: _logsError!,
                    onRetry: () =>
                        _refreshSection(_SupervisorDashboardSection.logs),
                  ),
                )
              else if (_pendingLogs.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 0 : 28,
                    vertical: 36,
                  ),
                  child: Text(
                    _logsError == null
                        ? 'No pending student logs to review right now.'
                        : 'Unable to refresh pending logs. You can retry or open the queue.',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF68768A),
                    ),
                  ),
                )
              else if (isNarrow)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 8,
                  ),
                  child: Column(
                    children: _pendingLogs.take(6).map(_buildLogCardRow).toList(),
                  ),
                )
              else
                ..._pendingLogs.take(6).map(_buildLogRow),
              if (isNarrow && _pendingLogs.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openPendingQueue,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open Full Queue'),
                  ),
                ),
              if (_logsError != null && _pendingLogs.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isNarrow ? 0 : 28,
                    8,
                    isNarrow ? 0 : 28,
                    0,
                  ),
                  child: DashboardInlineNotice(
                    message: _logsError!,
                    onRetry: () =>
                        _refreshSection(_SupervisorDashboardSection.logs),
                  ),
                )
              else if (isLoading)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isNarrow ? 0 : 28,
                    8,
                    isNarrow ? 0 : 28,
                    0,
                  ),
                  child: _buildSectionRefreshingHint(
                    'Refreshing pending logs...',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    final isSummaryLoading = _isSectionLoading(_SupervisorDashboardSection.summary);
    final summary = _dashboardSummary;
    final pendingCount = summary?.pendingReview ?? _pendingLogs.length;
    final totalStudents = summary?.totalStudents ?? 0;
    final approvedToday = summary?.approvedToday ?? 0;

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportWidth = constraints.maxWidth
              .clamp(0.0, _maxContentWidth)
              .toDouble();
          final horizontalPadding = constraints.maxWidth < 640
              ? 16.0
              : constraints.maxWidth >= 1440
              ? 40.0
              : 30.0;
          final contentWidth = (viewportWidth - (horizontalPadding * 2))
              .clamp(0.0, viewportWidth)
              .toDouble();
          final isNarrow = contentWidth < 900;
          final statCardWidth = contentWidth >= 1140
              ? (contentWidth - 24) / 3
              : contentWidth >= 720
              ? (contentWidth - 12) / 2
              : contentWidth;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  isNarrow ? 20 : 28,
                  horizontalPadding,
                  isNarrow ? 20 : 30,
                ),
                children: [
                  if (isSummaryLoading && _dashboardSummary == null)
                    _buildStatsSkeleton()
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildStatCard(
                          title: 'Pending Review',
                          value: '$pendingCount',
                          icon: Icons.access_time_rounded,
                          accent: const Color(0xFF326DE6),
                          width: statCardWidth,
                        ),
                        _buildStatCard(
                          title: 'Approved Today',
                          value: '$approvedToday',
                          icon: Icons.check_circle_outline_rounded,
                          accent: const Color(0xFF06C167),
                          width: statCardWidth,
                        ),
                        _buildStatCard(
                          title: 'Total Students',
                          value: '$totalStudents',
                          icon: Icons.circle,
                          accent: const Color(0xFF98A2B3),
                          width: statCardWidth,
                        ),
                      ],
                    ),
                  if (_summaryError != null) ...[
                    const SizedBox(height: 12),
                    DashboardInlineNotice(
                      message: _summaryError!,
                      onRetry: () =>
                          _refreshSection(_SupervisorDashboardSection.summary),
                    ),
                  ] else if (isSummaryLoading) ...[
                    const SizedBox(height: 12),
                    _buildSectionRefreshingHint(
                      'Refreshing dashboard summary...',
                    ),
                  ],
                  SizedBox(height: isNarrow ? 16 : 22),
                  _buildActionBar(),
                  SizedBox(height: isNarrow ? 16 : 24),
                  _buildLogsPanel(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(authProvider),
            Expanded(
              child: _isInitialLoading && !_hasCompletedFirstLoad
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupervisorSectionResult<T> {
  const _SupervisorSectionResult._({
    required this.succeeded,
    this.value,
  });

  final bool succeeded;
  final T? value;

  factory _SupervisorSectionResult.success(T? value) {
    return _SupervisorSectionResult<T>._(succeeded: true, value: value);
  }

  factory _SupervisorSectionResult.failure() {
    return _SupervisorSectionResult<T>._(succeeded: false);
  }
}
