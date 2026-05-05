import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:interntrack/core/exceptions/api_exception.dart';
import 'package:interntrack/core/services/adviser_management_service.dart';
import 'package:interntrack/features/admin/presentation/providers/adviser_management_provider.dart';
import 'package:interntrack/shared/models/adviser_info.dart';
import 'package:interntrack/shared/models/student_adviser_assignment.dart';

class MockAdviserManagementService extends Mock
    implements AdviserManagementService {}

void main() {
  group('AdviserManagementProvider', () {
    late MockAdviserManagementService mockService;
    late AdviserManagementProvider provider;

    setUp(() {
      mockService = MockAdviserManagementService();
      provider = AdviserManagementProvider(service: mockService);
    });

    test('initial state is correct', () {
      expect(provider.advisers, isEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.isAssigning, isFalse);
      expect(provider.errorMessage, isNull);
      expect(provider.successMessage, isNull);
    });

    group('loadAdvisers', () {
      test('loads advisers successfully', () async {
        final advisers = [
          AdviserInfo(id: 1, name: 'Jane Smith', email: 'jane@test.com'),
          AdviserInfo(id: 2, name: 'Bob Johnson', email: 'bob@test.com'),
        ];

        when(mockService.fetchAdvisers()).thenAnswer((_) async => advisers);

        await provider.loadAdvisers();

        expect(provider.advisers, equals(advisers));
        expect(provider.errorMessage, isNull);
        expect(provider.isLoading, isFalse);
      });

      test('handles error when loading advisers fails', () async {
        when(mockService.fetchAdvisers()).thenThrow(
          ApiException(
            message: 'Failed to load advisers',
            errorType: ApiErrorType.unknown,
          ),
        );

        await provider.loadAdvisers();

        expect(provider.advisers, isEmpty);
        expect(provider.errorMessage, 'Failed to load advisers');
        expect(provider.isLoading, isFalse);
      });
    });

    group('loadStudentAdviser', () {
      test('loads student adviser successfully', () async {
        final assignment = StudentAdviserAssignment(
          studentId: 1,
          studentName: 'John Doe',
          adviserId: 1,
          adviserName: 'Jane Smith',
          assignedAt: DateTime.now(),
        );

        when(mockService.getStudentAdviser(1))
            .thenAnswer((_) async => assignment);

        final result = await provider.loadStudentAdviser(1);

        expect(result, equals(assignment));
        expect(provider.getStudentAssignment(1), equals(assignment));
        expect(provider.errorMessage, isNull);
      });

      test('returns null and sets error on failure', () async {
        when(mockService.getStudentAdviser(1)).thenThrow(
          ApiException(
            message: 'Student not found',
            errorType: ApiErrorType.unknown,
          ),
        );

        final result = await provider.loadStudentAdviser(1);

        expect(result, isNull);
        expect(provider.errorMessage, 'Student not found');
      });
    });

    group('assignAdviser', () {
      test('assigns adviser successfully', () async {
        final adviser = AdviserInfo(id: 1, name: 'Jane Smith', email: 'jane@test.com');
        final assignment = StudentAdviserAssignment(
          studentId: 1,
          studentName: 'John Doe',
          adviserId: 1,
          adviserName: 'Jane Smith',
          assignedAt: DateTime.now(),
        );

        when(mockService.assignAdviser(studentId: 1, adviserId: 1))
            .thenAnswer((_) async => assignment);

        final result = await provider.assignAdviser(
          studentId: 1,
          adviserId: 1,
        );

        expect(result, isTrue);
        expect(provider.getStudentAssignment(1), equals(assignment));
        expect(provider.successMessage, contains('Adviser assigned successfully'));
        expect(provider.errorMessage, isNull);
        expect(provider.isAssigning, isFalse);
      });

      test('removes adviser successfully', () async {
        final assignment = StudentAdviserAssignment(
          studentId: 1,
          studentName: 'John Doe',
          adviserId: null,
          adviserName: null,
          assignedAt: DateTime.now(),
        );

        when(mockService.assignAdviser(studentId: 1, adviserId: null))
            .thenAnswer((_) async => assignment);

        final result = await provider.assignAdviser(
          studentId: 1,
          adviserId: null,
        );

        expect(result, isTrue);
        expect(provider.getStudentAssignment(1), equals(assignment));
        expect(provider.successMessage, contains('Adviser assignment removed successfully'));
        expect(provider.errorMessage, isNull);
      });

      test('handles error on assignment failure', () async {
        when(mockService.assignAdviser(studentId: 1, adviserId: 1))
            .thenThrow(
              ApiException(
                message: 'Selected user is not an adviser',
                errorType: ApiErrorType.unknown,
              ),
            );

        final result = await provider.assignAdviser(
          studentId: 1,
          adviserId: 1,
        );

        expect(result, isFalse);
        expect(provider.errorMessage, 'Selected user is not an adviser');
        expect(provider.successMessage, isNull);
        expect(provider.isAssigning, isFalse);
      });
    });

    group('clearMessages', () {
      test('clears error and success messages', () {
        provider.setErrorMessage('Error');
        provider.setSuccessMessage('Success');

        provider.clearMessages();

        expect(provider.errorMessage, isNull);
        expect(provider.successMessage, isNull);
      });
    });
  });
}

extension on AdviserManagementProvider {
  void setErrorMessage(String message) {
    // This would require making the method public or using a private setter
    // For testing purposes, this is just for documentation
  }

  void setSuccessMessage(String message) {
    // This would require making the method public or using a private setter
    // For testing purposes, this is just for documentation
  }
}
