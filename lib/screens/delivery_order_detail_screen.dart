import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/api_client.dart';
import '../utils/format.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/painting.dart' show instantiateImageCodec;
import 'dart:math' as Math;

/// Sevkiyat adımı görselleştirme durumları
enum _StageState { done, current, todo }

class DeliveryOrderDetailScreen extends StatefulWidget {
  final String orderNumber;
  final String? initialDeliveryStatus;

  const DeliveryOrderDetailScreen({
    super.key,
    required this.orderNumber,
    this.initialDeliveryStatus,
  });

  @override
  State<DeliveryOrderDetailScreen> createState() =>
      _DeliveryOrderDetailScreenState();
}

class _DeliveryOrderDetailScreenState extends State<DeliveryOrderDetailScreen> {
  bool _loading = true;
  String? _error;
  _OrderVM? _order;
  String? _motoErr;
  // Google Map controller
  GoogleMapController? _gmap;

  // Pickup -> Delivery rotası
  List<LatLng> _routePD = [];
  bool _routePDLoading = false;
  String? _routePDError;
  double? _routePDDistanceMeters;
  double? _routePDDurationSeconds;

  // Kurye -> Pickup rotası
  List<LatLng> _routeCP = [];
  bool _routeCPLoading = false;
  String? _routeCPError;
  double? _routeCPDistanceMeters;
  double? _routeCPDurationSeconds;

  // Animasyonlu araç (Pickup->Delivery üzerinde)
  Timer? _carTimer;
  int _carIndex = 0;
  LatLng? _carPos;
  double _carRotationDeg = 0;

  // Kurye polling
  Timer? _courierPollTimer;
  DateTime? _courierLastFetch;
  LatLng? _courierLastLatLngForRoute; // rota güncelleme eşiği için
  BitmapDescriptor? _motoIcon;
  static const String kMotoAsset = 'assets/icon/motor.png';

// ===== Primary UI (Purple + Grey + Orange) =====
  static const Color kPurple = Color(0xFF0D4631);
  static const Color kPurple2 = Color(0xFF0D4631);
  static const Color kOrange = Color(0xFF98F090); // açık yeşil vurgu

  static const Color kBg = Color(0xFFF6F7FB);
  static const Color kCard = Colors.white;
  static const Color kLine = Color(0xFFE6E8EF);

  static const Color kText = Color(0xFF0F172A);
  static const Color kMuted = Color(0xFF64748B);

  Future<BitmapDescriptor> _bitmapFromAsset(String path,
      {int width = 80}) async {
    final data = await rootBundle.load(path);
    final codec = await instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(format: ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    // Yeni API:
    return BitmapDescriptor.bytes(bytes);
    // Eğer sende yoksa:
    // return BitmapDescriptor.fromBytes(bytes);
  }

  double _bearingBetween(LatLng from, LatLng to) {
    final lat1 = from.latitude * 0.017453292519943295;
    final lat2 = to.latitude * 0.017453292519943295;
    final dLon = (to.longitude - from.longitude) * 0.017453292519943295;

    final y = Math.sin(dLon) * Math.cos(lat2);
    final x = Math.cos(lat1) * Math.sin(lat2) -
        Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);

    final brng = Math.atan2(y, x);
    return (brng * 57.29577951308232 + 360) % 360;
  }

  Future<void> _loadMotoIcon() async {
    try {
      final icon = await _bitmapFromAsset(kMotoAsset, width: 90);
      if (!mounted) return;
      setState(() {
        _motoIcon = icon;
        _motoErr = null;
      });
      //debugprint('✅ Moto icon LOADED OK');
    } catch (e) {
      //debugprint('❌ Moto icon load FAILED: $e');
      if (!mounted) return;
      setState(() {
        _motoIcon = null;
        _motoErr = e.toString();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMotoIcon();
    _load();
  }

  @override
  void dispose() {
    _carTimer?.cancel();
    _courierPollTimer?.cancel();
    _gmap?.dispose();
    super.dispose();
  }

  // ---------------- JSON helpers ----------------

  List<dynamic> _jsonList0(dynamic v) {
    if (v is List) return v;
    if (v is String && v.trim().isNotEmpty) {
      try {
        final d = jsonDecode(v);
        if (d is List) return d;
      } catch (_) {}
    }
    return const [];
  }

  Map<String, dynamic> _jsonMap0(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    if (v is String && v.trim().isNotEmpty) {
      try {
        final d = jsonDecode(v);
        if (d is Map) return Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) {
      final d = double.tryParse(v.replaceAll(',', '.'));
      return d ?? 0;
    }
    return 0;
  }

  double? _asNullableDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String && v.trim().isNotEmpty) {
      return double.tryParse(v.replaceAll(',', '.'));
    }
    return null;
  }

  LatLng? _extractLatLng(Map<String, dynamic> m) {
    final lat = _asNullableDouble(m['lat'] ?? m['latitude'] ?? m['y']);
    final lng =
        _asNullableDouble(m['lng'] ?? m['lon'] ?? m['longitude'] ?? m['x']);
    if (lat == null || lng == null) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return LatLng(lat, lng);
  }

  String _joinNonEmpty(List<String?> parts, {String sep = ' • '}) {
    return parts
        .where((e) => (e ?? '').trim().isNotEmpty)
        .map((e) => e!.trim())
        .join(sep);
  }

  // ---------------- LOAD order ----------------

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _order = null;

      _routePD = [];
      _routePDLoading = false;
      _routePDError = null;
      _routePDDistanceMeters = null;
      _routePDDurationSeconds = null;

      _routeCP = [];
      _routeCPLoading = false;
      _routeCPError = null;
      _routeCPDistanceMeters = null;
      _routeCPDurationSeconds = null;

      _carTimer?.cancel();
      _carPos = null;
      _carIndex = 0;
      _carRotationDeg = 0;

      _courierPollTimer?.cancel();
      _courierLastFetch = null;
      _courierLastLatLngForRoute = null;
    });

