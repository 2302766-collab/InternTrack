import 'package:flutter/material.dart';

import 'package:intern_track_app/core/exceptions/api_exception.dart';
import 'package:intern_track_app/core/services/supervisor_management_service.dart';
import 'package:intern_track_app/shared/models/student_supervisor_assignment.dart';
import 'package:intern_track_app/shared/models/supervisor_option.dart';

class SupervisorManagementProvider extends ChangeNotifier {
  SupervisorManagementProvider({SupervisorManagementService? service})
    : _service = service ?? SupervisorManagementService();

  SupervisorManagementService _service;

  List<SupervisorOption> _supervisors = <SupervisorOption>[];
  final Map<int, StudentSupervisorAssignment> _studentAssignments =
      <int, StudentSupervisorAssignment>{};
  bool _isLoading = false;
  bool _isAssigning = false;
  String? _errorMessage;
  String? _successMessage;

  List<SupervisorOption> get supervisors => _supervisors;
  bool get isLoading => _isLoading;
  bool get isAssigning => _isAssigning;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  StudentSupervisorAssignment? getStudentAssignment(int studentId) =>
      _studentAssignments[studentId];

  void updateService(SupervisorManagementService service) {
    _service = service;
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  Future<void> loadSupervisors() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _supervisors = await _service.fetchSupervisors();
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _supervisors = [];
    } catch (e) {
      _errorMessage = 'Failed to load supervisors: $e';
      _supervisors = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<StudentSupervisorAssignment?> loadStudentSupervisor(
    int studentId,
  ) async {
    try {
      final assignment = await _service.getStudentSupervisor(studentId);
      _studentAssignments[studentId] = assignment;
      _errorMessage = null;
      notifyListeners();
      return assignment;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return null;
    } catch (e) {
      _errorMessage = 'Failed to load student supervisor: $e';
      return null;
    }
  }

  Future<bool> assignSupervisor({
    required int studentId,
    int? supervisorId,
  }) async {
    _isAssigning = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final assignment = await _service.assignSupervisor(
        studentId: studentId,
        supervisorId: supervisorId,
      );
      _studentAssignments[studentId] = assignment;
      _successMessage = supervisorId == null
          ? 'Supervisor assignment removed successfully.'
          : 'Supervisor assigned successfully.';
      _errorMessage = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _successMessage = null;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to assign supervisor: $e';
      _successMessage = null;
      notifyListeners();
      return false;
    } finally {
      _isAssigning = false;
      notifyListeners();
    }
  }
}
