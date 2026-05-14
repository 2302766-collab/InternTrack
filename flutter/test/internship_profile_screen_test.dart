import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/constants/app_routes.dart';
import 'package:intern_track_app/core/exceptions/api_exception.dart';
import 'package:intern_track_app/core/services/internship_service.dart';
import 'package:intern_track_app/features/internship/presentation/screens/internship_profile_screen.dart';
import 'package:intern_track_app/shared/models/internship_profile.dart';
import 'package:intern_track_app/shared/models/supervisor_option.dart';
import 'package:provider/provider.dart';

void main() {
  group('InternshipProfileScreen', () {
    testWidgets('existing profile opens in view mode with Edit', (
      tester,
    ) async {
      final service = _FakeInternshipService(
        profile: _sampleProfile(),
        supervisors: const [],
      );

      await _pumpScreen(tester, service);

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      expect(find.textContaining('InternTrack Labs'), findsWidgets);
    });

    testWidgets('Edit switches to edit mode with Save and Cancel', (
      tester,
    ) async {
      final service = _FakeInternshipService(
        profile: _sampleProfile(),
        supervisors: const [],
      );

      await _pumpScreen(tester, service);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Edit Internship Profile'), findsOneWidget);
    });

    testWidgets('Save submits valid edited values', (tester) async {
      final service = _FakeInternshipService(
        profile: _sampleProfile(),
        supervisors: const [],
      );

      await _pumpScreen(tester, service);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Company Name'),
        'Updated Company',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('internship_profile_save_button')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('internship_profile_save_button')),
      );
      await tester.pumpAndSettle();

      expect(service.updateCallCount, 1);
      expect(service.lastUpdatedCompanyName, 'Updated Company');
      expect(find.textContaining('Updated Company'), findsWidgets);
      expect(find.text('Save'), findsNothing);
    });

    testWidgets('Cancel restores original values and exits edit mode', (
      tester,
    ) async {
      final service = _FakeInternshipService(
        profile: _sampleProfile(),
        supervisors: const [],
      );

      await _pumpScreen(tester, service);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Company Name'),
        'Temporary Name',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('internship_profile_cancel_button')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('internship_profile_cancel_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsNothing);
      expect(find.textContaining('InternTrack Labs'), findsWidgets);
      expect(find.text('Temporary Name'), findsNothing);
    });

    testWidgets('date picker selection updates start date field', (
      tester,
    ) async {
      final service = _FakeInternshipService(
        profile: null,
        supervisors: _supervisorList(),
      );

      await _pumpScreen(tester, service);

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final y = yesterday.year.toString().padLeft(4, '0');
      final m = yesterday.month.toString().padLeft(2, '0');
      final d = yesterday.day.toString().padLeft(2, '0');
      final expectedIso = '$y-$m-$d';

      await tester.tap(
        find.byKey(
          const ValueKey<String>('internship_profile_start_date_field'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('${yesterday.day}').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text(expectedIso), findsOneWidget);
    });

    testWidgets('start and end date fields are read-only (no manual typing)', (
      tester,
    ) async {
      final service = _FakeInternshipService(
        profile: _sampleProfile(),
        supervisors: const [],
      );

      await _pumpScreen(tester, service);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      final startField = find.descendant(
        of: find.byKey(
          const ValueKey<String>('internship_profile_start_date_field'),
        ),
        matching: find.byType(TextField),
      );
      final endField = find.descendant(
        of: find.byKey(
          const ValueKey<String>('internship_profile_end_date_field'),
        ),
        matching: find.byType(TextField),
      );

      expect(tester.widget<TextField>(startField).readOnly, isTrue);
      expect(tester.widget<TextField>(endField).readOnly, isTrue);

      await tester.enterText(
        find.byKey(
          const ValueKey<String>('internship_profile_start_date_field'),
        ),
        '2099-01-01',
      );
      await tester.pumpAndSettle();

      expect(find.text('2099-01-01'), findsNothing);
    });

    testWidgets(
      'end date on or before start date shows inline validation error',
      (tester) async {
        final service = _FakeInternshipService(
          profile: null,
          supervisors: _supervisorList(),
        );

        await _pumpScreen(tester, service);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Company Name'),
          'Acme Corp',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Company Address'),
          '123 Main St',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Required Hours'),
          '120',
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(
            const ValueKey<String>('internship_profile_start_date_field'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('20').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(
            const ValueKey<String>('internship_profile_end_date_field'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('10').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(
            const ValueKey<String>('internship_profile_create_button'),
          ),
        );
        await tester.tap(
          find.byKey(
            const ValueKey<String>('internship_profile_create_button'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('End date must be after start date'), findsOneWidget);
      },
    );

    testWidgets('invalid required hours shows inline validation error', (
      tester,
    ) async {
      final service = _FakeInternshipService(
        profile: null,
        supervisors: _supervisorList(),
      );

      await _pumpScreen(tester, service);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Company Name'),
        'Acme Corp',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Company Address'),
        '123 Main St',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Required Hours'),
        '0',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('internship_profile_create_button')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('internship_profile_create_button')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('greater than 0'), findsOneWidget);
    });

    testWidgets('failed save shows error and keeps edited values', (
      tester,
    ) async {
      final service = _FakeInternshipService(
        profile: _sampleProfile(),
        supervisors: const [],
      );
      service.nextUpdateError = ApiException(
        message: 'Unable to save. Try again.',
        errorType: ApiErrorType.networkError,
      );

      await _pumpScreen(tester, service);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Company Name'),
        'Edited While Failing',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('internship_profile_save_button')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('internship_profile_save_button')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Unable to save'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Edited While Failing'), findsOneWidget);
    });
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeInternshipService service,
) async {
  final binding = tester.binding;
  await binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() async {
    await binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    MaterialApp(
      routes: {
        '/': (_) => Provider<InternshipService>.value(
          value: service,
          child: const InternshipProfileScreen(),
        ),
        AppRoutes.studentDashboard: (_) => const SizedBox.shrink(),
        AppRoutes.logbook: (_) => const SizedBox.shrink(),
        AppRoutes.studentDtr: (_) => const SizedBox.shrink(),
        AppRoutes.studentReport: (_) => const SizedBox.shrink(),
        AppRoutes.internshipProfile: (_) => Provider<InternshipService>.value(
          value: service,
          child: const InternshipProfileScreen(),
        ),
      },
      initialRoute: '/',
    ),
  );
  await tester.pumpAndSettle();
}

List<SupervisorOption> _supervisorList() {
  return const <SupervisorOption>[
    SupervisorOption(id: 9, name: 'Supervisor Smith', email: 'sup@example.com'),
  ];
}

InternshipProfile _sampleProfile() {
  return InternshipProfile(
    id: 1,
    studentId: 17,
    companyName: 'InternTrack Labs',
    companyAddress: 'Quezon City',
    requiredHours: 486,
    startDate: '2026-05-01',
    endDate: '2026-08-31',
    supervisorId: 9,
    adviserId: 11,
    supervisorName: 'Supervisor Smith',
    supervisorEmail: 'supervisor@example.com',
  );
}

class _FakeInternshipService extends InternshipService {
  _FakeInternshipService({required this.profile, required this.supervisors});

  InternshipProfile? profile;
  List<SupervisorOption> supervisors;
  int updateCallCount = 0;
  String? lastUpdatedCompanyName;
  Object? nextUpdateError;

  @override
  Future<InternshipProfile?> getInternshipProfile() async => profile;

  @override
  Future<List<SupervisorOption>> getSupervisors() async => supervisors;

  @override
  Future<InternshipProfile> createInternshipProfile({
    required String companyName,
    required String companyAddress,
    required int supervisorId,
    required int requiredHours,
    required String startDate,
    required String endDate,
  }) async {
    final created = InternshipProfile(
      id: 1,
      studentId: 1,
      companyName: companyName,
      companyAddress: companyAddress,
      requiredHours: requiredHours,
      startDate: startDate,
      endDate: endDate,
      supervisorId: supervisorId,
      adviserId: null,
      supervisorName: 'Supervisor Smith',
      supervisorEmail: 'sup@example.com',
    );
    profile = created;
    return created;
  }

  @override
  Future<InternshipProfile> updateInternshipProfile({
    required String companyName,
    required String companyAddress,
    required int requiredHours,
    required String startDate,
    required String endDate,
  }) async {
    updateCallCount++;
    lastUpdatedCompanyName = companyName;

    final err = nextUpdateError;
    if (err != null) {
      nextUpdateError = null;
      throw err;
    }

    final current = profile!;
    final updated = InternshipProfile(
      id: current.id,
      studentId: current.studentId,
      companyName: companyName,
      companyAddress: companyAddress,
      requiredHours: requiredHours,
      startDate: startDate,
      endDate: endDate,
      supervisorId: current.supervisorId,
      adviserId: current.adviserId,
      supervisorName: current.supervisorName,
      supervisorEmail: current.supervisorEmail,
    );
    profile = updated;
    return updated;
  }
}