    final dio = context.read<ApiClient>().dio;

    Map<String, dynamic>? _extractDeliveryRec(dynamic payload) {
      if (payload is Map) {
        final data = payload['data'];
        if (data is Map) {
          if (data['data'] is List && (data['data'] as List).isNotEmpty) {
            return Map<String, dynamic>.from(
                (data['data'] as List).first as Map);
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

    try {
      Map<String, dynamic>? rec;

      // 1) /delivery-orders/by-number/{no}
      try {
        final r =
            await dio.get('delivery-orders/by-number/${widget.orderNumber}');
        rec = _extractDeliveryRec(r.data);
      } catch (_) {}

      // 2) /delivery-orders?number=...&per_page=1
      if (rec == null) {
        try {
          final r2 = await dio.get('delivery-orders', queryParameters: {
            'number': widget.orderNumber,
            'per_page': 1,
          });
          rec = _extractDeliveryRec(r2.data);
        } catch (_) {}
      }

      if (rec == null) {
        setState(() {
          _error = 'Sevkiyat bulunamadı';
          _loading = false;
        });
        return;
      }

      final vm = _orderFromDelivery(rec);

      setState(() {
        _order = vm;
        _loading = false;
      });

      // 1) Pickup->Delivery rotası
      final p = vm.pickupLatLng;
      final d = vm.deliveryLatLng;
      if (p != null && d != null) {
        await _fetchRoutePD(p, d);
      } else {
        _fitMapToAll();
      }

      // 2) Kurye konumunu çek + polling başlat
      if (vm.deliveryManId != null) {
        await _refreshCourierAndMaybeRoute(forceRoute: true);
        _startCourierPolling();
      }
    } catch (e) {
      setState(() {
        _error = 'Sipariş yüklenemedi: $e';
        _loading = false;
      });
    }
  }

  String _pickOrderNumber(
    Map<String, dynamic> rec,
    Map<String, dynamic> pickup,
    Map<String, dynamic> delivery,
  ) {
    // ✅ 1) Senin gerçek sipariş numaran (ORD-…): customer_fcm_token
    final t = rec['customer_fcm_token']?.toString().trim();
    if (t != null && t.isNotEmpty) return t;

    // 2) Alternatif alan adları
    final direct =
        (rec['order_number'] ?? rec['order_no'] ?? rec['number'] ?? rec['code'])
            ?.toString()
            .trim();
    if (direct != null && direct.isNotEmpty) return direct;

    // 3) fallback: pickup/delivery reference
    final ref =
        (pickup['reference'] ?? delivery['reference'])?.toString().trim();
    if (ref != null && ref.isNotEmpty) return ref;

    // 4) en son ekrandan gelen
    return widget.orderNumber;
  }

  _OrderVM _orderFromDelivery(Map<String, dynamic> rec) {
    final pickup = _jsonMap0(rec['pickup_point']);
    final delivery = _jsonMap0(rec['delivery_point']);

    // final orderNumber =    (pickup['reference'] ?? delivery['reference'] ?? '').toString();
    final orderNumber = _pickOrderNumber(rec, pickup, delivery);

    final status = (rec['status'] ?? '').toString();
    final createdAt = DateTime.tryParse(rec['date']?.toString() ?? '') ??
        DateTime.tryParse(rec['created_at']?.toString() ?? '') ??
        DateTime.now();

    final shippingAddress = [
      delivery['address']?.toString(),
      _joinNonEmpty([
        delivery['city']?.toString(),
        delivery['district']?.toString(),
      ], sep: '/')
    ].where((e) => (e ?? '').trim().isNotEmpty).join(' - ');

    final createdByName =
        (delivery['contact_name'] ?? pickup['contact_name'] ?? '-').toString();

    final pickupLL = _extractLatLng(pickup);
    final deliveryLL = _extractLatLng(delivery);

    // ---------------- ITEMS ----------------
    final List<_OrderItemVM> items = [];

    _OrderItemVM _mapItem(Map<String, dynamic> it) {
      final label = (it['product_name'] ?? it['label'] ?? it['name'] ?? 'Ürün')
          .toString()
          .trim();
      final variant = it['variant_name']?.toString().trim();

      final qty = _asDouble(it['qty'] ?? it['quantity'] ?? it['adet']);
      final unitPrice =
          _asDouble(it['unit_price'] ?? it['price'] ?? it['birim_fiyat']);

      double lineTotal = _asDouble(
          it['line_total'] ?? it['total'] ?? it['total_price'] ?? it['tutar']);

      if (lineTotal == 0 && unitPrice > 0 && qty > 0) {
        lineTotal = unitPrice * qty;
      }

      final title =
          (variant == null || variant.isEmpty) ? label : '$label ($variant)';

      return _OrderItemVM(
        productTitle: title,
        qtyCases: qty == 0 ? null : qty,
        approxKgPerCase: null,
        pricePerKg: unitPrice == 0 ? null : unitPrice,
        lineTotal: lineTotal,
      );
    }

    // ✅ 1) reason_items varsa (en temiz)
    final reasonItemsRaw = rec['reason_items'];
    if (reasonItemsRaw is List) {
      for (final it0 in reasonItemsRaw.whereType<Map>()) {
        items.add(_mapItem(Map<String, dynamic>.from(it0)));
      }
    } else {
      // ✅ 2) reason: JSON string veya list olabilir; bu payload’da direkt item listesi
      final reasonList = _jsonList0(rec['reason']);
      for (final it0 in reasonList.whereType<Map>()) {
        items.add(_mapItem(Map<String, dynamic>.from(it0)));
      }
    }

    double subtotal = 0;
    for (final it in items) subtotal += it.lineTotal;

    final apiTotal = _asDouble(rec['total_amount']);
    final grand = apiTotal > 0 ? apiTotal : subtotal;
    final totals = _Totals(subtotal, 0, grand);

    final pickPhoto = (rec['pick_photo'] ?? rec['pick_photo_url'])?.toString();
    final deliveryPhoto =
        (rec['delivery_photo'] ?? rec['delivery_photo_url'])?.toString();
    final deliveryStatus = rec['status']?.toString();

    final pickupName =
        (pickup['name'] ?? pickup['contact_name'] ?? '').toString();
    final pickupAddress = (pickup['address'] ?? '').toString();
    final deliveryName =
        (delivery['name'] ?? delivery['contact_name'] ?? '').toString();
    final deliveryAddress = (delivery['address'] ?? '').toString();
    final ad_soyad = (delivery['ad_soyad'] ?? '').toString();

    final int? deliveryManId = (() {
      final v =
          rec['delivery_man_id'] ?? rec['deliver_man_id'] ?? rec['courier_id'];
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    })();

    return _OrderVM(
      orderNumber: orderNumber.isEmpty ? widget.orderNumber : orderNumber,
      status: status,
      createdAt: createdAt,
      shippingAddress: shippingAddress.isEmpty ? null : shippingAddress,
      createdByName: createdByName.isEmpty ? '—' : createdByName,
      ad_soyad: ad_soyad.toString(),
      items: items,
      totals: totals,
      pickPhotoPath:
          (pickPhoto != null && pickPhoto.trim().isNotEmpty) ? pickPhoto : null,
      deliveryPhotoPath:
          (deliveryPhoto != null && deliveryPhoto.trim().isNotEmpty)
              ? deliveryPhoto
              : null,
      deliveryStatus: deliveryStatus,
      pickupLatLng: pickupLL,
      deliveryLatLng: deliveryLL,
      pickupName: pickupName.isEmpty ? null : pickupName,
      pickupAddress: pickupAddress.isEmpty ? null : pickupAddress,
      deliveryName: deliveryName.isEmpty ? null : deliveryName,
      deliveryAddress: deliveryAddress.isEmpty ? null : deliveryAddress,
      deliveryManId: deliveryManId,
      courierLatLng: null,
      courierName: null,
    );
  }

  // ---------------- Users fetch (courier) ----------------

  Future<Map<String, dynamic>?> _fetchUserById(int id) async {
    final dio = context.read<ApiClient>().dio;

    Map<String, dynamic>? pickUser(dynamic payload) {
      if (payload is Map) {
        if (payload['data'] is Map) {
          return Map<String, dynamic>.from(payload['data']);
        }
        if (payload.containsKey('id')) {
          return Map<String, dynamic>.from(payload);
        }
      }
      return null;
    }

    // deneme 1
    try {
      final r = await dio.get('users/$id');
      return pickUser(r.data);
    } catch (_) {}

    // deneme 2
    try {
      final r = await dio.get('user/$id');
      return pickUser(r.data);
    } catch (_) {}

    // deneme 3 (liste)
    try {
      final r =
          await dio.get('users', queryParameters: {'id': id, 'per_page': 1});
      final p = r.data;
      if (p is Map && p['data'] is List && (p['data'] as List).isNotEmpty) {
        return Map<String, dynamic>.from((p['data'] as List).first as Map);
      }
      if (p is Map && p['data'] is Map && (p['data'] as Map)['data'] is List) {
        final l = (p['data'] as Map)['data'] as List;
        if (l.isNotEmpty) return Map<String, dynamic>.from(l.first as Map);
      }
    } catch (_) {}

    return null;
  }

  LatLng? _extractUserLatLng(Map<String, dynamic> u) {
    final lat = _asNullableDouble(u['latitude'] ?? u['lat']);
    final lng = _asNullableDouble(u['longitude'] ?? u['lng'] ?? u['lon']);
    if (lat == null || lng == null) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return LatLng(lat, lng);
  }

  void _startCourierPolling() {
    _courierPollTimer?.cancel();
    _courierPollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return;
      await _refreshCourierAndMaybeRoute(forceRoute: false);
    });
  }

  double _haversineMeters(LatLng a, LatLng b) {
    const R = 6371000.0; // meters
    final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLon = (b.longitude - a.longitude) * math.pi / 180.0;
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * R * math.asin(math.sqrt(h));
  }

  Future<void> _refreshCourierAndMaybeRoute({required bool forceRoute}) async {
    final vm = _order;
    if (vm == null) return;
    final id = vm.deliveryManId;
    if (id == null) return;

    _courierLastFetch = DateTime.now();

    final user = await _fetchUserById(id);
    if (user == null) return;

    final ll = _extractUserLatLng(user);
    final name = (user['name'] ??
            user['full_name'] ??
            user['ad_soyad'] ??
            user['username'])
        ?.toString();

    if (!mounted) return;

    setState(() {
      _order = _order!.copyWithCourier(
        courierLatLng: ll,
        courierName: name,
      );
    });

    // Kurye->Pickup rotasını güncelle
    final courier = ll;
    final pickup = _order?.pickupLatLng;

    if (courier == null || pickup == null) {
      _fitMapToAll();
      return;
    }

    final prev = _courierLastLatLngForRoute;
    final movedMeters =
        (prev == null) ? 999999.0 : _haversineMeters(prev, courier);

    // 30 metreden fazla hareket ettiyse rota yenile (ya da force)
    if (forceRoute || movedMeters >= 30) {
      _courierLastLatLngForRoute = courier;
      await _fetchRouteCP(courier, pickup);
    }
  }

  // ---------------- ROUTES via OSRM ----------------

  Future<void> _fetchRoutePD(LatLng pickup, LatLng delivery) async {
    setState(() {
      _routePDLoading = true;
      _routePDError = null;
      _routePD = [];
      _routePDDistanceMeters = null;
      _routePDDurationSeconds = null;

      _carTimer?.cancel();
      _carPos = null;
      _carIndex = 0;
      _carRotationDeg = 0;
    });

    try {
      final res = await _osrmRoute(pickup, delivery);
      if (!mounted) return;

      setState(() {
        _routePD = res.points;
        _routePDDistanceMeters = res.distanceMeters;
        _routePDDurationSeconds = res.durationSeconds;
        _routePDLoading = false;
      });

      _fitMapToAll();
      _startCarAnimationOnPD();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _routePDError = 'Pickup→Delivery rota alınamadı: $e';
        _routePDLoading = false;
      });
    }
  }

  Future<void> _fetchRouteCP(LatLng courier, LatLng pickup) async {
    setState(() {
      _routeCPLoading = true;
      _routeCPError = null;
      _routeCP = [];
      _routeCPDistanceMeters = null;
      _routeCPDurationSeconds = null;
    });

    try {
      final res = await _osrmRoute(courier, pickup);
      if (!mounted) return;

      setState(() {
        _routeCP = res.points;
        _routeCPDistanceMeters = res.distanceMeters;
        _routeCPDurationSeconds = res.durationSeconds;
        _routeCPLoading = false;
      });

      _fitMapToAll();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _routeCPError = 'Kurye→Pickup rota alınamadı: $e';
        _routeCPLoading = false;
      });
    }
  }

  Future<_RouteResult> _osrmRoute(LatLng a, LatLng b) async {
    // OSRM expects lon,lat
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${a.longitude},${a.latitude};${b.longitude},${b.latitude}'
      '?overview=full&geometries=geojson&steps=false',
    );

    final resp = await http.get(url);
    if (resp.statusCode != 200) {
      throw Exception('OSRM status: ${resp.statusCode}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final routes = (json['routes'] as List?) ?? [];
    if (routes.isEmpty) throw Exception('Rota bulunamadı');

    final first = routes.first as Map<String, dynamic>;
    final dist = (first['distance'] as num?)?.toDouble();
    final dur = (first['duration'] as num?)?.toDouble();

    final geom = first['geometry'] as Map<String, dynamic>;
    final coords = (geom['coordinates'] as List)
        .whereType<List>()
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();

    if (coords.length < 2) throw Exception('Rota kısa/boş');

    return _RouteResult(
      points: coords,
      distanceMeters: dist,
      durationSeconds: dur,
    );
  }

  // ---------------- CAR animation (on PD route) ----------------

  void _startCarAnimationOnPD() {
    _carTimer?.cancel();
    if (_routePD.length < 2) return;

    setState(() {
      _carIndex = 0;
      _carPos = _routePD.first;

      _carRotationDeg = _bearingBetween(_routePD[0], _routePD[1]);
    });

    final int stepMs = _routePD.length > 2000 ? 8 : 15;

    _carTimer = Timer.periodic(Duration(milliseconds: stepMs), (_) {
      if (!mounted) return;
      if (_routePD.isEmpty) return;

      final next = _carIndex + 1;
      if (next >= _routePD.length) {
        _carTimer?.cancel();
        return;
      }

      final p1 = _routePD[_carIndex];
      final p2 = _routePD[next];

      setState(() {
        _carIndex = next;
        _carPos = p2;
        _carRotationDeg = _bearingDeg(p1, p2);
      });
    });
  }

  double _bearingDeg(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * (math.pi / 180);

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    var deg = math.atan2(y, x) * 180 / math.pi;
    deg = (deg + 360) % 360;
    return deg;
  }

  // ---------------- MAP fit bounds ----------------

  LatLngBounds? _boundsFromPoints(List<LatLng> pts) {
    if (pts.isEmpty) return null;
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;

    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // google_maps_flutter LatLngBounds: southwest must be <= northeast
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _fitMapToAll() {
    if (_gmap == null) return;

    final pts = <LatLng>[];
    if (_routePD.isNotEmpty) pts.addAll(_routePD);
    if (_routeCP.isNotEmpty) pts.addAll(_routeCP);

    final o = _order;
    if (pts.isEmpty && o != null) {
      if (o.courierLatLng != null) pts.add(o.courierLatLng!);
      if (o.pickupLatLng != null) pts.add(o.pickupLatLng!);
      if (o.deliveryLatLng != null) pts.add(o.deliveryLatLng!);
    }

    if (pts.isEmpty) return;

    // tek nokta
    if (pts.length == 1) {
      _gmap!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: pts.first, zoom: 14),
        ),
      );
      return;
    }

    final b = _boundsFromPoints(pts);
    if (b == null) return;

    _gmap!.animateCamera(CameraUpdate.newLatLngBounds(b, 60));
  }

  // ---------------- Status Chip ----------------

  String _deliveryStatusLabel(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Durum yok';
    final s = raw.toLowerCase().trim();
    if (s.contains('cancel')) return 'İptal';
    if (s == 'completed' || s.contains('delivered')) return 'Teslim Etti';
    if (s == 'courier_picked_up' || s.contains('picked')) {
      return 'Kurye Teslim Aldı';
    }
    if (s == 'active' || s.contains('enroute') || s.contains('in_transit')) {
      return 'Kuryede';
    }
    return 'Oluşturuldu';
  }

  IconData _deliveryStatusIcon(String? raw) {
    final s = (raw ?? '').toLowerCase().trim();
    if (s.contains('cancel')) return Icons.cancel_outlined;
    if (s == 'completed' || s.contains('delivered')) {
      return Icons.verified_outlined;
    }
    if (s == 'courier_picked_up' || s.contains('picked')) {
      return Icons.inventory_2_outlined;
    }
    if (s == 'active' || s.contains('enroute') || s.contains('in_transit')) {
      return Icons.local_shipping_outlined;
    }
    return Icons.pending_actions_outlined;
  }

  Color _deliveryStatusBg(String? raw) {
    final s = (raw ?? '').toLowerCase().trim();
    if (s.contains('cancel')) return Colors.red.withOpacity(.15);
    if (s == 'completed' || s.contains('delivered')) {
      return Color(0xFF6e188a);
    }
    if (s == 'courier_picked_up' || s.contains('picked')) {
      return Colors.amber.withOpacity(.15);
    }
    if (s == 'active' || s.contains('enroute') || s.contains('in_transit')) {
      return Colors.blue.withOpacity(.15);
    }
    return Colors.grey.withOpacity(.15);
  }

  Widget _deliveryStatusChip(String? raw) {
    final label = _deliveryStatusLabel(raw);
    final icon = _deliveryStatusIcon(raw);
    final bg = _deliveryStatusBg(raw);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }

  // ---------------- BUILD ----------------

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context); // mevcut tema
    final themed = base.copyWith(
      scaffoldBackgroundColor: kBg,
      cardTheme: CardTheme(
        color: kCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerColor: kLine,
      colorScheme: base.colorScheme.copyWith(
        primary: kPurple,
        secondary: kOrange,
        surface: kCard,
      ),
      tabBarTheme: TabBarTheme(
        labelColor: kPurple,
        unselectedLabelColor: kMuted,
        indicatorColor: kPurple,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: kText,
          side: BorderSide(color: kLine),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPurple,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          elevation: 0,
        ),
      ),
    );

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_order == null) {
      return Theme(
        data: themed,
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_long_outlined, size: 64),
                const SizedBox(height: 8),
                Text(_error ?? 'Sipariş bulunamadı'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Geri'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final order = _order!;
    final totals = order.totals;
    final shipmentStatus = order.deliveryStatus ?? widget.initialDeliveryStatus;

    return Theme(
      data: themed,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, box) {
              final isWide = box.maxWidth >= 980;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _topHeader(order, shipmentStatus),
                  const SizedBox(height: 16),
                  if (isWide)
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _mapCard(order)),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 420,
                            child: ListView(
                              children: [
                                _summaryCard(context, order, totals),
                                const SizedBox(height: 12),
                                _itemsCard(context, order),
                                const SizedBox(height: 12),
                                _shipmentCard(shipmentStatus),
                                const SizedBox(height: 12),
                                _photosCard(order),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        children: [
                          _mapCard(order, height: 360),
                          const SizedBox(height: 12),
                          _summaryCard(context, order, totals),
                          const SizedBox(height: 12),
                          _itemsCard(context, order),
                          const SizedBox(height: 12),
                          _shipmentCard(shipmentStatus),
                          const SizedBox(height: 12),
                          _photosCard(order),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _topHeader(_OrderVM order, String? shipmentStatus) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [kPurple2, kPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: kPurple.withOpacity(.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            child: Icon(Icons.receipt_long, color: kPurple),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Sipariş Detayı',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16)),
                SelectableText(
                  order.orderNumber,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14),
                ),
                _deliveryStatusChip(shipmentStatus),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Geri'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0x66FFFFFF)),
            ),
          ),
        ],
      ),
    );
  }

  // ================== MAP UI ==================

  String _prettyKm(double? meters) {
    if (meters == null) return '—';
    final km = meters / 1000.0;
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.toStringAsFixed(0)} km';
  }

  String _prettyMin(double? seconds) {
    if (seconds == null) return '—';
    final totalMin = (seconds / 60).round();
    if (totalMin < 60) return '$totalMin dk';
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    return '${h}sa ${m}dk';
  }

  Widget _mapCard(_OrderVM order, {double? height}) {
    final p = order.pickupLatLng;
    final d = order.deliveryLatLng;
    final c = order.courierLatLng;

    final hasAny = (p != null || d != null || c != null);

    return Card(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // başlık satırı
              Row(
                children: [
                  Text('Harita',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  if (_routeCPLoading || _routePDLoading)
                    const Text('Rota alınıyor…',
                        style: TextStyle(color: Colors.black54)),
                ],
              ),

              const SizedBox(height: 8),

              // rota özetleri
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  _miniChip(
                    icon: Icons.route,
                    title: 'Pickup→Delivery',
                    value:
                        '${_prettyKm(_routePDDistanceMeters)} • ${_prettyMin(_routePDDurationSeconds)}',
                    loading: _routePDLoading,
                    error: _routePDError,
                  ),
                  _miniChip(
                    icon: Icons.delivery_dining,
                    title: 'Kurye→Pickup',
                    value:
                        '${_prettyKm(_routeCPDistanceMeters)} • ${_prettyMin(_routeCPDurationSeconds)}',
                    loading: _routeCPLoading,
                    error: _routeCPError,
                  ),
                  if (order.courierName != null &&
                      order.courierName!.trim().isNotEmpty)
                    _miniChip(
                      icon: Icons.person,
                      title: 'Kurye',
                      value: order.courierName!,
                      loading: false,
                      error: null,
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // mini adresler
              Wrap(
                runSpacing: 6,
                spacing: 12,
                children: [
                  _locMini(
                    title: 'Alış Noktası',
                    name: order.pickupName,
                    address: order.pickupAddress,
                    latLng: p,
                    icon: Icons.store_mall_directory_outlined,
                  ),
                  _locMini(
                    title: 'Teslimat Noktası',
                    name: order.deliveryName,
                    address: order.deliveryAddress,
                    latLng: d,
                    icon: Icons.location_on_outlined,
                  ),
                  _locMini(
                    title: 'Kurye',
                    name: order.courierName,
                    address: null,
                    latLng: c,
                    icon: Icons.delivery_dining,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: hasAny ? _mapWidget(order) : _noLocationBox(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniChip({
    required IconData icon,
    required String title,
    required String value,
    required bool loading,
    required String? error,
  }) {
    final bg = error != null
        ? Colors.red.withOpacity(.10)
        : Colors.black12.withOpacity(.06);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 11, color: Colors.black54)),
              const SizedBox(height: 2),
              if (loading)
                const Text('Yükleniyor…',
                    style: TextStyle(fontWeight: FontWeight.w700))
              else if (error != null)
                const Text('Hata',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: Colors.red))
              else
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noLocationBox() {
    return Container(
      color: Colors.black12.withOpacity(.06),
      child: const Center(
        child: Text(
            'Konum bilgisi bulunamadı (pickup/delivery/kurye lat-lng yok)'),
      ),
    );
  }

  Widget _locMini({
    required String title,
    required String? name,
    required String? address,
    required LatLng? latLng,
    required IconData icon,
  }) {
    final txt = [
      if ((name ?? '').trim().isNotEmpty) name!.trim(),
      if ((address ?? '').trim().isNotEmpty) address!.trim(),
    ].join(' • ');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            txt.isEmpty ? '$title: —' : '$title: $txt',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (latLng != null) ...[
          const SizedBox(width: 8),
          Text(
            '(${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)})',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          )
        ],
      ],
    );
  }

  Widget _mapWidget(_OrderVM order) {
    final pickup = order.pickupLatLng;
    final delivery = order.deliveryLatLng;
    final courier = order.courierLatLng;

    final center =
        courier ?? pickup ?? delivery ?? const LatLng(41.0082, 28.9784);

    // Markers
    final Set<Marker> markers = {
      if (pickup != null)
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          infoWindow: InfoWindow(
            title: 'Pickup',
            snippet: (order.pickupName ?? '').trim().isEmpty
                ? null
                : order.pickupName!.trim(),
          ),
        ),
      if (delivery != null)
        Marker(
          markerId: const MarkerId('delivery'),
          position: delivery,
          infoWindow: InfoWindow(
            title: 'Delivery',
            snippet: (order.deliveryName ?? '').trim().isEmpty
                ? null
                : order.deliveryName!.trim(),
          ),
        ),
      if (courier != null)
        Marker(
          markerId: const MarkerId('courier'),
          position: courier,
          infoWindow: InfoWindow(
            title: 'Kurye',
            snippet: (order.courierName ?? '').trim().isEmpty
                ? null
                : order.courierName!.trim(),
          ),
        ),
      if (_carPos != null)
        Marker(
          markerId: const MarkerId('car'),
          position: _carPos!,
          rotation: _carRotationDeg,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          //    icon:   BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.),

          icon: _motoIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),

          infoWindow: const InfoWindow(title: 'Kurye  (hareket halinde)'),
        ),
    };

    // Polylines
    final Set<Polyline> polylines = {
      if (_routeCP.length >= 2)
        Polyline(
          polylineId: const PolylineId('cp'),
          points: _routeCP,
          width: 4,
        ),
      if (_routePD.length >= 2)
        Polyline(
          polylineId: const PolylineId('pd'),
          points: _routePD,
          width: 6,
        ),
      if (_routePD.isEmpty && pickup != null && delivery != null)
        Polyline(
          polylineId: const PolylineId('fallback'),
          points: [pickup, delivery],
          width: 4,
        ),
    };

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: 13),
      onMapCreated: (c) {
        _gmap = c;
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToAll());
      },
      markers: markers,
      polylines: polylines,
      compassEnabled: true,
      zoomControlsEnabled: true,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  // ================== Right cards ==================

  Widget _summaryCard(BuildContext context, _OrderVM order, _Totals totals) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Özet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _kv('Durum', order.status),
            _kv('Tarih', dt(order.createdAt)),
            if (order.shippingAddress != null)
              _kv('Adres', order.shippingAddress!),
            _kv('Oluşturan', order.createdByName),
            _kv('Alıcı', order.ad_soyad ?? 'Bilinmiyor'),
            const Divider(height: 24),
            _kv('Ara Toplam', tl(totals.subtotal)),
            //        _kv('%8 KDV', tl(totals.vat)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Genel Toplam',
                    style: Theme.of(context).textTheme.titleMedium),
                Text(tl(totals.grandTotal),
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemsCard(BuildContext context, _OrderVM order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ürünler', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (order.items.isEmpty)
              const Text('Ürün kalemi yok')
            else
              Column(
                children: [
                  for (final it in order.items) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            it.productTitle,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (it.qtyCases != null)
                          Text(
                            'x${it.qtyCases!.toStringAsFixed(it.qtyCases! % 1 == 0 ? 0 : 2)}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        const SizedBox(width: 12),
                        Text(
                          tl(it.lineTotal),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _shipmentCard(String? deliveryStatus) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sevkiyat Durumu',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (deliveryStatus == null || deliveryStatus.isEmpty)
              const Text('Sevkiyat kaydı bulunamadı')
            else
              _shipmentTimelineByDeliveryStatus(deliveryStatus),
          ],
        ),
      ),
    );
  }

  Widget _photosCard(_OrderVM order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _photosTabs(order),
      ),
    );
  }

  // ================== Photo ==================

  String _buildImageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    final p = path.trim();
    if (p.startsWith('http://') || p.startsWith('https://')) return p;

    try {
      final base = ('http://localhost:8082/').trim();
      final u = Uri.tryParse(base);
      final origin = (u != null && u.hasScheme && u.host.isNotEmpty)
          ? '${u.scheme}://${u.host}${u.hasPort ? ':${u.port}' : ''}'
          : '';
      final cleanPath = p.replaceFirst(RegExp(r'^/+'), '');
      return '$origin/storage/$cleanPath';
    } catch (_) {
      return '/storage/${p.replaceFirst(RegExp(r"^/+"), "")}';
    }
  }

  Widget _photosTabs(_OrderVM order) {
    final urlPick = _buildImageUrl(order.pickPhotoPath);
    final urlDelivery = _buildImageUrl(order.deliveryPhotoPath);

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library_outlined, size: 18),
              const SizedBox(width: 8),
              Text('Fotoğraflar',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          const TabBar(
            isScrollable: false,
            tabs: [
              Tab(text: 'Alım (pick)'),
              Tab(text: 'Teslim (delivery)'),
            ],
          ),
          SizedBox(
            height: 260,
            child: TabBarView(
              children: [
                _photoGrid([urlPick]),
                _photoGrid([urlDelivery]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoGrid(List<String> urls) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: [
          for (final u in urls)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  color: Colors.black12.withOpacity(.06),
                  child: (u.isEmpty)
                      ? const Center(child: Text('Görsel yok'))
                      : Image.network(
                          u,
                          fit: BoxFit.cover,
                          loadingBuilder: (c, w, p) => p == null
                              ? w
                              : const Center(
                                  child: CircularProgressIndicator()),
                          errorBuilder: (_, __, ___) =>
                              const Center(child: Text('Yüklenemedi')),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ================== Timeline ==================

  int _mapDeliveryStatusToStage(String raw) {
    final s = raw.toLowerCase().trim();
    if (s.contains('cancel')) return -1;
    if (s == 'completed' || s.contains('delivered')) return 3;
    if (s == 'active' || s.contains('enroute') || s.contains('in_transit')) {
      return 1;
    }
    if (s == 'courier_picked_up' || s.contains('picked')) return 2;
    return 0;
  }

  Widget _shipmentTimelineByDeliveryStatus(String status) {
    final current = _mapDeliveryStatusToStage(status);

    const stages = [
      ('Talep Oluşturuldu', Icons.pending_actions_outlined),
      ('Kurye İşi Aldı', Icons.inventory_2_outlined),
      ('Paket Teslim Alındı', Icons.inventory_2_outlined),
      ('Paket Teslim Edildi', Icons.verified_outlined),
    ];

    if (current == -1) {
      return Row(
        children: const [
          CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFFFFE5E5),
            child: Icon(Icons.cancel_outlined, color: Colors.red),
          ),
          SizedBox(width: 8),
          Text('Sipariş İptal Edildi',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < stages.length; i++)
          _vStage(
            label: stages[i].$1,
            icon: stages[i].$2,
            state: i < current
                ? _StageState.done
                : (i == current ? _StageState.current : _StageState.todo),
            showConnectorBelow: i != stages.length - 1,
          ),
      ],
    );
  }

  // ================== Small UI helpers ==================

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: Colors.black54)),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(v, textAlign: TextAlign.right),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vStage({
    required String label,
    required IconData icon,
    required _StageState state,
    required bool showConnectorBelow,
  }) {
    final Color color = switch (state) {
      _StageState.done => Color(0xFF6e188a),
      _StageState.current => Colors.amber,
      _StageState.todo => Colors.black26,
    };
    final Color lineColor =
        state == _StageState.done ? Color(0xFF6e188a) : Colors.black12;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: color.withOpacity(.15),
                child: Icon(icon, color: color, size: 18),
              ),
              if (showConnectorBelow)
                Container(width: 2, height: 24, color: lineColor),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: state == _StageState.todo
                      ? FontWeight.w500
                      : FontWeight.w700,
                  color: state == _StageState.todo
                      ? Colors.black54
                      : Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================== Route result ==================

class _RouteResult {
  final List<LatLng> points;
  final double? distanceMeters;
  final double? durationSeconds;

  _RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

// ================== ViewModel & totals ==================

class _OrderItemVM {
  final String productTitle;
  final double? qtyCases;
  final double? approxKgPerCase;
  final double? pricePerKg;
  final double lineTotal;

  _OrderItemVM({
    required this.productTitle,
    required this.qtyCases,
    required this.approxKgPerCase,
    required this.pricePerKg,
    required this.lineTotal,
  });
}

class _Totals {
  final double subtotal;
  final double vat;
  final double grandTotal;
  const _Totals(this.subtotal, this.vat, this.grandTotal);
}

class _OrderVM {
  final String orderNumber;
  final String status;
  final DateTime createdAt;
  final String? shippingAddress;
  final String createdByName;
  final String ad_soyad;
  final List<_OrderItemVM> items;
  final _Totals totals;

  final String? pickPhotoPath;
  final String? deliveryPhotoPath;
  final String? deliveryStatus;

  final LatLng? pickupLatLng;
  final LatLng? deliveryLatLng;

  final String? pickupName;
  final String? pickupAddress;
  final String? deliveryName;
  final String? deliveryAddress;

  // ✅ Kurye
  final int? deliveryManId; // delivery_orders.delivery_man_id
  final LatLng? courierLatLng; // users.latitude/longitude
  final String? courierName;

  _OrderVM({
    required this.orderNumber,
    required this.status,
    required this.createdAt,
    required this.shippingAddress,
    required this.createdByName,
    required this.ad_soyad,
    required this.items,
    required this.totals,
    this.pickPhotoPath,
    this.deliveryPhotoPath,
    this.deliveryStatus,
    this.pickupLatLng,
    this.deliveryLatLng,
    this.pickupName,
    this.pickupAddress,
    this.deliveryName,
    this.deliveryAddress,
    this.deliveryManId,
    this.courierLatLng,
    this.courierName,
  });

  _OrderVM copyWithCourier({LatLng? courierLatLng, String? courierName}) {
    return _OrderVM(
      orderNumber: orderNumber,
      status: status,
      createdAt: createdAt,
      shippingAddress: shippingAddress,
      createdByName: createdByName,
      ad_soyad: ad_soyad,
      items: items,
      totals: totals,
      pickPhotoPath: pickPhotoPath,
      deliveryPhotoPath: deliveryPhotoPath,
      deliveryStatus: deliveryStatus,
      pickupLatLng: pickupLatLng,
      deliveryLatLng: deliveryLatLng,
      pickupName: pickupName,
      pickupAddress: pickupAddress,
      deliveryName: deliveryName,
      deliveryAddress: deliveryAddress,
      deliveryManId: deliveryManId,
      courierLatLng: courierLatLng ?? this.courierLatLng,
      courierName: courierName ?? this.courierName,
    );
  }
}
