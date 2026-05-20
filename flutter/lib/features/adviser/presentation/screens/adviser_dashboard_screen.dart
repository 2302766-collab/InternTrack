import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/intern_list_service.dart';
import '../../../../core/theme/ocean_breeze_palette.dart';
import '../../../../core/utils/file_picker_helper_stub.dart'
    if (dart.library.html) '../../../../core/utils/file_picker_helper_web.dart'
    as file_picker;
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/intern_list_item.dart';
import '../../../../shared/widgets/dashboard_refresh_widgets.dart';
import '../../../../shared/widgets/notification_bell_button.dart';
import '../../../../shared/widgets/settings_shortcut_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../supervisor/presentation/screens/intern_detail_screen.dart';
import '../../../supervisor/presentation/screens/intern_list_screen.dart';

class AdviserDashboardScreen extends StatefulWidget {
  final String userName;
  final DateTime Function()? clock;

  const AdviserDashboardScreen({super.key, required this.userName, this.clock});

  @override
  State<AdviserDashboardScreen> createState() => _AdviserDashboardScreenState();
}

class _AdviserDashboardScreenState extends State<AdviserDashboardScreen> {
  static const double _maxContentWidth = 1360;
  static const int _staleLogThresholdDays = 3;
  static const Color _canvasColor = OceanBreezePalette.canvas;
  static const Color _surfaceColor = OceanBreezePalette.surface;
  static const Color _borderColor = OceanBreezePalette.border;
  static const Color _headlineColor = OceanBreezePalette.textPrimary;
  static const Color _bodyColor = OceanBreezePalette.textSecondary;
  static const Color _heroStart = OceanBreezePalette.midnight;
  static const Color _accentPrimary = OceanBreezePalette.deepSea;
  static const Color _accentSecondary = OceanBreezePalette.tide;
  static const Color _accentTertiary = OceanBreezePalette.sky;
  static const Color _accentSoft = OceanBreezePalette.mist;

