import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/admin_student_service.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/models/admin_student_summary.dart';
import '../../../../shared/models/adviser_info.dart';
import '../../../../shared/models/student_adviser_assignment.dart';
import '../../../../shared/models/student_supervisor_assignment.dart';
import '../../../../shared/models/supervisor_option.dart';
import '../providers/adviser_management_provider.dart';
import '../providers/supervisor_management_provider.dart';

class StudentAssignmentManagementScreen extends StatefulWidget {
  const StudentAssignmentManagementScreen({super.key});

  @override
  State<StudentAssignmentManagementScreen> createState() =>
      _StudentAssignmentManagementScreenState();
}

class _StudentAssignmentManagementScreenState
    extends State<StudentAssignmentManagementScreen> {
  static const int _itemsPerPage = 10;

  late final AdminStudentService _studentService;
  late final AdviserManagementProvider _adviserProvider;
  late final SupervisorManagementProvider _supervisorProvider;

  final Map<int, AdviserInfo?> _draftAdvisers = <int, AdviserInfo?>{};
  final Map<int, SupervisorOption?> _draftSupervisors =
      <int, SupervisorOption?>{};
  final List<AdminStudentSummary> _students = <AdminStudentSummary>[];

  bool _isLoadingStudents = true;
  bool _isPageLoading = false;
  bool _showOnlyNeedsAssignment = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _lastPage = 1;
  int _totalStudents = 0;

  @override
  void initState() {
    super.initState();
    _studentService = context.read<AdminStudentService>();
    _adviserProvider = context.read<AdviserManagementProvider>();
    _supervisorProvider = context.read<SupervisorManagementProvider>();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait(<Future<void>>[
      _adviserProvider.loadAdvisers(),
      _supervisorProvider.loadSupervisors(),
    ]);
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
        studentsPage.students.expand(
          (student) => <Future<dynamic>>[
            _adviserProvider.loadStudentAdviser(student.studentId),
            _supervisorProvider.loadStudentSupervisor(student.studentId),
          ],
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
    await Future.wait(<Future<void>>[
      _adviserProvider.loadAdvisers(),
      _supervisorProvider.loadSupervisors(),
    ]);
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

  Future<void> _assignSupervisor(
    int studentId,
    SupervisorOption? supervisor,
  ) async {
    final success = await _supervisorProvider.assignSupervisor(
      studentId: studentId,
      supervisorId: supervisor?.id,
    );

    if (!mounted) return;

    if (success) {
      await _supervisorProvider.loadStudentSupervisor(studentId);
      if (!mounted) return;
      setState(() {
        _draftSupervisors.remove(studentId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            supervisor == null
                ? 'Supervisor removed successfully.'
                : 'Supervisor assigned successfully.',
          ),
          backgroundColor: const Color(0xFF067647),
        ),
      );
      _supervisorProvider.clearMessages();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _supervisorProvider.errorMessage ??
              'Failed to update supervisor assignment.',
        ),
        backgroundColor: const Color(0xFFB42318),
      ),
    );
    _supervisorProvider.clearMessages();
  }

  List<AdminStudentSummary> get _visibleStudents {
    if (!_showOnlyNeedsAssignment) {
      return _students;
    }

    return _students.where((student) {
      final adviser = _adviserProvider.getStudentAssignment(student.studentId);
      final supervisor = _supervisorProvider.getStudentAssignment(
        student.studentId,
      );
      return !student.hasAdviser ||
          adviser?.adviserId == null ||
          !student.hasSupervisor ||
          supervisor?.supervisorId == null;
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

  int get _studentsWithoutSupervisorOnPage {
    return _students.where((student) {
      final assignment = _supervisorProvider.getStudentAssignment(
        student.studentId,
      );
      return !student.hasSupervisor || assignment?.supervisorId == null;
    }).length;
  }

  String _studentStatusLabel(AdminStudentSummary student) {
    if (!student.hasInternshipProfile) {
      return 'Missing internship profile';
    }
    if (!student.hasSupervisor && !student.hasAdviser) {
      return 'Needs both assignments';
    }
    if (!student.hasSupervisor) {
      return 'No supervisor assigned';
    }
    if (!student.hasAdviser) {
      return 'No adviser assigned';
    }
    return 'Ready';
  }

  Color _studentStatusColor(AdminStudentSummary student) {
    if (!student.hasInternshipProfile) return const Color(0xFFB54708);
    if (!student.hasSupervisor && !student.hasAdviser) {
      return const Color(0xFFB42318);
    }
    if (!student.hasSupervisor) return const Color(0xFF175CD3);
    if (!student.hasAdviser) return const Color(0xFF7A5AF8);
    return const Color(0xFF067647);
  }

  Color _studentStatusBackground(AdminStudentSummary student) {
    if (!student.hasInternshipProfile) return const Color(0xFFFFF4E5);
    if (!student.hasSupervisor && !student.hasAdviser) {
      return const Color(0xFFFEE4E2);
    }
    if (!student.hasSupervisor) return const Color(0xFFE8F1FF);
    if (!student.hasAdviser) return const Color(0xFFF1EBFF);
    return const Color(0xFFE7F6EC);
  }

  Widget _buildTopPanel() {
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
          const Text(
            'Student Assignment Management',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Assign supervisors and advisers, close setup gaps, and keep student support coverage complete.',
            style: TextStyle(color: Color(0xFFE3F5F7), height: 1.45),
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
                label: 'Need Supervisor',
                value: '$_studentsWithoutSupervisorOnPage',
              ),
              _buildHeroChip(
                label: 'Need Adviser',
                value: '$_studentsWithoutAdviserOnPage',
              ),
              _buildHeroChip(
                label: 'Supervisors',
                value: '${_supervisorProvider.supervisors.length}',
              ),
              _buildHeroChip(
                label: 'Advisers',
                value: '${_adviserProvider.advisers.length}',
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
                selected: !_showOnlyNeedsAssignment,
                onSelected: (_) {
                  setState(() {
                    _showOnlyNeedsAssignment = false;
                  });
                },
                selectedColor: const Color(0xFFD8ECF0),
                side: const BorderSide(color: Color(0xFFD0D5DD)),
              ),
              FilterChip(
                label: const Text('Needs Assignment'),
                selected: _showOnlyNeedsAssignment,
                onSelected: (_) {
                  setState(() {
                    _showOnlyNeedsAssignment = true;
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
      if (_currentPage > 1) pages.add(_currentPage - 1);
      if (_currentPage < _lastPage) pages.add(_currentPage + 1);
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

  Widget _buildProviderError(
    String message,
    Color borderColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        message,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildBody() {
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
            _buildTopPanel(),
            const SizedBox(height: 20),
            _buildToolbar(),
            if (_supervisorProvider.errorMessage != null &&
                _supervisorProvider.supervisors.isEmpty) ...[
              const SizedBox(height: 16),
              _buildProviderError(
                _supervisorProvider.errorMessage!,
                const Color(0xFF84CAFF),
                const Color(0xFF175CD3),
              ),
            ],
            if (_adviserProvider.errorMessage != null &&
                _adviserProvider.advisers.isEmpty) ...[
              const SizedBox(height: 16),
              _buildProviderError(
                _adviserProvider.errorMessage!,
                const Color(0xFFFDB022),
                const Color(0xFFB54708),
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
                  child: _StudentAssignmentCard(
                    student: student,
                    currentAdviser: _adviserProvider.getStudentAssignment(
                      student.studentId,
                    ),
                    currentSupervisor: _supervisorProvider.getStudentAssignment(
                      student.studentId,
                    ),
                    selectedAdviser: _draftAdvisers[student.studentId],
                    selectedSupervisor: _draftSupervisors[student.studentId],
                    hasDraftAdviser: _draftAdvisers.containsKey(
                      student.studentId,
                    ),
                    hasDraftSupervisor: _draftSupervisors.containsKey(
                      student.studentId,
                    ),
                    availableAdvisers: _adviserProvider.advisers,
                    availableSupervisors: _supervisorProvider.supervisors,
                    isAssigningAdviser: _adviserProvider.isAssigning,
                    isAssigningSupervisor: _supervisorProvider.isAssigning,
                    statusLabel: _studentStatusLabel(student),
                    statusColor: _studentStatusColor(student),
                    statusBackground: _studentStatusBackground(student),
                    onAdviserChanged: (adviser) {
                      setState(() {
                        _draftAdvisers[student.studentId] = adviser;
                      });
                    },
                    onSupervisorChanged: (supervisor) {
                      setState(() {
                        _draftSupervisors[student.studentId] = supervisor;
                      });
                    },
                    onAssignAdviser: (adviser) =>
                        _assignAdviser(student.studentId, adviser),
                    onAssignSupervisor: (supervisor) =>
                        _assignSupervisor(student.studentId, supervisor),
                    onResetAdviser: () {
                      setState(() {
                        _draftAdvisers.remove(student.studentId);
                      });
                    },
                    onResetSupervisor: () {
                      setState(() {
                        _draftSupervisors.remove(student.studentId);
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
      appBar: AppBar(title: const Text('Manage Student Assignments')),
      body: Consumer2<AdviserManagementProvider, SupervisorManagementProvider>(
        builder: (context, adviserProvider, supervisorProvider, _) =>
            _buildBody(),
      ),
    );
  }
}

class _StudentAssignmentCard extends StatelessWidget {
  const _StudentAssignmentCard({
    required this.student,
    required this.currentAdviser,
    required this.currentSupervisor,
    required this.selectedAdviser,
    required this.selectedSupervisor,
    required this.hasDraftAdviser,
    required this.hasDraftSupervisor,
    required this.availableAdvisers,
    required this.availableSupervisors,
    required this.isAssigningAdviser,
    required this.isAssigningSupervisor,
    required this.statusLabel,
    required this.statusColor,
    required this.statusBackground,
    required this.onAdviserChanged,
    required this.onSupervisorChanged,
    required this.onAssignAdviser,
    required this.onAssignSupervisor,
    required this.onResetAdviser,
    required this.onResetSupervisor,
  });

  final AdminStudentSummary student;
  final StudentAdviserAssignment? currentAdviser;
  final StudentSupervisorAssignment? currentSupervisor;
  final AdviserInfo? selectedAdviser;
  final SupervisorOption? selectedSupervisor;
  final bool hasDraftAdviser;
  final bool hasDraftSupervisor;
  final List<AdviserInfo> availableAdvisers;
  final List<SupervisorOption> availableSupervisors;
  final bool isAssigningAdviser;
  final bool isAssigningSupervisor;
  final String statusLabel;
  final Color statusColor;
  final Color statusBackground;
  final ValueChanged<AdviserInfo?> onAdviserChanged;
  final ValueChanged<SupervisorOption?> onSupervisorChanged;
  final ValueChanged<AdviserInfo?> onAssignAdviser;
  final ValueChanged<SupervisorOption?> onAssignSupervisor;
  final VoidCallback onResetAdviser;
  final VoidCallback onResetSupervisor;

  AdviserInfo? get _effectiveAdviser {
    if (hasDraftAdviser) {
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

  SupervisorOption? get _effectiveSupervisor {
    if (hasDraftSupervisor) {
      return selectedSupervisor;
    }

    final matchingIndex = availableSupervisors.indexWhere(
      (supervisor) => supervisor.id == currentSupervisor?.supervisorId,
    );
    if (matchingIndex >= 0) {
      return availableSupervisors[matchingIndex];
    }

    if (currentSupervisor?.supervisorId != null) {
      return SupervisorOption(
        id: currentSupervisor!.supervisorId!,
        name: currentSupervisor!.supervisorName ?? 'Unknown supervisor',
        email: '',
      );
    }

    return null;
  }

  bool get _hasPendingAdviserChanges =>
      _effectiveAdviser?.id != currentAdviser?.adviserId;

  bool get _hasPendingSupervisorChanges =>
      _effectiveSupervisor?.id != currentSupervisor?.supervisorId;

  @override
  Widget build(BuildContext context) {
    final progress = (student.completionPercentage / 100).clamp(0.0, 1.0);
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
          const SizedBox(height: 18),
          _CurrentAssignmentBanner(
            title: 'Current Supervisor',
            value:
                currentSupervisor?.supervisorName ?? 'No supervisor assigned',
            assignedAt: currentSupervisor?.assignedAt,
            missingColor: const Color(0xFF175CD3),
            missingBackground: const Color(0xFFE8F1FF),
            readyColor: const Color(0xFF067647),
            readyBackground: const Color(0xFFF0FDF4),
          ),
          const SizedBox(height: 12),
          _CurrentAssignmentBanner(
            title: 'Current Adviser',
            value: currentAdviser?.adviserName ?? 'No adviser assigned',
            assignedAt: currentAdviser?.assignedAt,
            missingColor: const Color(0xFFB54708),
            missingBackground: const Color(0xFFFFF7ED),
            readyColor: const Color(0xFF067647),
            readyBackground: const Color(0xFFF0FDF4),
          ),
          const SizedBox(height: 18),
          _AssignmentSection(
            title: 'Assign Supervisor',
            isBusy: isAssigningSupervisor,
            hasPendingChanges: _hasPendingSupervisorChanges,
            onReset: onResetSupervisor,
            onSave: () => onAssignSupervisor(_effectiveSupervisor),
            onRemove: currentSupervisor?.supervisorId != null
                ? () => onAssignSupervisor(null)
                : null,
            saveLabel: _effectiveSupervisor == null
                ? 'Remove Supervisor'
                : 'Save Supervisor',
            removeLabel: 'Remove Supervisor',
            child: DropdownButtonFormField<SupervisorOption?>(
              key: ValueKey<String>(
                'supervisor-${student.studentId}-${_effectiveSupervisor?.id ?? 'none'}',
              ),
              initialValue: _effectiveSupervisor,
              hint: const Text('Select a supervisor'),
              isExpanded: true,
              items: [
                const DropdownMenuItem<SupervisorOption?>(
                  value: null,
                  child: Text('None (Remove supervisor)'),
                ),
                ...availableSupervisors.map(
                  (supervisor) => DropdownMenuItem<SupervisorOption?>(
                    value: supervisor,
                    child: Text(
                      supervisor.displayLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: isAssigningSupervisor ? null : onSupervisorChanged,
              decoration: _dropdownDecoration(),
            ),
          ),
          const SizedBox(height: 18),
          _AssignmentSection(
            title: 'Assign Adviser',
            isBusy: isAssigningAdviser,
            hasPendingChanges: _hasPendingAdviserChanges,
            onReset: onResetAdviser,
            onSave: () => onAssignAdviser(_effectiveAdviser),
            onRemove: currentAdviser?.adviserId != null
                ? () => onAssignAdviser(null)
                : null,
            saveLabel: _effectiveAdviser == null
                ? 'Remove Adviser'
                : 'Save Adviser',
            removeLabel: 'Remove Adviser',
            child: DropdownButtonFormField<AdviserInfo?>(
              key: ValueKey<String>(
                'adviser-${student.studentId}-${_effectiveAdviser?.id ?? 'none'}',
              ),
              initialValue: _effectiveAdviser,
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
              onChanged: isAssigningAdviser ? null : onAdviserChanged,
              decoration: _dropdownDecoration(),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        borderSide: const BorderSide(color: Color(0xFF0F4C5C), width: 1.4),
      ),
    );
  }
}

class _CurrentAssignmentBanner extends StatelessWidget {
  const _CurrentAssignmentBanner({
    required this.title,
    required this.value,
    required this.assignedAt,
    required this.missingColor,
    required this.missingBackground,
    required this.readyColor,
    required this.readyBackground,
  });

  final String title;
  final String value;
  final DateTime? assignedAt;
  final Color missingColor;
  final Color missingBackground;
  final Color readyColor;
  final Color readyBackground;

  @override
  Widget build(BuildContext context) {
    final missing = assignedAt == null && value.startsWith('No ');
    final foreground = missing ? missingColor : readyColor;
    final background = missing ? missingBackground : readyBackground;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: foreground.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
          if (assignedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Assigned ${DateFormatter.formatDateOnly(assignedAt!)}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF667085)),
            ),
          ],
        ],
      ),
    );
  }
}

class _AssignmentSection extends StatelessWidget {
  const _AssignmentSection({
    required this.title,
    required this.child,
    required this.isBusy,
    required this.hasPendingChanges,
    required this.onReset,
    required this.onSave,
    required this.onRemove,
    required this.saveLabel,
    required this.removeLabel,
  });

  final String title;
  final Widget child;
  final bool isBusy;
  final bool hasPendingChanges;
  final VoidCallback onReset;
  final VoidCallback onSave;
  final VoidCallback? onRemove;
  final String saveLabel;
  final String removeLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF102A56),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        child,
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 10,
          children: [
            if (hasPendingChanges)
              TextButton(
                onPressed: isBusy ? null : onReset,
                child: const Text('Reset'),
              ),
            if (hasPendingChanges)
              ElevatedButton.icon(
                onPressed: isBusy ? null : onSave,
                icon: isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(saveLabel),
              )
            else if (onRemove != null)
              OutlinedButton.icon(
                onPressed: isBusy ? null : onRemove,
                icon: const Icon(Icons.clear_rounded),
                label: Text(removeLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB42318),
                  side: const BorderSide(color: Color(0xFFFDA29B)),
                ),
              ),
          ],
        ),
      ],
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
