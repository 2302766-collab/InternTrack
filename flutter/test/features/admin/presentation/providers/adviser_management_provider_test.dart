import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/exceptions/api_exception.dart';
import 'package:intern_track_app/core/services/adviser_management_service.dart';
import 'package:intern_track_app/features/admin/presentation/providers/adviser_management_provider.dart';
import 'package:intern_track_app/shared/models/adviser_info.dart';
import 'package:intern_track_app/shared/models/student_adviser_assignment.dart';

class FakeAdviserManagementService extends AdviserManagementService {
  FakeAdviserManagementService({
    this.fetchAdvisersHandler,
    this.getStudentAdviserHandler,
    this.assignAdviserHandler,
  });

  Future<List<AdviserInfo>> Function()? fetchAdvisersHandler;
  Future<StudentAdviserAssignment> Function(int studentId)?
  getStudentAdviserHandler;
  Future<StudentAdviserAssignment> Function({
    required int studentId,
    int? adviserId,
  })?
  assignAdviserHandler;

  @override
  Future<List<AdviserInfo>> fetchAdvisers() async {
    final handler = fetchAdvisersHandler;
    if (handler == null) return <AdviserInfo>[];
    return handler();
  }

  @override
  Future<StudentAdviserAssignment> getStudentAdviser(int studentId) async {
    final handler = getStudentAdviserHandler;
    if (handler == null) {
      throw ApiException(message: 'Handler not set');
    }
    return handler(studentId);
  }

  @override
  Future<StudentAdviserAssignment> assignAdviser({
    required int studentId,
    int? adviserId,
  }) async {
    final handler = assignAdviserHandler;
    if (handler == null) {
      throw ApiException(message: 'Handler not set');
    }
    return handler(studentId: studentId, adviserId: adviserId);
  }
}

