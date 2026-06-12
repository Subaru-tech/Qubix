import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Creates a configured Dio instance with base URL and auth interceptor.
Dio createDioClient(String baseUrl, String? token) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
      receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
      sendTimeout: const Duration(milliseconds: AppConstants.sendTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Auth interceptor
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        // TODO: handle 401 → logout
        return handler.next(error);
      },
    ),
  );

  return dio;
}

/// Provider for SharedPreferences.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden at startup');
});

/// Provider for server base URL.
class ServerUrlNotifier extends Notifier<String> {
  @override
  String build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getString(AppConstants.keyServerUrl) ?? AppConstants.defaultServerUrl;
  }
  void update(String url) => state = url;
}
final serverUrlProvider = NotifierProvider<ServerUrlNotifier, String>(ServerUrlNotifier.new);

/// Provider for auth token.
class AuthTokenNotifier extends Notifier<String?> {
  @override
  String? build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getString(AppConstants.keyAuthToken);
  }
  void update(String? token) => state = token;
}
final authTokenProvider = NotifierProvider<AuthTokenNotifier, String?>(AuthTokenNotifier.new);

/// Provider for the Dio HTTP client — rebuilds when URL or token changes.
final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(serverUrlProvider);
  final token = ref.watch(authTokenProvider);
  return createDioClient(baseUrl, token);
});
