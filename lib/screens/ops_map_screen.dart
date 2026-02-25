import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../config.dart';
import 'haldeki_ui.dart';

class OpsMapScreen extends StatefulWidget {
  const OpsMapScreen({super.key});

  @override
  State<OpsMapScreen> createState() => _OpsMapScreenState();
}

/// -------------------------
/// PRIMARY UI COLORS
/// -------------------------
class KOpsColors {
  static const Color purple = Color(0xFF6e188a);
  static const Color purple2 = Color(0xFF6e188a);
  static const Color orange = Color(0xFF6e188a);

  static const Color bg = Color(0xFFF6F7FB);
  static const Color card = Color(0xFFFFFFFF);
  static const Color soft = Color(0xFFF8FAFC);
  static const Color line = Color(0xFFE6E8EF);

  static const Color text = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);

  static Color withOpacity(Color c, double o) => c.withOpacity(o);
}

/// -------------------------
/// MODELLER (OpsMap içinde)
/// -------------------------

class CourierLive {
  final int id;
  final String name;
  final double lat;
  final double lng;
  final bool isActive;
  final bool canTakeOrders;
  final int? dealerId;

  CourierLive({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.isActive,
    required this.canTakeOrders,
    required this.dealerId,
  });

  static int? _i(dynamic v) => v == null ? null : int.tryParse('$v');
  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final raw = v.toString().trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw.replaceAll(',', '.'));
  }

  static bool _b(dynamic v, {bool def = false}) {
    if (v == null) return def;
    if (v is bool) return v;
    final s = v.toString().toLowerCase().trim();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return def;
  }

  /// ✅ latitude/longitude yoksa location_lat/location_lng'den alır
  static CourierLive? tryParse(Map<String, dynamic> j) {
    final id = _i(j['id']);
    if (id == null) return null;

    final name = (j['name'] ?? j['username'] ?? 'Kurye').toString();

    final isActive = _b(j['is_active'], def: true);
    final canTake = _b(j['can_take_orders'], def: true);
    final dealerId = _i(j['dealer_id']);

    var lat = _d(j['latitude']);
    var lng = _d(j['longitude']);

    lat ??= _d(j['location_lat']);
    lng ??= _d(j['location_lng']);

    if (lat == null || lng == null) return null;

    return CourierLive(
      id: id,
      name: name,
      lat: lat,
      lng: lng,
      isActive: isActive,
      canTakeOrders: canTake,
      dealerId: dealerId,
    );
  }
}

/// Orders tablosundan “bekleyen” siparişler (delivery_status=0)
class PendingOrder {
  final String id;
  final String orderNumber;
  final String? shippingAddress;
  final String? buyerName;
  final String? buyerCity;
  final String? buyerDistrict;
  final double totalAmount;
  final int deliveryStatus;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropLat;
  final double? dropLng;
  final String? created_at;

  PendingOrder({
    required this.id,
    required this.orderNumber,
    required this.totalAmount,
    required this.deliveryStatus,
    this.shippingAddress,
    this.buyerName,
    this.buyerCity,
    this.buyerDistrict,
    this.pickupLat,
    this.pickupLng,
    this.dropLat,
    this.dropLng,
    this.created_at,
  });

  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final raw = v.toString().trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw.replaceAll(',', '.'));
  }

  static int _int(dynamic v, {int def = 0}) {
    if (v == null) return def;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? def;
  }

  static String _s(dynamic v) => (v ?? '').toString();

  static PendingOrder? tryParse(Map<String, dynamic> j) {
    final id = _s(j['id']);
    final orderNumber =
        _s(j['order_number'] ?? j['orderNumber'] ?? j['number']);
    if (id.isEmpty || orderNumber.isEmpty) return null;

    final total = _d(j['total_amount'] ?? j['total'] ?? j['grand_total']);
    final deliveryStatus = _int(j['delivery_status'], def: 0);

    final shippingAddress = _s(j['shipping_address'] ?? j['address']);
    final buyerName = _s(j['buyer_name'] ?? j['name'] ?? j['ad_soyad']);
    final buyerCity = _s(j['buyer_city'] ?? j['city']);
    final buyerDistrict = _s(j['buyer_district'] ?? j['district']);

    final pickupLat = _d(j['pickup_lat'] ?? j['pickupLatitude']);
    final pickupLng = _d(j['pickup_lng'] ?? j['pickupLongitude']);
    final dropLat = _d(j['dropoff_lat'] ?? j['drop_lat'] ?? j['dropLatitude']);
    final dropLng = _d(j['dropoff_lng'] ?? j['drop_lng'] ?? j['dropLongitude']);

    final created_at = _s(j['created_at']);

    if (total == null) return null;

    return PendingOrder(
      id: id,
      orderNumber: orderNumber,
      totalAmount: total,
      deliveryStatus: deliveryStatus,
      shippingAddress: shippingAddress.isEmpty ? null : shippingAddress,
      buyerName: buyerName.isEmpty ? null : buyerName,
      buyerCity: buyerCity.isEmpty ? null : buyerCity,
      buyerDistrict: buyerDistrict.isEmpty ? null : buyerDistrict,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropLat: dropLat,
      dropLng: dropLng,
      created_at: created_at.isEmpty ? null : created_at,
    );
  }
}

/// delivery_orders pickup_point / delivery_point parse
class DeliveryPoint {
  final String? name;
  final String? address;
  final double? lat;
  final double? lng;

