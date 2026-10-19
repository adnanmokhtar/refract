import 'package:dio/dio.dart';

import '../auth/session.dart';

/// The driver API. Every screen and the background sync share this one client.
class ApiClient {
  ApiClient(this._session)
      : _dio = Dio(BaseOptions(
          baseUrl: const String.fromEnvironment('API_URL', defaultValue: 'https://driver-api.pantrygo.example'),
          headers: {'X-Client': 'driver'},
        )) {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      final bearer = _session.bearer;
      if (bearer != null) options.headers['Authorization'] = 'Bearer $bearer';
      handler.next(options);
    }));
  }

  final DriverSession _session;
  final Dio _dio;

  Future<List<Map<String, dynamic>>> todaysStops() async {
    final response = await _dio.get<List<dynamic>>('/driver/stops/today');
    return (response.data ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> stop(int id) async {
    final response = await _dio.get<Map<String, dynamic>>('/driver/stops/$id');
    return response.data ?? const {};
  }

  Future<Duration> eta(String stopId) async {
    final response = await _dio.get<Map<String, dynamic>>('/driver/stops/$stopId/eta');
    return Duration(seconds: (response.data?['seconds'] as int?) ?? 0);
  }

  Future<void> post(String path, Map<String, dynamic> body, {Map<String, String>? headers}) async {
    await _dio.post<void>(path, data: body, options: Options(headers: headers));
  }
}

final api = ApiClient(driverSession);
