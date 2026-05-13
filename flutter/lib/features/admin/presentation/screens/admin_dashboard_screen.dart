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
  static const String _filterAll = 'all';
  static const String _filterNeedsAttention = 'needs_attention';
  static const String _filterMissingProfile = 'missing_profile';
  static const String _filterMissingSupervisor = 'missing_supervisor';
  static const String _filterMissingAdviser = 'missing_adviser';

  static const String _sortAttentionFirst = 'attention_first';
  static const String _sortCompletionHigh = 'completion_high';
  static const String _sortCompletionLow = 'completion_low';
  static const String _sortNameAsc = 'name_asc';
  static const String _sortNameDesc = 'name_desc';

  late final AdminStudentService _studentService;
  late final AdminDashboardService _dashboardService;
  late final TextEditingController _searchController;

  final List<AdminStudentSummary> _students = <AdminStudentSummary>[];

  bool _isInitialLoading = true;
  bool _isPageLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _lastPage = 1;
  int _totalStudents = 0;
  int _itemsPerPage = 10;
  String _selectedFilter = _filterAll;
  String _selectedSort = _sortAttentionFirst;
  String _searchQuery = '';
  AdminDashboardSummary? _dashboardSummary;

  @override
  void initState() {
    super.initState();
    _studentService = context.read<AdminStudentService>();
    _dashboardService = context.read<AdminDashboardService>();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    AdminStudentsPage? studentsPage;
    AdminDashboardSummary? summary;
    String? studentError;
    String? summaryError;

    try {
      await Future.wait<void>([
        Future<void>(() async {
          try {
            studentsPage = await _studentService.fetchStudents(
              page: page,
              perPage: _itemsPerPage,
            );
          } catch (e) {
            studentError = _readErrorMessage(e);
          }
        }),
        Future<void>(() async {
          try {
            summary = await _dashboardService.getSummary();
          } catch (e) {
            summaryError = _readErrorMessage(e);
          }
        }),
      ]);

      if (!mounted) return;

      setState(() {
        if (studentsPage != null) {
          _currentPage = studentsPage!.currentPage;
          _lastPage = studentsPage!.lastPage == 0 ? 1 : studentsPage!.lastPage;
          _totalStudents = studentsPage!.total;
          _itemsPerPage = studentsPage!.perPage == 0
              ? _itemsPerPage
              : studentsPage!.perPage;
          _students
            ..clear()
            ..addAll(studentsPage!.students);
        }

        if (summary != null) {
          _dashboardSummary = summary;
        }

        _errorMessage = _combineLoadErrors(
          studentError: studentError,
          summaryError: summaryError,
        );
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

  String _readErrorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  String? _combineLoadErrors({
    required String? studentError,
    required String? summaryError,
  }) {
    if (studentError == null && summaryError == null) {
      return null;
    }

    if (studentError != null && summaryError != null) {
      return 'Student list: $studentError\nDashboard summary: $summaryError';
    }

    return studentError ?? summaryError;
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

  void _setFilter(String filterKey) {
    setState(() {
      _selectedFilter = filterKey;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  List<AdminStudentSummary> get _visibleStudents {
    final query = _searchQuery.trim().toLowerCase();
    final filtered =
        _students.where((student) => _matchesSelectedFilter(student)).where((
          student,
        ) {
          if (query.isEmpty) {
            return true;
          }

          final company = student.company?.toLowerCase() ?? '';
          return student.name.toLowerCase().contains(query) ||
              company.contains(query);
        }).toList()..sort(_compareStudents);

    return filtered;
  }

  bool _matchesSelectedFilter(AdminStudentSummary student) {
    switch (_selectedFilter) {
      case _filterNeedsAttention:
        return _needsAttention(student);
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

  int _compareStudents(AdminStudentSummary left, AdminStudentSummary right) {
    switch (_selectedSort) {
      case _sortCompletionHigh:
        return _compareByCompletion(right, left);
      case _sortCompletionLow:
        return _compareByCompletion(left, right);
      case _sortNameAsc:
        return left.name.toLowerCase().compareTo(right.name.toLowerCase());
      case _sortNameDesc:
        return right.name.toLowerCase().compareTo(left.name.toLowerCase());
      case _sortAttentionFirst:
      default:
        final urgencyCompare = _studentUrgencyScore(
          right,
        ).compareTo(_studentUrgencyScore(left));
        if (urgencyCompare != 0) {
          return urgencyCompare;
        }

        final completionCompare = _compareByCompletion(left, right);
        if (completionCompare != 0) {
          return completionCompare;
        }

        return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    }
  }

  int _compareByCompletion(
    AdminStudentSummary left,
    AdminStudentSummary right,
  ) {
    final completionCompare = left.completionPercentage.compareTo(
      right.completionPercentage,
    );
    if (completionCompare != 0) {
      return completionCompare;
    }

    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  }

  bool _needsAttention(AdminStudentSummary student) {
    return !student.hasInternshipProfile ||
        !student.hasSupervisor ||
        !student.hasAdviser;
  }

  int _studentUrgencyScore(AdminStudentSummary student) {
    var score = 0;

    if (!student.hasInternshipProfile) {
      score += 4;
    }
    if (!student.hasSupervisor) {
      score += 2;
    }
    if (!student.hasAdviser) {
      score += 2;
    }
    if (student.completionPercentage < 25) {
      score += 1;
    }

    return score;
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

  String _filterLabel(String filterKey) {
    switch (filterKey) {
      case _filterNeedsAttention:
        return 'Needs Attention';
      case _filterMissingProfile:
        return 'Missing Profile';
      case _filterMissingSupervisor:
        return 'No Supervisor';
      case _filterMissingAdviser:
        return 'No Adviser';
      case _filterAll:
      default:
        return 'All Students';
    }
  }

  String _sortLabel(String sortKey) {
    switch (sortKey) {
      case _sortCompletionHigh:
        return 'Completion High to Low';
      case _sortCompletionLow:
        return 'Completion Low to High';
      case _sortNameAsc:
        return 'Name A to Z';
      case _sortNameDesc:
        return 'Name Z to A';
      case _sortAttentionFirst:
      default:
        return 'Needs Attention First';
    }
  }

  String _studentStatusLine(AdminStudentSummary student) {
    if (!student.hasInternshipProfile) {
      return 'Missing internship profile';
    }
    if (!student.hasSupervisor && !student.hasAdviser) {
      return 'Needs supervisor and adviser assignment';
    }
    if (!student.hasSupervisor) {
      return 'Needs supervisor assignment';
    }
    if (!student.hasAdviser) {
      return 'Needs adviser assignment';
    }

    return 'Setup complete';
  }

  String _actionHeadline(AdminDashboardSummary summary) {
    if (summary.studentsWithoutAdviser > 0) {
      return '${summary.studentsWithoutAdviser} students still need adviser assignments.';
    }
    if (summary.studentsWithoutSupervisor > 0) {
      return '${summary.studentsWithoutSupervisor} students still need supervisors assigned.';
    }
    if (summary.studentsWithoutProfile > 0) {
      return '${summary.studentsWithoutProfile} students still need internship profiles.';
    }

    return 'All current internship profiles already have advisers and supervisors assigned.';
  }

  Widget _buildHeader(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFD9E3EE))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDEEF1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Admin Web Console',
                    style: TextStyle(
                      color: Color(0xFF0F4C5C),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D2250),
                    height: 1,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Run student setup, monitor approvals, and resolve internship gaps.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF4E6483),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Row(
            children: [
              const SettingsShortcutButton(),
              const SizedBox(width: 10),
              NotificationBellButton(token: authProvider.token ?? ''),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF0F4C5C),
                child: Text(
                  _initialsFor(widget.userName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(AdminDashboardSummary summary) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF0E586A), Color(0xFF1B8EA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Operations Snapshot',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD5F0F5),
                  ),
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: const Icon(
                  Icons.space_dashboard_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${summary.studentsRequiringAttention} students need admin attention',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${summary.pendingLogs} pending logs are still waiting in the review flow.',
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFFE8F7F9),
              height: 1.5,
            ),
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
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => _setFilter(_filterNeedsAttention),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F4C5C),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                icon: const Icon(Icons.priority_high_rounded),
                label: const Text('Review Students'),
              ),
              OutlinedButton.icon(
                onPressed: _openAdviserAssignment,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('Manage Advisers'),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD5F0F5),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  List<_SummaryItem> _summaryItems(AdminDashboardSummary summary) {
    return <_SummaryItem>[
      _SummaryItem(
        label: 'Needs Attention',
        value: '${summary.studentsRequiringAttention}',
        icon: Icons.crisis_alert_outlined,
        color: const Color(0xFFD92D20),
        subtitle: 'Show highest-risk students first',
        filterKey: _filterNeedsAttention,
      ),
      _SummaryItem(
        label: 'Pending Logs',
        value: '${summary.pendingLogs}',
        icon: Icons.pending_actions_outlined,
        color: const Color(0xFFB54708),
        subtitle: 'Review queue still waiting',
        filterKey: _filterNeedsAttention,
      ),
      _SummaryItem(
        label: 'Missing Profiles',
        value: '${summary.studentsWithoutProfile}',
        icon: Icons.description_outlined,
        color: const Color(0xFF9E4F15),
        subtitle: 'Incomplete setup blocks progress',
        filterKey: _filterMissingProfile,
      ),
      _SummaryItem(
        label: 'No Supervisor',
        value: '${summary.studentsWithoutSupervisor}',
        icon: Icons.badge_outlined,
        color: const Color(0xFF175CD3),
        subtitle: 'Students still need reviewer coverage',
        filterKey: _filterMissingSupervisor,
      ),
      _SummaryItem(
        label: 'No Adviser',
        value: '${summary.studentsWithoutAdviser}',
        icon: Icons.school_outlined,
        color: const Color(0xFF7A5AF8),
        subtitle: 'Open adviser management quickly',
        filterKey: _filterMissingAdviser,
      ),
    ];
  }

  // ignore: unused_element
  Widget _buildSummaryGrid(AdminDashboardSummary summary) {
    final items = _summaryItems(summary);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 540) {
          return Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _buildSummaryCard(items[index], width: double.infinity),
                if (index != items.length - 1) const SizedBox(height: 14),
              ],
            ],
          );
        }

        final rows = <List<_SummaryItem>>[];
        for (var index = 0; index < items.length; index += 2) {
          rows.add(items.skip(index).take(2).toList());
        }

        final columnWidth = (constraints.maxWidth - 14) / 2;

        return Column(
          children: [
            for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
              if (rows[rowIndex].length == 1)
                _buildSummaryCard(rows[rowIndex].first, width: double.infinity)
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSummaryCard(rows[rowIndex][0], width: columnWidth),
                    const SizedBox(width: 14),
                    _buildSummaryCard(rows[rowIndex][1], width: columnWidth),
                  ],
                ),
              if (rowIndex != rows.length - 1) const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(_SummaryItem item, {required double width}) {
    final selected = item.filterKey == _selectedFilter;

    return InkWell(
      onTap: () => _setFilter(item.filterKey),
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        constraints: const BoxConstraints(minHeight: 192),
        duration: const Duration(milliseconds: 180),
        width: width,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0F7F9) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? const Color(0xFF0F4C5C) : const Color(0xFFE4EBF4),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F0F172A),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                const Spacer(),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF0F4C5C),
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              item.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF49617D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0D2250),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                item.subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF66798F),
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildActionPanel(AdminDashboardSummary summary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE3EAF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Actions',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D2250),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use the dashboard to fix setup issues, not just monitor users.',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF5F738B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFFF5FAFF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFD4E2FF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _actionHeadline(summary),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF12305B),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Use adviser management for assignments, then jump back here to review students with setup issues first.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4C6682),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: _openAdviserAssignment,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F4C5C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                      ),
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: const Text('Manage Advisers'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _setFilter(_filterNeedsAttention),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0B3D5C),
                        side: const BorderSide(color: Color(0xFFC8D7EA)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                      ),
                      icon: const Icon(Icons.filter_alt_outlined),
                      label: const Text('Show Attention Queue'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _refreshDashboard,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0B3D5C),
                        side: const BorderSide(color: Color(0xFFC8D7EA)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh Data'),
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

  // ignore: unused_element
  Widget _buildOperationsPanel(List<AdminStudentSummary> visibleStudents) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE3EAF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const SizedBox(
                width: 460,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Operations',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D2250),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Search, sort, and filter the current page so the attention queue rises to the top faster.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF5F738B),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F6FB),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFD8E4F0)),
                ),
                child: Text(
                  '${visibleStudents.length} visible on page $_currentPage',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF35516E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildControlRow(),
          const SizedBox(height: 18),
          _buildFilterChips(),
          const SizedBox(height: 14),
          Text(
            'Active filter: ${_filterLabel(_selectedFilter)}${_searchQuery.trim().isEmpty ? '' : ' | Search: "${_searchQuery.trim()}"'} | Sort: ${_sortLabel(_selectedSort)}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF66798F)),
          ),
        ],
      ),
    );
  }

  Widget _buildControlRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;

        final searchField = TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.close_rounded),
                  ),
            hintText: 'Search current page by student or company',
            filled: true,
            fillColor: const Color(0xFFF8FBFD),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFD5E0EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFD5E0EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Color(0xFF0F4C5C),
                width: 1.4,
              ),
            ),
          ),
        );

        final sortField = _buildLabeledField(
          label: 'Sort students',
          width: 240,
          child: DropdownButtonFormField<String>(
            initialValue: _selectedSort,
            isExpanded: true,
            decoration: _buildDropdownDecoration(),
            items: const [
              DropdownMenuItem(
                value: _sortAttentionFirst,
                child: Text(
                  'Needs Attention First',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: _sortCompletionHigh,
                child: Text(
                  'Completion High to Low',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: _sortCompletionLow,
                child: Text(
                  'Completion Low to High',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(value: _sortNameAsc, child: Text('Name A to Z')),
              DropdownMenuItem(
                value: _sortNameDesc,
                child: Text('Name Z to A'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedSort = value;
              });
            },
          ),
        );

        final rowsField = _buildLabeledField(
          label: 'Rows',
          width: 150,
          child: DropdownButtonFormField<int>(
            initialValue: _itemsPerPage,
            isExpanded: true,
            decoration: _buildDropdownDecoration(),
            items: const [
              DropdownMenuItem(value: 10, child: Text('10 rows')),
              DropdownMenuItem(value: 20, child: Text('20 rows')),
              DropdownMenuItem(value: 40, child: Text('40 rows')),
            ],
            onChanged: (value) async {
              if (value == null || value == _itemsPerPage) {
                return;
              }

              setState(() {
                _itemsPerPage = value;
              });
              await _loadDashboard(page: 1);
            },
          ),
        );

        final resetButton = OutlinedButton.icon(
          onPressed: () {
            _clearSearch();
            setState(() {
              _selectedFilter = _filterAll;
              _selectedSort = _sortAttentionFirst;
            });
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0B3D5C),
            side: const BorderSide(color: Color(0xFFD0DCE8)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
          icon: const Icon(Icons.layers_clear_outlined),
          label: const Text('Reset View'),
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 14),
              sortField,
              const SizedBox(width: 14),
              rowsField,
              const SizedBox(width: 14),
              resetButton,
            ],
          );
        }

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(width: 360, child: searchField),
            sortField,
            rowsField,
            resetButton,
          ],
        );
      },
    );
  }

  Widget _buildLabeledField({
    required String label,
    required double width,
    required Widget child,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4E6483),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  InputDecoration _buildDropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8FBFD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD5E0EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD5E0EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF0F4C5C), width: 1.4),
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
            (filter) => FilterChip(
              label: Text(filter.label),
              selected: _selectedFilter == filter.key,
              onSelected: (_) => _setFilter(filter.key),
              selectedColor: const Color(0xFFD9EEF2),
              checkmarkColor: const Color(0xFF0F4C5C),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: _selectedFilter == filter.key
                    ? const Color(0xFF0F4C5C)
                    : const Color(0xFFD0D7E2),
              ),
              labelStyle: TextStyle(
                color: _selectedFilter == filter.key
                    ? const Color(0xFF0F4C5C)
                    : const Color(0xFF334E68),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          )
          .toList(),
    );
  }

  // ignore: unused_element
  Widget _buildStudentsWorkspace(
    List<AdminStudentSummary> visibleStudents,
    BoxConstraints constraints,
  ) {
    if (visibleStudents.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE3EAF3)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No students matched this view.',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0D2250),
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Try clearing the search field, changing the filter, or loading a different page size.',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF66798F),
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    final isWideTable = constraints.maxWidth >= 1080;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE3EAF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          if (isWideTable) _buildStudentTableHeader(),
          ...visibleStudents.asMap().entries.map((entry) {
            final index = entry.key;
            final student = entry.value;

            return Column(
              children: [
                if (isWideTable)
                  _buildStudentTableRow(student)
                else
                  _buildStudentCompactCard(student),
                if (index != visibleStudents.length - 1)
                  const Divider(height: 1, color: Color(0xFFE6EDF5)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStudentTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Expanded(flex: 4, child: Text('Student', style: _headerTextStyle)),
          Expanded(flex: 3, child: Text('Progress', style: _headerTextStyle)),
          Expanded(
            flex: 2,
            child: Text('Approved Hours', style: _headerTextStyle),
          ),
          Expanded(
            flex: 3,
            child: Text('Company / Issues', style: _headerTextStyle),
          ),
          SizedBox(width: 170, child: Text('Action', style: _headerTextStyle)),
        ],
      ),
    );
  }

  Widget _buildStudentTableRow(AdminStudentSummary student) {
    final progress = (student.completionPercentage / 100).clamp(0.0, 1.0);
    final needsAttention = _needsAttention(student);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: needsAttention ? const Color(0xFFFFFBF8) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D2250),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buildStudentIssueBadges(student),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 12,
                          backgroundColor: const Color(0xFFD9E2EC),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            needsAttention
                                ? const Color(0xFFB54708)
                                : const Color(0xFF147D74),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${student.completionPercentage.round()}%',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0B3D5C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _studentStatusLine(student),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: needsAttention
                        ? const Color(0xFFB54708)
                        : const Color(0xFF147D74),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${student.approvedHours} / ${student.requiredHours}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF223A5E),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.company?.isNotEmpty == true
                      ? student.company!
                      : 'Not assigned yet',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF334E68),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _studentIssueSummary(student),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF66798F),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 170,
            child: Align(
              alignment: Alignment.topLeft,
              child: _buildStudentAction(student),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCompactCard(AdminStudentSummary student) {
    final progress = (student.completionPercentage / 100).clamp(0.0, 1.0);
    final needsAttention = _needsAttention(student);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 420,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D2250),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _buildStudentIssueBadges(student),
                    ),
                  ],
                ),
              ),
              _buildStudentAction(student),
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
                    minHeight: 14,
                    backgroundColor: const Color(0xFFD9E2EC),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      needsAttention
                          ? const Color(0xFFB54708)
                          : const Color(0xFF147D74),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${student.completionPercentage.round()}%',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0B3D5C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 22,
            runSpacing: 8,
            children: [
              Text(
                'Approved Hours: ${student.approvedHours} / ${student.requiredHours}',
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF334E68),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Company: ${student.company?.isNotEmpty == true ? student.company! : 'Not assigned yet'}',
                style: const TextStyle(fontSize: 15, color: Color(0xFF5F738B)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _studentIssueSummary(student),
            style: const TextStyle(fontSize: 14, color: Color(0xFF66798F)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStudentIssueBadges(AdminStudentSummary student) {
    if (!student.hasInternshipProfile) {
      return [
        _buildStatusBadge(
          label: 'Missing Profile',
          backgroundColor: const Color(0xFFFFF1E8),
          foregroundColor: const Color(0xFFB54708),
        ),
      ];
    }

    final badges = <Widget>[];

    if (!student.hasSupervisor) {
      badges.add(
        _buildStatusBadge(
          label: 'No Supervisor',
          backgroundColor: const Color(0xFFE8F1FF),
          foregroundColor: const Color(0xFF175CD3),
        ),
      );
    }
    if (!student.hasAdviser) {
      badges.add(
        _buildStatusBadge(
          label: 'No Adviser',
          backgroundColor: const Color(0xFFF1EBFF),
          foregroundColor: const Color(0xFF6941C6),
        ),
      );
    }
    if (badges.isEmpty) {
      badges.add(
        _buildStatusBadge(
          label: 'Setup Complete',
          backgroundColor: const Color(0xFFE7F6EC),
          foregroundColor: const Color(0xFF067647),
        ),
      );
    }

    return badges;
  }

  String _studentIssueSummary(AdminStudentSummary student) {
    if (!student.hasInternshipProfile) {
      return 'Student has not completed the internship profile yet.';
    }
    if (!student.hasSupervisor && !student.hasAdviser) {
      return 'Student still needs both a supervisor and an adviser.';
    }
    if (!student.hasSupervisor) {
      return 'Student still needs a supervisor assigned.';
    }
    if (!student.hasAdviser) {
      return 'Student still needs an adviser assigned.';
    }

    return 'Student is ready for regular monitoring and progress follow-up.';
  }

  Widget _buildStudentAction(AdminStudentSummary student) {
    if (!student.hasAdviser) {
      return FilledButton.icon(
        onPressed: _openAdviserAssignment,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0F4C5C),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        icon: const Icon(Icons.manage_accounts_outlined, size: 18),
        label: const Text('Assign Adviser'),
      );
    }

    if (!student.hasInternshipProfile) {
      return OutlinedButton.icon(
        onPressed: () => _setFilter(_filterMissingProfile),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF9E4F15),
          side: const BorderSide(color: Color(0xFFFFD7BA)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        icon: const Icon(Icons.warning_amber_rounded, size: 18),
        label: const Text('Needs Profile'),
      );
    }

    if (!student.hasSupervisor) {
      return OutlinedButton.icon(
        onPressed: () => _setFilter(_filterMissingSupervisor),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF175CD3),
          side: const BorderSide(color: Color(0xFFC9DDFF)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        icon: const Icon(Icons.person_search_rounded, size: 18),
        label: const Text('Review Setup'),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Healthy',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Color(0xFF067647),
        ),
      ),
    );
  }

  Widget _buildStatusBadge({
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: foregroundColor,
        ),
      ),
    );
  }

  List<int> _visiblePages(bool isCompact) {
    if (_lastPage <= 1) {
      return const <int>[1];
    }

    final radius = isCompact ? 1 : 2;
    final start = (_currentPage - radius).clamp(1, _lastPage);
    final end = (_currentPage + radius).clamp(1, _lastPage);
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
    final size = compact ? 42.0 : 50.0;

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
              fontSize: compact ? 17 : 19,
              fontWeight: FontWeight.w800,
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
  }) {
    return IconButton(
      tooltip: 'Pagination',
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

    final isCompact = constraints.maxWidth < 900;
    final visiblePages = _visiblePages(isCompact);
    final startItem = _totalStudents == 0
        ? 0
        : ((_currentPage - 1) * _itemsPerPage) + 1;
    final endItem = (_currentPage * _itemsPerPage).clamp(0, _totalStudents);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE3EAF3)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '$startItem-$endItem of $_totalStudents students',
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF66798F),
              fontWeight: FontWeight.w700,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
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
                  compact: isCompact,
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
            ],
          ),
        ],
      ),
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
    final visibleStudents = _visibleStudents;

    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
            children: [
              if (summary != null)
                _buildHeroCard(summary)
              else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE3EAF3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Admin summary is not available yet.',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF102A56),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage ??
                            'You can still review the current student page below.',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF667085),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: _refreshDashboard,
                        child: const Text('Retry Dashboard'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              if (summary != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE3EAF3)),
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildQuickMetric(
                        'Students',
                        '${summary.totalStudents}',
                        const Color(0xFF0F4C5C),
                      ),
                      _buildQuickMetric(
                        'Pending Logs',
                        '${summary.pendingLogs}',
                        const Color(0xFFB54708),
                      ),
                      _buildQuickMetric(
                        'No Adviser',
                        '${summary.studentsWithoutAdviser}',
                        const Color(0xFF6941C6),
                      ),
                      _buildQuickMetric(
                        'No Supervisor',
                        '${summary.studentsWithoutSupervisor}',
                        const Color(0xFF175CD3),
                      ),
                    ],
                  ),
                ),
              if (summary != null) const SizedBox(height: 22),
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
              if (_errorMessage != null &&
                  (_students.isNotEmpty || _dashboardSummary != null))
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4F4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFBCACA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _errorMessage!,
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
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('All Students'),
                    selected: _selectedFilter == _filterAll,
                    onSelected: (_) => _setFilter(_filterAll),
                  ),
                  ChoiceChip(
                    label: const Text('Needs Attention'),
                    selected: _selectedFilter == _filterNeedsAttention,
                    onSelected: (_) => _setFilter(_filterNeedsAttention),
                  ),
                  ChoiceChip(
                    label: const Text('Missing Profile'),
                    selected: _selectedFilter == _filterMissingProfile,
                    onSelected: (_) => _setFilter(_filterMissingProfile),
                  ),
                  ChoiceChip(
                    label: const Text('No Supervisor'),
                    selected: _selectedFilter == _filterMissingSupervisor,
                    onSelected: (_) => _setFilter(_filterMissingSupervisor),
                  ),
                  ChoiceChip(
                    label: const Text('No Adviser'),
                    selected: _selectedFilter == _filterMissingAdviser,
                    onSelected: (_) => _setFilter(_filterMissingAdviser),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (_isPageLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 18),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (visibleStudents.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Text(
                    'No students matched this filter on the current page.',
                    style: TextStyle(fontSize: 15, color: Color(0xFF667085)),
                  ),
                )
              else
                ...visibleStudents.map(_buildBasicStudentCard),
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

  Widget _buildQuickMetric(String label, String value, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EAF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicStudentCard(AdminStudentSummary student) {
    final needsAttention = _needsAttention(student);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: needsAttention
              ? const Color(0xFFFFD7BA)
              : const Color(0xFFE3EAF3),
        ),
      ),
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
          const SizedBox(height: 8),
          Text(
            _studentIssueSummary(student),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF667085),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Company: ${student.company?.isNotEmpty == true ? student.company! : 'Not assigned yet'}',
            style: const TextStyle(fontSize: 14, color: Color(0xFF475467)),
          ),
          const SizedBox(height: 6),
          Text(
            'Approved Hours: ${student.approvedHours} / ${student.requiredHours}',
            style: const TextStyle(fontSize: 14, color: Color(0xFF475467)),
          ),
          const SizedBox(height: 6),
          Text(
            'Completion: ${student.completionPercentage.round()}%',
            style: const TextStyle(fontSize: 14, color: Color(0xFF475467)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FB),
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
  final String subtitle;
  final String filterKey;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
    required this.filterKey,
  });
}

class _StudentFilter {
  final String key;
  final String label;

  const _StudentFilter({required this.key, required this.label});
}

const TextStyle _headerTextStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w800,
  letterSpacing: 0.3,
  color: Color(0xFF66798F),
);
