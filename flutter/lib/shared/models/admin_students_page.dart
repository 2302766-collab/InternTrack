import 'admin_student_summary.dart';

class AdminStudentsPage {
  final List<AdminStudentSummary> students;
  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;
  final bool hasMorePages;

  const AdminStudentsPage({
    required this.students,
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
    required this.hasMorePages,
  });
}
