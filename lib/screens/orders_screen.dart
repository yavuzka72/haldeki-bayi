import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/api_client.dart';
import '../utils/format.dart';
import 'haldeki_ui.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  // ===== Premium Colors (match delivery_orders_screen.dart) =====
  static const Color kGreen = Color(0xFF0D4631);
  static const Color kGreenDark = Color(0xFF0D4631);
  static const Color kAmber = Color(0xFF98F090);
  static const Color kGray = Color(0xFF6B7280);
  static const Color kBg = Color(0xFFF6F7FB);
  static const Color kBorder = Color(0xFFE5E7EB);
  static const Color kHaldekiGreen = Color(0xFF16A34A); // Tailwind green-600

// deliveryStatus yoksa bunu kullanma

  // Veri
  List<_Order> _all = [];
  List<_Order> _visible = [];
  String? _hoveredRowId;
  // Çoklu seçim: order.id set
  final Set<String> _selectedOrderIds = {};
  final Set<String> _handoffLoading = {};
  // _hasMultiSelection is now unused (removed for clarity)

  // ✅ Master-detail seçili kayıt
  _Order? _selected;

  // Arama & sıralama
  final _search = TextEditingController();
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final bool canAssignCourier = true;
  // UI state
  bool _loading = true;
  String? _error;

  // Dealer durum seçenekleri — ENUM (EN)
  static const List<String> _statusDealerOptions = [
    'pending',
    'courier',
    'delivered',
    'closed',
    'cancelled',
  ];
  String mapUiStatusToEnum(String ui) {
    switch (ui.trim().toLowerCase()) {
      case 'onaylandı':
        return 'confirmed';
      case 'iptal':
        return 'canceled';
      case 'bekliyor':
      default:
        return 'pending';
    }
  }

  // NORMAL (legacy TR) seçenekler — backend geriye uyumluluk için
  static const List<String> _statusOptions = [
    'bekliyor',
    'onaylandı',
    'iptal',
  ];

  // Üst bar filtre (dealer enum) — segment gibi çalışsın
  String? _dealerFilter; // null = tümü

  // Sipariş tipi filtresi: null = hepsi, 'client' = işletme, 'user' = müşteri
  String? _userTypeFilter;

  // Tarih filtresi
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ---------------- API ----------------

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedOrderIds.clear();
    });

    try {
      final api = context.read<ApiClient>();
      final dio = api.dio;
      final dealerEmail = api.currentEmail;

      if (dealerEmail == null || dealerEmail.isEmpty) {
        setState(() {
          _error = 'Oturum bulunamadı. Lütfen tekrar giriş yapın.';
        });
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      dynamic data;
      try {
        final res = await dio.post(
          AppConfig.dealerOrdersPath,
          data: {'email': dealerEmail},
          queryParameters: {'page': 1},
        );
        data = res.data;
      } catch (_) {
        // Bazı backend sürümlerinde bu endpoint GET olarak çalışıyor.
        final res = await dio.get(
          AppConfig.dealerOrdersPath,
          queryParameters: {'page': 1},
        );
        data = res.data;
      }

      final list = _parseOrdersPayload(data);
      setState(() {
        _all = list;
        _visible = List.of(_all);
        _applyFilters();
        _applySort();
      });
    } catch (e) {
      setState(() => _error = 'Siparişler yüklenemedi: ${_humanizeError(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _humanizeError(Object e) {
    final s = e.toString();
    if (s.contains('DioException')) {
      final code = RegExp(r'status code of (\d{3})').firstMatch(s)?.group(1);
      if (code != null) return 'Sunucu hatası (HTTP $code).';
      return 'Ağ hatası oluştu.';
    }
    return s;
  }

  Widget _miniIconBtn({
    required String tooltip,
    required IconData icon,
    Color? color,
    VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      splashRadius: 18,
    );
  }

  // JSON -> _Order[]
  List<_Order> _parseOrdersPayloadOld(dynamic payload) {
    List items;
    if (payload is List) {
      items = payload;
    } else if (payload is Map) {
      if (payload['data'] is List) {
        items = payload['data'];
      } else if (payload['results'] is List) {
        items = payload['results'];
      } else {
        items = [];
      }
    } else {
      items = [];
    }

    String pickStr(Map m, List<String> keys, {String fallback = ''}) {
      for (final k in keys) {
        final v = m[k];
        if (v == null) continue;
        final s = v.toString();
        if (s.isNotEmpty) return s;
      }
      return fallback;
    }

    double pickNum(Map m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v == null) continue;
        if (v is num) return v.toDouble();
        if (v is String) {
          final d = double.tryParse(v.replaceAll(',', '.'));
          if (d != null) return d;
        }
      }
      return 0.0;
    }

    DateTime pickDate(Map m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is String) {
          final d = DateTime.tryParse(v);
          if (d != null) return d;
        }
        if (v is int) {
          final s = v.toString();
          if (s.length >= 13) return DateTime.fromMillisecondsSinceEpoch(v);
          if (s.length >= 10) {
            return DateTime.fromMillisecondsSinceEpoch(v * 1000);
          }
        }
      }
      return DateTime.now();
    }

    int pickInt(Map m, List<String> keys, {int fallback = 0}) {
      for (final k in keys) {
        final v = m[k];
        if (v == null) continue;
        if (v is num) return v.toInt();
        if (v is String) {
          final i = int.tryParse(v);
          if (i != null) return i;
        }
      }
      return fallback;
    }

    return items.whereType<Map>().map((raw0) {
      final raw = Map<String, dynamic>.from(raw0);

      final deliveryStatus = pickInt(raw, ['delivery_status'], fallback: 0);

      final id = pickStr(raw, ['id', '_id', 'order_id'], fallback: '');
      final number = pickStr(
        raw,
        ['orderNumber', 'order_number', 'number', 'code', 'no'],
        fallback: id.isEmpty ? '—' : '#$id',
      );

      final partnerOrderId = pickStr(
        raw,
        ['partner_order_id', 'partnerOrderId'],
        fallback: '',
      );
      final rawDealerStatus = pickStr(
        raw,
        ['dealer_status', 'dealer_status_ui', 'status', 'state'],
        fallback: '',
      );

      final rawStatus = pickStr(
        raw,
        ['status', 'status_ui', 'state'],
        fallback: '',
      );

      final rawSupplierStatus = pickStr(
        raw,
        [
          'supplier_status',
          'supplierStatus',
          'supplier_status_ui',
          'supplierState',
        ],
        fallback: '',
      );

      final createdAt = pickDate(raw, [
        'createdAt',
        'created_at',
        'date',
        'ordered_at',
        'created_at_iso',
      ]);

      final total =
          pickNum(raw, ['total', 'total_amount', 'amount', 'grand_total']);

      final address = pickStr(raw, [
        'shippingAddress',
        'shipping_address',
        'address',
        'delivery_address',
      ]);

      final buyerName = pickStr(raw, ['buyer_name', 'buyerName']);
      final buyerCity = pickStr(raw, ['buyer_city', 'buyerCity']);
      final buyerDistrict = pickStr(raw, ['buyer_district', 'buyerDistrict']);
      final buyerType = pickStr(raw, ['buyer_type', 'buyerType']);

      final createdBy = pickStr(
        raw,
        [
          'createdByName',
          'created_by_name',
          'user_name',
          'customer_name',
          'createdBy',
        ],
        fallback: buyerName,
      );

      // user_type / buyer_type: client veya user
      final userType = pickStr(
        raw,
        ['usertype', 'buyer_type', 'buyerType'],
        fallback: 'user',
      ).toLowerCase();

      final user_type = pickStr(
        raw,
        ['user_type'],
        fallback: 'user',
      ).toLowerCase();

      final int userId = pickInt(raw, ['user_id'], fallback: 0);
      final adSoyad = pickStr(raw, ['ad_soyad']);
      // Dealer status'i normalize et, yoksa status'ten türet
      final dealerEnum = _normalizeDealerStatusEnum(
        rawDealerStatus.isNotEmpty ? rawDealerStatus : rawStatus,
      );

      final legacyStatusTr = _toUiStatus(rawStatus);

      return _Order(
        id: id,
        orderNumber: number,
        // status = dealer enum ile senkron
        status: legacyStatusTr,
        dealer_status: dealerEnum,
        supplier_status: _toUiSupStatus(rawSupplierStatus), // TR
        createdAt: createdAt,
        totalAmount: total,
        shippingAddress: address.isEmpty ? null : address,
        createdByName: createdBy.isNotEmpty ? createdBy : '—',
        buyerName: buyerName.isNotEmpty ? buyerName : null,
        buyerCity: buyerCity.isNotEmpty ? buyerCity : null,
        buyerDistrict: buyerDistrict.isNotEmpty ? buyerDistrict : null,
        buyerType: buyerType.isNotEmpty ? buyerType : null,
        userType: (userType == 'client' || userType == 'user')
            ? userType
            : 'user', // fallback

        deliveryStatus: deliveryStatus,
        user_type: (user_type == 'client' || user_type == 'user')
            ? user_type
            : 'user', // fallback
        user_id: userId,
      );
    }).toList();
  }

  List<_Order> _parseOrdersPayload(dynamic payload) {
    List items;
    if (payload is List) {
      items = payload;
    } else if (payload is Map) {
      if (payload['data'] is List) {
        items = payload['data'];
      } else if (payload['results'] is List) {
        items = payload['results'];
      } else {
        items = [];
      }
    } else {
      items = [];
    }

    String pickStr(Map m, List<String> keys, {String fallback = ''}) {
      for (final k in keys) {
        final v = m[k];
        if (v == null) continue;
        final s = v.toString();
        if (s.isNotEmpty) return s;
      }
      return fallback;
    }

    double pickNum(Map m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v == null) continue;
        if (v is num) return v.toDouble();
        if (v is String) {
          final d = double.tryParse(v.replaceAll(',', '.'));
          if (d != null) return d;
        }
      }
      return 0.0;
    }

    // ✅ nullable sayı (lat/long için)
    double? pickNumNullable(Map m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v == null) continue;
        if (v is num) return v.toDouble();
        if (v is String) {
          final s = v.trim();
          if (s.isEmpty) continue;
          final d = double.tryParse(s.replaceAll(',', '.'));
          if (d != null) return d;
        }
      }
      return null;
    }

    DateTime pickDate(Map m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is String) {
          final d = DateTime.tryParse(v);
          if (d != null) return d;
        }
        if (v is int) {
          final s = v.toString();
          if (s.length >= 13) return DateTime.fromMillisecondsSinceEpoch(v);
          if (s.length >= 10) {
            return DateTime.fromMillisecondsSinceEpoch(v * 1000);
          }
        }
      }
      return DateTime.now();
    }

    int pickInt(Map m, List<String> keys, {int fallback = 0}) {
      for (final k in keys) {
        final v = m[k];
        if (v == null) continue;
        if (v is num) return v.toInt();
        if (v is String) {
          final i = int.tryParse(v);
          if (i != null) return i;
        }
      }
      return fallback;
    }

    return items.whereType<Map>().map((raw0) {
      final raw = Map<String, dynamic>.from(raw0);

      final deliveryStatus = pickInt(raw, ['delivery_status'], fallback: 0);

      final id = pickStr(raw, ['id', '_id', 'order_id'], fallback: '');
      final number = pickStr(
        raw,
        ['orderNumber', 'order_number', 'number', 'code', 'no'],
        fallback: id.isEmpty ? '—' : '#$id',
      );

      final partnerOrderId = pickStr(
        raw,
        ['partner_order_id', 'partnerOrderId'],
        fallback: '',
      );
      final rawDealerStatus = pickStr(
        raw,
        ['dealer_status', 'dealer_status_ui', 'status', 'state'],
        fallback: '',
      );

      final rawStatus = pickStr(
        raw,
        ['status', 'status_ui', 'state'],
        fallback: '',
      );

      final rawSupplierStatus = pickStr(
        raw,
        [
          'supplier_status',
          'supplierStatus',
          'supplier_status_ui',
          'supplierState',
        ],
        fallback: '',
      );

      final createdAt = pickDate(raw, [
        'createdAt',
        'created_at',
        'date',
        'ordered_at',
        'created_at_iso',
      ]);

      final total =
          pickNum(raw, ['total', 'total_amount', 'amount', 'grand_total']);

      final address = pickStr(raw, [
        'shippingAddress',
        'shipping_address',
        'address',
        'delivery_address',
      ]);

      final buyerName = pickStr(raw, ['buyer_name', 'buyerName']);
      final buyerCity = pickStr(raw, ['buyer_city', 'buyerCity']);
      final buyerDistrict = pickStr(raw, ['buyer_district', 'buyerDistrict']);
      final buyerType = pickStr(raw, ['buyer_type', 'buyerType']);

      final createdBy = pickStr(
        raw,
        [
          'createdByName',
          'created_by_name',
          'user_name',
          'customer_name',
          'createdBy',
        ],
        fallback: buyerName,
      );

      // ✅ partner_client alanları (backend alias isimleriyle)
      final partnerName = pickStr(raw, ['partner_client_name'], fallback: '');
      final partnerAddr =
          pickStr(raw, ['partner_client_address'], fallback: '');
      final partnerLat = pickNumNullable(raw, ['partner_client_lat']);
      final partnerLong = pickNumNullable(raw, ['partner_client_long']);

      final adSoyadPick = pickStr(raw, ['ad_soyad']);

      // user_type / buyer_type: client veya user
      final userType = pickStr(
        raw,
        ['usertype', 'buyer_type', 'buyerType'],
        fallback: 'user',
      ).toLowerCase();

      final user_type = pickStr(
        raw,
        [
          'user_type',
        ],
        fallback: 'user',
      ).toLowerCase();

      final int userId = pickInt(raw, ['user_id'], fallback: 0);

      // Dealer status'i normalize et, yoksa status'ten türet
      final dealerEnum = _normalizeDealerStatusEnum(
        rawDealerStatus.isNotEmpty ? rawDealerStatus : rawStatus,
      );

      final legacyStatusTr = _toUiStatus(rawStatus);

      return _Order(
        id: id,
        orderNumber: number,
        status: legacyStatusTr,
        dealer_status: dealerEnum,
        supplier_status: _toUiSupStatus(rawSupplierStatus),
        createdAt: createdAt,
        totalAmount: total,
        shippingAddress: address.isEmpty ? null : address,
        createdByName: createdBy.isNotEmpty ? createdBy : '—',
        buyerName: buyerName.isNotEmpty ? buyerName : null,
        buyerCity: buyerCity.isNotEmpty ? buyerCity : null,
        buyerDistrict: buyerDistrict.isNotEmpty ? buyerDistrict : null,
        buyerType: buyerType.isNotEmpty ? buyerType : null,
        userType:
            (userType == 'client' || userType == 'user') ? userType : 'user',
        deliveryStatus: deliveryStatus,
        user_id: userId,
        user_type:
            (user_type == 'client' || user_type == 'user') ? user_type : 'user',
        // ✅ EKLENDİ: partner client
        partnerOrderId: partnerOrderId.isNotEmpty ? partnerOrderId : null,
        partner_client_name: partnerName.isNotEmpty ? partnerName : null,
        partner_client_address: partnerAddr.isNotEmpty ? partnerAddr : null,
        partner_client_lat: partnerLat,
        partner_client_long: partnerLong,
        adSoyad: adSoyadPick.isNotEmpty ? adSoyadPick : null,
      );
    }).toList();
  }

  // ---------------- Çoklu seçim helpers ----------------

  void _toggleSelection(_Order o, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedOrderIds.add(o.id);
      } else {
        _selectedOrderIds.remove(o.id);
      }
    });
  }

  // _clearSelection is now unused (removed for clarity)

  // _handoffSelectedToCouriers is now unused (removed for clarity)

  // ---------------- Filters & Sort ----------------

  void _applyFilters() {
    final q = _search.text.trim().toLowerCase();
    setState(() {
      Iterable<_Order> list = _all;

      // Sipariş tipi filtresi: client / user
      if (_userTypeFilter != null) {
        list = list.where((o) => o.user_type == _userTypeFilter);
      }

      // Dealer durumu filtresi
      if (_dealerFilter != null) {
        list = list.where((o) => o.dealer_status == _dealerFilter);
      }

      // Tarih filtresi (iki tarih arası)
      if (_fromDate != null) {
        final from = DateTime(
            _fromDate!.year, _fromDate!.month, _fromDate!.day, 0, 0, 0);
        list = list.where((o) => !o.createdAt.isBefore(from));
      }
      if (_toDate != null) {
        final to =
            DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
        list = list.where((o) => !o.createdAt.isAfter(to));
      }

      // Arama filtresi
      if (q.isNotEmpty) {
        list = list.where((o) =>
            o.orderNumber.toLowerCase().contains(q) ||
            (o.shippingAddress ?? '').toLowerCase().contains(q) ||
            o.createdByName.toLowerCase().contains(q) ||
            (o.buyerName ?? '').toLowerCase().contains(q) ||
            (o.buyerCity ?? '').toLowerCase().contains(q) ||
            (o.buyerType ?? '').toLowerCase().contains(q) ||
            (o.buyerDistrict ?? '').toLowerCase().contains(q));
      }

      _visible = list.toList();

      // ✅ seçim koru (yoksa ilkini seç)
      if (_visible.isEmpty) {
        _selected = null;
      } else {
        final still =
            _selected != null && _visible.any((x) => x.id == _selected!.id);
        _selected = still ? _selected : _visible.first;
      }
    });
  }

  void _applySort() {
    if (_sortColumnIndex == null) return;
    final col = _sortColumnIndex!;
    _visible.sort((a, b) {
      int cmp;
      switch (col) {
        case 0:
          cmp = a.orderNumber.compareTo(b.orderNumber);
          break;
        case 1:
          cmp = (a.buyerName ?? '').compareTo(b.buyerName ?? '');
          break;
        case 2:
          cmp = (a.buyerCity ?? '').compareTo(b.buyerCity ?? '');
          break;
        case 3:
          cmp = (a.buyerDistrict ?? '').compareTo(b.buyerDistrict ?? '');
          break;
        case 4:
          // status artık dealer enum ile senkron, TR label üzerinden sırala
          cmp = _statusDealerLabel(a.status)
              .compareTo(_statusDealerLabel(b.status));
          break;
        case 5:
          cmp = _statusDealerLabel(a.dealer_status)
              .compareTo(_statusDealerLabel(b.dealer_status));
          break;
        case 6:
          cmp = _statusSupLabel(a.supplier_status)
              .compareTo(_statusSupLabel(b.supplier_status));
          break;
        case 7:
          cmp = a.createdAt.compareTo(b.createdAt);
          break;
        case 8:
          cmp = a.totalAmount.compareTo(b.totalAmount);
          break;
        default:
          cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
  }

  // _onSort is now unused (removed for clarity)

  // ---------------- Status helpers ----------------

  // Dealer ENUM normalize (EN)
  String _normalizeDealerStatusEnum(String? v) {
    final t = (v ?? '').toLowerCase().trim();
    if (_statusDealerOptions.contains(t)) return t;

    if (t == 'prepare' ||
        t == 'preparing' ||
        t.contains('hazır') ||
        t.contains('bekle')) {
      return 'pending';
    }
    if (t == 'shipped' ||
        t == 'in_transit' ||
        t == 'on_the_way' ||
        t == 'transit' ||
        t == 'away' ||
        t.contains('sevk') ||
        t.contains('kuryede') ||
        t.contains('yol')) {
      return 'courier';
    }
    if (t == 'delivered' ||
        t == 'completed' ||
        t == 'complete' ||
        t.contains('teslim')) {
      return 'delivered';
    }
    if (t == 'cancel' ||
        t == 'canceled' ||
        t == 'cancelled' ||
        t.contains('iptal')) {
      return 'cancelled';
    }
    if (t == 'closed' || t == 'done' || t == 'finished' || t == 'archived') {
      return 'closed';
    }
    return 'pending';
  }

  // Legacy/TR status → TR label kümeleri
  String _toUiStatus(String input) {
    final t = input.toLowerCase().trim();
    if (t.contains('bekli')) return 'bekliyor';
    if (t.contains('onay')) return 'onaylandı';

    if (t.contains('teslim')) return 'teslim';
    if (t.contains('iptal')) return 'iptal';

    if (t == 'pending' || t == 'prepare' || t == 'preparing') return 'bekliyor';
    if (t == 'confirmed' ||
        t == 'confirm' ||
        t == 'approved' ||
        t == 'accepted') {
      return 'onaylandı';
    }

    if (t == 'delivered' || t == 'completed' || t == 'complete') {
      return 'teslim';
    }
    if (t == 'cancel' || t == 'canceled' || t == 'cancelled') return 'iptal';

    return 'bekliyor';
  }

  // Supplier için TR normalize
  String _toUiSupStatus(String input) {
    final raw = (input).trim();
    if (raw.isEmpty) return 'bekliyor';
    final t = raw
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');

    if (t.contains('bekli')) return 'bekliyor';
    if (t.contains('hazir')) return 'hazırlanıyor';
    if (t.contains('sevk') || t.contains('kargo') || t.contains('transit')) {
      return 'sevk edildi';
    }
    if (t.contains('teslim')) return 'teslim edildi';
    if (t.contains('iptal')) return 'iptal';

    switch (t) {
      case 'wait':
      case 'waiting':
      case 'pending':
        return 'bekliyor';
      case 'prepare':
      case 'preparing':
        return 'hazırlanıyor';
      case 'shipped':
      case 'in_transit':
      case 'on_the_way':
      case 'transit':
        return 'sevk edildi';
      case 'delivered':
      case 'complete':
      case 'completed':
        return 'teslim edildi';
      case 'cancel':
      case 'canceled':
      case 'cancelled':
      case 'rejected':
        return 'iptal';
    }
    return 'bekliyor';
  }

  String _statusLabel(String statusTr) {
    switch (statusTr) {
      case 'bekliyor':
        return 'Bekliyor';
      case 'onaylandı':
        return 'Onaylandı';

      case 'iptal':
        return 'İptal';
      default:
        return statusTr;
    }
  }

  String _statusSupLabel(String s) {
    switch (s) {
      case 'bekliyor':
        return 'Bekliyor';
      case 'hazırlanıyor':
        return 'Hazırlanıyor';
      case 'sevk edildi':
        return 'Sevk edildi';
      case 'teslim edildi':
        return 'Teslim Edildi';
      case 'iptal':
        return 'İptal';
      default:
        return 'Bekliyor';
    }
  }

  // Dealer label — ENUM (EN) → TR
  String _statusDealerLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Bekliyor';
      case 'courier':
        return 'Sevk edildi';
      case 'delivered':
        return 'Teslim edildi';
      case 'closed':
        return 'Kapatıldı';
      case 'cancelled':
        return 'İptal';
      default:
        return status;
    }
  }

  IconData _statusIconDealer(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_bottom_outlined;
      case 'courier':
        return Icons.local_shipping_outlined;
      case 'delivered':
        return Icons.check_circle_outline;
      case 'closed':
        return Icons.inventory_2_outlined;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color _statusBgDealer(String status) {
    switch (status) {
      case 'pending':
        return Colors.amber.withOpacity(.15);
      case 'courier':
        return Colors.blue.withOpacity(.15);
      case 'delivered':
        return Colors.green.withOpacity(.15);
      case 'closed':
        return Colors.grey.withOpacity(.15);
      case 'cancelled':
        return Colors.red.withOpacity(.15);
      default:
        return Colors.grey.withOpacity(.15);
    }
  }

  // ---------------- Status updaters / helpers ----------------

  Future<void> _pickAndUpdateStatus(_Order o) async {
    final current = _toUiStatus(o.status);

    final newStatus = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Sipariş Durumu",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 18),
              ..._statusOptions.map((status) {
                final isSelected = status == current;
                final color = _statusColor(status);

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(ctx, status),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withOpacity(0.12)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isSelected ? color : Colors.grey.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 20,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _statusLabel(status),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: color,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle, size: 18, color: color),
                      ],
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );

    if (newStatus == null || newStatus == current) return;

    // 🔥 OPTIMISTIC UPDATE
    setState(() {
      final ix = _all.indexWhere((e) => e.orderNumber == o.orderNumber);
      if (ix >= 0) {
        _all[ix] = _all[ix].copyWith(status: newStatus);
      }

      final vx = _visible.indexWhere((e) => e.orderNumber == o.orderNumber);
      if (vx >= 0) {
        _visible[vx] = _visible[vx].copyWith(status: newStatus);
      }
    });

    try {
      await _sendStatusUpdate(o.orderNumber, newStatus);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _statusColor(newStatus),
          content: Text(
            "Durum güncellendi → ${_statusLabel(newStatus)}",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
    } catch (e) {
      // ❌ ROLLBACK
      setState(() {
        final ix = _all.indexWhere((e) => e.orderNumber == o.orderNumber);
        if (ix >= 0) {
          _all[ix] = _all[ix].copyWith(status: o.status);
        }

        final vx = _visible.indexWhere((e) => e.orderNumber == o.orderNumber);
        if (vx >= 0) {
          _visible[vx] = _visible[vx].copyWith(status: o.status);
        }
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text("Güncelleme başarısız ❌"),
        ),
      );
    }
  }

  Future<void> _pickDealerAndUpdateStatus(_Order o) async {
    String selected = o.dealer_status;

    final newStatus = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sipariş Durumu Güncelle'),
        content: StatefulBuilder(
          builder: (ctx, setS) {
            return DropdownButton<String>(
              value: _statusDealerOptions.contains(selected)
                  ? selected
                  : _statusDealerOptions.first,
              isExpanded: true,
              items: _statusDealerOptions
                  .map((s) => DropdownMenuItem<String>(
                        value: s,
                        child: Text(_statusDealerLabel(s)),
                      ))
                  .toList(),
              onChanged: (v) => setS(() => selected = v ?? selected),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, selected),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (newStatus == null || newStatus == o.dealer_status) return;

    try {
      await _sendDealerStatusUpdate(o.orderNumber, newStatus);
      setState(() {
        final ix = _all.indexWhere((e) => e.orderNumber == o.orderNumber);
        if (ix >= 0) _all[ix] = _all[ix].copyWith(dealer_status: newStatus);
        final vx = _visible.indexWhere((e) => e.orderNumber == o.orderNumber);
        if (vx >= 0) {
          _visible[vx] = _visible[vx].copyWith(dealer_status: newStatus);
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Durum güncellendi: ${_statusDealerLabel(newStatus)}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Güncelleme başarısız: $e'),
        ),
      );
    }
  }

  Future<void> _sendStatusUpdate(String orderNumber, String uiStatusTr) async {
    final api = context.read<ApiClient>();
    final dio = api.dio;
    String email = api.currentEmail.toString();

    final enumStatus = mapUiStatusToEnum(uiStatusTr);

    await dio.post(
      'order-update-status',
      data: {'email': email, 'order_number': orderNumber, 'status': enumStatus},
    );
  }

  Future<void> _sendDealerStatusUpdate(
      String orderNumber, String dealerEnum) async {
    final api = context.read<ApiClient>();
    final dio = api.dio;
    String email = api.currentEmail.toString();

    await dio.post(
      'dealer-order-update-status',
      data: {
        'email': email,
        'order_number': orderNumber,
        'dealer_status': dealerEnum,
      },
    );
  }

  // ---------------- Tarih picker helper ----------------

  String _fmtDateShort(DateTime? d) {
    if (d == null) return 'Tarih seç';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd.$mm.$yy';
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final initial = _fromDate ?? DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        _applyFilters();
        _applySort();
      });
    }
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final initial = _toDate ?? DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) {
      setState(() {
        _toDate = picked;
        _applyFilters();
        _applySort();
      });
    }
  }

  // ---------------- BUILD ----------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themed = HaldekiUI.withRectButtons(context, cs).copyWith(
      inputDecorationTheme: HaldekiUI.inputDense(context),
      dataTableTheme: HaldekiUI.dataTableTheme(cs),
    );

    if (_loading) {
      return Theme(
        data: themed,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Theme(
        data: themed,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 8),
              Text(_error!),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );
    }

    // METRİKLER: toplam sipariş / bekleyen / sevk edilen / teslim edilen
    final totalOrders = _visible.length;
    final pending = _visible.where((o) => o.dealer_status == 'pending').length;
    final courier = _visible.where((o) => o.dealer_status == 'courier').length;
    final delivered =
        _visible.where((o) => o.dealer_status == 'delivered').length;

    return Theme(
      data: themed,
      child: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
              children: [
                _heroHeader(
                  totalOrders: totalOrders,
                  pending: pending,
                  courier: courier,
                  delivered: delivered,
                  onRefresh: _load,
                ),
                const SizedBox(height: 14),
                _filtersCard(),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, box) {
                    final wide = box.maxWidth >= 1100;
                    if (!wide) {
                      return _ordersContainer(
                        child: _visible.isEmpty
                            ? _emptyState()
                            : _ordersCardsList(shrinkWrap: true),
                      );
                    }

                    final h = MediaQuery.of(context).size.height;
                    final tableH =
                        (h - 260).clamp(520.0, 760.0); // ✅ esnek yükseklik

                    return SizedBox(
                      height: tableH,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: _ordersContainer(
                              child: _visible.isEmpty
                                  ? _emptyState()
                                  : _ordersWideTable(shrinkWrap: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          /*    Expanded(
                            flex: 4,
                            child: _rightOrderDetailPanel(),
                          ),
                          */
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ordersContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: kGreen.withOpacity(0.45),
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            color: Color(0x14000000),
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10), // ✅ 14 -> 10
        child: child,
      ),
    );
  }

  Widget _heroHeader({
    required int totalOrders,
    required int pending,
    required int courier,
    required int delivered,
    required VoidCallback onRefresh,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [kGreenDark, kGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            color: kGreen.withOpacity(.22),
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(.55),
                      blurRadius: 16,
                    )
                  ],
                ),
                child: const CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.list_alt_outlined, color: kGreenDark),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Siparişler",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18)),
                    SizedBox(height: 2),
                    Text("Tüm sipariş kayıtları • filtrele • güncelle",
                        style: TextStyle(
                            color: Color(0xEEFFFFFF),
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: onRefresh,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x66FFFFFF)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.refresh, size: 22),
                label: const Text("Yenile",
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, box) {
              final isWide = box.maxWidth >= 860;
              final cards = [
                _miniStat("Toplam", "$totalOrders", Icons.list_alt_outlined),
                _miniStat(
                    "Bekleyen", "$pending", Icons.hourglass_bottom_outlined),
                _miniStat(
                    "Sevk edilen", "$courier", Icons.local_shipping_outlined),
                _miniStat(
                    "Teslim edilen", "$delivered", Icons.check_circle_outline),
              ];
              if (isWide) {
                return Row(
                  children: [
                    for (int i = 0; i < cards.length; i++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              right: i == cards.length - 1 ? 0 : 10),
                          child: cards[i],
                        ),
                      ),
                  ],
                );
              }
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: cards
                    .map((e) =>
                        SizedBox(width: (box.maxWidth - 10) / 2, child: e))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x22FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xEEFFFFFF),
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _filtersCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kAmber.withOpacity(0.55), width: 1.4),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            color: kAmber.withOpacity(0.18),
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Filtreler",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _rangeChip(
                label: "Hepsi",
                active: _userTypeFilter == null,
                color: kGray,
                onTap: () {
                  setState(() {
                    _userTypeFilter = null;
                    _applyFilters();
                  });
                },
              ),
              _rangeChip(
                label: "İşletme",
                active: _userTypeFilter == 'client',
                color: kGreen,
                onTap: () {
                  setState(() {
                    _userTypeFilter = 'client';
                    _applyFilters();
                  });
                },
              ),
              _rangeChip(
                label: "Müşteri",
                active: _userTypeFilter == 'user',
                color: kAmber,
                onTap: () {
                  setState(() {
                    _userTypeFilter = 'user';
                    _applyFilters();
                  });
                },
              ),
              const SizedBox(width: 16),
              ...[
                null,
                ..._statusDealerOptions,
              ].map((val) {
                final selected = _dealerFilter == val ||
                    (_dealerFilter == null && val == null);
                return _rangeChip(
                  label: val == null ? 'Tümü' : _statusDealerLabel(val),
                  active: selected,
                  color: kGreenDark,
                  onTap: () {
                    setState(() {
                      _dealerFilter = val;
                      _applyFilters();
                    });
                  },
                );
              }).toList(),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(_fromDate == null
                    ? 'Başlangıç'
                    : 'Başlangıç: ${_fmtDateShort(_fromDate)}'),
                onPressed: _pickFromDate,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month, size: 16),
                label: Text(_toDate == null
                    ? 'Bitiş'
                    : 'Bitiş: ${_fmtDateShort(_toDate)}'),
                onPressed: _pickToDate,
              ),
              TextButton.icon(
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Tarihleri temizle'),
                onPressed: () {
                  setState(() {
                    _fromDate = null;
                    _toDate = null;
                    _applyFilters();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Sipariş no, işletme veya adres ara…',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: kBg,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kGreen, width: 2),
              ),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Temizle',
                      onPressed: () {
                        setState(() => _search.clear());
                        _applyFilters();
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
            onChanged: (_) => _applyFilters(),
          ),
        ],
      ),
    );
  }

  Widget _rangeChip({
    required String label,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  colors: [color, color.withOpacity(.82)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: active ? null : kBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? color : kBorder),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withOpacity(.28),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  )
                ]
              : const [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF111827),
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _rightOrderDetailPanel() {
    final o = _selected;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            offset: Offset(0, 8),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: o == null
          ? const Center(child: Text('Soldan bir sipariş seç'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${o.partnerOrderId} - ${o.id} • ${o.orderNumber}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Detaya git',
                          onPressed: () => context.go(
                              '/orders/${Uri.encodeComponent(o.orderNumber)}'),
                          icon: const Icon(Icons.open_in_new),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _statusDealerWithEdit(o),
                    const SizedBox(height: 14),
                    _detailTile(
                      icon: Icons.calendar_month,
                      label: 'Tarih',
                      value: dt(o.createdAt),
                    ),
                    const SizedBox(height: 10),
                    _detailTile(
                      icon: Icons.paid_outlined,
                      label: 'Tutar',
                      value: tl(o.totalAmount),
                    ),
                    const SizedBox(height: 10),
                    _detailTile(
                      icon: Icons.person_outline,
                      label: 'Kimden',
                      value: o.createdByName,
                    ),
                    const SizedBox(height: 10),
                    _detailTile(
                      icon: Icons.location_on_outlined,
                      label: 'Adres',
                      value: o.shippingAddress ?? '—',
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Yenile'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _pickDealerAndUpdateStatus(o),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Durum Değiştir'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _detailTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6B7280)),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w900, color: Color(0xFF6B7280))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Parçalar ----------

  // _filtersBar is now unused (removed for clarity)

  // _metricsGrid is now unused (removed for clarity)

  Widget _statusDealerWithEdit(_Order o) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _statusDealerChip(o.dealer_status),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Durumu güncelle',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.edit_outlined, size: 16),
          onPressed: () => _pickDealerAndUpdateStatus(o),
        ),
      ],
    );
  }

  Widget _statusLegacyWithEdit(_Order o) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _statusLegacyChip(o.status),
        const SizedBox(width: 6),
        const SizedBox(height: 6),
        IconButton(
          tooltip: 'Durumu güncelle',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.edit_outlined, size: 16),
          onPressed: () => _pickAndUpdateStatus(o),
        ),
      ],
    );
  }

  // Kullanıcı tipi label
  String _userTypeLabel(_Order o) {
    return o.user_type == 'client' ? 'İŞLETME SİPARİŞİ' : 'MÜŞTERİ SİPARİŞİ';
  }

  Widget _userTypeChip(_Order o) {
    final isClient = o.user_type == 'client';
    final bg =
        isClient ? Colors.blue.withOpacity(.12) : Colors.green.withOpacity(.12);
    final fg = isClient ? Colors.blue : Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isClient ? Icons.storefront_outlined : Icons.person_outline,
            size: 14,
            color: fg,
          ),
          const SizedBox(width: 16),
          Text(
            _userTypeLabel(o),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  /// Dar ekran kart listesi
  Widget _ordersCardsList({required bool shrinkWrap}) {
    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _visible.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final o = _visible[i];
        final buyerLine = [
          if (o.partner_client_name != null &&
              o.partner_client_name!.isNotEmpty)
            o.partner_client_name!,
          if ((o.buyerCity ?? '').isNotEmpty &&
              (o.buyerDistrict ?? '').isNotEmpty)
            '${o.buyerCity}/${o.buyerDistrict}'
          else if ((o.buyerCity ?? '').isNotEmpty)
            o.buyerCity!
          else if ((o.buyerDistrict ?? '').isNotEmpty)
            o.buyerDistrict!
        ].join(' • ');

        final isSelected = _selectedOrderIds.contains(o.id);

        return InkWell(
          onTap: () =>
              context.go('/orders/${Uri.encodeComponent(o.orderNumber)}'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.purple.withOpacity(.04) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(8, 12, 14, 12),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (v) => _toggleSelection(o, v),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _userTypeChip(o),
                      const SizedBox(height: 6),
                      Text(
                        '${o.partnerOrderId} - ${o.orderNumber}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Kimden:
                      Text(
                        'Kimden: ${o.partner_client_name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (buyerLine.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, top: 2),
                          child: Text(
                            buyerLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        children: [
                          _statusLegacyWithEdit(o),
                        ],
                      ),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        children: [
                          _statusDealerWithEdit(o),
                          Text(
                            dt(o.createdAt),
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                      if (o.shippingAddress != null &&
                          o.shippingAddress!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          o.shippingAddress!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      tl(o.totalAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.black38,
                    ),
                    const Icon(
                      Icons.access_alarms_outlined,
                      size: 16,
                      color: Colors.black38,
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

  Widget _ordersWideTable({required bool shrinkWrap}) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ✅ ÜST BAŞLIK SATIRI (sabit)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: Color(0xFFF9FAFB),
            border: Border(
              bottom: BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
          child: Row(
            children: [
              _headerCell("Sipariş", 1),
              _headerCell("Müşteri", 3),
              _headerCell("Adres", 3),
              _headerCell("Tutar", 1),
              _headerCell("Sipariş Durumu", 2),
              _headerCell("Tedarikçi Durumu", 2),
              _headerCell("Kurye", 1),
              _headerCell("İşlemler", 2),
            ],
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 6),

        // ✅ SATIRLAR (scroll)
        Expanded(
          child: ListView.separated(
            itemCount: _visible.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) => _wideRow(_visible[i], i, cs),
          ),
        ),
      ],
    );
  }

  Widget _headerCell(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  Widget _colHeader(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  /// Geniş ekran: TEK grup kutusu içinde alt alta satırlar
  Widget _ordersWideTableOld({required bool shrinkWrap}) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ÜST BAŞLIK SATIRI (3 grup başlığı tek hizada)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              const SizedBox(
                width: 40,
                child: Center(
                  child: Icon(
                    Icons.check_box_outline_blank,
                    size: 18,
                    color: Colors.black54,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'Sipariş • Kimden • Şehir • İlçe',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Sipariş Durumu • Tedarikçi Durumu',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'Kurye Durumu • Tarih • Tutar • İşlemler',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // SATIRLAR
        for (int i = 0; i < _visible.length; i++) ...[
          _wideRow(_visible[i], i, cs),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  /// Tek satır (tek oval box) – içinde 3 bölge yan yana
  // _wideRowaaaa is now unused (removed for clarity)
  Widget _ordersTableHeader(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.08)),
      ),
      child: Row(
        children: const [
          SizedBox(width: 40), // checkbox space

          Expanded(flex: 4, child: Text("Product / Order")),
          Expanded(flex: 3, child: Text("Status")),
          Expanded(flex: 3, child: Text("Payment / Date / Action")),
        ],
      ),
    );
  }

  Widget _wideRow(_Order o, int index, ColorScheme cs) {
    final isSelected = _selectedOrderIds.contains(o.id);

    final bgColor = index.isEven ? Colors.white : const Color(0xFFF9FAFB);

    final isDealerConfirmed = _toUiStatus(o.status) == 'onaylandı';
    final isSupplierDelivered = o.supplier_status == 'teslim edildi';

    final bool isLoading = _handoffLoading.contains(o.orderNumber);

    final bool canAssignCourier = o.deliveryStatus == 0 &&
        isDealerConfirmed &&
        isSupplierDelivered &&
        !isLoading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? kHaldekiGreen : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: kHaldekiGreen.withOpacity(0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─────────────────────────────
            // TOP META LINE
            // ─────────────────────────────
            Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (v) => _toggleSelection(o, v),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        "İşletme: ",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        o.partner_client_name ?? '-',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Text(
                        "Sipariş Tarihi: ",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        dt(o.createdAt),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  "Sipariş No: ",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  o.partnerOrderId != null && o.partnerOrderId!.isNotEmpty
                      ? "${o.partnerOrderId} • ${o.orderNumber}"
                      : o.orderNumber,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),
            const DashedDivider(),
            const SizedBox(height: 20),

            // ─────────────────────────────
            // CONTENT ROW (HİZALI VERSİYON)
            // ─────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1️⃣ Sipariş (Logo + Order No)
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade100,
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/logo/haldeki_logo_icon.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          o.orderNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2️⃣ Müşteri
                Expanded(
                  flex: 2,
                  child: Text(
                    o.adSoyad ?? '-',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),

                // 3️⃣ Adres
                Expanded(
                  flex: 3,
                  child: Text(
                    o.shippingAddress ?? '-',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),

                // 4️⃣ Tutar
                Expanded(
                  flex: 1,
                  child: Text(
                    tl(o.totalAmount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),

                // 5️⃣ Sipariş Durumu
                Expanded(
                  flex: 2,
                  child: _statusMasterEditable(
                    text: _toUiStatus(o.status),
                    color: _statusColor(_toUiStatus(o.status)),
                    onEdit: () => _pickAndUpdateStatus(o),
                  ),
                ),

                // 6️⃣ Tedarikçi Durumu
                Expanded(
                  flex: 2,
                  child: _statusMasterEditable(
                    text: _statusSupLabel(o.supplier_status),
                    color: _statusColor(_statusSupLabel(o.supplier_status)),
                    onEdit: null,
                  ),
                ),

                // 7️⃣ Kurye
                Expanded(
                  flex: 1,
                  child: Center(
                    child: o.deliveryStatus == 1
                        ? const Icon(Icons.check_circle,
                            color: Colors.green, size: 18)
                        : const Icon(Icons.remove_circle_outline,
                            color: Colors.grey, size: 18),
                  ),
                ),

                // 8️⃣ İşlemler
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      // 🔍 DETAY
                      Tooltip(
                        message: "Sipariş Detay",
                        child: InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () => context.go(
                            '/orders/${Uri.encodeComponent(o.orderNumber)}',
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.open_in_new_rounded,
                              size: 18,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // 🏍️ KURYEYE AKTAR
                      Tooltip(
                        message:
                            canAssignCourier ? "Kuryeye Aktar" : "Aktarılamaz",
                        child: InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: !canAssignCourier
                              ? null
                              : () async {
                                  if (_handoffLoading.contains(o.orderNumber))
                                    return;

                                  setState(() {
                                    _handoffLoading.add(o.orderNumber);
                                  });

                                  try {
                                    setState(() {
                                      final ix = _all.indexWhere(
                                        (e) => e.orderNumber == o.orderNumber,
                                      );
                                      if (ix >= 0) {
                                        _all[ix] = _all[ix]
                                            .copyWith(deliveryStatus: 1);
                                      }
                                    });

                                    final resp = await context
                                        .read<ApiClient>()
                                        .handoffByOrderNumber(
                                          o.orderNumber,
                                          clientId: o.user_id,
                                        );

                                    final ok = (resp['success'] == true);

                                    if (!mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          ok
                                              ? 'Kuryelere aktarıldı ✅'
                                              : 'Aktarma başarısız ❌',
                                        ),
                                      ),
                                    );
                                  } catch (_) {
                                    if (!mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Aktarma başarısız ❌'),
                                      ),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _handoffLoading.remove(o.orderNumber);
                                      });
                                    }
                                  }
                                },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: canAssignCourier
                                  ? kHaldekiGreen.withOpacity(0.12)
                                  : Colors.grey.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Icon(
                                    Icons.motorcycle,
                                    size: 18,
                                    color: canAssignCourier
                                        ? kHaldekiGreen
                                        : Colors.grey,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusMasterEditable({
    required String text,
    required Color color,
    required VoidCallback? onEdit,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: color,
            ),
          ),
          if (onEdit != null) ...[
            const SizedBox(width: 6),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: onEdit,
              child: const Icon(
                Icons.edit_outlined,
                size: 14,
                color: Colors.black54,
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _statusMaster({
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _masterStatus(
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'onaylandı':
        return const Color(0xFF2563EB); // primary blue
      case 'hazırlanıyor':
        return const Color(0xFFF59E0B); // amber
      case 'teslim edildi':
        return const Color(0xFF10B981); // green
      case 'iptal':
        return const Color(0xFFEF4444); // red
      default:
        return const Color(0xFF6B7280); // gray
    }
  }

  Widget _ultraChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _accentColorByStatus(String? status) {
    final s = status?.toLowerCase() ?? '';

    if (s.contains('onay')) return const Color(0xFF16A34A);
    if (s.contains('hazır') || s.contains('işlen'))
      return const Color(0xFF2563EB);
    if (s.contains('yolda') || s.contains('kargo'))
      return const Color(0xFF7C3AED);
    if (s.contains('iptal')) return const Color(0xFFDC2626);
    if (s.contains('bekle')) return const Color(0xFFF59E0B);

    return const Color(0xFF6B7280);
  }

  Widget _iconActionBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Icon(
            icon,
            size: 18,
            color: color ?? Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _verticalDivider(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      width: 1,
      height: 48,
      color: cs.outline.withOpacity(0.15),
    );
  }

  Widget _verticalDivider2(ColorScheme cs) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      height: 40,
      color: cs.outlineVariant.withOpacity(0.6),
    );
  }

  Widget _statusLegacyChip(String status) {
    final ui = _toUiStatus(status);
    final color = _statusColor(ui);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sol renk barı (enterprise hissi)
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            ui,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => const Padding(
        padding: EdgeInsets.all(8.0),
        child: Center(child: Text('Eşleşen sipariş bulunamadı')),
      );

  // _metricCard is now unused (removed for clarity)

  Widget _statusLegacyChip2(String statusValue) {
    final t = statusValue.toLowerCase().trim();

    // Eğer dealer enum geldiyse, dealer görünümüyle göster
    if (_statusDealerOptions.contains(t)) {
      final icon = _statusIconDealer(t);
      final bg = _statusBgDealer(t);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(_statusDealerLabel(t)),
          ],
        ),
      );
    }

    // Aksi halde legacy TR statüler
    final s = _toUiStatus(statusValue);
    Color bg;
    IconData icon;
    switch (s) {
      case 'bekliyor':
        bg = Colors.amber.withOpacity(.15);
        icon = Icons.hourglass_bottom_outlined;
        break;
      case 'onaylandı':
        bg = Colors.blue.withOpacity(.15);
        icon = Icons.confirmation_num_outlined;
        break;

      case 'iptal':
        bg = Colors.red.withOpacity(.15);
        icon = Icons.cancel_outlined;
        break;
      default:
        bg = Colors.grey.withOpacity(.15);
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(_statusLabel(s)),
        ],
      ),
    );
  }

  Widget _statusDealerChip(String dealerStatusEnum) {
    final icon = _statusIconDealer(dealerStatusEnum);
    final bg = _statusBgDealer(dealerStatusEnum);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(_statusDealerLabel(dealerStatusEnum)),
        ],
      ),
    );
  }
}

// --------------------- View-model ---------------------
class _Order {
  final String id;
  final String orderNumber;
  final String status; // dealer enum veya legacy
  final String dealer_status; // ENUM (EN)
  final String supplier_status; // TR
  final int deliveryStatus; // 0 = aktarılmadı, 1 = kuryelere aktarıldı
  final DateTime createdAt;
  final double totalAmount;
  final String? shippingAddress;
  final String createdByName;

  // Opsiyonel buyer alanları
  final String? buyerName;
  final String? buyerCity;
  final String? buyerDistrict;
  final String? buyerType;
  final String? user_type;

  // client / user
  final String userType;
  final int user_id;
  final String? adSoyad;
  final String? partnerOrderId;
  final String? partner_client_name;
  final String? partner_client_address;
  final double? partner_client_lat;
  final double? partner_client_long;

  _Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.dealer_status,
    required this.supplier_status,
    required this.createdAt,
    required this.totalAmount,
    required this.shippingAddress,
    required this.createdByName,
    required this.deliveryStatus,
    required this.userType,
    required this.user_type,
    required this.user_id, // ✅ required
    this.buyerName,
    this.buyerCity,
    this.buyerDistrict,
    this.buyerType,
    this.adSoyad,
    this.partnerOrderId,
    this.partner_client_name,
    this.partner_client_address,
    this.partner_client_lat,
    this.partner_client_long,
  });

  _Order copyWith({
    String? id,
    String? orderNumber,
    String? status,
    String? dealer_status,
    String? supplier_status,
    DateTime? createdAt,
    double? totalAmount,
    String? shippingAddress,
    String? createdByName,
    String? buyerName,
    String? buyerCity,
    String? buyerDistrict,
    String? buyerType,
    int? deliveryStatus,
    String? userType,
    String? user_type,
    int? user_id,
    String? partnerOrderId,
    String? partner_client_name,
    String? partner_client_address,
    double? partner_client_lat,
    double? partner_client_long,
    String? adSoyad,
  }) {
    return _Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      status: status ?? this.status,
      dealer_status: dealer_status ?? this.dealer_status,
      supplier_status: supplier_status ?? this.supplier_status,
      createdAt: createdAt ?? this.createdAt,
      totalAmount: totalAmount ?? this.totalAmount,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      createdByName: createdByName ?? this.createdByName,
      buyerName: buyerName ?? this.buyerName,
      buyerCity: buyerCity ?? this.buyerCity,
      buyerDistrict: buyerDistrict ?? this.buyerDistrict,
      buyerType: buyerType ?? this.buyerType,
      user_type: user_type ?? this.user_type,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      userType: userType ?? this.userType,
      adSoyad: adSoyad ?? this.adSoyad,
      user_id: user_id ?? this.user_id,
      partnerOrderId: partnerOrderId ?? this.partnerOrderId,
      partner_client_name: partner_client_name ?? this.partner_client_name,
      partner_client_address:
          partner_client_address ?? this.partner_client_address,
      partner_client_lat: partner_client_lat ?? this.partner_client_lat,
      partner_client_long: partner_client_long ?? this.partner_client_long,
    );
  }
}

class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 6.0;
        const dashSpace = 4.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFF0D4631),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
