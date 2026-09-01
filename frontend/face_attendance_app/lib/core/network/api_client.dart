import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central HTTP client.
///
/// The base URL can be overridden at build time:
///
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.7:8000/api/
///
/// - `10.0.2.2` reaches the host machine from the Android emulator.
/// - Use your machine's LAN IP (e.g. `192.168.1.7`) for a physical device.
class ApiClient {
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/',
  );

  late final Dio dio;
  final String _baseUrl;

  ApiClient({String? baseUrl}) : _baseUrl = baseUrl ?? defaultBaseUrl {
    dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        // The backend must never redirect an API call; if it does, treat it
        // as an error instead of silently following it.
        followRedirects: false,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('access_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          final statusCode = error.response?.statusCode;
          final requestOptions = error.requestOptions;

          // Never attempt a refresh loop for the auth endpoints themselves.
          final isAuthPath = requestOptions.path.contains('auth/login') ||
              requestOptions.path.contains('auth/token/refresh');

          if (statusCode == 401 && !isAuthPath && !requestOptions.extra.containsKey('_retried')) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              // Retry the original request exactly once with the new token.
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
  }

  /// Attempts to obtain a fresh access token using the stored refresh token.
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
      // SimpleJWT rotates the refresh token when ROTATE_REFRESH_TOKENS is on.
      final newRefresh = response.data['refresh'];
      if (newRefresh != null) {
        await prefs.setString('refresh_token', newRefresh);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
