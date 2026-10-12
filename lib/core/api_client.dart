import 'dart:async';

import 'package:dio/dio.dart';

import 'config.dart';
import 'token_store.dart';

/// An error the user can read. The backend sends {"success":false,"error":"...","data":{field: message}}.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.fieldErrors = const {}});

  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors;

  @override
  String toString() {
    if (fieldErrors.isEmpty) return message;
    return '$message: ${fieldErrors.entries.map((e) => '${e.key} ${e.value}').join(', ')}';
  }
}

/// Dio with bearer auth and transparent token refresh. On a 401 it refreshes once (shared by concurrent
/// requests) and retries; if the refresh fails the session ends via [onSessionExpired].
class ApiClient {
  ApiClient(this._tokens, {required this.onSessionExpired})
      : dio = Dio(BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        )) {
    dio.interceptors.add(QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokens.accessToken;
        if (token != null && options.extra['noAuth'] != true) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final request = error.requestOptions;
        final isAuthCall = request.path.startsWith('/auth/login') || request.path.startsWith('/auth/refresh');
        if (error.response?.statusCode == 401 && !isAuthCall && request.extra['retried'] != true) {
          if (await _refresh()) {
            request.extra['retried'] = true;
            request.headers['Authorization'] = 'Bearer ${await _tokens.accessToken}';
            try {
              // A separate Dio: retrying through this one would queue behind the handler we're inside
              return handler.resolve(await _plain.fetch(request));
            } on DioException catch (e) {
              return handler.next(e);
            }
          }
          onSessionExpired();
        }
        handler.next(error);
      },
    ));
  }

  final Dio dio;
  final Dio _plain = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
  final TokenStore _tokens;
  final void Function() onSessionExpired;
  Future<bool>? _refreshing;

  Future<bool> _refresh() {
    return _refreshing ??= () async {
      try {
        final refreshToken = await _tokens.refreshToken;
        if (refreshToken == null) return false;
        final response = await _plain.post('/auth/refresh', data: {'refreshToken': refreshToken});
        await _tokens.save(response.data['accessToken'], response.data['refreshToken']);
        return true;
      } catch (_) {
        await _tokens.clear();
        return false;
      } finally {
        _refreshing = null;
      }
    }();
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _wrap(() => dio.get(path, queryParameters: _clean(query)));

  Future<T> post<T>(String path, {Object? body, Map<String, dynamic>? query, bool auth = true}) =>
      _wrap(() => dio.post(path, data: body, queryParameters: _clean(query), options: Options(extra: {'noAuth': !auth})));

  Future<T> put<T>(String path, {Object? body}) => _wrap(() => dio.put(path, data: body));

  Future<T> delete<T>(String path) => _wrap(() => dio.delete(path));

  /// Raw bytes for authenticated file downloads (driver documents).
  Future<List<int>> bytes(String path) async {
    final response = await _wrap<dynamic>(
        () => dio.get(path, options: Options(responseType: ResponseType.bytes)));
    return (response as List).cast<int>();
  }

  Future<T> _wrap<T>(Future<Response> Function() call) async {
    try {
      final response = await call();
      return response.data as T;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  static Map<String, dynamic>? _clean(Map<String, dynamic>? query) =>
      query == null ? null : (Map.of(query)..removeWhere((_, v) => v == null || v == ''));

  static ApiException _toApiException(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final fields = data['data'] is Map
          ? (data['data'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()))
          : <String, String>{};
      return ApiException(data['error']?.toString() ?? 'Something went wrong',
          statusCode: e.response?.statusCode, fieldErrors: fields);
    }
    if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
      return ApiException("Can't reach SchoolDrop. Check your internet connection.");
    }
    return ApiException('Something went wrong (${e.response?.statusCode ?? e.type.name})',
        statusCode: e.response?.statusCode);
  }
}
