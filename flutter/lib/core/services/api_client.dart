import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../exceptions/api_error_mapper.dart';

class ApiClient {
  ApiClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            );

  final Dio _dio;

  Dio get client => _dio;

  /// Adds an interceptor to the Dio client
  void addInterceptor(Interceptor interceptor) {
    _dio.interceptors.add(interceptor);
  }

  /// Wraps GET request with error handling
  Future<T> get<T>({
    required String path,
    Map<String, dynamic>? queryParameters,
    Options? options,
    required T Function(dynamic) converter,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return converter(response.data);
    } catch (e) {
      throw ApiErrorMapper.fromException(e);
    }
  }

  /// Wraps POST request with error handling
  Future<T> post<T>({
    required String path,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    required T Function(dynamic) converter,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return converter(response.data);
    } catch (e) {
      throw ApiErrorMapper.fromException(e);
    }
  }

  /// Wraps PATCH request with error handling
  Future<T> patch<T>({
    required String path,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    required T Function(dynamic) converter,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return converter(response.data);
    } catch (e) {
      throw ApiErrorMapper.fromException(e);
    }
  }

  /// Wraps PUT request with error handling
  Future<T> put<T>({
    required String path,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    required T Function(dynamic) converter,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return converter(response.data);
    } catch (e) {
      throw ApiErrorMapper.fromException(e);
    }
  }

  /// Wraps DELETE request with error handling
  Future<T> delete<T>({
    required String path,
    Map<String, dynamic>? queryParameters,
    Options? options,
    required T Function(dynamic) converter,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return converter(response.data);
    } catch (e) {
      throw ApiErrorMapper.fromException(e);
    }
  }

  /// For file downloads that return raw bytes
  Future<List<int>> download({
    required String path,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final response = await downloadResponse(
      path: path,
      queryParameters: queryParameters,
      options: options,
    );
    return response.data ?? [];
  }

  Future<Response<List<int>>> downloadResponse({
    required String path,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<List<int>>(
        path,
        queryParameters: queryParameters,
        options: (options ?? Options()).copyWith(
          responseType: ResponseType.bytes,
        ),
      );
    } catch (e) {
      throw ApiErrorMapper.fromException(e);
    }
  }
}
