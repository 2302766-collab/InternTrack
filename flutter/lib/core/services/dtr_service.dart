import '../../shared/models/daily_time_record.dart';
import '../exceptions/api_exception.dart';
import '../services/api_client.dart';
import '../services/base_service.dart';

/// Data model for exported DTR files
class DtrExportFile {
  final List<int> bytes;
  final String filename;
  final String mimeType;

  const DtrExportFile({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });
}

/// Service for managing Daily Time Records (DTR)
/// 
/// Handles punch operations (time-in, time-out, lunch breaks) and DTR exports
/// All methods throw [ApiException] for consistent error handling
class DtrService extends BaseService {
  final ApiClient _apiClient;

  DtrService(this._apiClient);

  /// Fetches today's DTR record
  /// 
  /// Throws [ApiException] with user-friendly error messages
  Future<DailyTimeRecord> getTodayRecord() async {
    try {
      return await _apiClient.get<DailyTimeRecord>(
        path: '/student/dtr/today',
        converter: (data) => _parseDtrResponse(data),
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  /// Punches in/out or takes lunch break
  /// 
  /// Action should be: 'time-in', 'time-out', 'lunch-in', 'lunch-out'
  Future<DailyTimeRecord> punch({
    required String action,
  }) async {
    try {
      return await _apiClient.post<DailyTimeRecord>(
        path: '/student/dtr/$action',
        converter: (data) => _parseDtrResponse(data),
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  /// Punch in for the day
  Future<DailyTimeRecord> timeIn() => punch(action: 'time-in');

  /// Punch out for lunch
  Future<DailyTimeRecord> lunchOut() => punch(action: 'lunch-out');

  /// Punch in from lunch
  Future<DailyTimeRecord> lunchIn() => punch(action: 'lunch-in');

  /// Punch out for the day
  Future<DailyTimeRecord> timeOut() => punch(action: 'time-out');

  /// Exports DTR as PDF for given month/year
  /// 
  /// Throws [ApiException] if export fails
  /// Returns DtrExportFile with bytes and filename
  Future<DtrExportFile> exportPdf({
    required int month,
    required int year,
  }) =>
      _exportMonthly(
        month: month,
        year: year,
        format: 'pdf',
        fallbackMimeType: 'application/pdf',
      );

  /// Exports DTR as Excel/CSV for given month/year
  /// 
  /// Throws [ApiException] if export fails
  /// Returns DtrExportFile with bytes and filename
  Future<DtrExportFile> exportExcel({
    required int month,
    required int year,
  }) =>
      _exportMonthly(
        month: month,
        year: year,
        format: 'excel',
        fallbackMimeType: 'text/csv',
      );

  /// Downloads and returns DTR export file
  Future<DtrExportFile> _exportMonthly({
    required int month,
    required int year,
    required String format,
    required String fallbackMimeType,
  }) async {
    try {
      final bytes = await _apiClient.download(
        path: '/student/dtr/export/$format?month=$month&year=$year',
      );

      final filename =
          'dtr_$year-${month.toString().padLeft(2, '0')}.${format == 'pdf' ? 'pdf' : 'csv'}';

      return DtrExportFile(
        bytes: bytes,
        filename: filename,
        mimeType: fallbackMimeType,
      );
    } on ApiException catch (e) {
      handleApiError(e);
      rethrow;
    }
  }

  /// Parses DTR response and returns DailyTimeRecord
  DailyTimeRecord _parseDtrResponse(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw ApiException(
        message: 'Invalid DTR response format',
        errorType: ApiErrorType.unknown,
      );
    }

    final responseData = data['data'] as Map<String, dynamic>?;
    if (responseData == null) {
      throw ApiException(
        message: 'No DTR data in response',
        errorType: ApiErrorType.unknown,
      );
    }

    try {
      return DailyTimeRecord.fromJson(responseData);
    } catch (e) {
      throw ApiException(
        message: 'Failed to parse DTR record',
        errorType: ApiErrorType.unknown,
        originalError: e,
      );
    }
  }
}
