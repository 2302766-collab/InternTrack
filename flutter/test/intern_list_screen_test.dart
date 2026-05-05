import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/services/api_client.dart';
import 'package:intern_track_app/core/services/intern_list_service.dart';
import 'package:intern_track_app/features/supervisor/presentation/screens/intern_list_screen.dart';
import 'package:intern_track_app/shared/models/intern_list_item.dart';

void main() {
  group('InternListScreen pagination', () {
    testWidgets('loads first page and appends more interns', (tester) async {
      final service = _FakeInternListService((request) async {
        if (request.page == 1) {
          return _page(
            page: 1,
            total: 3,
            hasMore: true,
            interns: [
              _intern(id: 1, studentName: 'John Doe'),
              _intern(id: 2, studentName: 'Ana Cruz'),
            ],
          );
        }

        return _page(
          page: 2,
          total: 3,
          hasMore: false,
          interns: [
            _intern(id: 3, studentName: 'Ben Santos'),
          ],
        );
      });

      await tester.pumpWidget(_buildTestApp(service));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Ana Cruz'), findsOneWidget);
      expect(find.text('Showing 2 of 3 interns'), findsOneWidget);
      expect(find.text('Load more'), findsOneWidget);

      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      expect(find.text('Ben Santos'), findsOneWidget);
      expect(find.text('Showing 3 of 3 interns'), findsOneWidget);
      expect(find.text('All interns loaded.'), findsOneWidget);
      expect(service.requests.map((request) => request.page), [1, 2]);
    });

    testWidgets('sends search to API and resets to the first page', (
      tester,
    ) async {
      final service = _FakeInternListService((request) async {
        if (request.search.toLowerCase() == 'ana') {
          return _page(
            page: request.page,
            total: 1,
            interns: [
              _intern(id: 2, studentName: 'Ana Cruz'),
            ],
          );
        }

        return _page(
          page: request.page,
          total: 2,
          interns: [
            _intern(id: 1, studentName: 'John Doe'),
            _intern(id: 2, studentName: 'Ana Cruz'),
          ],
        );
      });

      await tester.pumpWidget(_buildTestApp(service));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Ana');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Ana Cruz'), findsOneWidget);
      expect(find.text('John Doe'), findsNothing);
      expect(service.requests.last.search, 'Ana');
      expect(service.requests.last.page, 1);
    });

    testWidgets('shows empty state when no interns are returned', (
      tester,
    ) async {
      final service = _FakeInternListService((request) async {
        return _page(page: request.page, total: 0);
      });

      await tester.pumpWidget(_buildTestApp(service));
      await tester.pumpAndSettle();

      expect(find.text('No assigned interns found.'), findsOneWidget);
    });

    testWidgets('shows retry after initial load failure', (tester) async {
      var shouldFail = true;
      final service = _FakeInternListService((request) async {
        if (shouldFail) {
          shouldFail = false;
          throw Exception('Network error.');
        }

        return _page(
          page: request.page,
          total: 1,
          interns: [
            _intern(id: 1, studentName: 'John Doe'),
          ],
        );
      });

      await tester.pumpWidget(_buildTestApp(service));
      await tester.pumpAndSettle();

      expect(find.text('Network error.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('John Doe'), findsOneWidget);
      expect(service.requests.length, 2);
    });
  });
}

Widget _buildTestApp(InternListService service) {
  return MaterialApp(
    home: InternListScreen(
      token: 'token',
      role: 'supervisor',
      service: service,
    ),
  );
}

InternListPage _page({
  required int page,
  required int total,
  bool hasMore = false,
  List<InternListItem> interns = const <InternListItem>[],
}) {
  return InternListPage(
    interns: interns,
    currentPage: page,
    lastPage: hasMore ? page + 1 : page,
    perPage: 10,
    total: total,
    hasMorePages: hasMore,
  );
}

InternListItem _intern({
  required int id,
  required String studentName,
}) {
  return InternListItem(
    id: id,
    studentId: id,
    studentName: studentName,
    companyName: 'Acme Corp',
    requiredHours: 486,
  );
}

class _InternPageRequest {
  final int page;
  final int perPage;
  final String search;

  const _InternPageRequest({
    required this.page,
    required this.perPage,
    required this.search,
  });
}

class _FakeInternListService extends InternListService {
  _FakeInternListService(this.handler)
      : super(
          ApiClient(
            dio: Dio(),
          ),
        );

  final Future<InternListPage> Function(_InternPageRequest request) handler;
  final List<_InternPageRequest> requests = <_InternPageRequest>[];

  @override
  Future<InternListPage> getInternPage({
    required String role,
    int page = 1,
    int perPage = 10,
    String search = '',
  }) async {
    final request = _InternPageRequest(
      page: page,
      perPage: perPage,
      search: search,
    );
    requests.add(request);
    return handler(request);
  }
}
