import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../core/services/admin_student_service.dart';
import '../../../../shared/models/admin_student_summary.dart';
import '../../../../shared/models/adviser_info.dart';
import '../../../../shared/models/student_adviser_assignment.dart';
import '../providers/adviser_management_provider.dart';

class StudentAdviserAssignmentScreen extends StatefulWidget {
  const StudentAdviserAssignmentScreen({super.key});

  @override
  State<StudentAdviserAssignmentScreen> createState() =>
      _StudentAdviserAssignmentScreenState();
}

class _StudentAdviserAssignmentScreenState
    extends State<StudentAdviserAssignmentScreen> {
  static const int _itemsPerPage = 10;

  late final AdminStudentService _studentService;
  late final AdviserManagementProvider _adviserProvider;

  final Map<int, _AdviserDraft> _draftAdvisers = <int, _AdviserDraft>{};
  final List<AdminStudentSummary> _students = <AdminStudentSummary>[];

  bool _isLoadingStudents = true;
  bool _isPageLoading = false;
  bool _showOnlyUnassigned = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _lastPage = 1;
  int _totalStudents = 0;

  @override
  void initState() {
    super.initState();
    _studentService = context.read<AdminStudentService>();
    _adviserProvider = context.read<AdviserManagementProvider>();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _adviserProvider.loadAdvisers();
    await _loadStudents(page: 1);
  }

  Future<void> _loadStudents({required int page}) async {
    final isInitial = _students.isEmpty && !_isPageLoading;

    setState(() {
      _errorMessage = null;
      if (isInitial) {
        _isLoadingStudents = true;
      } else {
        _isPageLoading = true;
      }
    });

    try {
      final studentsPage = await _studentService.fetchStudents(
        page: page,
        perPage: _itemsPerPage,
      );

      if (!mounted) return;

      setState(() {
        _students
          ..clear()
          ..addAll(studentsPage.students);
        _currentPage = studentsPage.currentPage;
        _lastPage = studentsPage.lastPage == 0 ? 1 : studentsPage.lastPage;
        _totalStudents = studentsPage.total;
      });

      await Future.wait(
        studentsPage.students.map(
          (student) => _adviserProvider.loadStudentAdviser(student.studentId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStudents = false;
          _isPageLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _adviserProvider.loadAdvisers();
    await _loadStudents(page: _currentPage);
  }

  Future<void> _goToPage(int page) async {
    if (page < 1 ||
        page > _lastPage ||
        page == _currentPage ||
        _isPageLoading) {
      return;
    }

    await _loadStudents(page: page);
  }

  Future<void> _assignAdviser(int studentId, AdviserInfo? adviser) async {
    final success = await _adviserProvider.assignAdviser(
      studentId: studentId,
      adviserId: adviser?.id,
    );

    if (!mounted) return;

    if (success) {
      await _adviserProvider.loadStudentAdviser(studentId);
      if (!mounted) return;

      setState(() {
        _draftAdvisers.remove(studentId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            adviser == null
                ? 'Adviser removed successfully.'
                : 'Adviser assigned successfully.',
          ),
          backgroundColor: const Color(0xFF067647),
        ),
      );
      _adviserProvider.clearMessages();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _adviserProvider.errorMessage ??
              'Failed to update adviser assignment.',
        ),
        backgroundColor: const Color(0xFFB42318),
      ),
    );
    _adviserProvider.clearMessages();
  }

  List<AdminStudentSummary> get _visibleStudents {
    if (!_showOnlyUnassigned) {
      return _students;
    }

    return _students.where((student) {
      final assignment = _adviserProvider.getStudentAssignment(
        student.studentId,
      );
      return !student.hasAdviser || assignment?.adviserId == null;
    }).toList();
  }

  int get _studentsWithoutAdviserOnPage {
    return _students.where((student) {
      final assignment = _adviserProvider.getStudentAssignment(
        student.studentId,
      );
      return !student.hasAdviser || assignment?.adviserId == null;
    }).length;
  }

  String _studentStatusLabel(AdminStudentSummary student) {
    if (!student.hasInternshipProfile) return 'Missing internship profile';
    if (!student.hasSupervisor) return 'No supervisor assigned';
    if (!student.hasAdviser) return 'No adviser assigned';
    return 'Ready';
  }

  Color _studentStatusColor(AdminStudentSummary student) {
    if (!student.hasInternshipProfile) return const Color(0xFFB54708);
    if (!student.hasSupervisor) return const Color(0xFF175CD3);
    if (!student.hasAdviser) return const Color(0xFF7A5AF8);
    return const Color(0xFF067647);
  }

  Color _studentStatusBackground(AdminStudentSummary student) {
    if (!student.hasInternshipProfile) return const Color(0xFFFFF4E5);
    if (!student.hasSupervisor) return const Color(0xFFE8F1FF);
    if (!student.hasAdviser) return const Color(0xFFF1EBFF);
    return const Color(0xFFE7F6EC);
  }

  Widget _buildTopPanel(AdviserManagementProvider adviserProvider) {
    final theme = Theme.of(context);

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Adviser Management',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Assign advisers, follow setup gaps, and keep student support coverage complete.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFE3F5F7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.manage_accounts_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildHeroChip(
                label: 'Students on Page',
                value: '${_students.length}',
              ),
              _buildHeroChip(
                label: 'Need Adviser',
                value: '$_studentsWithoutAdviserOnPage',
              ),
              _buildHeroChip(
                label: 'Available Advisers',
                value: '${adviserProvider.advisers.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip({required String label, required String value}) {
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

  Widget _buildToolbar() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assignment Queue',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF102A56),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Work through the current page, then move forward using the page controls below.',
            style: TextStyle(fontSize: 14, color: Color(0xFF667085)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilterChip(
                label: const Text('All Students'),
                selected: !_showOnlyUnassigned,
                onSelected: (_) {
                  setState(() {
                    _showOnlyUnassigned = false;
                  });
                },
                selectedColor: const Color(0xFFD8ECF0),
                side: const BorderSide(color: Color(0xFFD0D5DD)),
              ),
              FilterChip(
                label: const Text('Needs Adviser'),
                selected: _showOnlyUnassigned,
                onSelected: (_) {
                  setState(() {
                    _showOnlyUnassigned = true;
                  });
                },
                selectedColor: const Color(0xFFEDE7FF),
                side: const BorderSide(color: Color(0xFFD0D5DD)),
              ),
              OutlinedButton.icon(
                onPressed: _isPageLoading ? null : _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ],
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
    return <int>[for (var page = start; page <= end; page++) page];
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
            '$startItem-$endItem of $_totalStudents students',
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
          '$startItem-$endItem of $_totalStudents students',
          style: const TextStyle(fontSize: 16, color: Color(0xFF667085)),
        ),
      ],
    );
  }

  Widget _buildBody(AdviserManagementProvider adviserProvider) {
    if (_isLoadingStudents) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _students.isEmpty) {
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
                onPressed: () => _loadStudents(page: 1),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final visibleStudents = _visibleStudents;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            _buildTopPanel(adviserProvider),
            const SizedBox(height: 20),
            _buildToolbar(),
            if (adviserProvider.errorMessage != null &&
                adviserProvider.advisers.isEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFDB022)),
                ),
                child: Text(
                  adviserProvider.errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFB54708),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (visibleStudents.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  'No students matched this filter on the current page.',
                  style: TextStyle(fontSize: 15, color: Color(0xFF667085)),
                ),
              )
            else
              ...visibleStudents.map(
                (student) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _StudentAdviserCard(
                    student: student,
                    currentAdviser: adviserProvider.getStudentAssignment(
                      student.studentId,
                    ),
                    selectedAdviser: _draftAdvisers[student.studentId]?.adviser,
                    hasDraftSelection: _draftAdvisers.containsKey(
                      student.studentId,
                    ),
                    availableAdvisers: adviserProvider.advisers,
                    isAssigning: adviserProvider.isAssigning,
                    statusLabel: _studentStatusLabel(student),
                    statusColor: _studentStatusColor(student),
                    statusBackground: _studentStatusBackground(student),
                    onAdviserChanged: (adviser) {
                      setState(() {
                        _draftAdvisers[student.studentId] = _AdviserDraft(
                          adviser: adviser,
                        );
                      });
                    },
                    onAssign: (adviser) =>
                        _assignAdviser(student.studentId, adviser),
                    onReset: () {
                      setState(() {
                        _draftAdvisers.remove(student.studentId);
                      });
                    },
                  ),
                ),
              ),
            if (_errorMessage != null && _students.isNotEmpty)
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
                        onPressed: () => _loadStudents(page: _currentPage),
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(title: const Text('Manage Student Advisers')),
      body: Consumer<AdviserManagementProvider>(
        builder: (context, adviserProvider, _) => _buildBody(adviserProvider),
      ),
    );
  }
}

