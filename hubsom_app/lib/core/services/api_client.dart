import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'local_store.dart';

typedef UnauthorizedHandler = Future<void> Function();

class ApiClient {
  ApiClient({Dio? dio, UnauthorizedHandler? onUnauthorized})
      : _onUnauthorized = onUnauthorized,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 12),
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
            // Auth.js session cookie bridge when same-site API is available.
            options.headers['Cookie'] =
                'authjs.session-token=$token; next-auth.session-token=$token';
          }
          if (AppConfig.adminApiKey.isNotEmpty) {
            options.headers['X-Hubsom-Admin-Key'] = AppConfig.adminApiKey;
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          if (status == 401 || status == 403) {
            final path = error.requestOptions.path;
            final isAuthCall = path.contains('/api/auth/');
            if (!isAuthCall) {
              if (kDebugMode) {
                debugPrint('API unauthorized on $path — clearing session');
              }
              await LocalStore.clearSession();
              final cb = _onUnauthorized;
              if (cb != null) await cb();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final UnauthorizedHandler? _onUnauthorized;

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (s) => s != null && s < 500,
        ),
      );

  Options get _jsonBody => Options(
        contentType: Headers.jsonContentType,
        headers: {'Content-Type': 'application/json'},
        validateStatus: (s) => s != null && s < 500,
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
