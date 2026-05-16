import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/intern_list_service.dart';
import '../../../../shared/models/intern_list_item.dart';
import '../../../../shared/widgets/dashboard_refresh_widgets.dart';
import '../../../../shared/widgets/notification_bell_button.dart';
import '../../../../shared/widgets/settings_shortcut_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../supervisor/presentation/screens/intern_list_screen.dart';
import '../../../supervisor/presentation/screens/intern_detail_screen.dart';

class AdviserDashboardScreen extends StatefulWidget {
  final String userName;
  final DateTime Function()? clock;

  const AdviserDashboardScreen({super.key, required this.userName, this.clock});

  @override
  State<AdviserDashboardScreen> createState() => _AdviserDashboardScreenState();
}

class _AdviserDashboardScreenState extends State<AdviserDashboardScreen> {
  late final InternListService _internListService;

  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _hasCompletedFirstLoad = false;
  DateTime? _lastUpdated;
  String? _errorMessage;
  List<InternListItem> _interns = <InternListItem>[];

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasCompletedFirstLoad && _interns.isEmpty && !_isRefreshing) {
      _internListService = InternListService(context.read<ApiClient>());
      _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    if (_isRefreshing) return;

    final token = context.read<AuthProvider>().token ?? '';
    if (token.isEmpty) {
      setState(() {
        _isInitialLoading = false;
        _isRefreshing = false;
        _hasCompletedFirstLoad = true;
        _errorMessage = 'Missing authentication token. Please log in again.';
      });
      return;
    }

    final showFullScreenLoader = !_hasCompletedFirstLoad && _interns.isEmpty;

    setState(() {
      _isInitialLoading = showFullScreenLoader;
      _isRefreshing = !showFullScreenLoader;
    });

    try {
      final interns = await _internListService.getInternList(role: 'adviser');

      if (!mounted) return;

      setState(() {
        _interns = interns;
        _errorMessage = null;
        _lastUpdated = _now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _isRefreshing = false;
          _hasCompletedFirstLoad = true;
        });
      }
    }
  }

  Future<void> _openIntern(InternListItem detail) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InternDetailScreen(
          role: 'adviser',
          profileId: detail.id,
          initialIntern: detail,
        ),
      ),
    );

    if (mounted) {
      await _loadDashboardData();
    }
  }

  Future<void> _openInternReports() async {
    if (_interns.length == 1) {
      await _openIntern(_interns.first);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const InternListScreen(role: 'adviser'),
      ),
    );

    if (mounted) {
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
    if (parts.isEmpty) return 'AD';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  double _progressValue(InternListItem detail) {
    if (detail.requiredHours <= 0) return 0;
    final progress = detail.completedHours / detail.requiredHours;
    return progress.clamp(0, 1);
  }

  String _statusLabel(InternListItem detail) {
    switch (detail.alertStatus.toUpperCase()) {
      case 'BEHIND':
        return 'Behind';
      case 'INACTIVE':
        return 'Inactive';
      case 'NO_LOGS_YET':
        return 'No Logs Yet';
      case 'ON_TRACK':
        return 'On Track';
      default:
        return detail.alertStatus
            .replaceAll('_', ' ')
            .toLowerCase()
            .split(' ')
            .where((word) => word.isNotEmpty)
            .map(
              (word) =>
                  '${word.substring(0, 1).toUpperCase()}${word.substring(1)}',
            )
            .join(' ');
    }
  }

  Color _statusColor(InternListItem detail) {
    switch (detail.alertStatus.toUpperCase()) {
      case 'INACTIVE':
        return const Color(0xFFD92D20);
      case 'BEHIND':
        return const Color(0xFFFF5B00);
      case 'NO_LOGS_YET':
        return const Color(0xFFB54708);
      case 'ON_TRACK':
        return const Color(0xFF00A63E);
      default:
        return const Color(0xFF326DE6);
    }
  }

  Color _progressColor(InternListItem detail, int index) {
    if (detail.hasActiveAlert) return _statusColor(detail);
    return index.isEven ? const Color(0xFF3B82F6) : const Color(0xFF00C853);
  }

  DateTime? _lastLogDate(InternListItem detail) {
    return DateTime.tryParse(detail.lastLogDate ?? '');
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'No logs yet';
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
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }

  List<_AdviserAlert> _buildAlerts() {
    return _interns
        .where((detail) => detail.hasActiveAlert)
        .map(
          (detail) => _AdviserAlert(
            studentName: detail.studentName,
            status: _statusLabel(detail),
            message: detail.alertMessage,
            color: _statusColor(detail),
          ),
        )
        .take(3)
        .toList();
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

        final profileSection = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SettingsShortcutButton(),
            const SizedBox(width: 8),
            NotificationBellButton(token: authProvider.token ?? ''),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.userName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Academic Adviser',
                  style: TextStyle(fontSize: 13, color: secondaryTextColor),
                ),
              ],
            ),
            const SizedBox(width: 14),
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFFA142F4),
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

        return Container(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(bottom: BorderSide(color: dividerColor)),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: _logout,
                          icon: const Icon(Icons.arrow_back),
                          tooltip: 'Logout',
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Academic Adviser Dashboard',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: primaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Monitor student internship progress',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: secondaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DashboardRefreshStatus(
                                lastUpdated: _lastUpdated,
                                isRefreshing: _isRefreshing,
                                pullToRefreshLabel:
                                    'Pull down to refresh dashboard data',
                                refreshingLabel:
                                    'Refreshing adviser dashboard...',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Academic Adviser Dashboard',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Monitor student internship progress',
                            style: TextStyle(
                              fontSize: 14,
                              color: secondaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DashboardRefreshStatus(
                            lastUpdated: _lastUpdated,
                            isRefreshing: _isRefreshing,
                            pullToRefreshLabel:
                                'Pull down to refresh dashboard data',
                            refreshingLabel: 'Refreshing adviser dashboard...',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    profileSection,
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
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF355070),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accent.withAlpha(28),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 30),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsPanel(List<_AdviserAlert> alerts) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFC58A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5B00)),
              SizedBox(width: 10),
              Text(
                'Alerts',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF102A56),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (alerts.isEmpty)
            const Text(
              'No active alerts. Your advisees are progressing well.',
              style: TextStyle(fontSize: 15, color: Color(0xFF4A6480)),
            )
          else
            ...alerts.map((alert) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.studentName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF102A56),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: alert.color.withAlpha(28),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            alert.status,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: alert.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      alert.message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4A6480),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildProgressPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
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
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 720;
                return isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Intern Progress',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF102A56),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _interns.isEmpty
                                  ? null
                                  : _openInternReports,
                              icon: const Icon(Icons.download_rounded),
                              label: const Text('Open Intern Reports'),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Intern Progress',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF102A56),
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _interns.isEmpty
                                ? null
                                : _openInternReports,
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Open Intern Reports'),
                          ),
                        ],
                      );
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE7EBF0)),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                if (_interns.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No interns assigned yet.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF68768A),
                        ),
                      ),
                    ),
                  )
                else
                  ..._interns.asMap().entries.map((entry) {
                    final index = entry.key;
                    final detail = entry.value;
                    final progress = _progressValue(detail);
                    final status = _statusLabel(detail);
                    final statusColor = _statusColor(detail);

                    return InkWell(
                      onTap: () => _openIntern(detail),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 18),
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: index == 0
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFFE0E6ED),
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 720;

                            final identitySection = Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: const Color(0xFF326DE6),
                                  child: Text(
                                    _initialsFor(detail.studentName),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        detail.studentName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF102A56),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        detail.companyName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF4A6480),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );

                            final statusSection = Column(
                              crossAxisAlignment: isNarrow
                                  ? CrossAxisAlignment.start
                                  : CrossAxisAlignment.end,
                              children: [
                                Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Last log: ${_formatDate(_lastLogDate(detail))}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF4A6480),
                                  ),
                                ),
                              ],
                            );

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isNarrow) ...[
                                  identitySection,
                                  const SizedBox(height: 14),
                                  statusSection,
                                ] else
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: identitySection),
                                      const SizedBox(width: 16),
                                      statusSection,
                                    ],
                                  ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Progress',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF355070),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    minHeight: 16,
                                    value: progress,
                                    backgroundColor: const Color(0xFFDDE2EA),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _progressColor(detail, index),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${detail.completedHours} / ${detail.requiredHours} hours',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF243B63),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${(progress * 100).round()}%',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF102A56),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final totalInterns = _interns.length;
    final onTrack = _interns
        .where((detail) => detail.alertStatus.toUpperCase() == 'ON_TRACK')
        .length;
    final needsAttention = _interns
        .where((detail) => detail.hasActiveAlert)
        .length;
    final avgProgress = _interns.isEmpty
        ? 0
        : ((_interns.map(_progressValue).reduce((a, b) => a + b) /
                      _interns.length) *
                  100)
              .round();
    final alerts = _buildAlerts();

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final statCardWidth = maxWidth >= 1280
              ? (maxWidth - 54) / 4
              : maxWidth >= 860
              ? (maxWidth - 18) / 2
              : maxWidth;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(26, 28, 26, 30),
            children: [
              if (_errorMessage != null && _interns.isNotEmpty) ...[
                DashboardInlineNotice(
                  message: _errorMessage!,
                  onRetry: _loadDashboardData,
                ),
                const SizedBox(height: 18),
              ],
              Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  _buildStatCard(
                    title: 'Total Interns',
                    value: '$totalInterns',
                    icon: Icons.groups_2_outlined,
                    accent: const Color(0xFF326DE6),
                    width: statCardWidth,
                  ),
                  _buildStatCard(
                    title: 'On Track',
                    value: '$onTrack',
                    icon: Icons.trending_up_rounded,
                    accent: const Color(0xFF00A63E),
                    width: statCardWidth,
                  ),
                  _buildStatCard(
                    title: 'Needs Attention',
                    value: '$needsAttention',
                    icon: Icons.warning_amber_rounded,
                    accent: const Color(0xFFFF5B00),
                    width: statCardWidth,
                  ),
                  _buildStatCard(
                    title: 'Avg Progress',
                    value: '$avgProgress%',
                    icon: Icons.circle,
                    accent: const Color(0xFF98A2B3),
                    width: statCardWidth,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _buildAlertsPanel(alerts),
              const SizedBox(height: 30),
              _buildProgressPanel(),
            ],
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
                  : _errorMessage != null && _interns.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF475467)),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadDashboardData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdviserAlert {
  final String studentName;
  final String status;
  final String message;
  final Color color;

  const _AdviserAlert({
    required this.studentName,
    required this.status,
    required this.message,
    required this.color,
  });
}