class _StudentAdviserCard extends StatelessWidget {
  const _StudentAdviserCard({
    required this.student,
    required this.currentAdviser,
    required this.selectedAdviser,
    required this.hasDraftSelection,
    required this.availableAdvisers,
    required this.isAssigning,
    required this.statusLabel,
    required this.statusColor,
    required this.statusBackground,
    required this.onAdviserChanged,
    required this.onAssign,
    required this.onReset,
  });

  final AdminStudentSummary student;
  final StudentAdviserAssignment? currentAdviser;
  final AdviserInfo? selectedAdviser;
  final bool hasDraftSelection;
  final List<AdviserInfo> availableAdvisers;
  final bool isAssigning;
  final String statusLabel;
  final Color statusColor;
  final Color statusBackground;
  final ValueChanged<AdviserInfo?> onAdviserChanged;
  final ValueChanged<AdviserInfo?> onAssign;
  final VoidCallback onReset;

  AdviserInfo? get _effectiveSelection {
    if (hasDraftSelection) {
      return selectedAdviser;
    }

    final matchingIndex = availableAdvisers.indexWhere(
      (adviser) => adviser.id == currentAdviser?.adviserId,
    );

    if (matchingIndex >= 0) {
      return availableAdvisers[matchingIndex];
    }

    if (currentAdviser?.adviserId != null) {
      return AdviserInfo(
        id: currentAdviser!.adviserId,
        name: currentAdviser!.adviserName,
        email: null,
      );
    }

    return null;
  }