  late final InternListService _internListService;
  late final TextEditingController _searchController;
  late final ScrollController _dashboardScrollController;
  final GlobalKey _internProgressKey = GlobalKey();
  final GlobalKey _alertsPanelKey = GlobalKey();
  final GlobalKey _expandedAlertsKey = GlobalKey();
  final GlobalKey _profileMenuAnchorKey = GlobalKey();

  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _hasCompletedFirstLoad = false;
  DateTime? _lastUpdated;
  bool _showAllAlerts = false;
  String? _errorMessage;
  String _searchQuery = '';
  _DashboardFilter _selectedFilter = _DashboardFilter.all;
  _DashboardSort _selectedSort = _DashboardSort.mostUrgent;
  List<InternListItem> _interns = <InternListItem>[];

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _dashboardScrollController = ScrollController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dashboardScrollController.dispose();
    super.dispose();
  }

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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _removeProfilePhoto() async {
    try {
      await context.read<AuthProvider>().updateAvatarBase64(null);
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo removed.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
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
      color: const Color(0xFFF5F9FF),
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
                  color: Colors.white,
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

  Widget _buildProfileInfoRow({
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
            color: Colors.white,
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

  Widget _buildProfileInfoCard(AppUser? user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6F2)),
      ),
      child: Column(
        children: [
          _buildProfileInfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Adviser',
            value: user?.name.isNotEmpty == true ? user!.name : widget.userName,
          ),
          const SizedBox(height: 10),
          _buildProfileInfoRow(
            icon: Icons.alternate_email_rounded,
            label: 'Email',
            value: user?.email.isNotEmpty == true
                ? user!.email
                : 'Not available',
          ),
          const SizedBox(height: 10),
          _buildProfileInfoRow(
            icon: Icons.wc_rounded,
            label: 'Gender',
            value: (user?.gender ?? '').isNotEmpty ? user!.gender! : 'Not set',
          ),
          const SizedBox(height: 10),
          _buildProfileInfoRow(
            icon: Icons.fingerprint_rounded,
            label: 'Account ID',
            value: user != null ? '#${user.id}' : 'Unavailable',
          ),
        ],
      ),
    );
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
      barrierLabel: 'Adviser profile',
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
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: _borderColor),
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
                                                : 'Adviser')
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
                              'Upload a JPG or PNG image for this adviser.',
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

  void _setFilter(_DashboardFilter filter, {bool focusResults = false}) {
    setState(() {
      _selectedFilter = filter;
    });

    if (focusResults) {
      _focusInternProgress(filter);
    }
  }

  void _setSort(_DashboardSort sort, {bool focusResults = false}) {
    setState(() {
      _selectedSort = sort;
    });

    if (focusResults) {
      _focusSortedResults(sort);
    }
  }

  String _filterLabel(_DashboardFilter filter) {
    switch (filter) {
      case _DashboardFilter.all:
        return 'All Interns';
      case _DashboardFilter.needsAttention:
        return 'Needs Attention';
      case _DashboardFilter.behind:
        return 'Behind';
      case _DashboardFilter.inactive:
        return 'Inactive';
      case _DashboardFilter.completed:
        return 'Completed';
      case _DashboardFilter.noRecentLog:
        return 'No Recent Log';
      case _DashboardFilter.noLogsYet:
        return 'No Logs Yet';
      case _DashboardFilter.missingSupervisor:
        return 'Missing Supervisor';
      case _DashboardFilter.needsReview:
        return 'Pending Approval';
    }
  }

  void _focusInternProgress(_DashboardFilter filter) {
    final message = filter == _DashboardFilter.all
        ? 'Showing all interns in Intern Progress.'
        : 'Filtered Intern Progress to ${_filterLabel(filter)}.';

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final targetContext = _internProgressKey.currentContext;
      if (targetContext != null) {
        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: 0.04,
        );
      }

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    });
  }

  void _focusSortedResults(_DashboardSort sort) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final targetContext = _internProgressKey.currentContext;
      if (targetContext != null) {
        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: 0.04,
        );
      }

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Sorted Intern Progress by ${sort.label}.'),
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  void _toggleAlertsVisibility(List<_AdviserAlert> alerts) {
    final shouldShowAll = !_showAllAlerts;

    setState(() {
      _showAllAlerts = shouldShowAll;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final targetContext = shouldShowAll
          ? _expandedAlertsKey.currentContext ?? _alertsPanelKey.currentContext
          : _alertsPanelKey.currentContext;

      if (targetContext != null) {
        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: shouldShowAll ? 0.14 : 0.04,
        );
      }

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            shouldShowAll
                ? 'Showing all ${alerts.length} alerts.'
                : 'Showing top 3 alerts.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    });
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
    return detail.progressFraction;
  }

  bool _isCompleted(InternListItem detail) {
    if (detail.requiredHours <= 0) return false;
    return detail.completedHours >= detail.requiredHours;
  }

  DateTime _referenceDate() {
    for (final detail in _interns) {
      final parsed = DateTime.tryParse(
        detail.alertMeta['server_date']?.toString() ?? '',
      );
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }
    }

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }

  DateTime? _lastLogDate(InternListItem detail) {
    return _parseDate(detail.lastLogDate);
  }

  DateTime? _endDate(InternListItem detail) {
    return _parseDate(detail.endDate);
  }

  int? _daysSince(DateTime? value, DateTime referenceDate) {
    if (value == null) return null;
    final normalized = DateTime(value.year, value.month, value.day);
    return referenceDate.difference(normalized).inDays;
  }

  int? _daysRemaining(InternListItem detail, DateTime referenceDate) {
    final endDate = _endDate(detail);
    if (endDate == null) return null;
    final normalized = DateTime(endDate.year, endDate.month, endDate.day);
    return normalized.difference(referenceDate).inDays;
  }

  int? _expectedHoursByNow(InternListItem detail) {
    final raw = detail.alertMeta['expected_hours_by_now'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  bool _hasNoRecentLog(InternListItem detail, DateTime referenceDate) {
    final daysSince = _daysSince(_lastLogDate(detail), referenceDate);
    if (daysSince == null) return true;
    return daysSince >= _staleLogThresholdDays;
  }

  bool _needsReview(InternListItem detail) => detail.pendingLogs > 0;

  String _baseStatusLabel(InternListItem detail) {
    switch (detail.alertStatus.toUpperCase()) {
      case 'BEHIND':
        return 'Behind';
      case 'INACTIVE':
        return 'Inactive';
      case 'NO_LOGS_YET':
        return 'No Logs Yet';
      case 'MISSING_SUPERVISOR':
        return 'Missing Supervisor';
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

  String _statusLabel(InternListItem detail) {
    if (_isCompleted(detail)) {
      return 'Completed';
    }
    return _baseStatusLabel(detail);
  }

  String? _secondaryStatusLabel(InternListItem detail) {
    if (_isCompleted(detail) && detail.hasActiveAlert) {
      return _baseStatusLabel(detail);
    }
    return null;
  }

  Color _statusColor(InternListItem detail) {
    if (_isCompleted(detail)) {
      return const Color(0xFF0F766E);
    }

    switch (detail.alertStatus.toUpperCase()) {
      case 'INACTIVE':
        return const Color(0xFFD92D20);
      case 'BEHIND':
        return const Color(0xFFFF5B00);
      case 'NO_LOGS_YET':
        return const Color(0xFFB54708);
      case 'MISSING_SUPERVISOR':
        return const Color(0xFFD92D20);
      case 'ON_TRACK':
        return const Color(0xFF00A63E);
      default:
        return const Color(0xFF326DE6);
    }
  }

  Color _progressColor(InternListItem detail) {
    if (_isCompleted(detail)) {
      return const Color(0xFF0F766E);
    }
    if (detail.hasActiveAlert) return _statusColor(detail);
    return const Color(0xFF326DE6);
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

  String _formatCompactDate(DateTime? value) {
    if (value == null) return 'No date';
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[value.month - 1]} ${value.day}';
  }

  String _staleLogLabel(InternListItem detail, DateTime referenceDate) {
    final daysSince = _daysSince(_lastLogDate(detail), referenceDate);
    if (daysSince == null) return 'No log submitted yet';
    if (daysSince <= 0) return 'Updated today';
    if (daysSince == 1) return 'No log for 1 day';
    return 'No log for $daysSince days';
  }

  int _urgencyRank(InternListItem detail, DateTime referenceDate) {
    if (_isCompleted(detail)) {
      return detail.hasActiveAlert ? 4 : 8;
    }

    final status = detail.alertStatus.toUpperCase();
    if (status == 'MISSING_SUPERVISOR') return 0;
    if (status == 'INACTIVE') return 1;
    if (status == 'BEHIND') return 2;
    if (status == 'NO_LOGS_YET') return 3;
    if (_needsReview(detail)) return 4;
    if (_hasNoRecentLog(detail, referenceDate)) return 5;
    return 6;
  }

  String _forecastLabel(InternListItem detail, DateTime referenceDate) {
    if (_isCompleted(detail)) return 'Likely to finish';

    final status = detail.alertStatus.toUpperCase();
    final expectedHours = _expectedHoursByNow(detail);
    final paceGap = expectedHours == null
        ? 0
        : detail.completedHours - expectedHours;
    final daysRemaining = _daysRemaining(detail, referenceDate);

    if (status == 'MISSING_SUPERVISOR') return 'Likely to miss target';
    if (status == 'INACTIVE') return 'Likely to miss target';
    if (status == 'BEHIND' &&
        ((daysRemaining != null && daysRemaining <= 14) || paceGap <= -24)) {
      return 'Likely to miss target';
    }
    if (status == 'NO_LOGS_YET' &&
        daysRemaining != null &&
        daysRemaining <= 21) {
      return 'Likely to miss target';
    }
    if (status == 'BEHIND' || status == 'NO_LOGS_YET' || paceGap < 0) {
      return 'Watch closely';
    }
    return 'Likely to finish';
  }

  Color _forecastColor(String label) {
    switch (label) {
      case 'Likely to miss target':
        return const Color(0xFFD92D20);
      case 'Watch closely':
        return const Color(0xFFFF5B00);
      default:
        return const Color(0xFF00A63E);
    }
  }

  String _forecastSubtitle(InternListItem detail, DateTime referenceDate) {
    final expectedHours = _expectedHoursByNow(detail);
    final daysRemaining = _daysRemaining(detail, referenceDate);
    final paceGap = expectedHours == null
        ? null
        : detail.completedHours - expectedHours;

    if (_isCompleted(detail)) {
      return 'Completed ${detail.completedHours} of ${detail.requiredHours} required hours.';
    }

    if (paceGap != null && paceGap < 0) {
      return '${paceGap.abs()} hours behind expected pace${daysRemaining == null ? '' : ' with $daysRemaining days remaining'}.';
    }

    if (daysRemaining != null) {
      return '$daysRemaining days left in the internship window.';
    }

    return detail.alertMessage;
  }

  bool _matchesSearch(InternListItem detail, String query) {
    if (query.isEmpty) return true;
    final normalized = query.toLowerCase();
    return detail.studentName.toLowerCase().contains(normalized) ||
        detail.companyName.toLowerCase().contains(normalized) ||
        _statusLabel(detail).toLowerCase().contains(normalized) ||
        detail.alertMessage.toLowerCase().contains(normalized);
  }

  bool _matchesFilter(
    InternListItem detail,
    _DashboardFilter filter,
    DateTime referenceDate,
  ) {
    switch (filter) {
      case _DashboardFilter.all:
        return true;
      case _DashboardFilter.needsAttention:
        return detail.hasActiveAlert;
      case _DashboardFilter.behind:
        return detail.alertStatus.toUpperCase() == 'BEHIND';
      case _DashboardFilter.inactive:
        return detail.alertStatus.toUpperCase() == 'INACTIVE';
      case _DashboardFilter.completed:
        return _isCompleted(detail);
      case _DashboardFilter.noRecentLog:
        return _hasNoRecentLog(detail, referenceDate);
      case _DashboardFilter.noLogsYet:
        return detail.alertStatus.toUpperCase() == 'NO_LOGS_YET';
      case _DashboardFilter.missingSupervisor:
        return detail.alertStatus.toUpperCase() == 'MISSING_SUPERVISOR' ||
            detail.supervisorId == null;
      case _DashboardFilter.needsReview:
        return _needsReview(detail);
    }
  }

  List<InternListItem> _filteredInterns(DateTime referenceDate) {
    return _interns
        .where((detail) => _matchesSearch(detail, _searchQuery))
        .where(
          (detail) => _matchesFilter(detail, _selectedFilter, referenceDate),
        )
        .toList();
  }

  List<InternListItem> _visibleInterns(DateTime referenceDate) {
    final interns = _filteredInterns(referenceDate);

    interns.sort((a, b) {
      switch (_selectedSort) {
        case _DashboardSort.mostUrgent:
          final urgency = _urgencyRank(
            a,
            referenceDate,
          ).compareTo(_urgencyRank(b, referenceDate));
          if (urgency != 0) return urgency;
          return a.progressFraction.compareTo(b.progressFraction);
        case _DashboardSort.lowestProgress:
          final progress = a.progressFraction.compareTo(b.progressFraction);
          if (progress != 0) return progress;
          return a.studentName.compareTo(b.studentName);
        case _DashboardSort.oldestLog:
          final aDays = _daysSince(_lastLogDate(a), referenceDate) ?? 9999;
          final bDays = _daysSince(_lastLogDate(b), referenceDate) ?? 9999;
          final compare = bDays.compareTo(aDays);
          if (compare != 0) return compare;
          return a.studentName.compareTo(b.studentName);
        case _DashboardSort.company:
          final company = a.companyName.compareTo(b.companyName);
          if (company != 0) return company;
          return a.studentName.compareTo(b.studentName);
        case _DashboardSort.name:
          return a.studentName.compareTo(b.studentName);
      }
    });

    return interns;
  }

  List<_AdviserAlert> _buildAlerts(DateTime referenceDate) {
    final alerts =
        _interns
            .where((detail) => detail.hasActiveAlert)
            .map(
              (detail) => _AdviserAlert(
                intern: detail,
                studentName: detail.studentName,
                status: _baseStatusLabel(detail),
                message: detail.alertMessage,
                color: _statusColor(detail),
                followUpLabel: _staleLogLabel(detail, referenceDate),
              ),
            )
            .toList()
          ..sort(
            (a, b) => _urgencyRank(
              a.intern,
              referenceDate,
            ).compareTo(_urgencyRank(b.intern, referenceDate)),
          );

    return alerts;
  }

  List<_ActionItem> _buildUpcomingItems(
    List<InternListItem> interns,
    DateTime referenceDate,
  ) {
    final upcoming = <_ActionItem>[];

    final byEndDate =
        interns
            .where((detail) => !_isCompleted(detail))
            .where((detail) => _daysRemaining(detail, referenceDate) != null)
            .toList()
          ..sort(
            (a, b) => (_daysRemaining(a, referenceDate) ?? 999).compareTo(
              _daysRemaining(b, referenceDate) ?? 999,
            ),
          );

    for (final detail in byEndDate.take(3)) {
      final daysRemaining = _daysRemaining(detail, referenceDate) ?? 0;
      upcoming.add(
        _ActionItem(
          intern: detail,
          title: detail.studentName,
          subtitle:
              '${detail.companyName} ends in ${daysRemaining < 0 ? 0 : daysRemaining} day${daysRemaining == 1 ? '' : 's'}.',
          tag: daysRemaining <= 7 ? 'Urgent' : 'Upcoming',
          color: daysRemaining <= 7
              ? const Color(0xFFD92D20)
              : const Color(0xFF326DE6),
        ),
      );
    }

    if (upcoming.length < 4) {
      final stale =
          interns
              .where((detail) => _hasNoRecentLog(detail, referenceDate))
              .where(
                (detail) => upcoming.every(
                  (item) => item.intern.studentId != detail.studentId,
                ),
              )
              .toList()
            ..sort(
              (a, b) => (_daysSince(_lastLogDate(b), referenceDate) ?? 999)
                  .compareTo(_daysSince(_lastLogDate(a), referenceDate) ?? 999),
            );

      for (final detail in stale.take(4 - upcoming.length)) {
        upcoming.add(
          _ActionItem(
            intern: detail,
            title: detail.studentName,
            subtitle: _staleLogLabel(detail, referenceDate),
            tag: 'Follow-up',
            color: const Color(0xFFFF5B00),
          ),
        );
      }
    }

    return upcoming;
  }

  List<_ActionItem> _buildReviewItems(List<InternListItem> interns) {
    final review = interns.where(_needsReview).toList()
      ..sort((a, b) => b.pendingLogs.compareTo(a.pendingLogs));

    return review
        .take(4)
        .map(
          (detail) => _ActionItem(
            intern: detail,
            title: detail.studentName,
            subtitle:
                '${detail.pendingLogs} pending log${detail.pendingLogs == 1 ? '' : 's'} waiting for supervisor approval.',
            tag: detail.pendingLogs > 2 ? 'Priority' : 'Pending',
            color: detail.pendingLogs > 2
                ? const Color(0xFFD92D20)
                : const Color(0xFF326DE6),
          ),
        )
        .toList();
  }

  List<_ActionItem> _buildRecentActivityItems(
    List<InternListItem> interns,
    DateTime referenceDate,
  ) {
    final recent =
        interns.where((detail) => _lastLogDate(detail) != null).toList()..sort(
          (a, b) => (_lastLogDate(b) ?? DateTime(2000)).compareTo(
            _lastLogDate(a) ?? DateTime(2000),
          ),
        );

    return recent
        .take(4)
        .map(
          (detail) => _ActionItem(
            intern: detail,
            title: detail.studentName,
            subtitle:
                'Last activity ${_formatDate(_lastLogDate(detail))} at ${detail.companyName}.',
            tag: (_daysSince(_lastLogDate(detail), referenceDate) ?? 99) <= 1
                ? 'New'
                : 'Recent',
            color: const Color(0xFF0F766E),
          ),
        )
        .toList();
  }

  List<_WeeklyActivityPoint> _buildWeeklyActivity(
    List<InternListItem> interns,
    DateTime referenceDate,
  ) {
    final points = <_WeeklyActivityPoint>[];
    final weekdayLabels = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    for (var offset = 6; offset >= 0; offset--) {
      final day = referenceDate.subtract(Duration(days: offset));
      final count = interns.where((detail) {
        final lastLog = _lastLogDate(detail);
        if (lastLog == null) return false;
        return lastLog.year == day.year &&
            lastLog.month == day.month &&
            lastLog.day == day.day;
      }).length;

      points.add(
        _WeeklyActivityPoint(
          label: weekdayLabels[day.weekday - 1],
          dateLabel: _formatCompactDate(day),
          count: count,
        ),
      );
    }

    return points;
  }

  List<_CompanySnapshot> _buildCompanySnapshots(List<InternListItem> interns) {
    final grouped = <String, List<InternListItem>>{};
    for (final detail in interns) {
      grouped
          .putIfAbsent(detail.companyName, () => <InternListItem>[])
          .add(detail);
    }

    final snapshots =
        grouped.entries.map((entry) {
          final interns = entry.value;
          final avgProgress = interns.isEmpty
              ? 0
              : (interns
                            .map((detail) => detail.progressPercentage)
                            .reduce((a, b) => a + b) /
                        interns.length)
                    .round();
          final attentionCount = interns
              .where((detail) => detail.hasActiveAlert)
              .length;
          final pendingReviewCount = interns.fold<int>(
            0,
            (sum, detail) => sum + detail.pendingLogs,
          );

          return _CompanySnapshot(
            companyName: entry.key,
            totalInterns: interns.length,
            avgProgress: avgProgress,
            attentionCount: attentionCount,
            pendingReviews: pendingReviewCount,
          );
        }).toList()..sort((a, b) {
          final attention = b.attentionCount.compareTo(a.attentionCount);
          if (attention != 0) return attention;
          return b.totalInterns.compareTo(a.totalInterns);
        });

    return snapshots.take(4).toList();
  }

  List<InternListItem> _buildAtRiskInterns(
    List<InternListItem> interns,
    DateTime referenceDate,
  ) {
    final rankedInterns =
        interns.where((detail) => !_isCompleted(detail)).toList()..sort(
          (a, b) => _urgencyRank(
            a,
            referenceDate,
          ).compareTo(_urgencyRank(b, referenceDate)),
        );
    return rankedInterns.take(5).toList();
  }

  List<_ForecastItem> _buildForecastItems(
    List<InternListItem> interns,
    DateTime referenceDate,
  ) {
    final forecasts =
        interns
            .map(
              (detail) => _ForecastItem(
                intern: detail,
                label: _forecastLabel(detail, referenceDate),
                subtitle: _forecastSubtitle(detail, referenceDate),
                color: _forecastColor(_forecastLabel(detail, referenceDate)),
              ),
            )
            .toList()
          ..sort((a, b) {
            final rank = _forecastPriority(
              a.label,
            ).compareTo(_forecastPriority(b.label));
            if (rank != 0) return rank;
            return _urgencyRank(
              a.intern,
              referenceDate,
            ).compareTo(_urgencyRank(b.intern, referenceDate));
          });

    return forecasts.take(4).toList();
  }

  int _forecastPriority(String label) {
    switch (label) {
      case 'Likely to miss target':
        return 0;
      case 'Watch closely':
        return 1;
      default:
        return 2;
    }
  }

  Future<void> _showReminderSheet(InternListItem detail) async {
    final message =
        'Hello ${detail.studentName}, this is a reminder to update your internship logs in InternTrack. '
        '${detail.alertMessage} Please submit your latest progress and hours as soon as possible.';

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Send Reminder',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF102A56),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use this reminder draft for ${detail.studentName}.',
                style: const TextStyle(fontSize: 14, color: Color(0xFF4A6480)),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFDDE5EF)),
                ),
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF243B63),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(this.context);
                    await Clipboard.setData(ClipboardData(text: message));
                    if (!mounted) return;
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Reminder copied for ${detail.studentName}.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_all_rounded),
                  label: const Text('Copy Reminder'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(AuthProvider authProvider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        final isCompact = constraints.maxWidth < 520;
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
                      color: _headlineColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    authProvider.user?.role.isNotEmpty == true
                        ? authProvider.user!.role
                        : 'Academic Adviser',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: _bodyColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            InkWell(
              key: _profileMenuAnchorKey,
              onTap: _openProfilePanel,
              borderRadius: BorderRadius.circular(999),
              child: _buildAvatar(
                user: authProvider.user,
                radius: 26,
                fontSize: 16,
              ),
            ),
          ],
        );

        return Container(
          padding: EdgeInsets.fromLTRB(
            isNarrow ? 16 : 28,
            20,
            isNarrow ? 16 : 28,
            20,
          ),
          decoration: BoxDecoration(
            color: _surfaceColor,
            border: const Border(bottom: BorderSide(color: _borderColor)),
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
                                  color: _headlineColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Search, triage, and coach advisees from one place.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _bodyColor,
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
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: profileMaxWidth),
                        child: profileSection,
                      ),
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
                              color: _headlineColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Search, triage, and coach advisees from one place.',
                            style: TextStyle(fontSize: 14, color: _bodyColor),
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
    required String subtitle,
    required IconData icon,
    required Color accent,
    required _DashboardFilter filter,
    double? width,
  }) {
    final selected = _selectedFilter == filter;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _setFilter(filter, focusResults: true),
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected ? accent : _borderColor,
                width: selected ? 1.6 : 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120F172A),
                  blurRadius: 18,
                  offset: Offset(0, 6),
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.25,
                          color: _headlineColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: accent.withAlpha(28),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: accent, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: _bodyColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPulsePanel({
    required int avgProgress,
    required int onTrack,
    required int completed,
    required int pendingReviews,
    required int staleLogs,
    required int endingSoon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _heroStart,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x250F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monitoring Pulse',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'A quick read on workload, progress, and who needs attention first.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFFD9E5F2),
                  ),
                ),
              ],
            ),
          ),
          _buildPulseMetric(
            'Avg Progress',
            '$avgProgress%',
            OceanBreezePalette.mist,
          ),
          _buildPulseMetric('On Track', '$onTrack', OceanBreezePalette.sky),
          _buildPulseMetric('Completed', '$completed', OceanBreezePalette.tide),
          _buildPulseMetric(
            'Pending Approval',
            '$pendingReviews',
            OceanBreezePalette.surfaceMuted,
          ),
          _buildPulseMetric(
            'No Recent Log',
            '$staleLogs',
            OceanBreezePalette.mist,
          ),
          _buildPulseMetric(
            'Ending Soon',
            '$endingSoon',
            OceanBreezePalette.sky,
          ),
        ],
      ),
    );
  }

  Widget _buildPulseMetric(String label, String value, Color accent) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: OceanBreezePalette.mist,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionPanel({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required Widget child,
    double? width,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _borderColor),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withAlpha(20),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _headlineColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: _bodyColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildAlignedPanelGrid({
    required List<Widget> panels,
    required int columns,
    required double spacing,
  }) {
    if (columns <= 1) {
      return Column(
        children: [
          for (var index = 0; index < panels.length; index++) ...[
            panels[index],
            if (index < panels.length - 1) SizedBox(height: spacing),
          ],
        ],
      );
    }

    final rows = <Widget>[];
    for (var start = 0; start < panels.length; start += columns) {
      final end = (start + columns).clamp(0, panels.length);
      final rowPanels = panels.sublist(start, end);

      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < rowPanels.length; index++) ...[
                Expanded(child: rowPanels[index]),
                if (index < rowPanels.length - 1) SizedBox(width: spacing),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          rows[index],
          if (index < rows.length - 1) SizedBox(height: spacing),
        ],
      ],
    );
  }

  Widget _buildEmptySectionMessage(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF4)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Color(0xFF66798F),
        ),
      ),
    );
  }

  Widget _buildActionList(
    List<_ActionItem> items, {
    required VoidCallback onEmptyAction,
    required String emptyMessage,
    String? emptyButtonLabel,
  }) {
    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEmptySectionMessage(emptyMessage),
          if (emptyButtonLabel != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onEmptyAction,
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(emptyButtonLabel),
            ),
          ],
        ],
      );
    }

    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _openIntern(item.intern),
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8EDF4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF102A56),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: Color(0xFF4A6480),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildTag(item.tag, item.color),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAtRiskSpotlight(
    List<InternListItem> atRiskInterns,
    DateTime referenceDate,
  ) {
    if (atRiskInterns.isEmpty) {
      return _buildEmptySectionMessage(
        'No advisees are currently flagged as high-risk. Keep monitoring the recent activity and review queue.',
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: atRiskInterns.map((detail) {
        final width = atRiskInterns.length == 1 ? double.infinity : 260.0;
        return SizedBox(
          width: width,
          child: InkWell(
            onTap: () => _openIntern(detail),
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF5D2BE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF326DE6),
                        child: Text(
                          _initialsFor(detail.studentName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          detail.studentName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF102A56),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildTag(_baseStatusLabel(detail), _statusColor(detail)),
                  const SizedBox(height: 10),
                  Text(
                    detail.alertMessage,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF4A6480),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _staleLogLabel(detail, referenceDate),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB54708),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWeeklyActivityChart(List<_WeeklyActivityPoint> points) {
    if (points.isEmpty) {
      return _buildEmptySectionMessage('Weekly activity is not available yet.');
    }

    final maxCount = points
        .map((point) => point.count)
        .fold<int>(0, (max, value) => value > max ? value : max);
    final normalizedMax = maxCount == 0 ? 1 : maxCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Students active per day',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF243B63),
              ),
            ),
            const Spacer(),
            Text(
              '${points.fold<int>(0, (sum, point) => sum + point.count)} activity checks',
              style: const TextStyle(fontSize: 13, color: Color(0xFF68768A)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 132,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: points.map((point) {
              final heightFactor = point.count / normalizedMax;
              return Expanded(
                child: Tooltip(
                  message:
                      '${point.dateLabel}: ${point.count} student${point.count == 1 ? '' : 's'} active',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${point.count}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF102A56),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: heightFactor == 0
                                  ? 0.08
                                  : heightFactor,
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF4F8CFF),
                                      Color(0xFF0F4C5C),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          point.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF68768A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCompanySnapshot(List<_CompanySnapshot> snapshots) {
    if (snapshots.isEmpty) {
      return _buildEmptySectionMessage(
        'Company grouping appears here once advisees are assigned to internship sites.',
      );
    }

    return Column(
      children: snapshots.map((snapshot) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE8EDF4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        snapshot.companyName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF102A56),
                        ),
                      ),
                    ),
                    _buildTag(
                      '${snapshot.attentionCount} attention',
                      snapshot.attentionCount > 0
                          ? const Color(0xFFFF5B00)
                          : const Color(0xFF00A63E),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildMetricBadge(
                      '${snapshot.totalInterns}',
                      'Interns',
                      const Color(0xFF326DE6),
                    ),
                    _buildMetricBadge(
                      '${snapshot.avgProgress}%',
                      'Avg Progress',
                      const Color(0xFF0F766E),
                    ),
                    _buildMetricBadge(
                      '${snapshot.pendingReviews}',
                      'Pending Approval',
                      const Color(0xFFB54708),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMetricBadge(String value, String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$value ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            TextSpan(
              text: label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4A6480),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForecastList(List<_ForecastItem> forecasts) {
    if (forecasts.isEmpty) {
      return _buildEmptySectionMessage(
        'Completion forecast becomes available after advisees log progress and internship dates are set.',
      );
    }

    return Column(
      children: forecasts.map((forecast) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _openIntern(forecast.intern),
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8EDF4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          forecast.intern.studentName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF102A56),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          forecast.subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: Color(0xFF4A6480),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildTag(forecast.label, forecast.color),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAlertsPanel(List<_AdviserAlert> alerts) {
    final primaryAlerts = alerts.take(3).toList();
    final extraAlerts = alerts.length > 3
        ? alerts.skip(3).toList()
        : const <_AdviserAlert>[];
    final showingCount = _showAllAlerts ? alerts.length : primaryAlerts.length;

    return Container(
      key: _alertsPanelKey,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFC58A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5B00)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Alerts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF102A56),
                  ),
                ),
              ),
              if (alerts.length > 3)
                TextButton(
                  onPressed: () => _toggleAlertsVisibility(alerts),
                  child: Text(
                    _showAllAlerts ? 'Show top 3' : 'View all alerts',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Top priority students surface here first, with one-tap actions for follow-up.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF68768A),
            ),
          ),
          if (alerts.isNotEmpty) ...[
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                alerts.length <= 3
                    ? 'Showing all $showingCount alerts.'
                    : _showAllAlerts
                    ? 'Showing all $showingCount alerts.'
                    : 'Showing top $showingCount of ${alerts.length} alerts.',
                key: ValueKey<String>(
                  'alerts-count-$showingCount-$_showAllAlerts',
                ),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB54708),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (alerts.isEmpty)
            const Text(
              'No active alerts. Your advisees are progressing well.',
              style: TextStyle(fontSize: 15, color: Color(0xFF4A6480)),
            )
          else
            ...primaryAlerts.map((alert) {
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 560;

                        final title = Text(
                          alert.studentName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF102A56),
                          ),
                        );

                        final badge = _buildTag(alert.status, alert.color);

                        return isCompact
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  title,
                                  const SizedBox(height: 10),
                                  badge,
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: title),
                                  badge,
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      alert.message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4A6480),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      alert.followUpLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB54708),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _openIntern(alert.intern),
                          icon: const Icon(Icons.person_search_rounded),
                          label: const Text('View Student'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showReminderSheet(alert.intern),
                          icon: const Icon(Icons.mark_email_unread_rounded),
                          label: const Text('Send Reminder'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => _openIntern(alert.intern),
                          icon: const Icon(Icons.description_outlined),
                          label: const Text('Open Report'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          if (extraAlerts.isNotEmpty)
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: !_showAllAlerts
                  ? const SizedBox.shrink()
                  : Column(
                      key: _expandedAlertsKey,
                      children: extraAlerts.map((alert) {
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
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isCompact = constraints.maxWidth < 560;

                                  final title = Text(
                                    alert.studentName,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF102A56),
                                    ),
                                  );

                                  final badge = _buildTag(
                                    alert.status,
                                    alert.color,
                                  );

                                  return isCompact
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            title,
                                            const SizedBox(height: 10),
                                            badge,
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Expanded(child: title),
                                            badge,
                                          ],
                                        );
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                alert.message,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF4A6480),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                alert.followUpLabel,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFB54708),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _openIntern(alert.intern),
                                    icon: const Icon(
                                      Icons.person_search_rounded,
                                    ),
                                    label: const Text('View Student'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _showReminderSheet(alert.intern),
                                    icon: const Icon(
                                      Icons.mark_email_unread_rounded,
                                    ),
                                    label: const Text('Send Reminder'),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: () => _openIntern(alert.intern),
                                    icon: const Icon(
                                      Icons.description_outlined,
                                    ),
                                    label: const Text('Open Report'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlsHeader(
    double contentWidth,
    int visibleCount,
    int totalCount,
  ) {
    return Container(
      width: contentWidth,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7).withAlpha(245),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE1E7EF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 840;

          final searchField = TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search student, company, status, or alert',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          );

          final sortField = DropdownButtonFormField<_DashboardSort>(
            initialValue: _selectedSort,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Sort',
              prefixIcon: Icon(Icons.swap_vert_rounded),
            ),
            items: _DashboardSort.values
                .map(
                  (sort) => DropdownMenuItem<_DashboardSort>(
                    value: sort,
                    child: Text(sort.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              _setSort(value, focusResults: true);
            },
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isNarrow) ...[
                searchField,
                const SizedBox(height: 10),
                sortField,
              ] else
                Row(
                  children: [
                    Expanded(flex: 3, child: searchField),
                    const SizedBox(width: 12),
                    SizedBox(width: 220, child: sortField),
                  ],
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Showing $visibleCount of $totalCount interns',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF355070),
                    ),
                  ),
                  if (_selectedFilter != _DashboardFilter.all ||
                      _searchQuery.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _selectedFilter = _DashboardFilter.all;
                          _searchQuery = '';
                        });
                      },
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Clear filters'),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterWorkspace(double width) {
    final filters = <_FilterChoice>[
      const _FilterChoice(_DashboardFilter.all, 'All'),
      const _FilterChoice(_DashboardFilter.needsAttention, 'Needs Attention'),
      const _FilterChoice(_DashboardFilter.behind, 'Behind'),
      const _FilterChoice(_DashboardFilter.inactive, 'Inactive'),
      const _FilterChoice(_DashboardFilter.completed, 'Completed'),
      const _FilterChoice(_DashboardFilter.noRecentLog, 'No Recent Log'),
      const _FilterChoice(_DashboardFilter.noLogsYet, 'No Logs Yet'),
      const _FilterChoice(
        _DashboardFilter.missingSupervisor,
        'Missing Supervisor',
      ),
      const _FilterChoice(_DashboardFilter.needsReview, 'Pending Approval'),
    ];

    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5EAF1)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D0F172A),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Shortcuts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF102A56),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sticky search and sort stay pinned above while these quick filters let you jump between student groups.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Color(0xFF68768A),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: filters.map((filter) {
                final selected = _selectedFilter == filter.filter;
                return FilterChip(
                  label: Text(filter.label),
                  selected: selected,
                  onSelected: (_) => _setFilter(filter.filter),
                  selectedColor: const Color(0xFFD9EEF2),
                  checkmarkColor: const Color(0xFF0F4C5C),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFF0F4C5C)
                        : const Color(0xFFD0D7E2),
                  ),
                  labelStyle: TextStyle(
                    color: selected
                        ? const Color(0xFF0F4C5C)
                        : const Color(0xFF334E68),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildLegendPill('On Track', const Color(0xFF00A63E)),
                _buildLegendPill('Behind', const Color(0xFFFF5B00)),
                _buildLegendPill('Inactive', const Color(0xFFD92D20)),
                _buildLegendPill('No Logs Yet', const Color(0xFFB54708)),
                _buildLegendPill('Missing Supervisor', const Color(0xFFD92D20)),
                _buildLegendPill('Completed', const Color(0xFF0F766E)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildProgressPanel(
    List<InternListItem> visibleInterns,
    DateTime referenceDate,
  ) {
    return Container(
      key: _internProgressKey,
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
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 760;
                final subtitle =
                    _selectedFilter == _DashboardFilter.all &&
                        _searchQuery.isEmpty
                    ? 'Tap a student card to open details, reports, and log history.'
                    : 'Filtered results update as you search, sort, and focus on a status.';

                return isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Intern Progress',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF102A56),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF68768A),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _interns.isEmpty
                                  ? null
                                  : _openInternReports,
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: const Text('Open Intern Details'),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Intern Progress',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF102A56),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  subtitle,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF68768A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _interns.isEmpty
                                ? null
                                : _openInternReports,
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Open Intern Details'),
                          ),
                        ],
                      );
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE7EBF0)),
          Padding(
            padding: const EdgeInsets.all(24),
            child: visibleInterns.isEmpty
                ? _buildEmptySectionMessage(
                    'No interns matched the current search and filter settings.',
                  )
                : Column(
                    children: visibleInterns.map((detail) {
                      final progress = _progressValue(detail);
                      final status = _statusLabel(detail);
                      final secondaryStatus = _secondaryStatusLabel(detail);
                      final statusColor = _statusColor(detail);
                      final daysSince = _daysSince(
                        _lastLogDate(detail),
                        referenceDate,
                      );
                      final isStale = _hasNoRecentLog(detail, referenceDate);
                      final borderColor = isStale
                          ? const Color(0xFFFFD3BF)
                          : detail.hasActiveAlert
                          ? statusColor.withAlpha(80)
                          : const Color(0xFFE0E6ED);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: InkWell(
                          onTap: () => _openIntern(detail),
                          borderRadius: BorderRadius.circular(24),
                          child: Ink(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: borderColor),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 760;

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
                                              fontWeight: FontWeight.w800,
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
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _buildTag(status, statusColor),
                                              if (secondaryStatus != null)
                                                _buildTag(
                                                  secondaryStatus,
                                                  _forecastColor(
                                                    'Watch closely',
                                                  ),
                                                ),
                                              if (_needsReview(detail))
                                                _buildTag(
                                                  '${detail.pendingLogs} pending',
                                                  const Color(0xFF326DE6),
                                                ),
                                              if (isStale)
                                                _buildTag(
                                                  _staleLogLabel(
                                                    detail,
                                                    referenceDate,
                                                  ),
                                                  daysSince == null ||
                                                          daysSince >= 6
                                                      ? const Color(0xFFD92D20)
                                                      : const Color(0xFFB54708),
                                                ),
                                            ],
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
                                      'Last log',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF68768A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDate(_lastLogDate(detail)),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isStale
                                            ? const Color(0xFFB54708)
                                            : const Color(0xFF102A56),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _forecastLabel(detail, referenceDate),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _forecastColor(
                                          _forecastLabel(detail, referenceDate),
                                        ),
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
                                    Row(
                                      children: [
                                        const Text(
                                          'Progress',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF355070),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${detail.completedHours} / ${detail.requiredHours} hours',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF243B63),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        minHeight: 16,
                                        value: progress,
                                        backgroundColor: const Color(
                                          0xFFDDE2EA,
                                        ),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              _progressColor(detail),
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    if (isNarrow)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${(progress * 100).round()}% complete',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF102A56),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            detail.alertMessage,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF4A6480),
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              detail.alertMessage,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF4A6480),
                                                height: 1.45,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            '${(progress * 100).round()}%',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
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
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final referenceDate = _referenceDate();
    final filteredInterns = _filteredInterns(referenceDate);
    final visibleInterns = _visibleInterns(referenceDate);
    final alerts = _buildAlerts(referenceDate);
    final totalInterns = _interns.length;
    final onTrack = _interns
        .where(
          (detail) =>
              detail.alertStatus.toUpperCase() == 'ON_TRACK' &&
              !_isCompleted(detail),
        )
        .length;
    final completed = _interns.where(_isCompleted).length;
    final needsAttention = _interns
        .where((detail) => detail.hasActiveAlert)
        .length;
    final staleLogs = _interns
        .where((detail) => _hasNoRecentLog(detail, referenceDate))
        .length;
    final pendingReviews = _interns.fold<int>(
      0,
      (sum, detail) => sum + detail.pendingLogs,
    );
    final endingSoon = _interns.where((detail) {
      final daysRemaining = _daysRemaining(detail, referenceDate);
      return daysRemaining != null &&
          daysRemaining >= 0 &&
          daysRemaining <= 14 &&
          !_isCompleted(detail);
    }).length;
    final avgProgress = _interns.isEmpty
        ? 0
        : (_interns
                      .map((detail) => detail.progressPercentage)
                      .reduce((a, b) => a + b) /
                  _interns.length)
              .round();
    final noLogsYet = _interns
        .where((detail) => detail.alertStatus.toUpperCase() == 'NO_LOGS_YET')
        .length;
    final reviewItems = _buildReviewItems(filteredInterns);
    final upcomingItems = _buildUpcomingItems(filteredInterns, referenceDate);
    final recentActivityItems = _buildRecentActivityItems(
      filteredInterns,
      referenceDate,
    );
    final weeklyActivity = _buildWeeklyActivity(filteredInterns, referenceDate);
    final companySnapshots = _buildCompanySnapshots(filteredInterns);
    final atRiskInterns = _buildAtRiskInterns(filteredInterns, referenceDate);
    final forecasts = _buildForecastItems(filteredInterns, referenceDate);

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
              : 26.0;
          const spacing = 18.0;
          final contentWidth = (viewportWidth - (horizontalPadding * 2))
              .clamp(0.0, viewportWidth)
              .toDouble();
          final statCardWidth = contentWidth >= 1220
              ? (contentWidth - (spacing * 3)) / 4
              : contentWidth >= 720
              ? (contentWidth - spacing) / 2
              : contentWidth;
          final statCardColumns = contentWidth >= 1220
              ? 4
              : contentWidth >= 720
              ? 2
              : 1;
          final triPanelWidth = contentWidth >= 1260
              ? (contentWidth - (spacing * 2)) / 3
              : contentWidth >= 820
              ? (contentWidth - spacing) / 2
              : contentWidth;
          final dualPanelWidth = contentWidth >= 1180
              ? (contentWidth - spacing) / 2
              : contentWidth;
          final triPanelColumns = contentWidth >= 1260
              ? 3
              : contentWidth >= 820
              ? 2
              : 1;
          final dualPanelColumns = contentWidth >= 1180 ? 2 : 1;
          final stickyHeight = constraints.maxWidth < 840 ? 196.0 : 160.0;

          return CustomScrollView(
            controller: _dashboardScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _maxContentWidth,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        28,
                        horizontalPadding,
                        24,
                      ),
                      child: Column(
                        children: [
                          _buildAlignedPanelGrid(
                            columns: statCardColumns,
                            spacing: spacing,
                            panels: [
                              _buildStatCard(
                                title: 'Total Interns',
                                value: '$totalInterns',
                                subtitle:
                                    '$onTrack on track and $completed completed.',
                                icon: Icons.groups_2_outlined,
                                accent: _accentPrimary,
                                filter: _DashboardFilter.all,
                                width: statCardWidth,
                              ),
                              _buildStatCard(
                                title: 'Needs Attention',
                                value: '$needsAttention',
                                subtitle:
                                    '$staleLogs have stale logs and $noLogsYet have no logs yet.',
                                icon: Icons.warning_amber_rounded,
                                accent: _accentSecondary,
                                filter: _DashboardFilter.needsAttention,
                                width: statCardWidth,
                              ),
                              _buildStatCard(
                                title: 'No Recent Log',
                                value: '$staleLogs',
                                subtitle:
                                    '$pendingReviews logs are waiting for supervisor approval.',
                                icon: Icons.schedule_rounded,
                                accent: _accentTertiary,
                                filter: _DashboardFilter.noRecentLog,
                                width: statCardWidth,
                              ),
                              _buildStatCard(
                                title: 'Completed',
                                value: '$completed',
                                subtitle:
                                    '${totalInterns - completed} still in progress across your roster.',
                                icon: Icons.verified_rounded,
                                accent: _accentSoft,
                                filter: _DashboardFilter.completed,
                                width: statCardWidth,
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          _buildPulsePanel(
                            avgProgress: avgProgress,
                            onTrack: onTrack,
                            completed: completed,
                            pendingReviews: pendingReviews,
                            staleLogs: staleLogs,
                            endingSoon: endingSoon,
                          ),
                          const SizedBox(height: 28),
                          _buildAlertsPanel(alerts),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyHeaderDelegate(
                  minExtentValue: stickyHeight,
                  maxExtentValue: stickyHeight,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _maxContentWidth,
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          8,
                          horizontalPadding,
                          8,
                        ),
                        child: _buildControlsHeader(
                          contentWidth,
                          visibleInterns.length,
                          totalInterns,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _maxContentWidth,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        18,
                        horizontalPadding,
                        32,
                      ),
                      child: Column(
                        children: [
                          _buildFilterWorkspace(contentWidth),
                          const SizedBox(height: 18),
                          _buildAlignedPanelGrid(
                            columns: triPanelColumns,
                            spacing: spacing,
                            panels: [
                              _buildSectionPanel(
                                title: 'Pending Supervisor Approval',
                                subtitle:
                                    'Logs that advisers should monitor while waiting for supervisor action.',
                                icon: Icons.assignment_turned_in_outlined,
                                accent: _accentPrimary,
                                width: triPanelWidth,
                                child: _buildActionList(
                                  reviewItems,
                                  onEmptyAction: _openInternReports,
                                  emptyMessage:
                                      'No logs are waiting for supervisor approval right now.',
                                  emptyButtonLabel: 'Open Intern Details',
                                ),
                              ),
                              _buildSectionPanel(
                                title: 'Upcoming Deadlines',
                                subtitle:
                                    'Internship end dates and stale follow-ups to keep on your radar.',
                                icon: Icons.event_available_rounded,
                                accent: _accentSecondary,
                                width: triPanelWidth,
                                child: _buildActionList(
                                  upcomingItems,
                                  onEmptyAction: _loadDashboardData,
                                  emptyMessage:
                                      'No deadlines or follow-ups were detected from the current advisee data.',
                                ),
                              ),
                              _buildSectionPanel(
                                title: 'Recent Activity',
                                subtitle:
                                    'Quick visibility into which students updated most recently.',
                                icon: Icons.bolt_rounded,
                                accent: _accentSoft,
                                width: triPanelWidth,
                                child: _buildActionList(
                                  recentActivityItems,
                                  onEmptyAction: _loadDashboardData,
                                  emptyMessage:
                                      'Recent activity will appear here once advisees start logging time.',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _buildSectionPanel(
                            title: 'At-Risk Spotlight',
                            subtitle:
                                'The top five advisees who likely need outreach first.',
                            icon: Icons.priority_high_rounded,
                            accent: _accentSecondary,
                            width: contentWidth,
                            child: _buildAtRiskSpotlight(
                              atRiskInterns,
                              referenceDate,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildSectionPanel(
                            title: 'Weekly Activity',
                            subtitle:
                                'A seven-day read of how many advisees logged activity each day.',
                            icon: Icons.bar_chart_rounded,
                            accent: _accentPrimary,
                            width: contentWidth,
                            child: _buildWeeklyActivityChart(weeklyActivity),
                          ),
                          const SizedBox(height: 18),
                          _buildAlignedPanelGrid(
                            columns: dualPanelColumns,
                            spacing: spacing,
                            panels: [
                              _buildSectionPanel(
                                title: 'Company Snapshot',
                                subtitle:
                                    'Group advisees by internship site to surface location-level issues.',
                                icon: Icons.apartment_rounded,
                                accent: _accentPrimary,
                                width: dualPanelWidth,
                                child: _buildCompanySnapshot(companySnapshots),
                              ),
                              _buildSectionPanel(
                                title: 'Completion Forecast',
                                subtitle:
                                    'Projected finish risk, based on current pace, alerts, and internship timing.',
                                icon: Icons.insights_rounded,
                                accent: _accentTertiary,
                                width: dualPanelWidth,
                                child: _buildForecastList(forecasts),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          _buildProgressPanel(visibleInterns, referenceDate),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
      backgroundColor: _canvasColor,
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
                            style: const TextStyle(color: _bodyColor),
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

enum _DashboardFilter {
  all,
  needsAttention,
  behind,
  inactive,
  completed,
  noRecentLog,
  noLogsYet,
  missingSupervisor,
  needsReview,
}

enum _DashboardSort {
  mostUrgent('Urgent'),
  lowestProgress('Low Progress'),
  oldestLog('Oldest Log'),
  company('Company'),
  name('Name');

  const _DashboardSort(this.label);

  final String label;
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minExtentValue;
  final double maxExtentValue;
  final Widget child;

  const _StickyHeaderDelegate({
    required this.minExtentValue,
    required this.maxExtentValue,
    required this.child,
  });

  @override
  double get minExtent => minExtentValue;

  @override
  double get maxExtent => maxExtentValue;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: OceanBreezePalette.canvas, child: child);
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return minExtentValue != oldDelegate.minExtentValue ||
        maxExtentValue != oldDelegate.maxExtentValue ||
        child != oldDelegate.child;
  }
}

class _FilterChoice {
  final _DashboardFilter filter;
  final String label;

  const _FilterChoice(this.filter, this.label);
}

class _AdviserAlert {
  final InternListItem intern;
  final String studentName;
  final String status;
  final String message;
  final String followUpLabel;
  final Color color;

  const _AdviserAlert({
    required this.intern,
    required this.studentName,
    required this.status,
    required this.message,
    required this.followUpLabel,
    required this.color,
  });
}

class _ActionItem {
  final InternListItem intern;
  final String title;
  final String subtitle;
  final String tag;
  final Color color;

  const _ActionItem({
    required this.intern,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.color,
  });
}

class _WeeklyActivityPoint {
  final String label;
  final String dateLabel;
  final int count;

  const _WeeklyActivityPoint({
    required this.label,
    required this.dateLabel,
    required this.count,
  });
}

class _CompanySnapshot {
  final String companyName;
  final int totalInterns;
  final int avgProgress;
  final int attentionCount;
  final int pendingReviews;

  const _CompanySnapshot({
    required this.companyName,
    required this.totalInterns,
    required this.avgProgress,
    required this.attentionCount,
    required this.pendingReviews,
  });
}

class _ForecastItem {
  final InternListItem intern;
  final String label;
  final String subtitle;
  final Color color;

  const _ForecastItem({
    required this.intern,
    required this.label,
    required this.subtitle,
    required this.color,
  });
}
