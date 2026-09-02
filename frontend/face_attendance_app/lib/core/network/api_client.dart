import 'dart:developer' as developer;
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CachedResponse {
  final dynamic data;
  final DateTime timestamp;
  final Duration cacheDuration;

  CachedResponse({
    required this.data,
    required this.timestamp,
    required this.cacheDuration,
  });

  bool get isExpired => DateTime.now().isAfter(timestamp.add(cacheDuration));
}

/// Central HTTP client.
///
/// The base URL is resolved in this order:
///   1. Runtime override stored in SharedPreferences (set via a settings screen)
///   2. Compile-time `--dart-define=API_BASE_URL=...`
///   3. Built-in default that detects emulator vs physical device
///
/// Examples:
///
///   # Physical tablet on LAN:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000/api/
///
///   # Android emulator:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/
class ApiClient {
  static const String _compileTimeDefault = String.fromEnvironment(
    'API_BASE_URL',
    // Fallback used when no --dart-define is passed. This is the LAN IP of
    // the Django backend so physical tablets on the same Wi-Fi work out of
    // the box. Override with:
    //   flutter run --dart-define=API_BASE_URL=http://<YOUR_LAN_IP>:8000/api/
    defaultValue: 'http://192.168.1.5:8000/api/',
  );

  /// SharedPreferences key used to persist a user-chosen server URL.
  static const String prefKey = 'api_base_url';

  late final Dio dio;
  final String _baseUrl;
  final Map<String, CachedResponse> _cache = {};
  final Map<String, CancelToken> _pendingRequests = {};

  /// [overrideUrl] is only used in tests / direct construction.
  ApiClient({String? overrideUrl})
      : _baseUrl = overrideUrl ?? _compileTimeDefault {
    dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        followRedirects: false,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // ── Debug logging interceptor ──────────────────────────────────
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: true,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
          logPrint: (obj) => developer.log('$obj', name: 'DIO'),
        ),
      );
    }

    // ── JWT + refresh interceptor ──────────────────────────────────
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Request deduplication - prevent duplicate simultaneous requests
          final cacheKey = _getCacheKey(options);
          if (_pendingRequests.containsKey(cacheKey)) {
            _log('CACHE', 'Request deduplication: $cacheKey');
            return; // Skip duplicate request
          }

          final cancelToken = CancelToken();
          _pendingRequests[cacheKey] = cancelToken;

          // Check cache for GET requests
          if (options.method == 'GET' && !options.extra.containsKey('skipCache')) {
            final cached = _cache[cacheKey];
            if (cached != null && !cached.isExpired) {
              _log('CACHE', 'Cache hit: $cacheKey');
              _pendingRequests.remove(cacheKey);
              return handler.resolve(
                Response(
                  requestOptions: options,
                  data: cached.data,
                  statusCode: 200,
                ),
              );
            }
          }

          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('access_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          _log('REQUEST', '${options.method} ${options.uri}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          final cacheKey = _getCacheKey(response.requestOptions);
          _pendingRequests.remove(cacheKey);

          // Cache successful GET responses
          if (response.requestOptions.method == 'GET' && 
              response.statusCode == 200 &&
              !response.requestOptions.extra.containsKey('skipCache')) {
            final cacheDuration = response.requestOptions.extra['cacheDuration'] ?? const Duration(minutes: 5);
            _cache[cacheKey] = CachedResponse(
              data: response.data,
              timestamp: DateTime.now(),
              cacheDuration: cacheDuration as Duration,
            );
            _log('CACHE', 'Cached response: $cacheKey');
          }

          _log('RESPONSE', '${response.statusCode} ${response.requestOptions.uri}');
          return handler.next(response);
        },
        onError: (DioException error, handler) async {
          final cacheKey = _getCacheKey(error.requestOptions);
          _pendingRequests.remove(cacheKey);
          _logError(error);

          final statusCode = error.response?.statusCode;
          final requestOptions = error.requestOptions;

          final isAuthPath = requestOptions.path.contains('auth/login') ||
              requestOptions.path.contains('auth/token/refresh');

          if (statusCode == 401 &&
              !isAuthPath &&
              !requestOptions.extra.containsKey('_retried')) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              final prefs = await SharedPreferences.getInstance();
              final newToken = prefs.getString('access_token');
              if (newToken != null && newToken.isNotEmpty) {
                requestOptions.headers['Authorization'] = 'Bearer $newToken';
              }
              requestOptions.extra['_retried'] = true;
              try {
                final retryResponse = await dio.fetch(requestOptions);
                return handler.resolve(retryResponse);
              } catch (_) {
                return handler.next(error);
              }
            }
          }

          return handler.next(error);
        },
      ),
    );

    _log('INIT', 'Base URL: $_baseUrl');
  }

  // ── Factory that reads from SharedPreferences at runtime ────────

  /// Creates an [ApiClient] whose base URL is resolved from:
  ///   1. SharedPreferences override
  ///   2. `--dart-define`
  ///   3. Built-in default
  static Future<ApiClient> fromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(prefKey);
    final url = (stored != null && stored.isNotEmpty) ? stored : _compileTimeDefault;
    return ApiClient(overrideUrl: url);
  }

  /// Persists a new server URL so subsequent [fromPrefs] calls use it.
  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, url);
    _log('CONFIG', 'Server URL updated to: $url');
  }

  /// Returns the effective base URL (for display / debugging).
  String get baseUrl => _baseUrl;

  /// Clears the response cache
  void clearCache() {
    _cache.clear();
    _log('CACHE', 'Cache cleared');
  }

  // ── Private helpers ─────────────────────────────────────────────

  Future<bool> _tryRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refresh = prefs.getString('refresh_token');
      if (refresh == null || refresh.isEmpty) return false;

      final refreshDio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          followRedirects: false,
          headers: {'Accept': 'application/json'},
        ),
      );

      final response = await refreshDio.post(
        'auth/token/refresh/',
        data: {'refresh': refresh},
      );

      final access = response.data['access'];
      if (access == null) return false;

      await prefs.setString('access_token', access);
      final newRefresh = response.data['refresh'];
      if (newRefresh != null) {
        await prefs.setString('refresh_token', newRefresh);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static void _log(String tag, String message) {
    if (kDebugMode) {
      developer.log(message, name: 'API[$tag]');
    }
  }

  static void _logError(DioException error) {
    final uri = error.requestOptions.uri;
    final method = error.requestOptions.method;
    final type = error.type.name;

    String detail;
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        detail = 'Connection timed out after ${error.requestOptions.connectTimeout}';
        break;
      case DioExceptionType.sendTimeout:
        detail = 'Send timed out after ${error.requestOptions.sendTimeout}';
        break;
      case DioExceptionType.receiveTimeout:
        detail = 'Receive timed out after ${error.requestOptions.receiveTimeout}';
        break;
      case DioExceptionType.connectionError:
        detail = 'Connection error – is the server running and reachable at $uri?';
        break;
      case DioExceptionType.badResponse:
        detail = 'HTTP ${error.response?.statusCode} from $uri – '
            '${error.response?.data}';
        break;
      case DioExceptionType.cancel:
        detail = 'Request cancelled';
        break;
      case DioExceptionType.badCertificate:
        detail = 'Bad SSL certificate';
        break;
      case DioExceptionType.unknown:
      default:
        detail = '${error.error}';
        break;
    }

    _log('ERROR', '[$type] $method $uri → $detail');
  }

  String _getCacheKey(RequestOptions options) {
    return '${options.method}_${options.uri}_${options.queryParameters}';
  }
}
