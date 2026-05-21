import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/exceptions/api_exception.dart';
import 'package:intern_track_app/core/services/supervisor_management_service.dart';
import 'package:intern_track_app/features/admin/presentation/providers/supervisor_management_provider.dart';
import 'package:intern_track_app/shared/models/student_supervisor_assignment.dart';
import 'package:intern_track_app/shared/models/supervisor_option.dart';

class FakeSupervisorManagementService extends SupervisorManagementService {
  FakeSupervisorManagementService({
    this.fetchSupervisorsHandler,
    this.getStudentSupervisorHandler,
    this.assignSupervisorHandler,
  });

  Future<List<SupervisorOption>> Function()? fetchSupervisorsHandler;
  Future<StudentSupervisorAssignment> Function(int studentId)?
  getStudentSupervisorHandler;
  Future<StudentSupervisorAssignment> Function({
    required int studentId,
    int? supervisorId,
  })?
  assignSupervisorHandler;

  @override
  Future<List<SupervisorOption>> fetchSupervisors() async {
    final handler = fetchSupervisorsHandler;
    if (handler == null) return <SupervisorOption>[];
    return handler();
  }

  @override
  Future<StudentSupervisorAssignment> getStudentSupervisor(
    int studentId,
  ) async {
    final handler = getStudentSupervisorHandler;
    if (handler == null) {
      throw ApiException(message: 'Handler not set');
    }
    return handler(studentId);
  }

  @override
  Future<StudentSupervisorAssignment> assignSupervisor({
    required int studentId,
    int? supervisorId,
  }) async {
    final handler = assignSupervisorHandler;
    if (handler == null) {
      throw ApiException(message: 'Handler not set');
    }
    return handler(studentId: studentId, supervisorId: supervisorId);
  }
}

