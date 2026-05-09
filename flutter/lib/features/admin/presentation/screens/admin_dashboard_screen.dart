import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/services/admin_dashboard_service.dart';
import '../../../../core/services/admin_student_service.dart';
import '../../../../shared/models/admin_dashboard_summary.dart';
import '../../../../shared/models/admin_student_summary.dart';
import '../../../../shared/models/admin_students_page.dart';
import '../../../../shared/widgets/notification_bell_button.dart';
import '../../../../shared/widgets/settings_shortcut_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String userName;

  const AdminDashboardScreen({super.key, required this.userName});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const int _itemsPerPage = 10;
  static const String _filterAll = 'all';
  static const String _filterNeedsAttention = 'needs_attention';
  static const String _filterMissingProfile = 'missing_profile';
  static const String _filterMissingSupervisor = 'missing_supervisor';
  static const String _filterMissingAdviser = 'missing_adviser';

  late final AdminStudentService _studentService;
  late final AdminDashboardService _dashboardService;

  final List<AdminStudentSummary> _students = <AdminStudentSummary>[];

  bool _isInitialLoading = true;
  bool _isPageLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _lastPage = 1;
  int _totalStudents = 0;
  String _selectedFilter = _filterAll;
  AdminDashboardSummary? _dashboardSummary;

  @override
  void initState() {
    super.initState();
    _studentService = context.read<AdminStudentService>();
    _dashboardService = context.read<AdminDashboardService>();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialLoading && _students.isEmpty && _dashboardSummary == null) {
      _refreshDashboard();
    }
  }

  Future<void> _refreshDashboard() async {
    await _loadDashboard(page: 1);
  }

  Future<void> _goToPage(int page) async {
    if (page < 1 || page > _lastPage || page == _currentPage) {
      return;
    }

    await _loadDashboard(page: page);
  }

  Future<void> _loadDashboard({required int page}) async {
    final token = context.read<AuthProvider>().token ?? '';
    if (token.isEmpty) {
      setState(() {
        _isInitialLoading = false;
        _isPageLoading = false;
        _errorMessage = 'Missing authentication token. Please log in again.';
      });
      return;
    }

    final isInitialRequest =
        (_students.isEmpty || _dashboardSummary == null) && !_isPageLoading;

    if (isInitialRequest) {
      setState(() {
        _isInitialLoading = true;
        _errorMessage = null;
      });
    } else {
      if (_isPageLoading) {
        return;
      }

      setState(() {
        _isPageLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        _studentService.fetchStudents(page: page, perPage: _itemsPerPage),
        _dashboardService.getSummary(),
      ]);

      if (!mounted) return;

      final studentsPage = results[0] as AdminStudentsPage;
      final summary = results[1] as AdminDashboardSummary;

      setState(() {
        _currentPage = studentsPage.currentPage;
        _lastPage = studentsPage.lastPage == 0 ? 1 : studentsPage.lastPage;
        _totalStudents = studentsPage.total;
        _dashboardSummary = summary;
        _errorMessage = null;
        _students
          ..clear()
          ..addAll(studentsPage.students);
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
          _isPageLoading = false;
        });
      }
    }
  }

  Future<void> _openAdviserAssignment() async {
    await Navigator.pushNamed(context, AppRoutes.studentAdviserAssignment);

    if (mounted) {
      await _loadDashboard(page: _currentPage);
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

  List<AdminStudentSummary> get _filteredStudents {
    return _students.where(_matchesSelectedFilter).toList();
  }

  bool _matchesSelectedFilter(AdminStudentSummary student) {
    switch (_selectedFilter) {
      case _filterNeedsAttention:
        return !student.hasInternshipProfile ||
            !student.hasSupervisor ||
            !student.hasAdviser;
      case _filterMissingProfile:
        return !student.hasInternshipProfile;
      case _filterMissingSupervisor:
        return student.hasInternshipProfile && !student.hasSupervisor;
      case _filterMissingAdviser:
        return student.hasInternshipProfile && !student.hasAdviser;
      case _filterAll:
      default:
        return true;
    }
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

  Widget _buildHeader(AuthProvider authProvider) {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;
    final primaryTextColor = theme.colorScheme.onSurface;
    final secondaryTextColor =
        theme.textTheme.bodyMedium?.color ?? primaryTextColor;
    final dividerColor =
        theme.dividerTheme.color ?? theme.colorScheme.outlineVariant;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: dividerColor)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Run student setup, monitor approvals, and resolve internship gaps.',
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryTextColor.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const SettingsShortcutButton(),
          const SizedBox(width: 8),
          NotificationBellButton(token: authProvider.token ?? ''),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF0F4C5C),
            child: Text(
              _initialsFor(widget.userName),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(AdminDashboardSummary summary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF0F4C5C), Color(0xFF1B7A8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1E0F172A),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Operations Snapshot',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFCFEFF4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${summary.studentsRequiringAttention} students need admin attention',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${summary.pendingLogs} pending logs are still waiting in the review flow.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFE3F5F7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildHeroStatChip(
                label: 'Students',
                value: '${summary.totalStudents}',
              ),
              _buildHeroStatChip(
                label: 'Average Completion',
                value:
                    '${summary.averageCompletionPercentage.toStringAsFixed(0)}%',
              ),
              _buildHeroStatChip(
                label: 'Approved Logs',
                value: '${summary.approvedLogs}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatChip({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD6F1F4),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(AdminDashboardSummary summary) {
    final items = <_SummaryItem>[
      _SummaryItem(
        label: 'Pending Logs',
        value: '${summary.pendingLogs}',
        icon: Icons.pending_actions_rounded,
        color: const Color(0xFFB54708),
      ),
      _SummaryItem(
        label: 'Missing Profiles',
        value: '${summary.studentsWithoutProfile}',
        icon: Icons.description_outlined,
        color: const Color(0xFF9E4F15),
      ),
      _SummaryItem(
        label: 'No Supervisor',
        value: '${summary.studentsWithoutSupervisor}',
        icon: Icons.badge_outlined,
        color: const Color(0xFF175CD3),
      ),
      _SummaryItem(
        label: 'No Adviser',
        value: '${summary.studentsWithoutAdviser}',
        icon: Icons.school_outlined,
        color: const Color(0xFF7A5AF8),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;
        final itemWidth = isCompact
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (item) =>
                    SizedBox(width: itemWidth, child: _buildSummaryCard(item)),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildSummaryCard(_SummaryItem item) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.icon, color: item.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF102A56),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Paginated internship progress overview',
                  style: TextStyle(fontSize: 14, color: Color(0xFF667085)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPanel(AdminDashboardSummary summary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF102A56),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Use the dashboard to fix setup issues, not just monitor users.',
            style: TextStyle(fontSize: 14, color: Color(0xFF667085)),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF5FAFF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD6E4FF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.studentsWithoutAdviser > 0
                      ? '${summary.studentsWithoutAdviser} students still need an adviser.'
                      : 'All current internship profiles already have advisers assigned.',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF12305B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Open adviser management to assign, update, or remove advisers per student.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF4A6480)),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _openAdviserAssignment,
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: const Text('Manage Advisers'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedFilter = _filterNeedsAttention;
                        });
                      },
                      icon: const Icon(Icons.filter_alt_outlined),
                      label: const Text('Show Attention Queue'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = <_StudentFilter>[
      const _StudentFilter(key: _filterAll, label: 'All Students'),
      const _StudentFilter(
        key: _filterNeedsAttention,
        label: 'Needs Attention',
      ),
      const _StudentFilter(
        key: _filterMissingProfile,
        label: 'Missing Profile',
      ),
      const _StudentFilter(
        key: _filterMissingSupervisor,
        label: 'No Supervisor',
      ),
      const _StudentFilter(key: _filterMissingAdviser, label: 'No Adviser'),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: filters
          .map(
            (filter) => ChoiceChip(
              label: Text(filter.label),
              selected: _selectedFilter == filter.key,
              onSelected: (_) {
                setState(() {
                  _selectedFilter = filter.key;
                });
              },
              selectedColor: const Color(0xFFD8ECF0),
              labelStyle: TextStyle(
                color: _selectedFilter == filter.key
                    ? const Color(0xFF0F4C5C)
                    : const Color(0xFF475467),
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(
                  color: _selectedFilter == filter.key
                      ? const Color(0xFF0F4C5C)
                      : const Color(0xFFD0D5DD),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildStudentCard(AdminStudentSummary student) {
    final progress = (student.completionPercentage / 100).clamp(0.0, 1.0);
    final issues = <Widget>[
      if (!student.hasInternshipProfile)
        _buildStatusBadge(
          label: 'Missing internship profile',
          backgroundColor: const Color(0xFFFFF4E5),
          foregroundColor: const Color(0xFFB54708),
        ),
      if (student.hasInternshipProfile && !student.hasSupervisor)
        _buildStatusBadge(
          label: 'No supervisor assigned',
          backgroundColor: const Color(0xFFE8F1FF),
          foregroundColor: const Color(0xFF175CD3),
        ),
      if (student.hasInternshipProfile && !student.hasAdviser)
        _buildStatusBadge(
          label: 'No adviser assigned',
          backgroundColor: const Color(0xFFF1EBFF),
          foregroundColor: const Color(0xFF6941C6),
        ),
      if (student.hasInternshipProfile &&
          student.hasSupervisor &&
          student.hasAdviser)
        _buildStatusBadge(
          label: 'Setup complete',
          backgroundColor: const Color(0xFFE7F6EC),
          foregroundColor: const Color(0xFF067647),
        ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 16,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF102A56),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: issues),
                  ],
                ),
              ),
              if (student.hasInternshipProfile && !student.hasAdviser)
                TextButton.icon(
                  onPressed: _openAdviserAssignment,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Assign Adviser'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: const Color(0xFFDCE3EB),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF0F766E),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${student.completionPercentage.round()}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F4C5C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Company: ${student.company?.isNotEmpty == true ? student.company : 'Not assigned yet'}',
            style: const TextStyle(fontSize: 14, color: Color(0xFF475467)),
          ),
          const SizedBox(height: 8),
          Text(
            'Approved Hours: ${student.approvedHours} / ${student.requiredHours}',
            style: const TextStyle(fontSize: 14, color: Color(0xFF667085)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge({
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }

  List<int> _visiblePages(bool isCompact) {
    if (_lastPage <= 1) {
      return const <int>[1];
    }

    if (isCompact) {
      final pages = <int>{_currentPage};
      if (_currentPage > 1) {
        pages.add(_currentPage - 1);
      }
      if (_currentPage < _lastPage) {
        pages.add(_currentPage + 1);
      }
      final sorted = pages.toList()..sort();
      return sorted;
    }

    final start = (_currentPage - 2).clamp(1, _lastPage);
    final end = (_currentPage + 2).clamp(1, _lastPage);
    final pages = <int>[];
    for (var page = start; page <= end; page++) {
      pages.add(page);
    }
    return pages;
  }

  Widget _buildPageButton({
    required int page,
    required bool selected,
    required bool compact,
  }) {
    final size = compact ? 40.0 : 42.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: _isPageLoading ? null : () => _goToPage(page),
        borderRadius: BorderRadius.circular(size / 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1976D2) : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$page',
            style: TextStyle(
              fontSize: compact ? 16 : 18,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF344054),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArrowButton({
    required IconData icon,
    required VoidCallback? onPressed,
    bool compact = false,
  }) {
    return IconButton(
      tooltip: compact ? null : 'Pagination',
      onPressed: _isPageLoading ? null : onPressed,
      icon: Icon(
        icon,
        color: onPressed == null
            ? const Color(0xFF98A2B3)
            : const Color(0xFF101828),
      ),
    );
  }

  Widget _buildPaginationControls(BoxConstraints constraints) {
    if (_students.isEmpty && _totalStudents == 0) {
      return const SizedBox.shrink();
    }

    final isCompact = constraints.maxWidth < 600;
    final visiblePages = _visiblePages(isCompact);
    final startItem = _totalStudents == 0
        ? 0
        : ((_currentPage - 1) * _itemsPerPage) + 1;
    final endItem = (_currentPage * _itemsPerPage).clamp(0, _totalStudents);

    if (isCompact) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildArrowButton(
                icon: Icons.chevron_left_rounded,
                compact: true,
                onPressed: _currentPage > 1
                    ? () => _goToPage(_currentPage - 1)
                    : null,
              ),
              ...visiblePages.map(
                (page) => _buildPageButton(
                  page: page,
                  selected: page == _currentPage,
                  compact: true,
                ),
              ),
              _buildArrowButton(
                icon: Icons.chevron_right_rounded,
                compact: true,
                onPressed: _currentPage < _lastPage
                    ? () => _goToPage(_currentPage + 1)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$startItem-$endItem of $_totalStudents items',
            style: const TextStyle(fontSize: 14, color: Color(0xFF667085)),
          ),
        ],
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 10,
      children: [
        _buildArrowButton(
          icon: Icons.keyboard_double_arrow_left_rounded,
          onPressed: _currentPage > 1 ? () => _goToPage(1) : null,
        ),
        _buildArrowButton(
          icon: Icons.chevron_left_rounded,
          onPressed: _currentPage > 1
              ? () => _goToPage(_currentPage - 1)
              : null,
        ),
        ...visiblePages.map(
          (page) => _buildPageButton(
            page: page,
            selected: page == _currentPage,
            compact: false,
          ),
        ),
        _buildArrowButton(
          icon: Icons.chevron_right_rounded,
          onPressed: _currentPage < _lastPage
              ? () => _goToPage(_currentPage + 1)
              : null,
        ),
        _buildArrowButton(
          icon: Icons.keyboard_double_arrow_right_rounded,
          onPressed: _currentPage < _lastPage
              ? () => _goToPage(_lastPage)
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          '$startItem-$endItem of $_totalStudents items',
          style: const TextStyle(fontSize: 16, color: Color(0xFF667085)),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null &&
        _students.isEmpty &&
        _dashboardSummary == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                onPressed: _refreshDashboard,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final summary = _dashboardSummary;
    final filteredStudents = _filteredStudents;

    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
            children: [
              if (summary != null) _buildHeroCard(summary),
              if (summary != null) ...[
                const SizedBox(height: 22),
                _buildSummaryGrid(summary),
                const SizedBox(height: 22),
                _buildActionPanel(summary),
              ],
              const SizedBox(height: 22),
              const Text(
                'Student Operations',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF102A56),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Filter the current page to find missing setup and follow-up work quickly.',
                style: TextStyle(fontSize: 14, color: Color(0xFF667085)),
              ),
              const SizedBox(height: 18),
              _buildFilterChips(),
              const SizedBox(height: 18),
              if (filteredStudents.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Text(
                    'No students matched this filter on the current page.',
                    style: TextStyle(fontSize: 15, color: Color(0xFF667085)),
                  ),
                )
              else
                ...filteredStudents.map(_buildStudentCard),
              if (_errorMessage != null &&
                  (_students.isNotEmpty || _dashboardSummary != null))
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFB42318)),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _loadDashboard(page: _currentPage),
                          child: const Text('Try loading again'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_isPageLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 18),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_students.isNotEmpty || _totalStudents > 0) ...[
                const SizedBox(height: 12),
                _buildPaginationControls(constraints),
              ],
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
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(authProvider),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _StudentFilter {
  final String key;
  final String label;

  const _StudentFilter({required this.key, required this.label});
}
