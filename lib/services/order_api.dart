import 'dart:convert';
import 'package:dio/dio.dart';

class OrderApiDio {
  OrderApiDio._();

  static final OrderApiDio I = OrderApiDio._();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl:
          'https://api.haldeki.com/', // 'https://api.haldeki.com//public/api/v1',
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      },
    ),
  );

  /// Restoran (misafir) siparişi gönder
  Future<Map<String, dynamic>> createOrderRestaurant({
    required String name,
    required String email,
    String? phone,
    String? address,
    String? note,
    num? totalAmount,
    int? resellerId,
    required List<Map<String, dynamic>> items,
  }) async {
    final payload = <String, dynamic>{
      'restaurant': {
        'name': name,
        'email': email,
        if (phone != null) 'phone': phone,
        if (address != null) 'address': address,
      },
      'reseller_id': 1,
      if (note != null && note.isNotEmpty) 'note': note,
      'total_amount': totalAmount ?? _sumTotal(items),
      'items': items,
    };

    // ---- DEBUG ----
    print("== DIO PAYLOAD ==");
    print(const JsonEncoder.withIndent('  ').convert(payload));
    // ----------------

    try {
      final response = await _dio.post('/orders', data: payload);

      // Eğer backend JSON döndürdüyse map'e çevir
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      if (response.data is String && response.data.toString().isNotEmpty) {
        return jsonDecode(response.data) as Map<String, dynamic>;
      }
      return {'success': true};
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response?.data;
        throw Exception(
            'Sipariş hatası: ${data is Map ? data['message'] ?? data['error'] : data}');
      }
      throw Exception('Network/Dio hatası: ${e.message}');
    }
  }

  num _sumTotal(List<Map<String, dynamic>> items) {
    num sum = 0;
    for (final it in items) {
      final tp = it['total_price'];
      if (tp is num) sum += tp;
    }
    return sum;
  }
}
