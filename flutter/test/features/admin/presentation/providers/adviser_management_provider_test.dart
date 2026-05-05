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
  Future<StudentAdviserAssignment> Function(int studentId)? getStudentAdviserHandler;
  Future<StudentAdviserAssignment> Function({required int studentId, int? adviserId})?
      assignAdviserHandler;

  @override
  Future<List<AdviserInfo>> fetchAdvisers() async {
    final handler = fetchAdvisersHandler;
    if (handler == null) return [];
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
      final advisers = [
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

    test('loadStudentAdviser sets assignment', () async {
      final assignment = StudentAdviserAssignment(
        studentId: 1,
        studentName: 'John Doe',
        adviserId: 1,
        adviserName: 'Jane Smith',
        assignedAt: DateTime.now(),
      );
      fakeService.getStudentAdviserHandler = (_) async => assignment;

      final result = await provider.loadStudentAdviser(1);

      expect(result, equals(assignment));
      expect(provider.getStudentAssignment(1), equals(assignment));
      expect(provider.errorMessage, isNull);
    });

    test('assignAdviser success sets success message', () async {
      final assignment = StudentAdviserAssignment(
        studentId: 1,
        studentName: 'John Doe',
        adviserId: 1,
        adviserName: 'Jane Smith',
        assignedAt: DateTime.now(),
      );
      fakeService.assignAdviserHandler = ({required studentId, adviserId}) async => assignment;

      final result = await provider.assignAdviser(studentId: 1, adviserId: 1);

      expect(result, isTrue);
      expect(provider.getStudentAssignment(1), equals(assignment));
      expect(provider.successMessage, contains('Adviser assigned successfully'));
      expect(provider.errorMessage, isNull);
    });
  });
}
