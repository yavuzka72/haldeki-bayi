// lib/api/dashboard_api.dart
import 'package:dio/dio.dart';
import '../services/api_client.dart';

class DashboardApi {
  DashboardApi._();
  static final DashboardApi I = DashboardApi._();

  Dio get _dio =>
      ApiClient().dio; // ApiClient içindeki Dio (auth, baseUrl vs. hazır)

  /// Restoran özeti (order_count, total_amount, by_status…)
  /// status: null → tüm statüler; 'pending' | 'confirmed' | 'away' | 'delivered' | 'cancelled'
  Future<Map<String, dynamic>> summaryForRestaurant({
    required String email,
    String? status,
  }) async {
    final e = email.trim();
    if (e.isEmpty) {
      throw ArgumentError('email gerekli');
    }

    final body = <String, dynamic>{
      'email': e,
      if (status != null && status.isNotEmpty && status != 'all')
        'status': status,
    };

    // Önce POST, sonra GET fallback
    final res = await _getFirstSuccess([
      // POST tercihli
      () => _dio.post('summary', data: body),
      () => _dio.post('analytics/summary', data: body),
      () => _dio.post('summary', data: body),
      // Fallback GET
      () => _dio.get('dashboard/summary', queryParameters: body),
      () => _dio.get('analytics/summary', queryParameters: body),
      () => _dio.get('summary', queryParameters: body),
    ]);

    return _unwrapMap(res.data);
  }

  /// En çok sipariş verilen ürünler
  /// Dönüş: [{ product_name, image_url?, total_qty, order_count, total_amount }, ...]
  Future<List<Map<String, dynamic>>> topProductsForRestaurant({
    required String email,
    required String status, // 'all' veya yukarıdaki statüler
    int limit = 10,
  }) async {
    final e = email.trim();
    if (e.isEmpty) {
      throw ArgumentError('email gerekli');
    }

    final body = <String, dynamic>{
      'email': e,
      if (status.isNotEmpty) 'status': status,
      'limit': limit,
    };

    // Önce POST, sonra GET fallback
    final res = await _getFirstSuccess([
      // POST tercihli
//      () => _dio.post('dashboard/top-products', data: body),
      //    () => _dio.post('analytics/top-products', data: body),
      () => _dio.post('top-products', data: body),
      // Fallback GET
      //  () => _dio.get ('top-products', queryParameters: body),
      //  () => _dio.get ('analytics/top-products', queryParameters: body),
      () => _dio.get('top-products', queryParameters: body),
    ]);

    final payload = res.data;
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (payload is Map) {
      final m = Map<String, dynamic>.from(payload);
      final list = (m['data'] ?? m['items'] ?? m['results']);
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }

  // ---------- Helpers ----------

  /// Sırayla çağrıları dener; ilk başarılı Response'u döndürür.
  Future<Response<dynamic>> _getFirstSuccess(
    List<Future<Response<dynamic>> Function()> calls,
  ) async {
    DioException? lastErr;
    for (final fn in calls) {
      try {
        final r = await fn();
        return r;
      } on DioException catch (e) {
        lastErr = e; // bir sonrakini dene
      }
    }
    throw lastErr ??
        DioException(
          requestOptions: RequestOptions(path: ''),
          error: 'No endpoint matched',
        );
  }

  Map<String, dynamic> _unwrapMap(dynamic data) {
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      final d = m['data'];
      if (d is Map) return Map<String, dynamic>.from(d);
      return m;
    }
    return <String, dynamic>{};
  }
}
