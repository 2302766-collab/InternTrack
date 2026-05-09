import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/services/api_client.dart';
import 'package:intern_track_app/core/services/intern_list_service.dart';
import 'package:intern_track_app/features/supervisor/presentation/screens/intern_list_screen.dart';
import 'package:intern_track_app/shared/models/intern_list_item.dart';
import 'package:intern_track_app/shared/models/intern_list_page.dart';

void main() {
  group('InternListScreen pagination', () {
    testWidgets('loads first page and appends more interns', (tester) async {
      _setLargeSurfaceSize(tester);
      final service = _FakeInternListService((request) async {
        if (request.page == 1) {
          return _page(
            page: 1,
            total: 3,
            hasMore: true,
            interns: [
              _intern(
                id: 1,
                studentName: 'John Doe',
                requiredHours: 100,
                completedHours: 80,
                approvedLogs: 8,
                pendingLogs: 1,
              ),
              _intern(
                id: 2,
                studentName: 'Ana Cruz',
                requiredHours: 100,
                completedHours: 40,
                approvedLogs: 4,
                pendingLogs: 2,
              ),
            ],
          );
        }

        return _page(
          page: 2,
          total: 3,
          hasMore: false,
          interns: [
            _intern(
              id: 3,
              studentName: 'Ben Santos',
              requiredHours: 100,
              completedHours: 95,
              approvedLogs: 9,
            ),
          ],
        );
      });

      await tester.pumpWidget(_buildTestApp(service));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Ana Cruz'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('Approved 80 of 100 hours'), findsOneWidget);
      expect(find.text('Showing 2 of 3 interns'), findsOneWidget);
      expect(find.text('Load More'), findsOneWidget);
      expect(service.requests.first.perPage, 20);

      final loadMoreButton = find.text('Load More');
      await tester.scrollUntilVisible(
        loadMoreButton,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(loadMoreButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Ben Santos'), findsOneWidget);
      expect(find.text('95%'), findsOneWidget);
      expect(find.text('Showing 3 of 3 interns'), findsOneWidget);
      expect(find.text('All interns loaded.'), findsOneWidget);
      expect(service.requests.map((request) => request.page), [1, 2]);
      expect(service.requests.map((request) => request.perPage), [20, 20]);
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
      expect(service.requests.last.perPage, 20);
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

    testWidgets('shows inline retry when load more fails', (tester) async {
      _setLargeSurfaceSize(tester);
      var shouldFailLoadMore = true;
      final service = _FakeInternListService((request) async {
        if (request.page == 2 && shouldFailLoadMore) {
          shouldFailLoadMore = false;
          throw Exception('Unable to load more interns.');
        }

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
      await tester.pumpAndSettle();

      final loadMoreButton = find.text('Load More');
      await tester.scrollUntilVisible(
        loadMoreButton,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(loadMoreButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Unable to load more interns.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Ben Santos'), findsOneWidget);
      expect(find.text('All interns loaded.'), findsOneWidget);
    });
  });
}

void _setLargeSurfaceSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
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
    perPage: 20,
    total: total,
    hasMorePages: hasMore,
  );
}

InternListItem _intern({
  required int id,
  required String studentName,
  int requiredHours = 486,
  int completedHours = 0,
  int approvedLogs = 0,
  int pendingLogs = 0,
  int rejectedLogs = 0,
}) {
  return InternListItem(
    id: id,
    studentId: id,
    studentName: studentName,
    companyName: 'Acme Corp',
    requiredHours: requiredHours,
    completedHours: completedHours,
    approvedLogs: approvedLogs,
    pendingLogs: pendingLogs,
    rejectedLogs: rejectedLogs,
    totalLogs: approvedLogs + pendingLogs + rejectedLogs,
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
    int perPage = 20,
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
