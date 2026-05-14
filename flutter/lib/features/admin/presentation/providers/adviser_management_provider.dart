import 'package:flutter/material.dart';

import 'package:intern_track_app/core/exceptions/api_exception.dart';
import 'package:intern_track_app/core/services/adviser_management_service.dart';
import 'package:intern_track_app/shared/models/adviser_info.dart';
import 'package:intern_track_app/shared/models/student_adviser_assignment.dart';

class AdviserManagementProvider extends ChangeNotifier {
  AdviserManagementProvider({AdviserManagementService? service})
      : _service = service ?? AdviserManagementService();

  final AdviserManagementService _service;

  // State
  List<AdviserInfo> _advisers = [];
  final Map<int, StudentAdviserAssignment> _studentAssignments = {};
  bool _isLoading = false;
  bool _isAssigning = false;
  String? _errorMessage;
  String? _successMessage;

  // Getters
  List<AdviserInfo> get advisers => _advisers;
  bool get isLoading => _isLoading;
  bool get isAssigning => _isAssigning;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  StudentAdviserAssignment? getStudentAssignment(int studentId) =>
      _studentAssignments[studentId];

  /// Clear error and success messages
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Fetch all available advisers
  Future<void> loadAdvisers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _advisers = await _service.fetchAdvisers();
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _advisers = [];
    } catch (e) {
      _errorMessage = 'Failed to load advisers: $e';
      _advisers = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get current adviser for a specific student
  Future<StudentAdviserAssignment?> loadStudentAdviser(int studentId) async {
    try {
      final assignment = await _service.getStudentAdviser(studentId);
      _studentAssignments[studentId] = assignment;
      _errorMessage = null;
      notifyListeners();
      return assignment;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return null;
    } catch (e) {
      _errorMessage = 'Failed to load student adviser: $e';
      return null;
    }
  }

  /// Assign or update adviser for a student
  Future<bool> assignAdviser({
    required int studentId,
    int? adviserId,
  }) async {
    _isAssigning = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final assignment = await _service.assignAdviser(
        studentId: studentId,
        adviserId: adviserId,
      );
      _studentAssignments[studentId] = assignment;
      _successMessage = adviserId == null
          ? 'Adviser assignment removed successfully.'
          : 'Adviser assigned successfully.';
      _errorMessage = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _successMessage = null;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to assign adviser: $e';
      _successMessage = null;
      notifyListeners();
      return false;
    } finally {
      _isAssigning = false;
      notifyListeners();
    }
  }
}