  DeliveryPoint({this.name, this.address, this.lat, this.lng});

  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final raw = v.toString().trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw.replaceAll(',', '.'));
  }

  static ({double? lat, double? lng}) _normalizeLatLng(
    double? lat,
    double? lng,
  ) {
    if (lat == null || lng == null) return (lat: lat, lng: lng);
    if (lat.abs() > 90 || lng.abs() > 180) return (lat: null, lng: null);
    return (lat: lat, lng: lng);
  }

  static DeliveryPoint? fromDynamic(dynamic raw) {
    if (raw == null) return null;

    Map<String, dynamic>? m;

    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) m = Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    } else if (raw is Map) {
      m = Map<String, dynamic>.from(raw);
    }

    if (m == null) return null;

    final rawLat = _d(
      m['latitude'] ??
          m['lat'] ??
          m['y'] ??
          m['pickup_lat'] ??
          m['dropoff_lat'],
    );
    final rawLng = _d(
      m['longitude'] ??
          m['lng'] ??
          m['lon'] ??
          m['x'] ??
          m['pickup_lng'] ??
          m['dropoff_lng'],
    );
    final normalized = _normalizeLatLng(rawLat, rawLng);

    final city = _s(m['city']);
    final district = _s(m['district']);
    final composedAddress = [
      if (district.isNotEmpty) district,
      if (city.isNotEmpty) city,
    ].join(', ');
    final rawAddress =
        _s(m['address'] ?? m['full_address'] ?? m['shipping_address']);
    final address = rawAddress.isNotEmpty ? rawAddress : composedAddress;

    return DeliveryPoint(
      name:
          (m['name'] ?? m['contact_name'] ?? m['buyer_name'] ?? '').toString(),
      address: address,
      lat: normalized.lat,
      lng: normalized.lng,
    );
  }

  static String _s(dynamic v) => (v ?? '').toString().trim();

  /// delivery_point null/boş ise, order alanlarından fallback üretir.
  static DeliveryPoint? fromOrderFallback(
    Map<String, dynamic> j, {
    required bool pickup,
  }) {
    final rawLat = _d(
      pickup
          ? (j['pickup_lat'] ?? j['pickupLatitude'] ?? j['pickup_point_lat'])
          : (j['dropoff_lat'] ??
              j['drop_lat'] ??
              j['y'] ??
              j['dropLatitude'] ??
              j['delivery_lat']),
    );
    final rawLng = _d(
      pickup
          ? (j['pickup_lng'] ?? j['pickupLongitude'] ?? j['pickup_point_lng'])
          : (j['dropoff_lng'] ??
              j['drop_lng'] ??
              j['lon'] ??
              j['x'] ??
              j['dropLongitude'] ??
              j['delivery_lng']),
    );
    final normalized = _normalizeLatLng(rawLat, rawLng);

    final name = pickup
        ? _s(j['pickup_name'] ?? j['seller_name'] ?? j['merchant_name'])
        : _s(j['buyer_name'] ?? j['name'] ?? j['customer_name']);

    final city = _s(j['buyer_city'] ?? j['city']);
    final district = _s(j['buyer_district'] ?? j['district']);
    final fallbackAddress = _s(j['shipping_address'] ?? j['address']);
    final composedAddress = [
      if (district.isNotEmpty) district,
      if (city.isNotEmpty) city
    ].join(' / ');
    final address = fallbackAddress.isNotEmpty
        ? fallbackAddress
        : (composedAddress.isNotEmpty ? composedAddress : '');

    if (normalized.lat == null &&
        normalized.lng == null &&
        name.isEmpty &&
        address.isEmpty) {
      return null;
    }

    return DeliveryPoint(
      name: name.isEmpty ? null : name,
      address: address.isEmpty ? null : address,
      lat: normalized.lat,
      lng: normalized.lng,
    );
  }
}

class DeliveryOrder {
  final int id;
  final String? status;
  final String? orderNo;
  final DeliveryPoint? pickupPoint;
  final DeliveryPoint? deliveryPoint;
  final String? deliveryManName;
  final int? deliveryManId;
  final String? dateRaw;
  final String? createdAtRaw;
  final double? totalAmount;

  DeliveryOrder({
    required this.id,
    this.status,
    this.orderNo,
    this.pickupPoint,
    this.deliveryPoint,
    this.deliveryManName,
    this.deliveryManId,
    this.dateRaw,
    this.createdAtRaw,
    this.totalAmount = 0,
  });

