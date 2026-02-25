import 'dart:convert';

class ClientOrderLite {
  final int id;
  final String status;
  final String? orderNo; // extra_charges.order_no
  final double totalAmount;
  final DateTime? pickupAt;
  final DateTime? deliveredAt;
  final String fromName; // pickup_point.name
  final String toName; // delivery_point.name

  ClientOrderLite({
    required this.id,
    required this.status,
    required this.totalAmount,
    required this.fromName,
    required this.toName,
    this.orderNo,
    this.pickupAt,
    this.deliveredAt,
  });

  // küçük yardımcılar
  static Map<String, dynamic> _parseMaybeJson(dynamic v) {
    if (v == null) return const {};
    if (v is Map<String, dynamic>) return v;
    if (v is String && v.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(v);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return const {};
  }

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  static double _numToDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  factory ClientOrderLite.fromAny(Map<String, dynamic> j) {
    final pickup = _parseMaybeJson(j['pickup_point']);
    final delivery = _parseMaybeJson(j['delivery_point']);
    final extra = _parseMaybeJson(j['extra_charges']);

    return ClientOrderLite(
      id: (j['id'] as num).toInt(),
      status: (j['status'] ?? 'create').toString(),
      orderNo: (j['order_no'] ?? extra['order_no'])?.toString(),
      totalAmount: _numToDouble(j['total_amount']),
      pickupAt: _dt(j['pickup_datetime'] ?? j['pickup_at']),
      deliveredAt: _dt(j['delivery_datetime'] ?? j['delivered_at']),
      fromName: (pickup['name'] ?? pickup['title'] ?? 'Çıkış').toString(),
      toName: (delivery['name'] ?? delivery['title'] ?? 'Varış').toString(),
    );
  }
}