void main() {
  group('AdviserManagementProvider', () {
    late FakeAdviserManagementService fakeService;
    late AdviserManagementProvider provider;

    setUp(() {
      fakeService = FakeAdviserManagementService();
      provider = AdviserManagementProvider(service: fakeService);
    });

    test('initial state is correct', () {
      expect(provider.advisers, isEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.isAssigning, isFalse);
      expect(provider.errorMessage, isNull);
      expect(provider.successMessage, isNull);
    });

    test('loadAdvisers loads advisers successfully', () async {
      final advisers = <AdviserInfo>[
        AdviserInfo(id: 1, name: 'Jane Smith', email: 'jane@test.com'),
        AdviserInfo(id: 2, name: 'Bob Johnson', email: 'bob@test.com'),
      ];
      fakeService.fetchAdvisersHandler = () async => advisers;

      await provider.loadAdvisers();

      expect(provider.advisers, equals(advisers));
      expect(provider.errorMessage, isNull);
      expect(provider.isLoading, isFalse);
    });

    test('loadAdvisers handles ApiException', () async {
      fakeService.fetchAdvisersHandler = () async => throw ApiException(
        message: 'Failed to load advisers',
        errorType: ApiErrorType.unknown,
      );

      await provider.loadAdvisers();

      expect(provider.advisers, isEmpty);
      expect(provider.errorMessage, 'Failed to load advisers');
      expect(provider.isLoading, isFalse);
    });

    test('loadAdvisers handles unexpected errors', () async {
      fakeService.fetchAdvisersHandler = () async => throw StateError('boom');

      await provider.loadAdvisers();

      expect(provider.advisers, isEmpty);
      expect(provider.errorMessage, contains('Failed to load advisers:'));
      expect(provider.errorMessage, contains('boom'));
      expect(provider.isLoading, isFalse);
    });

    test('loadStudentAdviser sets assignment', () async {
      final assignment = StudentAdviserAssignment(
        studentId: 1,
        studentName: 'John Doe',
        adviserId: 1,
        adviserName: 'Jane Smith',
        assignedAt: DateTime.now(),
      );
      fakeService.getStudentAdviserHandler = (studentId) async => assignment;

      final result = await provider.loadStudentAdviser(1);

      expect(result, equals(assignment));
      expect(provider.getStudentAssignment(1), equals(assignment));
      expect(provider.errorMessage, isNull);
    });

    test('returns null and sets error on adviser-load failure', () async {
      fakeService.getStudentAdviserHandler = (_) async => throw ApiException(
        message: 'Student not found',
        errorType: ApiErrorType.unknown,
      );

      final result = await provider.loadStudentAdviser(1);

      expect(result, isNull);
      expect(provider.errorMessage, 'Student not found');
    });

    test('returns null on unexpected adviser-load failure', () async {
      fakeService.getStudentAdviserHandler = (_) async =>
          throw StateError('broken adviser lookup');

      final result = await provider.loadStudentAdviser(1);

      expect(result, isNull);
      expect(
        provider.errorMessage,
        contains('Failed to load student adviser:'),
      );
      expect(provider.errorMessage, contains('broken adviser lookup'));
    });

    test('assignAdviser success sets success message', () async {
      final assignment = StudentAdviserAssignment(
        studentId: 1,
        studentName: 'John Doe',
        adviserId: 1,
        adviserName: 'Jane Smith',
        assignedAt: DateTime.now(),
      );
      fakeService.assignAdviserHandler =
          ({required studentId, adviserId}) async => assignment;

      final result = await provider.assignAdviser(studentId: 1, adviserId: 1);

      expect(result, isTrue);
      expect(provider.getStudentAssignment(1), equals(assignment));
      expect(
        provider.successMessage,
        contains('Adviser assigned successfully'),
      );
      expect(provider.errorMessage, isNull);
      expect(provider.isAssigning, isFalse);
    });

    test('assignAdviser can remove adviser successfully', () async {
      final assignment = StudentAdviserAssignment(
        studentId: 1,
        studentName: 'John Doe',
        adviserId: null,
        adviserName: null,
        assignedAt: DateTime.now(),
      );
      fakeService.assignAdviserHandler =
          ({required studentId, adviserId}) async => assignment;

      final result = await provider.assignAdviser(
        studentId: 1,
        adviserId: null,
      );

      expect(result, isTrue);
      expect(provider.getStudentAssignment(1), equals(assignment));
      expect(
        provider.successMessage,
        contains('Adviser assignment removed successfully'),
      );
      expect(provider.errorMessage, isNull);
      expect(provider.isAssigning, isFalse);
    });

    test('handles error on assignment failure', () async {
      fakeService.assignAdviserHandler =
          ({required studentId, adviserId}) async => throw ApiException(
            message: 'Selected user is not an adviser',
            errorType: ApiErrorType.unknown,
          );

      final result = await provider.assignAdviser(studentId: 1, adviserId: 1);

      expect(result, isFalse);
      expect(provider.errorMessage, 'Selected user is not an adviser');
      expect(provider.successMessage, isNull);
      expect(provider.isAssigning, isFalse);
    });

    test('handles unexpected error on assignment failure', () async {
      fakeService.assignAdviserHandler =
          ({required studentId, adviserId}) async =>
              throw StateError('assignment crashed');

      final result = await provider.assignAdviser(studentId: 1, adviserId: 1);

      expect(result, isFalse);
      expect(provider.errorMessage, contains('Failed to assign adviser:'));
      expect(provider.errorMessage, contains('assignment crashed'));
      expect(provider.successMessage, isNull);
      expect(provider.isAssigning, isFalse);
    });

    test('updateService swaps provider dependency', () async {
      final replacement = FakeAdviserManagementService(
        fetchAdvisersHandler: () async => <AdviserInfo>[
          AdviserInfo(
            id: 9,
            name: 'Replacement Adviser',
            email: 'new@test.com',
          ),
        ],
      );

      provider.updateService(replacement);
      await provider.loadAdvisers();

      expect(provider.advisers, hasLength(1));
      expect(provider.advisers.single.name, 'Replacement Adviser');
    });

    test('clearMessages clears error and success messages', () async {
      fakeService.assignAdviserHandler =
          ({required studentId, adviserId}) async => throw ApiException(
            message: 'Assignment failed',
            errorType: ApiErrorType.unknown,
          );

      await provider.assignAdviser(studentId: 1, adviserId: 1);
      expect(provider.errorMessage, 'Assignment failed');

      provider.clearMessages();

      expect(provider.errorMessage, isNull);
      expect(provider.successMessage, isNull);
    });
  });
}