  static int _i(dynamic v, {int def = 0}) {
    if (v == null) return def;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? def;
  }

  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final raw = v.toString().trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw.replaceAll(',', '.'));
  }

  factory DeliveryOrder.fromJson(Map<String, dynamic> j) {
    final pickupPoint = DeliveryPoint.fromDynamic(j['pickup_point']) ??
        DeliveryPoint.fromOrderFallback(j, pickup: true);
    final deliveryPoint = DeliveryPoint.fromDynamic(j['delivery_point']) ??
        DeliveryPoint.fromOrderFallback(j, pickup: false);

    return DeliveryOrder(
      id: _i(j['id']),
      status: (j['status'] ?? '').toString(),
      orderNo: (j['order_no'] ?? j['customer_fcm_token'] ?? '').toString(),
      pickupPoint: pickupPoint,
      deliveryPoint: deliveryPoint,
      deliveryManName:
          (j['delivery_man_name'] ?? j['delivery_man']?['name'] ?? '')
              .toString(),
      deliveryManId:
          j['delivery_man_id'] == null ? null : _i(j['delivery_man_id']),
      dateRaw: (j['date'] ?? '').toString(),
      createdAtRaw: (j['created_at'] ?? '').toString(),
      totalAmount: _d(j['total_amount'] ?? j['total'] ?? 0),
    );
  }

  String get bestDate => (dateRaw != null && dateRaw!.trim().isNotEmpty)
      ? dateRaw!.trim()
      : (createdAtRaw ?? '').trim();

  DeliveryOrder copyWith({
    String? status,
    String? orderNo,
    DeliveryPoint? pickupPoint,
    DeliveryPoint? deliveryPoint,
    String? deliveryManName,
    int? deliveryManId,
    String? dateRaw,
    String? createdAtRaw,
    double? totalAmount,
  }) {
    return DeliveryOrder(
      id: id,
      status: status ?? this.status,
      orderNo: orderNo ?? this.orderNo,
      pickupPoint: pickupPoint ?? this.pickupPoint,
      deliveryPoint: deliveryPoint ?? this.deliveryPoint,
      deliveryManName: deliveryManName ?? this.deliveryManName,
      deliveryManId: deliveryManId ?? this.deliveryManId,
      dateRaw: dateRaw ?? this.dateRaw,
      createdAtRaw: createdAtRaw ?? this.createdAtRaw,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }
}

/// -------------------------
/// OPS MAP SCREEN
/// -------------------------
class _OpsMapScreenState extends State<OpsMapScreen> {
  final MapController _map = MapController();
  Timer? _timer;

  bool _loading = false;
  String? _error;

  int _tabIndex = 0; // 0: bekleyen | 1: aktif | 2: tamamlanan
  int _pendingSubTab = 1; // 0: sipariş bekleyen | 1: kuryeye aktarılan

  List<PendingOrder> _pending = const [];
  List<DeliveryOrder> _deliveryOrders = const [];
  List<CourierLive> _couriers = const [];

  PendingOrder? _selectedPending;
  DeliveryOrder? _selectedDelivery;
  int? _selectedCourierId;

