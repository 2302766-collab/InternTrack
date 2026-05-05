import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/services/admin_student_service.dart';
import '../../../../shared/models/admin_student_summary.dart';
import '../../../../shared/widgets/notification_bell_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String userName;

  const AdminDashboardScreen({
    super.key,
    required this.userName,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final AdminStudentService _studentService;
  final ScrollController _scrollController = ScrollController();

  final List<AdminStudentSummary> _students = <AdminStudentSummary>[];

  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMorePages = true;
  String? _errorMessage;
  int _currentPage = 0;
  int _totalStudents = 0;

  @override
  void initState() {
    super.initState();
    _studentService = context.read<AdminStudentService>();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialLoading && _students.isEmpty) {
      _refreshStudents();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMorePages) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      _loadNextPage();
    }
  }

  Future<void> _refreshStudents() async {
    await _loadStudents(reset: true);
  }

  Future<void> _loadNextPage() async {
    await _loadStudents();
  }

  Future<void> _loadStudents({bool reset = false}) async {
    final token = context.read<AuthProvider>().token ?? '';
    if (token.isEmpty) {
      setState(() {
        _isInitialLoading = false;
        _isLoadingMore = false;
        _errorMessage = 'Missing authentication token. Please log in again.';
      });
      return;
    }

    if (reset) {
      setState(() {
        _isInitialLoading = true;
        _errorMessage = null;
      });
    } else {
      if (_isLoadingMore || !_hasMorePages) {
        return;
      }

      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final nextPage = reset ? 1 : _currentPage + 1;
      final page = await _studentService.fetchStudents(
        page: nextPage,
      );

      if (!mounted) return;

      final updatedStudents = reset
          ? page.students
          : <AdminStudentSummary>[
              ..._students,
              ...page.students,
            ];

      setState(() {
        _currentPage = page.currentPage;
        _hasMorePages = page.hasMorePages;
        _totalStudents = page.total;
        _errorMessage = null;
        _students
          ..clear()
          ..addAll(updatedStudents);
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
          _isLoadingMore = false;
        });
      }
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

  Widget _buildHeader(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE6E8EC)),
        ),
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
                const Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF102A56),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Monitor all students and internship progress at a glance.',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF4A6480).withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
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

  Widget _buildStatsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF0F4C5C),
            Color(0xFF1B7A8C),
          ],
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Students',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFCFEFF4),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$_totalStudents',
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Paginated internship progress overview',
                  style: TextStyle(
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
              Icons.groups_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(AdminStudentSummary student) {
    final progress = (student.completionPercentage / 100).clamp(0.0, 1.0);

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
          Text(
            student.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF102A56),
            ),
          ),
          const SizedBox(height: 14),
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
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475467),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Approved Hours: ${student.approvedHours} / ${student.requiredHours}',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
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
                onPressed: _refreshStudents,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshStudents,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
        children: [
          _buildStatsCard(),
          const SizedBox(height: 22),
          const Text(
            'Students',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF102A56),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Track progress across all active interns.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 18),
          if (_students.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Text(
                'No students found yet.',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF667085),
                ),
              ),
            )
          else
            ..._students.map(_buildStudentCard),
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
                      onPressed: _loadNextPage,
                      child: const Text('Try loading again'),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_hasMorePages)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Scroll to load more students',
                  style: TextStyle(color: Color(0xFF667085)),
                ),
              ),
            ),
        ],
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