  bool get _hasPendingChanges =>
      _effectiveSelection?.id != currentAdviser?.adviserId;

  @override
  Widget build(BuildContext context) {
    final progress = (student.completionPercentage / 100).clamp(0.0, 1.0);
    final currentAdviserName = currentAdviser?.adviserName;
    final theme = Theme.of(context);

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
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoPill(
                          label: 'Student ID ${student.studentId}',
                          backgroundColor: const Color(0xFFF2F4F7),
                          foregroundColor: const Color(0xFF344054),
                        ),
                        _InfoPill(
                          label: statusLabel,
                          backgroundColor: statusBackground,
                          foregroundColor: statusColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 86,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${student.completionPercentage.round()}%',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F4C5C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: const Color(0xFFDCE3EB),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF0F766E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Company: ${student.company?.isNotEmpty == true ? student.company : 'Not assigned yet'}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475467),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Approved Hours: ${student.approvedHours} / ${student.requiredHours}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: currentAdviserName == null
                  ? const Color(0xFFFFF7ED)
                  : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: currentAdviserName == null
                    ? const Color(0xFFFDB022)
                    : const Color(0xFFABEFC6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentAdviserName == null
                      ? 'Current Status'
                      : 'Current Adviser',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  currentAdviserName ?? 'No adviser assigned',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: currentAdviserName == null
                        ? const Color(0xFFB54708)
                        : const Color(0xFF067647),
                  ),
                ),
                if (currentAdviser?.assignedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Assigned ${DateFormatter.formatDateOnly(currentAdviser!.assignedAt!)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF667085),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Assign Adviser',
            style: theme.textTheme.titleMedium?.copyWith(
              color: const Color(0xFF102A56),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<AdviserInfo?>(
            key: ValueKey<String>(
              '${student.studentId}-${_effectiveSelection?.id ?? 'none'}',
            ),
            initialValue: _effectiveSelection,
            hint: const Text('Select an adviser'),
            isExpanded: true,
            items: [
              const DropdownMenuItem<AdviserInfo?>(
                value: null,
                child: Text('None (Remove adviser)'),
              ),
              ...availableAdvisers.map(
                (adviser) => DropdownMenuItem<AdviserInfo?>(
                  value: adviser,
                  child: Text(
                    adviser.email?.isNotEmpty == true
                        ? '${adviser.name} • ${adviser.email}'
                        : adviser.name ?? 'Unknown adviser',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: isAssigning ? null : onAdviserChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF0F4C5C),
                  width: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 10,
            children: [
              if (_hasPendingChanges)
                TextButton(
                  onPressed: isAssigning ? null : onReset,
                  child: const Text('Reset'),
                ),
              if (_hasPendingChanges)
                ElevatedButton.icon(
                  onPressed: isAssigning
                      ? null
                      : () => onAssign(_effectiveSelection),
                  icon: isAssigning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    _effectiveSelection == null
                        ? 'Remove Adviser'
                        : 'Save Assignment',
                  ),
                )
              else if (currentAdviser?.adviserId != null)
                OutlinedButton.icon(
                  onPressed: isAssigning ? null : () => onAssign(null),
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('Remove Adviser'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB42318),
                    side: const BorderSide(color: Color(0xFFFDA29B)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
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
}

class _AdviserDraft {
  const _AdviserDraft({required this.adviser});

  final AdviserInfo? adviser;
}