void main() {
  group('SupervisorManagementProvider', () {
    late FakeSupervisorManagementService fakeService;
    late SupervisorManagementProvider provider;

    setUp(() {
      fakeService = FakeSupervisorManagementService();
      provider = SupervisorManagementProvider(service: fakeService);
    });

    test('initial state is correct', () {
      expect(provider.supervisors, isEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.isAssigning, isFalse);
      expect(provider.errorMessage, isNull);
      expect(provider.successMessage, isNull);
    });

    test('loadSupervisors loads supervisors successfully', () async {
      final supervisors = <SupervisorOption>[
        const SupervisorOption(
          id: 1,
          name: 'Jane Smith',
          email: 'jane@test.com',
        ),
        const SupervisorOption(
          id: 2,
          name: 'Bob Johnson',
          email: 'bob@test.com',
        ),
      ];
      fakeService.fetchSupervisorsHandler = () async => supervisors;

      await provider.loadSupervisors();

      expect(provider.supervisors, equals(supervisors));
      expect(provider.errorMessage, isNull);
      expect(provider.isLoading, isFalse);
    });

    test('loadSupervisors handles ApiException', () async {
      fakeService.fetchSupervisorsHandler = () async => throw ApiException(
        message: 'Failed to load supervisors',
        errorType: ApiErrorType.unknown,
      );

      await provider.loadSupervisors();

      expect(provider.supervisors, isEmpty);
      expect(provider.errorMessage, 'Failed to load supervisors');
      expect(provider.isLoading, isFalse);
    });

    test('loadSupervisors handles unexpected errors', () async {
      fakeService.fetchSupervisorsHandler = () async =>
          throw StateError('boom');

      await provider.loadSupervisors();

      expect(provider.supervisors, isEmpty);
      expect(provider.errorMessage, contains('Failed to load supervisors:'));
      expect(provider.errorMessage, contains('boom'));
      expect(provider.isLoading, isFalse);
    });

    test('loadStudentSupervisor sets assignment', () async {
      final assignment = StudentSupervisorAssignment(
        studentId: 1,
        studentName: 'John Doe',
        supervisorId: 1,
        supervisorName: 'Jane Smith',
        assignedAt: DateTime.now(),
      );
      fakeService.getStudentSupervisorHandler = (studentId) async => assignment;

      final result = await provider.loadStudentSupervisor(1);

      expect(result, equals(assignment));
      expect(provider.getStudentAssignment(1), equals(assignment));
      expect(provider.errorMessage, isNull);
    });

    test('returns null and sets error on supervisor-load failure', () async {
      fakeService.getStudentSupervisorHandler = (_) async => throw ApiException(
        message: 'Student not found',
        errorType: ApiErrorType.unknown,
      );

      final result = await provider.loadStudentSupervisor(1);

      expect(result, isNull);
      expect(provider.errorMessage, 'Student not found');
    });

    test('returns null on unexpected supervisor-load failure', () async {
      fakeService.getStudentSupervisorHandler = (_) async =>
          throw StateError('broken supervisor lookup');

      final result = await provider.loadStudentSupervisor(1);

      expect(result, isNull);
      expect(
        provider.errorMessage,
        contains('Failed to load student supervisor:'),
      );
      expect(provider.errorMessage, contains('broken supervisor lookup'));
    });

    test('assignSupervisor success sets success message', () async {
      final assignment = StudentSupervisorAssignment(
        studentId: 1,
        studentName: 'John Doe',
        supervisorId: 1,
        supervisorName: 'Jane Smith',
        assignedAt: DateTime.now(),
      );
      fakeService.assignSupervisorHandler =
          ({required studentId, supervisorId}) async => assignment;

      final result = await provider.assignSupervisor(
        studentId: 1,
        supervisorId: 1,
      );

      expect(result, isTrue);
      expect(provider.getStudentAssignment(1), equals(assignment));
      expect(
        provider.successMessage,
        contains('Supervisor assigned successfully'),
      );
      expect(provider.errorMessage, isNull);
      expect(provider.isAssigning, isFalse);
    });

    test('assignSupervisor can remove supervisor successfully', () async {
      final assignment = StudentSupervisorAssignment(
        studentId: 1,
        studentName: 'John Doe',
        supervisorId: null,
        supervisorName: null,
        assignedAt: DateTime.now(),
      );
      fakeService.assignSupervisorHandler =
          ({required studentId, supervisorId}) async => assignment;

      final result = await provider.assignSupervisor(
        studentId: 1,
        supervisorId: null,
      );

      expect(result, isTrue);
      expect(provider.getStudentAssignment(1), equals(assignment));
      expect(
        provider.successMessage,
        contains('Supervisor assignment removed successfully'),
      );
      expect(provider.errorMessage, isNull);
      expect(provider.isAssigning, isFalse);
    });

    test('handles ApiException on assignment failure', () async {
      fakeService.assignSupervisorHandler =
          ({required studentId, supervisorId}) async => throw ApiException(
            message: 'Selected user is not a supervisor',
            errorType: ApiErrorType.unknown,
          );

      final result = await provider.assignSupervisor(
        studentId: 1,
        supervisorId: 1,
      );

      expect(result, isFalse);
      expect(provider.errorMessage, 'Selected user is not a supervisor');
      expect(provider.successMessage, isNull);
      expect(provider.isAssigning, isFalse);
    });

    test('handles unexpected error on assignment failure', () async {
      fakeService.assignSupervisorHandler =
          ({required studentId, supervisorId}) async =>
              throw StateError('assignment crashed');

      final result = await provider.assignSupervisor(
        studentId: 1,
        supervisorId: 1,
      );

      expect(result, isFalse);
      expect(provider.errorMessage, contains('Failed to assign supervisor:'));
      expect(provider.errorMessage, contains('assignment crashed'));
      expect(provider.successMessage, isNull);
      expect(provider.isAssigning, isFalse);
    });

    test('updateService swaps provider dependency', () async {
      final replacement = FakeSupervisorManagementService(
        fetchSupervisorsHandler: () async => <SupervisorOption>[
          const SupervisorOption(
            id: 9,
            name: 'Replacement Supervisor',
            email: 'new@test.com',
          ),
        ],
      );

      provider.updateService(replacement);
      await provider.loadSupervisors();

      expect(provider.supervisors, hasLength(1));
      expect(provider.supervisors.single.name, 'Replacement Supervisor');
    });

    test('clearMessages clears error and success messages', () async {
      fakeService.assignSupervisorHandler =
          ({required studentId, supervisorId}) async => throw ApiException(
            message: 'Assignment failed',
            errorType: ApiErrorType.unknown,
          );

      await provider.assignSupervisor(studentId: 1, supervisorId: 1);
      expect(provider.errorMessage, 'Assignment failed');

      provider.clearMessages();

      expect(provider.errorMessage, isNull);
      expect(provider.successMessage, isNull);
    });
  });
}
