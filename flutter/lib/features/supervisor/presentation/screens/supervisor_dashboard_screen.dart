import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/supervisor_dashboard_service.dart';
import '../../../../core/services/supervisor_log_service.dart';
import '../../../../core/theme/ocean_breeze_palette.dart';
import '../../../../core/utils/file_picker_helper_stub.dart'
    if (dart.library.html) '../../../../core/utils/file_picker_helper_web.dart'
    as file_picker;
import '../../../../shared/models/app_user.dart';
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
  static const double _maxContentWidth = 1520;
  static const Color _canvasColor = OceanBreezePalette.canvas;
  static const Color _panelColor = OceanBreezePalette.surface;
  static const Color _panelSoft = OceanBreezePalette.surfaceSoft;
  static const Color _panelBorder = OceanBreezePalette.border;
  static const Color _headlineColor = OceanBreezePalette.textPrimary;
  static const Color _bodyColor = OceanBreezePalette.textSecondary;
  static const Color _heroStart = OceanBreezePalette.midnight;
  static const Color _heroEnd = OceanBreezePalette.deepSea;
  static const Color _accentPrimary = OceanBreezePalette.deepSea;
  static const Color _accentSecondary = OceanBreezePalette.tide;
  static const Color _accentMuted = OceanBreezePalette.sky;
  static const Color _accentSoft = OceanBreezePalette.surfaceMuted;
  static const Color _accentSoftAlt = OceanBreezePalette.mist;

  late final SupervisorLogService _logService;
  late final SupervisorDashboardService _dashboardService;

  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _hasCompletedFirstLoad = false;
  DateTime? _lastUpdated;

  List<SupervisorLogItem> _pendingLogs = <SupervisorLogItem>[];
  SupervisorDashboardSummary? _dashboardSummary;
  final GlobalKey _profileMenuAnchorKey = GlobalKey();

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

  String? get _summaryError =>
      _sectionErrors[_SupervisorDashboardSection.summary];
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

    final successfulSections = results
        .where((result) => result.succeeded)
        .length;

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
      _SupervisorDashboardSection.summary => await _refreshSummary(
        markLoading: false,
      ),
      _SupervisorDashboardSection.logs => await _refreshPendingLogs(
        markLoading: false,
      ),
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
        _sectionErrors[_SupervisorDashboardSection.summary] = e
            .toString()
            .replaceFirst('Exception: ', '');
        _sectionLoading[_SupervisorDashboardSection.summary] = false;
      });

      return _SupervisorSectionResult<SupervisorDashboardSummary>.failure();
    }
  }

  Future<_SupervisorSectionResult<List<SupervisorLogItem>>>
  _refreshPendingLogs({bool markLoading = true}) async {
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
        _sectionErrors[_SupervisorDashboardSection.logs] = e
            .toString()
            .replaceFirst('Exception: ', '');
        _sectionLoading[_SupervisorDashboardSection.logs] = false;
      });

      return _SupervisorSectionResult<List<SupervisorLogItem>>.failure();
    }
  }

  Future<void> _openPendingQueue() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SupervisorPendingLogsScreen()),
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

  ImageProvider<Object>? _avatarImageProviderFor(String? avatarBase64) {
    if (avatarBase64 == null || avatarBase64.isEmpty) {
      return null;
    }

    try {
      return MemoryImage(base64Decode(avatarBase64));
    } catch (_) {
      return null;
    }
  }

  Widget _buildAvatar({
    required AppUser? user,
    required double radius,
    double fontSize = 16,
  }) {
    final imageProvider = _avatarImageProviderFor(user?.avatarBase64);
    final name = user?.name.isNotEmpty == true ? user!.name : widget.userName;

    return CircleAvatar(
      radius: radius,
      backgroundColor: _accentSecondary,
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Text(
              _initialsFor(name),
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final file = await file_picker.pickSingleFile(
        allowedExtensions: const <String>['jpg', 'jpeg', 'png'],
      );
      if (file == null) {
        return;
      }

      await authProvider.updateAvatarBytes(file.bytes);
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update profile photo right now.'),
        ),
      );
    }
  }

  Future<void> _removeProfilePhoto() async {
    await context.read<AuthProvider>().updateAvatarBase64(null);
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile photo removed.')));
  }

  Future<void> _openProfilePanel() async {
    final anchorContext = _profileMenuAnchorKey.currentContext;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final anchorBox = anchorContext?.findRenderObject() as RenderBox?;
    final anchorOffset = anchorBox?.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );
    final anchorSize = anchorBox?.size ?? const Size(280, 64);

    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Supervisor profile',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final authProvider = dialogContext.watch<AuthProvider>();
        final user = authProvider.user;

        return SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: (anchorOffset?.dy ?? 86) + anchorSize.height + 10,
                left: (() {
                  final desiredLeft =
                      (anchorOffset?.dx ?? (overlay.size.width - 344)) -
                      (344 - anchorSize.width);
                  final maxLeft = overlay.size.width > 376
                      ? overlay.size.width - 360.0
                      : 16.0;
                  return desiredLeft.clamp(16.0, maxLeft);
                })(),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 344,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                    decoration: BoxDecoration(
                      color: _panelColor,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: _panelBorder),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x260F172A),
                          blurRadius: 34,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                _buildAvatar(
                                  user: user,
                                  radius: 30,
                                  fontSize: 20,
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Material(
                                    color: _accentPrimary,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () async {
                                        Navigator.of(dialogContext).pop();
                                        await _pickProfilePhoto();
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(6),
                                        child: Icon(
                                          Icons.camera_alt_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.name.isNotEmpty == true
                                        ? user!.name
                                        : widget.userName,
                                    style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800,
                                      color: _headlineColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user?.email.isNotEmpty == true
                                        ? user!.email
                                        : 'No email available',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: _bodyColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildMiniTag(
                                    label:
                                        (user?.role.isNotEmpty == true
                                                ? user!.role
                                                : 'Supervisor')
                                            .toUpperCase(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _buildProfileActionTile(
                          icon: Icons.edit_outlined,
                          title: 'Change profile photo',
                          subtitle:
                              'Upload a JPG or PNG image for this supervisor.',
                          onTap: () async {
                            Navigator.of(dialogContext).pop();
                            await _pickProfilePhoto();
                          },
                        ),
                        if ((user?.avatarBase64 ?? '').isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildProfileActionTile(
                            icon: Icons.hide_image_outlined,
                            title: 'Remove profile photo',
                            subtitle:
                                'Switch back to the generated initials avatar.',
                            onTap: () async {
                              Navigator.of(dialogContext).pop();
                              await _removeProfilePhoto();
                            },
                          ),
                        ],
                        const SizedBox(height: 10),
                        _buildProfileInfoCard(user),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();
                              await _logout();
                            },
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Log out'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFB42318),
                              side: const BorderSide(color: Color(0xFFF0C4C0)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniTag({required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _accentPrimary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildProfileActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _panelSoft,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _panelColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _accentPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _headlineColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12.5, color: _bodyColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfoCard(AppUser? user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panelSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _panelBorder),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.badge_outlined,
            label: 'Supervisor',
            value: user?.name.isNotEmpty == true ? user!.name : widget.userName,
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            icon: Icons.alternate_email_rounded,
            label: 'Email',
            value: user?.email.isNotEmpty == true
                ? user!.email
                : 'Not available',
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            icon: Icons.verified_user_outlined,
            label: 'Role',
            value: user?.role.isNotEmpty == true ? user!.role : 'Supervisor',
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            icon: Icons.fingerprint_rounded,
            label: 'Account ID',
            value: user != null ? '#${user.id}' : 'Unavailable',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _panelColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: _accentPrimary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _bodyColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _headlineColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
                color: _bodyColor,
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
        return const Color(0xFFDDEEE6);
      case 'REJECTED':
        return const Color(0xFFF7DFDB);
      case 'PENDING':
      default:
        return const Color(0xFFF4E7C7);
    }
  }

  Color _statusFg(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return const Color(0xFF2F7A58);
      case 'REJECTED':
        return const Color(0xFFB24A3A);
      case 'PENDING':
      default:
        return const Color(0xFF8A6426);
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

  Color _surfaceTone(double opacity) {
    return Colors.white.withValues(alpha: opacity);
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
            ? 24.0
            : 22.0;
        final profileMaxWidth = constraints.maxWidth >= 1280 ? 420.0 : 360.0;

        final profileSection = Row(
          children: [
            const SettingsShortcutButton(),
            const SizedBox(width: 8),
            NotificationBellButton(token: authProvider.token ?? ''),
            const SizedBox(width: 8),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: _profileMenuAnchorKey,
                  onTap: _openProfilePanel,
                  borderRadius: BorderRadius.circular(22),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _panelSoft,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _panelBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: isCompact
                                ? CrossAxisAlignment.start
                                : CrossAxisAlignment.end,
                            children: [
                              Text(
                                authProvider.user?.name.isNotEmpty == true
                                    ? authProvider.user!.name
                                    : widget.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: primaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                authProvider.user?.role.isNotEmpty == true
                                    ? authProvider.user!.role
                                    : 'Company Supervisor',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        _buildAvatar(
                          user: authProvider.user,
                          radius: 26,
                          fontSize: 16,
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.keyboard_arrow_down_rounded),
                      ],
                    ),
                  ),
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
              'Monitor intern activity, review submissions, and keep approvals moving.',
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
                    titleBlock,
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
    required String helper,
    double? width,
  }) {
    final cardWidget = LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 20 : 24,
            vertical: isCompact ? 20 : 22,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _panelBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F0F172A),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: isCompact ? 15 : 16,
                        fontWeight: FontWeight.w700,
                        color: _headlineColor,
                      ),
                    ),
                  ),
                  Container(
                    width: isCompact ? 46 : 50,
                    height: isCompact ? 46 : 50,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: accent, size: isCompact ? 24 : 26),
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 18 : 20),
              Text(
                value,
                style: TextStyle(
                  fontSize: isCompact ? 30 : 36,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: _headlineColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                helper,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: _bodyColor,
                ),
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

  Widget _buildHeroPanel({
    required int pendingCount,
    required int approvedToday,
    required int totalStudents,
    required bool isNarrow,
  }) {
    final quickStats = <({String label, String value})>[
      (label: 'Pending reviews', value: '$pendingCount'),
      (label: 'Approved today', value: '$approvedToday'),
      (label: 'Assigned interns', value: '$totalStudents'),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isNarrow ? 22 : 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[_heroStart, _heroEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F172A),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _surfaceTone(0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _surfaceTone(0.12)),
            ),
            child: const Text(
              'Supervisor workspace',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            pendingCount == 0
                ? 'Everything is reviewed for now.'
                : '$pendingCount log${pendingCount == 1 ? '' : 's'} waiting for your review.',
            style: TextStyle(
              fontSize: isNarrow ? 24 : 30,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Stay on top of submissions, keep intern progress visible, and move from triage to approval with less friction.',
            style: TextStyle(
              fontSize: isNarrow ? 14 : 15,
              height: 1.55,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: quickStats
                .map(
                  (stat) => Container(
                    constraints: BoxConstraints(minWidth: isNarrow ? 150 : 170),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceTone(0.1),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _surfaceTone(0.16)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stat.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          stat.value,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
    required bool filled,
  }) {
    final background = filled ? _accentPrimary : _panelColor;
    final foreground = filled ? Colors.white : _headlineColor;
    final secondary = filled
        ? Colors.white.withValues(alpha: 0.78)
        : _bodyColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: filled ? _accentPrimary : _panelBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F0F172A),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: filled ? _surfaceTone(0.14) : _panelSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: foreground),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.arrow_forward_rounded, color: foreground, size: 20),
            ],
          ),
        ),
      ),
    );
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
              child: _buildQuickActionCard(
                title: 'Assigned Interns',
                description:
                    'Open the intern roster and check who you are currently supervising.',
                icon: Icons.groups_2_outlined,
                onTap: _openAssignedInterns,
                filled: true,
              ),
            ),
            SizedBox(
              width: actionWidth,
              child: _buildQuickActionCard(
                title: 'Pending Log Queue',
                description:
                    'Jump straight into submitted logs that still need a decision.',
                icon: Icons.fact_check_outlined,
                onTap: _openPendingQueue,
                filled: false,
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
      color: _bodyColor,
      fontSize: 13,
    );

    return const Padding(
      padding: EdgeInsets.fromLTRB(28, 18, 28, 18),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _panelBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _accentPrimary,
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
                        fontWeight: FontWeight.w700,
                        color: _headlineColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(log.date),
                      style: const TextStyle(fontSize: 13, color: _bodyColor),
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
            style: const TextStyle(fontSize: 14, color: _headlineColor),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: log.hasAttachments ? _accentSoft : _panelSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${log.hasAttachments ? 'Attached' : 'None'} (Proof)',
                  style: TextStyle(
                    fontSize: 12,
                    color: log.hasAttachments ? _accentPrimary : _bodyColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if ((log.companyName ?? '').isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _accentSoftAlt,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    log.companyName!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _accentSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Text(
                '${log.hoursRendered}h rendered',
                style: const TextStyle(fontSize: 12, color: _bodyColor),
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
        border: Border(top: BorderSide(color: Color(0xFFF0F3F7))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 24,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: _accentPrimary,
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
                      fontWeight: FontWeight.w700,
                      color: _headlineColor,
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
              style: const TextStyle(fontSize: 15, color: _bodyColor),
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              '${log.hoursRendered}h',
              style: const TextStyle(fontSize: 15, color: _bodyColor),
            ),
          ),
          Expanded(
            flex: 28,
            child: Text(
              log.taskDescription,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, color: _bodyColor),
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
                  color: log.hasAttachments ? _accentSoft : _panelSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  log.hasAttachments ? 'Attached' : 'None',
                  style: TextStyle(
                    color: log.hasAttachments ? _accentPrimary : _bodyColor,
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
    final visibleLogs = _pendingLogs.take(6).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;

        return Container(
          decoration: BoxDecoration(
            color: _panelColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _panelBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F0F172A),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pending Reviews',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _headlineColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            visibleLogs.isEmpty
                                ? 'No student submissions are waiting right now.'
                                : 'Showing the latest ${visibleLogs.length} log${visibleLogs.length == 1 ? '' : 's'} that need your attention.',
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              color: _bodyColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _panelSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_pendingLogs.length} total',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _accentPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openPendingQueue,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: Text(
                          isNarrow ? 'Open Queue' : 'Open Full Review Queue',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isNarrow) const Divider(height: 1, color: Color(0xFFF0F3F7)),
              if (!isNarrow) _buildTableHeader(),
              if (isLoading && _pendingLogs.isEmpty && _logsError == null)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: _buildLogsSkeleton(),
                )
              else if (_logsError != null && _pendingLogs.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: DashboardInlineNotice(
                    message: _logsError!,
                    onRetry: () =>
                        _refreshSection(_SupervisorDashboardSection.logs),
                  ),
                )
              else if (_pendingLogs.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _panelSoft,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _panelBorder),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _accentSoft,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.task_alt_rounded,
                            color: _accentPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _logsError == null
                              ? 'All caught up'
                              : 'Pending logs could not be refreshed',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _headlineColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _logsError == null
                              ? 'There are no student logs waiting for review at the moment.'
                              : 'You can retry loading the list or open the full queue for another attempt.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: _bodyColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (isNarrow)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Column(
                    children: visibleLogs.map(_buildLogCardRow).toList(),
                  ),
                )
              else
                ...visibleLogs.map(_buildLogRow),
              if (_logsError != null && _pendingLogs.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: DashboardInlineNotice(
                    message: _logsError!,
                    onRetry: () =>
                        _refreshSection(_SupervisorDashboardSection.logs),
                  ),
                )
              else if (isLoading)
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
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
    final isSummaryLoading = _isSectionLoading(
      _SupervisorDashboardSection.summary,
    );
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
              ? 22.0
              : 22.0;
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
                  _buildHeroPanel(
                    pendingCount: pendingCount,
                    approvedToday: approvedToday,
                    totalStudents: totalStudents,
                    isNarrow: isNarrow,
                  ),
                  SizedBox(height: isNarrow ? 18 : 22),
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
                          accent: _accentPrimary,
                          helper: 'Submissions waiting for your decision.',
                          width: statCardWidth,
                        ),
                        _buildStatCard(
                          title: 'Approved Today',
                          value: '$approvedToday',
                          icon: Icons.check_circle_outline_rounded,
                          accent: _accentSecondary,
                          helper: 'Logs you cleared within today\'s cycle.',
                          width: statCardWidth,
                        ),
                        _buildStatCard(
                          title: 'Total Students',
                          value: '$totalStudents',
                          icon: Icons.groups_rounded,
                          accent: _accentMuted,
                          helper:
                              'Interns currently assigned to your supervision.',
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
      backgroundColor: _canvasColor,
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
  const _SupervisorSectionResult._({required this.succeeded, this.value});

  final bool succeeded;
  final T? value;

  factory _SupervisorSectionResult.success(T? value) {
    return _SupervisorSectionResult<T>._(succeeded: true, value: value);
  }

  factory _SupervisorSectionResult.failure() {
    return _SupervisorSectionResult<T>._(succeeded: false);
  }
}
