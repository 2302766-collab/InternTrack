import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/services/api_client.dart';
import 'package:intern_track_app/core/services/dtr_service.dart';
import 'package:intern_track_app/core/services/intern_reporting_service.dart';

void main() {
  group('DtrService exports', () {
    test('sends start and end date filters for student PDF exports', () async {
      final adapter = _DownloadAdapter();
      final service = DtrService(
        ApiClient(dio: Dio()..httpClientAdapter = adapter),
      );

      final file = await service.exportPdf(
        startDate: DateTime(2026, 4, 2),
        endDate: DateTime(2026, 4, 30),
      );

      expect(adapter.lastPath, '/student/dtr/export/pdf');
      expect(adapter.lastQueryParameters, <String, dynamic>{
        'start_date': '2026-04-02',
        'end_date': '2026-04-30',
      });
      expect(file.filename, 'dtr_2026-04.pdf');
      expect(file.mimeType, 'application/pdf');
      expect(file.bytes, <int>[1, 2, 3]);
    });

    test(
      'keeps legacy month and year parameters for student CSV exports',
      () async {
        final adapter = _DownloadAdapter();
        final service = DtrService(
          ApiClient(dio: Dio()..httpClientAdapter = adapter),
        );

        final file = await service.exportExcel(month: 4, year: 2026);

        expect(adapter.lastPath, '/student/dtr/export/excel');
        expect(adapter.lastQueryParameters, <String, dynamic>{
          'month': 4,
          'year': 2026,
        });
        expect(file.filename, 'dtr_2026-04.csv');
        expect(file.mimeType, 'text/csv');
        expect(file.bytes, <int>[1, 2, 3]);
      },
    );
  });

  group('InternReportingService exports', () {
    test('sends start and end date filters for reviewer exports', () async {
      final adapter = _DownloadAdapter(
        contentDisposition: 'attachment; filename="custom_dtr.csv"',
        contentType: 'text/csv; charset=UTF-8',
      );
      final service = InternReportingService(
        ApiClient(dio: Dio()..httpClientAdapter = adapter),
      );

      final file = await service.exportDtr(
        role: 'supervisor',
        studentId: 17,
        startDate: DateTime(2026, 4, 10),
        endDate: DateTime(2026, 4, 25),
        pdf: false,
      );

      expect(adapter.lastPath, '/supervisor/students/17/dtr/export/excel');
      expect(adapter.lastQueryParameters, <String, dynamic>{
        'start_date': '2026-04-10',
        'end_date': '2026-04-25',
      });
      expect(file.filename, 'custom_dtr.csv');
      expect(file.mimeType, 'text/csv; charset=UTF-8');
      expect(file.bytes, <int>[1, 2, 3]);
    });

    test(
      'supports admin DTR exports through admin student endpoints',
      () async {
        final adapter = _DownloadAdapter(
          contentDisposition: 'attachment; filename="admin_dtr.pdf"',
          contentType: 'application/pdf',
        );
        final service = InternReportingService(
          ApiClient(dio: Dio()..httpClientAdapter = adapter),
        );

        final file = await service.exportDtr(
          role: 'admin',
          studentId: 23,
          startDate: DateTime(2026, 5, 1),
          endDate: DateTime(2026, 5, 30),
          pdf: true,
        );

        expect(adapter.lastPath, '/admin/students/23/dtr/export/pdf');
        expect(adapter.lastQueryParameters, <String, dynamic>{
          'start_date': '2026-05-01',
          'end_date': '2026-05-30',
        });
        expect(file.filename, 'admin_dtr.pdf');
        expect(file.mimeType, 'application/pdf');
        expect(file.bytes, <int>[1, 2, 3]);
      },
    );
  });
}

class _DownloadAdapter implements HttpClientAdapter {
  _DownloadAdapter({
    this.contentDisposition = 'attachment; filename="download.bin"',
    this.contentType = 'application/octet-stream',
  });

  final String contentDisposition;
  final String contentType;
  String? lastPath;
  Map<String, dynamic>? lastQueryParameters;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastQueryParameters = Map<String, dynamic>.from(options.queryParameters);

    return ResponseBody.fromBytes(
      <int>[1, 2, 3],
      200,
      headers: <String, List<String>>{
        'content-disposition': <String>[contentDisposition],
        Headers.contentTypeHeader: <String>[contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
