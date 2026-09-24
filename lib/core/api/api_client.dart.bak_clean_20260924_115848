import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vpn_agent_app/core/api/api_config.dart';
import 'package:vpn_agent_app/features/auth/services/auth_service.dart';
import 'package:vpn_agent_app/features/auth/screens/login_screen.dart';
import 'package:vpn_agent_app/main.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio _dio;

  Dio get dio => _dio;

  /// Runtime base-URL swap used by _FallbackInterceptor. BaseOptions.baseUrl
  /// is seeded once at construction, so without this the singleton would be
  /// pinned to whatever RemoteConfig held at first use.
  void updateBaseUrl(String newUrl) {
    _dio.options.baseUrl = newUrl;
    debugPrint('ApiClient: baseUrl switched to $newUrl');
  }

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        // Backend is now using Queue, so response is instant.
        // 15 seconds is enough.
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        validateStatus: (status) {
          return status != null && status < 500;
        },
      ),
    );

    _dio.interceptors.add(_FallbackInterceptor(this));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await AuthService().getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['Accept'] = 'application/json';
          return handler.next(options);
        },
        onResponse: (response, handler) async {
          if (response.statusCode == 401) {
            if (kDebugMode) print("Token Expired: Auto Logout");
            await AuthService().logout();
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            await AuthService().logout();
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
          return handler.next(e);
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
  }
}

/// Rotates baseUrl across the RemoteConfig domain chain when the primary is
/// DPI-blocked. Ported verbatim in behaviour from the user app
/// (VPN_Portal_VLESS lib/core/api/api_client.dart), which is device-verified
/// on a real Myanmar network.
class _FallbackInterceptor extends Interceptor {
  final ApiClient _client;
  // Guard so retries issued from within a fallback don't re-enter onError
  // and cause an infinite rotation loop.
  bool _inFallback = false;

  _FallbackInterceptor(this._client);

  // Ordered, de-duplicated, non-empty base URLs. Primary first, then backups.
  // backup2/backup3 are empty until published, so they drop out automatically.
  List<String> get _candidates {
    final raw = <String>[
      ApiConfig.baseUrl,
      ApiConfig.backupUrl,
      ApiConfig.backupUrl2,
      ApiConfig.backupUrl3,
    ];
    final seen = <String>{};
    final out = <String>[];
    for (final u in raw) {
      if (u.isEmpty) continue;
      if (seen.add(u)) out.add(u);
    }
    return out;
  }

  bool _shouldFallback(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.unknown) {
      return true;
    }
    // ISP transparent-proxy blocks sometimes inject a gateway error instead
    // of resetting the connection. 502/503 arrive as a DioException because
    // validateStatus only accepts < 500.
    final code = err.response?.statusCode;
    if (code == 502 || code == 503) return true;
    return false;
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_inFallback || !_shouldFallback(err)) {
      handler.next(err);
      return;
    }

    final candidates = _candidates;
    final currentUrl = _client.dio.options.baseUrl;
    final targets = candidates.where((u) => u != currentUrl).toList();

    if (targets.isEmpty) {
      handler.next(err);
      return;
    }

    _inFallback = true;
    try {
      for (final url in targets) {
        debugPrint('FallbackInterceptor: switching to backup: $url');
        _client.updateBaseUrl(url);
        try {
          final options = Options(
            method: err.requestOptions.method,
            headers: err.requestOptions.headers,
          );
          final response = await _client.dio.request(
            err.requestOptions.path,
            data: err.requestOptions.data,
            queryParameters: err.requestOptions.queryParameters,
            options: options,
          );
          return handler.resolve(response);
        } catch (_) {
          debugPrint('FallbackInterceptor: candidate failed: $url');
        }
      }
      debugPrint('FallbackInterceptor: all candidates failed');
      _client.updateBaseUrl(ApiConfig.baseUrl);
      handler.next(err);
    } finally {
      _inFallback = false;
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Reset to primary after a success so a recovered primary is tried first
    // next time (fixes the "stuck on backup" bug).
    if (_client.dio.options.baseUrl != ApiConfig.baseUrl) {
      _client.updateBaseUrl(ApiConfig.baseUrl);
    }
    handler.next(response);
  }
}
