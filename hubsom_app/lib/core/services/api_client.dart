import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'local_store.dart';

class ApiClient {
  ApiClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 12),
                // Do not set Content-Type globally — it forces CORS preflight
                // on every GET and breaks when Hosting has no /api backend yet.
                headers: {
                  'Accept': 'application/json',
                },
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = LocalStore.sessionToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
            options.headers['Cookie'] = 'authjs.session-token=$token';
          }
          if (AppConfig.adminApiKey.isNotEmpty) {
            options.headers['X-Hubsom-Admin-Key'] = AppConfig.adminApiKey;
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _dio.get<T>(
        path,
        queryParameters: queryParameters,
        // Plain text avoids JSON-parse crashes when Hosting returns index.html
        options: Options(responseType: ResponseType.plain, validateStatus: (s) => s != null && s < 500),
      );

  Options get _jsonBody => Options(
        contentType: Headers.jsonContentType,
        headers: {'Content-Type': 'application/json'},
      );

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) =>
      _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: data == null ? null : _jsonBody,
      );

  Future<Response<T>> put<T>(String path, {Object? data}) =>
      _dio.put<T>(path, data: data, options: data == null ? null : _jsonBody);

  Future<Response<T>> patch<T>(String path, {Object? data}) =>
      _dio.patch<T>(path, data: data, options: data == null ? null : _jsonBody);

  Future<Response<T>> delete<T>(String path, {Object? data}) =>
      _dio.delete<T>(path, data: data);
}
