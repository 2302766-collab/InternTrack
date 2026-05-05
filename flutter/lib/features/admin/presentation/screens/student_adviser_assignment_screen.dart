import 'package:flutter/material.dart';
import 'package:intern_track_app/shared/models/student_adviser_assignment.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/admin_student_service.dart';
import '../../../../shared/models/admin_student_summary.dart';
import '../../../../shared/models/adviser_info.dart';
import '../providers/adviser_management_provider.dart';

class StudentAdviserAssignmentScreen extends StatefulWidget {
  const StudentAdviserAssignmentScreen({super.key});

  @override
  State<StudentAdviserAssignmentScreen> createState() =>
      _StudentAdviserAssignmentScreenState();
}

class _StudentAdviserAssignmentScreenState
    extends State<StudentAdviserAssignmentScreen> {
  late final AdminStudentService _studentService;
  late final AdviserManagementProvider _adviserProvider;

  late List<AdminStudentSummary> _students = [];
  bool _isLoadingStudents = true;
  String? _errorMessage;
  int _currentPage = 1;
  final Map<int, AdviserInfo?> _selectedAdvisers = {};

  @override
  void initState() {
    super.initState();
    _studentService = context.read<AdminStudentService>();
    _adviserProvider = context.read<AdviserManagementProvider>();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _adviserProvider.loadAdvisers();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoadingStudents = true;
      _errorMessage = null;
    });

    try {
      final page = await _studentService.fetchStudents(page: _currentPage);
      setState(() {
        _students = page.students;
        _isLoadingStudents = false;
      });

      // Load adviser for each student
      for (final student in _students) {
        await _adviserProvider.loadStudentAdviser(student.studentId);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load students: $e';
        _isLoadingStudents = false;
      });
    }
  }

  Future<void> _assignAdviser(
    int studentId,
    AdviserInfo? adviser,
  ) async {
    final success = await _adviserProvider.assignAdviser(
      studentId: studentId,
      adviserId: adviser?.id,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              adviser == null
                  ? 'Adviser removed successfully'
                  : 'Adviser assigned successfully',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        _adviserProvider.clearMessages();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_adviserProvider.errorMessage ?? 'Failed to assign adviser'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        _adviserProvider.clearMessages();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Student Advisers'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AdviserManagementProvider>(
        builder: (context, adviserProvider, _) {
          if (_isLoadingStudents) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (_errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage ?? 'An error occurred',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadStudents,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (_students.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No students found',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          if (adviserProvider.advisers.isEmpty && adviserProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadStudents,
            child: ListView.builder(
              itemCount: _students.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final student = _students[index];
                final assignment = adviserProvider.getStudentAssignment(student.studentId);
                final selectedAdviser = _selectedAdvisers[student.studentId] ??
                    (assignment != null && assignment.adviserId != null
                        ? adviserProvider.advisers
                            .firstWhere(
                              (a) => a.id == assignment.adviserId,
                              orElse: () => AdviserInfo(
                                id: assignment.adviserId!,
                                name: assignment.adviserName,
                                email: null,
                              ),
                            )
                        : null);

                return _StudentAdviserCard(
                  student: student,
                  currentAdviser: assignment,
                  selectedAdviser: selectedAdviser,
                  availableAdvisers: adviserProvider.advisers,
                  isAssigning: adviserProvider.isAssigning,
                  onAdviserChanged: (adviser) {
                    setState(() {
                      _selectedAdvisers[student.studentId] = adviser;
                    });
                  },
                  onAssign: () {
                    _assignAdviser(student.studentId, selectedAdviser);
                    setState(() {
                      _selectedAdvisers.remove(student.studentId);
                    });
                  },
                  onRemove: () {
                    _assignAdviser(student.studentId, null);
                    setState(() {
                      _selectedAdvisers.remove(student.studentId);
                    });
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _StudentAdviserCard extends StatelessWidget {
  final AdminStudentSummary student;
  final StudentAdviserAssignment? currentAdviser;
  final AdviserInfo? selectedAdviser;
  final List<AdviserInfo> availableAdvisers;
  final bool isAssigning;
  final ValueChanged<AdviserInfo?> onAdviserChanged;
  final VoidCallback onAssign;
  final VoidCallback onRemove;

  const _StudentAdviserCard({
    required this.student,
    required this.currentAdviser,
    required this.selectedAdviser,
    required this.availableAdvisers,
    required this.isAssigning,
    required this.onAdviserChanged,
    required this.onAssign,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasChanges = selectedAdviser?.id != currentAdviser?.adviserId;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student name and ID
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${student.studentId}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Divider
            Divider(height: 1, color: Colors.grey[300]),
            const SizedBox(height: 12),
            // Current adviser display
            if (currentAdviser?.adviserName != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Adviser:',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currentAdviser!.adviserName ?? 'Unknown',
                            style: Theme.of(context).textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status:',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, size: 16, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Text(
                          'No adviser assigned',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            // Adviser dropdown
            Text(
              hasChanges ? 'Change to:' : 'Assign adviser:',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<AdviserInfo?>(
              initialValue: selectedAdviser,
              hint: const Text('Select an adviser...'),
              isExpanded: true,
              items: [
                DropdownMenuItem<AdviserInfo?>(
                  value: null,
                  child: Text(
                    'None (Remove adviser)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                ...availableAdvisers.map(
                  (adviser) => DropdownMenuItem<AdviserInfo?>(
                    value: adviser,
                    child: Text(adviser.name ?? 'Unknown'),
                  ),
                ),
              ],
              onChanged: isAssigning ? null : onAdviserChanged,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 12),
            // Action buttons
            if (hasChanges)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isAssigning
                        ? null
                        : () {
                            onAdviserChanged(
                              currentAdviser?.adviserId != null
                                  ? availableAdvisers.firstWhere(
                                      (a) => a.id == currentAdviser!.adviserId,
                                      orElse: () => AdviserInfo(
                                        id: currentAdviser!.adviserId!,
                                        name: currentAdviser!.adviserName,
                                        email: null,
                                      ),
                                    )
                                  : null,
                            );
                          },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: isAssigning ? null : onAssign,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    child: isAssigning
                        ? SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          )
                        : const Text('Assign'),
                  ),
                ],
              )
            else if (currentAdviser?.adviserName != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isAssigning ? null : onRemove,
                  icon: const Icon(Icons.clear),
                  label: const Text('Remove Adviser'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[700],
                    side: BorderSide(color: Colors.red[300]!),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