  final _tlFmt =
      NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadAll);
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadAll(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String tl(double v) => _tlFmt.format(v);

  Future<void> _loadAll({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final futures = await Future.wait([
        _fetchPendingOrders(),
        _fetchDeliveryOrders(),
        _fetchCouriers(),
      ]);

      final pending = futures[0] as List<PendingOrder>;
      final delivery = futures[1] as List<DeliveryOrder>;
      final couriers = futures[2] as List<CourierLive>;

      if (!mounted) return;

      setState(() {
        _pending = pending;
        _deliveryOrders = delivery;
        _couriers =
            couriers.where((c) => c.isActive && c.canTakeOrders).toList();

        if (_selectedPending != null &&
            !_pending.any((o) => o.id == _selectedPending!.id)) {
          _selectedPending = null;
        }
        if (_selectedDelivery != null &&
            !_deliveryOrders.any((o) => o.id == _selectedDelivery!.id)) {
          _selectedDelivery = null;
        }
        if (_selectedCourierId != null &&
            !_couriers.any((c) => c.id == _selectedCourierId)) {
          _selectedCourierId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Veriler alınamadı: $e');
    } finally {
      if (!silent && mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asMapList(dynamic v) {
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  Future<List<PendingOrder>> _fetchPendingOrders() async {
    final dio = context.read<ApiClient>().dio;
    final api = context.read<ApiClient>();
    final dealerEmail = api.currentEmail;

    final r = await dio.post(
      AppConfig.dealerOrdersPaending,
      data: {'email': dealerEmail},
      queryParameters: const {'page': 1},
    );

    final data = r.data;

    if (data is List) {
      final list = data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      return _parsePendingList(list);
    }

    if (data is Map) {
      final root = Map<String, dynamic>.from(data);

      final ordersBox = (root['orders'] is Map)
          ? Map<String, dynamic>.from(root['orders'])
          : <String, dynamic>{};
      final listRaw = ordersBox['data'] ?? root['data'] ?? root['orders'];

      if (listRaw is List) {
        final list = listRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        return _parsePendingList(list);
      }
    }

    return [];
  }

  List<PendingOrder> _parsePendingList(List<Map<String, dynamic>> list) {
    final out = <PendingOrder>[];
    for (final m in list) {
      final o = PendingOrder.tryParse(m);
      if (o == null) continue;
      if (o.deliveryStatus == 0) out.add(o);
    }
    return out;
  }

  Future<List<DeliveryOrder>> _fetchDeliveryOrders() async {
    final dio = context.read<ApiClient>().dio;
    final api = context.read<ApiClient>();
    final dealerEmail = api.currentEmail;

    final r = await dio.post(
      AppConfig.dealerOrdersDeliveryPath,
      data: {'email': dealerEmail},
      queryParameters: const {'page': 1},
    );

    final root = _asMap(r.data);
    final ordersBox = _asMap(root['orders']);
    final list = _asMapList(ordersBox['data']);

    return list.map((e) => DeliveryOrder.fromJson(e)).toList();
  }

  Map<String, dynamic>? _extractDeliveryRec(dynamic payload) {
    if (payload is Map) {
      final data = payload['data'];
      if (data is Map) {
        if (data['data'] is List && (data['data'] as List).isNotEmpty) {
          return Map<String, dynamic>.from((data['data'] as List).first as Map);
        }
        if (data.containsKey('id') && data.containsKey('pickup_point')) {
          return Map<String, dynamic>.from(data);
        }
      }
      if (payload['data'] is List && (payload['data'] as List).isNotEmpty) {
        return Map<String, dynamic>.from(
            (payload['data'] as List).first as Map);
      }
      if (payload.containsKey('id') && payload.containsKey('pickup_point')) {
        return Map<String, dynamic>.from(payload);
      }
    } else if (payload is List && payload.isNotEmpty) {
      final first = payload.first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return null;
  }

  Future<DeliveryOrder?> _fetchDeliveryOrderByNumber(String orderNumber) async {
    final dio = context.read<ApiClient>().dio;

    Map<String, dynamic>? rec;
    try {
      final r = await dio.get('delivery-orders/by-number/$orderNumber');
      rec = _extractDeliveryRec(r.data);
    } catch (_) {}

    if (rec == null) {
      try {
        final r = await dio.get(
          'delivery-orders',
          queryParameters: {'number': orderNumber, 'per_page': 1},
        );
        rec = _extractDeliveryRec(r.data);
      } catch (_) {}
    }

    if (rec == null) return null;
    return DeliveryOrder.fromJson(rec);
  }

  Future<DeliveryOrder> _hydrateDeliveryOrderIfNeeded(
      DeliveryOrder order) async {
    final hasDrop = _deliveryDrop(order) != null;
    if (hasDrop) return order;

    final number = (order.orderNo ?? '').trim();
    if (number.isEmpty) return order;

    final fetched = await _fetchDeliveryOrderByNumber(number);
    if (fetched == null) return order;

    final enriched = order.copyWith(
      pickupPoint: fetched.pickupPoint ?? order.pickupPoint,
      deliveryPoint: fetched.deliveryPoint ?? order.deliveryPoint,
      dateRaw:
          (order.dateRaw ?? '').isNotEmpty ? order.dateRaw : fetched.dateRaw,
      createdAtRaw: (order.createdAtRaw ?? '').isNotEmpty
          ? order.createdAtRaw
          : fetched.createdAtRaw,
    );

    if (!mounted) return enriched;
    setState(() {
      _deliveryOrders = _deliveryOrders
          .map((o) => o.id == enriched.id ? enriched : o)
          .toList();
      if (_selectedDelivery?.id == enriched.id) {
        _selectedDelivery = enriched;
      }
    });

    return enriched;
  }

  Future<void> _selectDeliveryOrder(DeliveryOrder order) async {
    setState(() {
      _selectedDelivery = order;
      _selectedPending = null;
    });

    final hydrated = await _hydrateDeliveryOrderIfNeeded(order);
    final pts = <LatLng?>[_deliveryPickup(hydrated), _deliveryDrop(hydrated)]
        .whereType<LatLng>()
        .toList();
    _focusPointsOrWarn(pts);
  }

  Future<List<CourierLive>> _fetchCouriers() async {
    final dio = context.read<ApiClient>().dio;
    final r = await dio.get(AppConfig.activeCouriersPath);

    final root = _asMap(r.data);
    final list = _asMapList(root['couriers']);

    final out = <CourierLive>[];
    for (final e in list) {
      final c = CourierLive.tryParse(e);
      if (c != null) out.add(c);
    }
    return out;
  }

  /// ---------------- Status helpers ----------------
  bool _isCompleted(DeliveryOrder o) {
    final s = (o.status ?? '').toLowerCase().trim();
    return s == 'completed' || s == 'delivered';
  }

  bool _isActiveDelivery(DeliveryOrder o) {
    final s = (o.status ?? '').toLowerCase().trim();
    if ({
      'pending',
      'confirmed',
      'assigned',
      'accepted',
      'pickup',
      'picked_up',
      'on_the_way',
    }.contains(s)) return true;

    if ({
      'completed',
      'delivered',
      'cancelled',
      'canceled',
      'rejected',
      'closed',
    }.contains(s)) return false;

    return s.isNotEmpty;
  }

  bool _isPoolWaiting(DeliveryOrder o) {
    final s = (o.status ?? '').toLowerCase().trim();
    final noCourier = (o.deliveryManId == null || o.deliveryManId == 0);
    final notFinal = !{
      'completed',
      'delivered',
      'cancelled',
      'canceled',
      'rejected',
      'closed'
    }.contains(s);

    return noCourier && notFinal;
  }

  /// ---------------- Map coords helpers ----------------
  LatLng? _pendingPickup(PendingOrder o) {
    if (o.pickupLat == null || o.pickupLng == null) return null;
    return LatLng(o.pickupLat!, o.pickupLng!);
  }

  LatLng? _pendingDrop(PendingOrder o) {
    if (o.dropLat == null || o.dropLng == null) return null;
    return LatLng(o.dropLat!, o.dropLng!);
  }

  LatLng? _deliveryPickup(DeliveryOrder o) {
    final p = o.pickupPoint;
    if (p == null || p.lat == null || p.lng == null) return null;
    return LatLng(p.lat!, p.lng!);
  }

  LatLng? _deliveryDrop(DeliveryOrder o) {
    final d = o.deliveryPoint;
    if (d == null || d.lat == null || d.lng == null) return null;
    return LatLng(d.lat!, d.lng!);
  }

  void _focusPoints(List<LatLng> pts) {
    if (pts.isEmpty) return;

    if (pts.length == 1) {
      _map.move(pts.first, 15);
      return;
    }

    double minLat = pts.first.latitude;
    double maxLat = pts.first.latitude;
    double minLng = pts.first.longitude;
    double maxLng = pts.first.longitude;

    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _map.move(center, 12);
  }

  void _focusPointsOrWarn(List<LatLng> pts) {
    if (pts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bu siparişte harita koordinatı bulunamadı.')),
      );
      return;
    }
    _focusPoints(pts);
  }

  Future<void> _copy(String text, {String? toast}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(toast ?? 'Kopyalandı ✅')),
    );
  }

  String _fmtLatLng(double? lat, double? lng) {
    if (lat == null || lng == null) return '—';
    return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              k,
              style: TextStyle(
                color: KOpsColors.muted,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              v,
              style: TextStyle(
                color: KOpsColors.text,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailCard() {
    final courier = (_selectedCourierId == null)
        ? null
        : _couriers.firstWhere(
            (c) => c.id == _selectedCourierId,
            orElse: () => CourierLive(
              id: -1,
              name: '',
              lat: 0,
              lng: 0,
              isActive: false,
              canTakeOrders: false,
              dealerId: null,
            ),
          );

    final hasCourier = courier != null && courier.id != -1;

    // Hiç seçim yoksa minimal info gösterelim:
    if (_selectedPending == null && _selectedDelivery == null && !hasCourier) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: KOpsColors.soft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KOpsColors.line),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: KOpsColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Detay görmek için bir sipariş veya kurye seç.',
                style: TextStyle(
                  color: KOpsColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Ortak buton
    Widget actionBtn({
      required IconData icon,
      required String text,
      required VoidCallback onTap,
      bool primary = false,
    }) {
      return Expanded(
        child: SizedBox(
          height: 40,
          child: primary
              ? FilledButton.icon(
                  onPressed: onTap,
                  icon: Icon(icon, size: 18),
                  label: Text(text),
                  style: FilledButton.styleFrom(
                    backgroundColor: KOpsColors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: onTap,
                  icon: Icon(icon, size: 18),
                  label: Text(text),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KOpsColors.text,
                    side: BorderSide(color: KOpsColors.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
        ),
      );
    }

    // 1) Pending seçili
    if (_selectedPending != null) {
      final o = _selectedPending!;
      final pick = _pendingPickup(o);
      final drop = _pendingDrop(o);

      final orderTitle = o.orderNumber;
      final sub = smartDate(o.created_at);
      final amount = tl(o.totalAmount);

      final customer = [
        if ((o.buyerName ?? '').isNotEmpty) o.buyerName!,
        if ((o.buyerDistrict ?? '').isNotEmpty) o.buyerDistrict!,
        if ((o.buyerCity ?? '').isNotEmpty) o.buyerCity!,
      ].where((x) => x.trim().isNotEmpty).join(' • ');

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: KOpsColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KOpsColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: KOpsColors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    orderTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 8),
                _chip('BEKLEYEN', bg: KOpsColors.orange, fg: Colors.white),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(sub,
                    style: TextStyle(
                        color: KOpsColors.muted, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text(amount,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
            _kv('Müşteri', customer.isEmpty ? '—' : customer),
            _kv('Adres', (o.shippingAddress ?? '—')),
            _kv('Alış Noktası', _fmtLatLng(o.pickupLat, o.pickupLng)),
            _kv('Teslim Noktasu', _fmtLatLng(o.dropLat, o.dropLng)),
            const SizedBox(height: 10),
            Row(
              children: [
                actionBtn(
                  icon: Icons.copy_all_outlined,
                  text: 'Kopyala',
                  onTap: () => _copy(
                    'Sipariş: ${o.orderNumber}\nTutar: ${tl(o.totalAmount)}\nAdres: ${o.shippingAddress ?? ''}\nPickup: ${_fmtLatLng(o.pickupLat, o.pickupLng)}\nDrop: ${_fmtLatLng(o.dropLat, o.dropLng)}',
                  ),
                ),
                const SizedBox(width: 10),
                actionBtn(
                  icon: Icons.center_focus_strong,
                  text: 'Odakla',
                  onTap: () {
                    final pts = <LatLng?>[
                      _pendingPickup(o),
                      _pendingDrop(o),
                    ].whereType<LatLng>().toList();
                    _focusPointsOrWarn(pts);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                actionBtn(
                  icon: Icons.delivery_dining_outlined,
                  text: 'Havuza Aktar',
                  primary: true,
                  onTap: () => _handoffPending(o),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 2) Delivery seçili
    if (_selectedDelivery != null) {
      final o = _selectedDelivery!;
      final pick = _deliveryPickup(o);
      final drop = _deliveryDrop(o);

      final title =
          (o.orderNo?.isNotEmpty == true) ? o.orderNo! : 'Sipariş #${o.id}';
      final sub = smartDate(o.bestDate);
      final amount = tl(o.totalAmount ?? 0);
      final statusText = (o.status ?? '—').toUpperCase();

      final courierName =
          (o.deliveryManName?.isNotEmpty == true) ? o.deliveryManName! : '—';
      final courierId = o.deliveryManId?.toString() ?? '—';

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: KOpsColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KOpsColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping_outlined, color: KOpsColors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 8),
                _chip(
                  statusText,
                  bg: _isCompleted(o) ? Colors.blueGrey : KOpsColors.purple,
                  fg: Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(sub,
                    style: TextStyle(
                        color: KOpsColors.muted, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text(amount,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
            _kv('Kurye', '$courierName (ID: $courierId)'),
            _kv('Alım Noktası ', (o.pickupPoint?.address ?? '—')),
            _kv('Teslim Noktası', (o.deliveryPoint?.address ?? '—')),
            _kv('Alım Noktası Konum',
                _fmtLatLng(o.pickupPoint?.lat, o.pickupPoint?.lng)),
            _kv('Teslim Noktası Konum',
                _fmtLatLng(o.deliveryPoint?.lat, o.deliveryPoint?.lng)),
            const SizedBox(height: 10),
            Row(
              children: [
                actionBtn(
                  icon: Icons.copy_all_outlined,
                  text: 'Kopyala',
                  onTap: () => _copy(
                    'Sipariş: $title\nDurumu: $statusText\nTutar: ${tl(o.totalAmount ?? 0)}\nKurye: $courierName (ID: $courierId)\nPickup: ${o.pickupPoint?.address ?? ''}\nDrop: ${o.deliveryPoint?.address ?? ''}',
                  ),
                ),
                const SizedBox(width: 10),
                actionBtn(
                  icon: Icons.center_focus_strong,
                  text: 'Odakla',
                  onTap: () {
                    final pts =
                        <LatLng?>[pick, drop].whereType<LatLng>().toList();
                    _focusPointsOrWarn(pts);
                  },
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 3) Sadece kurye seçili
    if (hasCourier) {
      final c = courier!;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: KOpsColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KOpsColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.two_wheeler, color: KOpsColors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 8),
                _chip('KURYE', bg: KOpsColors.orange, fg: Colors.white),
              ],
            ),
            _kv('ID', c.id.toString()),
            _kv('GPS', _fmtLatLng(c.lat, c.lng)),
            _kv('Dealer', c.dealerId?.toString() ?? '—'),
            const SizedBox(height: 10),
            Row(
              children: [
                actionBtn(
                  icon: Icons.copy_all_outlined,
                  text: 'Kopyala',
                  onTap: () => _copy(
                      'Kurye: ${c.name} (ID:${c.id})\nGPS: ${_fmtLatLng(c.lat, c.lng)}'),
                ),
                const SizedBox(width: 10),
                actionBtn(
                  icon: Icons.center_focus_strong,
                  text: 'Odakla',
                  onTap: () => _map.move(LatLng(c.lat, c.lng), 15),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // fallback
    return const SizedBox.shrink();
  }

  /// ---------------- Markers ----------------
  Marker _courierMarker(CourierLive c) {
    final selected = _selectedCourierId == c.id;

    return Marker(
      point: LatLng(c.lat, c.lng),
      width: 120,
      height: 80,
      alignment: Alignment.center,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _selectedCourierId = selected ? null : c.id);
          _map.move(LatLng(c.lat, c.lng), 15);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: Image.asset(
                'assets/icon/motor.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: selected ? 1 : 0,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 120),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(.25)),
                ),
                child: Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker buildPickupMarker(LatLng p, String title) {
    return Marker(
      point: p,
      width: 170,
      height: 86,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: KOpsColors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: const Icon(Icons.store, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            constraints: const BoxConstraints(maxWidth: 170),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Marker buildDropMarker(LatLng p, String title) {
    return Marker(
      point: p,
      width: 170,
      height: 86,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: KOpsColors.purple,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: const Icon(Icons.home, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            constraints: const BoxConstraints(maxWidth: 170),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ---------------- UI actions ----------------
  Future<void> _handoffPending(PendingOrder o) async {
    try {
      final api = context.read<ApiClient>();
      final resp = await api.handoffByOrderNumber(o.orderNumber);

      final ok = (resp['success'] == true);
      final msg = ok
          ? 'Kuryelere aktarıldı ✅'
          : (resp['message'] ?? 'İşlem tamamlandı');

      if (!mounted) return;

      if (ok) {
        setState(() {
          _pending = _pending.where((x) => x.id != o.id).toList();
          if (_selectedPending?.id == o.id) _selectedPending = null;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aktarma başarısız ❌')),
      );
    }
  }

  /// ---------------- UI helpers ----------------

  Widget _chip(String text, {required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _tabButton(String title, int idx, {int? badge}) {
    final selected = _tabIndex == idx;
    final bg = selected ? KOpsColors.purple : KOpsColors.card;
    final fg = selected ? Colors.white : KOpsColors.text;
    final br = selected ? KOpsColors.purple.withOpacity(.35) : KOpsColors.line;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          _tabIndex = idx;
          if (idx == 0) _pendingSubTab = 1;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: br),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : KOpsColors.text,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badge',
                    style: TextStyle(
                      color: selected ? KOpsColors.text : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _pendingSubButton(String title, int idx, int badge) {
    final selected = _pendingSubTab == idx;
    final bg = selected ? KOpsColors.orange : KOpsColors.card;
    final fg = selected ? Colors.white : KOpsColors.text;
    final br = selected ? KOpsColors.orange.withOpacity(.35) : KOpsColors.line;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _pendingSubTab = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: br),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : KOpsColors.text,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$badge',
                  style: TextStyle(
                    color: selected ? KOpsColors.text : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pendingTab2() {
    final pool = _deliveryOrders.where(_isPoolWaiting).toList();

    return Column(
      children: [
        Row(
          children: [
            _pendingSubButton('Sipariş Bekleyen', 0, _pending.length),
            const SizedBox(width: 10),
            _pendingSubButton('Kuryeye Aktarılan', 1, pool.length),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _pendingSubTab == 0 ? _pendingList() : _poolWaitingList(pool),
        ),
      ],
    );
  }

  Widget _panelCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KOpsColors.card.withOpacity(.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KOpsColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _rightPanel() {
    final activeCount = _deliveryOrders.where(_isActiveDelivery).length;
    final completedCount = _deliveryOrders.where(_isCompleted).length;
    final poolCount = _deliveryOrders.where(_isPoolWaiting).length;
    final waitingTotal = _pending.length + poolCount;
    return _panelCard(
      child: Column(
        children: [
          _detailCard(),
          const SizedBox(height: 10),
          Row(
            children: [
              _tabButton('Bekleyen', 0, badge: waitingTotal),
              const SizedBox(width: 10),
              _tabButton('Aktif', 1, badge: activeCount),
              const SizedBox(width: 10),
              _tabButton('Tamamlanan', 2, badge: completedCount),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _tabIndex == 0
                ? _pendingTab2()
                : _tabIndex == 1
                    ? _deliveryList(active: true)
                    : _deliveryList(active: false),
          ),
        ],
      ),
    );
  }

  String smartDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '—';

    final now = DateTime.now();
    final local = dt.toLocal();
    final diff = now.difference(local);

    String hhmm(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    if (diff.inMinutes < 1) return '⏰ şimdi';
    if (diff.inMinutes < 60) return '⏰ ${diff.inMinutes} dk önce';

    if (now.year == local.year &&
        now.month == local.month &&
        now.day == local.day) {
      return 'Bugün ${hhmm(local)}';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.year == local.year &&
        yesterday.month == local.month &&
        yesterday.day == local.day) {
      return 'Dün ${hhmm(local)}';
    }

    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.'
        '${local.year} ${hhmm(local)}';
  }

  Widget _pendingList() {
    if (_pending.isEmpty) {
      return const Center(child: Text('Bekleyen sipariş yok.'));
    }

    return ListView.separated(
      itemCount: _pending.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final o = _pending[i];
        final selected = _selectedPending?.id == o.id;

        final border = selected ? KOpsColors.purple : KOpsColors.line;
        final bg =
            selected ? KOpsColors.purple.withOpacity(.06) : KOpsColors.card;

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _selectedPending = o;
              _selectedDelivery = null;
            });
            final pts = <LatLng?>[_pendingPickup(o), _pendingDrop(o)]
                .whereType<LatLng>()
                .toList();
            _focusPointsOrWarn(pts);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        o.orderNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      smartDate(o.created_at),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: KOpsColors.muted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      tl(o.totalAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if ((o.buyerName ?? '').isNotEmpty) o.buyerName!,
                    if ((o.buyerDistrict ?? '').isNotEmpty) o.buyerDistrict!,
                    if ((o.buyerCity ?? '').isNotEmpty) o.buyerCity!,
                  ].join(' • ').isEmpty
                      ? (o.shippingAddress ?? '—')
                      : [
                          if ((o.buyerName ?? '').isNotEmpty) o.buyerName!,
                          if ((o.buyerDistrict ?? '').isNotEmpty)
                            o.buyerDistrict!,
                          if ((o.buyerCity ?? '').isNotEmpty) o.buyerCity!,
                        ].join(' • '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: KOpsColors.text.withOpacity(.78)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        o.shippingAddress ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: KOpsColors.muted),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () => _handoffPending(o),
                      icon:
                          const Icon(Icons.delivery_dining_outlined, size: 18),
                      label: const Text('Havuza Aktar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: KOpsColors.purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _poolWaitingList(List<DeliveryOrder> pool) {
    if (pool.isEmpty) {
      return const Center(child: Text('Havuzda kurye bekleyen sipariş yok.'));
    }

    return ListView.separated(
      itemCount: pool.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final o = pool[i];
        final selected = _selectedDelivery?.id == o.id;

        final border = selected ? KOpsColors.orange : KOpsColors.line;
        final bg =
            selected ? KOpsColors.orange.withOpacity(.08) : KOpsColors.card;

        final title =
            (o.orderNo?.isNotEmpty == true) ? o.orderNo! : 'Sipariş #${o.id}';

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _selectDeliveryOrder(o),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      smartDate(o.dateRaw),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: KOpsColors.muted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      tl(o.totalAmount ?? 0),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _chip(
                      (o.status ?? 'pending').toUpperCase(),
                      bg: KOpsColors.orange,
                      fg: Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Kurye: — (Atama bekliyor)',
                  style: TextStyle(color: KOpsColors.text.withOpacity(.78)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Alım Noktası: ${o.pickupPoint?.address ?? '—'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: KOpsColors.muted),
                ),
                Text(
                  'Teslimat Noktası: ${o.deliveryPoint?.address ?? '—'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: KOpsColors.muted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _deliveryList({required bool active}) {
    final list = _deliveryOrders
        .where((o) => active ? _isActiveDelivery(o) : _isCompleted(o))
        .toList();

    if (list.isEmpty) {
      return Center(
        child:
            Text(active ? 'Aktif teslimat yok.' : 'Tamamlanan teslimat yok.'),
      );
    }

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final o = list[i];
        final selected = _selectedDelivery?.id == o.id;

        final border = selected ? KOpsColors.purple : KOpsColors.line;
        final bg =
            selected ? KOpsColors.purple.withOpacity(.06) : KOpsColors.card;

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _selectDeliveryOrder(o),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (o.orderNo?.isNotEmpty == true)
                            ? o.orderNo!
                            : 'Sipariş #${o.id}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      smartDate(o.bestDate),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: KOpsColors.muted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      tl(o.totalAmount ?? 0),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _chip(
                      (o.status ?? '—').toUpperCase(),
                      bg: active ? KOpsColors.purple : Colors.blueGrey,
                      fg: Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Kurye: ${o.deliveryManName?.isNotEmpty == true ? o.deliveryManName : '—'}',
                  style: TextStyle(color: KOpsColors.text.withOpacity(.78)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Alım Noktası: ${o.pickupPoint?.address ?? '—'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: KOpsColors.muted),
                ),
                Text(
                  'Teslimat Noktası: ${o.deliveryPoint?.address ?? '—'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: KOpsColors.muted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Theme’yi login ile aynı mantıkta burada da uygula:
    final base = Theme.of(context);
    final cs = base.colorScheme.copyWith(
      primary: KOpsColors.purple,
      secondary: KOpsColors.purple2,
      tertiary: KOpsColors.orange,
      background: KOpsColors.bg,
      surface: KOpsColors.card,
      outline: KOpsColors.line,
      outlineVariant: KOpsColors.line,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onTertiary: Colors.white,
      onSurface: KOpsColors.text,
      onSurfaceVariant: KOpsColors.muted,
    );

    final theme = HaldekiUI.withRectButtons(context, cs).copyWith(
      colorScheme: cs,
      scaffoldBackgroundColor: KOpsColors.bg,
    );

    LatLng? pick;
    LatLng? drop;
    String pickName = '';
    String dropName = '';

    if (_selectedPending != null) {
      pick = _pendingPickup(_selectedPending!);
      drop = _pendingDrop(_selectedPending!);

      pickName = (_selectedPending!.buyerName ?? 'Restoran').trim();
      dropName = (_selectedPending!.buyerName ?? 'Müşteri').trim();
      if (dropName.isEmpty) dropName = 'Müşteri';
    } else if (_selectedDelivery != null) {
      pick = _deliveryPickup(_selectedDelivery!);
      drop = _deliveryDrop(_selectedDelivery!);

      pickName = (_selectedDelivery!.pickupPoint?.name ?? 'Restoran')
          .toString()
          .trim();
      dropName = (_selectedDelivery!.deliveryPoint?.name ?? 'Müşteri')
          .toString()
          .trim();
      if (pickName.isEmpty) pickName = 'Restoran';
      if (dropName.isEmpty) dropName = 'Müşteri';
    }

    final selectedPoints = <LatLng?>[pick, drop].whereType<LatLng>().toList();

    final markers = <Marker>[
      ..._couriers.map(_courierMarker),
      if (pick != null) buildPickupMarker(pick!, pickName),
      if (drop != null) buildDropMarker(drop!, dropName),
    ];

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kurye Operasyon (Harita)'),
          backgroundColor: KOpsColors.card,
          foregroundColor: KOpsColors.text,
          elevation: 0,
          surfaceTintColor: KOpsColors.card,
          actions: [
            IconButton(
              tooltip: 'Yenile',
              onPressed: () => _loadAll(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= 980;

            final mapWidget = ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: const LatLng(40.8773, 29.2361),
                      initialZoom: 10,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.esnafexpress.web',
                      ),
                      if (selectedPoints.length == 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: selectedPoints,
                              strokeWidth: 5,
                              color: KOpsColors.purple.withOpacity(.85),
                            ),
                          ],
                        ),
                      MarkerLayer(markers: markers),
                    ],
                  ),

                  // mini dashboard
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: KOpsColors.card.withOpacity(.94),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: KOpsColors.line),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.04),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: DefaultTextStyle(
                        style: TextStyle(color: KOpsColors.text),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hareketler',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: KOpsColors.text.withOpacity(.78),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('Kuryeler: ${_couriers.length}'),
                            Text('Bekleyen: ${_pending.length}'),
                            Text(
                              'Havuz Bekleyen: ${_deliveryOrders.where(_isPoolWaiting).length}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (_loading)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.75),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Yükleniyor...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          ],
                        ),
                      ),
                    ),

                  if (_error != null)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(.10),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: Colors.red.withOpacity(.25)),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );

            final rightWidget = _rightPanel();

            return Padding(
              padding: const EdgeInsets.all(12),
              child: wide
                  ? Row(
                      children: [
                        Expanded(flex: 7, child: mapWidget),
                        const SizedBox(width: 12),
                        Expanded(flex: 5, child: rightWidget),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(flex: 6, child: mapWidget),
                        const SizedBox(height: 12),
                        Expanded(flex: 5, child: rightWidget),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}
