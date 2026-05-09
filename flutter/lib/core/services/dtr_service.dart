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
  Future<DailyTimeRecord> punch({required String action}) async {
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

  /// Exports DTR as PDF for a monthly or filtered range export
  ///
  /// Throws [ApiException] if export fails
  /// Returns DtrExportFile with bytes and filename
  Future<DtrExportFile> exportPdf({
    int? month,
    int? year,
    DateTime? startDate,
    DateTime? endDate,
  }) => _exportMonthly(
    month: month,
    year: year,
    startDate: startDate,
    endDate: endDate,
    format: 'pdf',
    fallbackMimeType: 'application/pdf',
  );

  /// Exports DTR as Excel/CSV for a monthly or filtered range export
  ///
  /// Throws [ApiException] if export fails
  /// Returns DtrExportFile with bytes and filename
  Future<DtrExportFile> exportExcel({
    int? month,
    int? year,
    DateTime? startDate,
    DateTime? endDate,
  }) => _exportMonthly(
    month: month,
    year: year,
    startDate: startDate,
    endDate: endDate,
    format: 'excel',
    fallbackMimeType: 'text/csv',
  );

  /// Downloads and returns DTR export file
  Future<DtrExportFile> _exportMonthly({
    int? month,
    int? year,
    DateTime? startDate,
    DateTime? endDate,
    required String format,
    required String fallbackMimeType,
  }) async {
    final queryParameters = _buildExportQueryParameters(
      month: month,
      year: year,
      startDate: startDate,
      endDate: endDate,
    );
    final resolvedYear = year ?? startDate!.year;
    final resolvedMonth = month ?? startDate!.month;

    try {
      final bytes = await _apiClient.download(
        path: '/student/dtr/export/$format',
        queryParameters: queryParameters,
      );

      final filename =
          'dtr_$resolvedYear-${resolvedMonth.toString().padLeft(2, '0')}.${format == 'pdf' ? 'pdf' : 'csv'}';

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

  Map<String, dynamic> _buildExportQueryParameters({
    int? month,
    int? year,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final hasDateRange = startDate != null || endDate != null;

    if (hasDateRange) {
      if (startDate == null || endDate == null) {
        throw ApiException(
          message:
              'Both start and end dates are required for filtered exports.',
          errorType: ApiErrorType.clientError,
          isRecoverable: false,
        );
      }

      return <String, dynamic>{
        'start_date': _formatDate(startDate),
        'end_date': _formatDate(endDate),
      };
    }

    if (month == null || year == null) {
      throw ApiException(
        message: 'Month and year are required when no date range is provided.',
        errorType: ApiErrorType.clientError,
        isRecoverable: false,
      );
    }

    return <String, dynamic>{'month': month, 'year': year};
  }

  String _formatDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
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
