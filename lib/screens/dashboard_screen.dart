// lib/screens/dashboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart' show DioException;

import '../config.dart';
import '../services/api_client.dart';
import '../models/order.dart';
import '../utils/format.dart';
import '../widgets/donut_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ---- DATA ----
  List<Order> _all = const <Order>[];
  List<Order> _visible = const <Order>[];

  // ---- UI state ----
  final _search = TextEditingController();
  String? _statusFilter;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  bool _topSortByRevenue = false;
  List<_TopStat> _topByQty = [];
  List<_TopStat> _topByRevenue = [];

  bool _loading = false;
  String? _error;

  // Tarih filtreleri
  DateTime? _startDate;
  DateTime? _endDate;

  // --- UI constants ---
  static const double _gap = 16;
  static const double _metricHeight = 120;
  static const double _smallCardHeight = 420;
  static const double _panelHeight = 520;
  static const double _sideCardWidth = 360;
  static const double _donutWidth = 340;

  // --- Brand (Light Primary) ---
  static const Color kPrimary = Color(0xFF1E6A4F); // koyu yeşil
  static const Color kAccent = Color(0xFF98F090); // açık yeşil vurgu
  static const Color kBg = Color(0xFFFFFFFF); // beyaz zemin
  static const Color kSurface = Color(0xFFFFFFFF);
  static const Color kSoft = Color(0xFFF8FAFC);
  static const Color kSoft2 = Color(0xFFF3F4F6);
  static const Color kText = Color(0xFF111827);
  static const Color kMuted = Color(0xFF6B7280);
  static const Color kOutline = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _recomputeTop();
    Future.microtask(_loadOrders);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ---------- STATUS HELPERS ----------
  /// dealer_status + legacy status → normalize
  ///
  /// dealer_status enum:
  /// pending / courier / delivered / closed / cancelled
  String _normStatus(String? raw) {
    final s = (raw ?? '').toLowerCase().trim();
    if (s.isEmpty) return 'hazırlanıyor';

    // ---- dealer_status ENUM öncelikli ----
    if (s == 'pending') return 'hazırlanıyor';
    if (s == 'courier') return 'sevk edildi';
    if (s == 'delivered' || s == 'delivered_full' || s == 'closed') {
      return 'teslim edildi';
    }
    if (s == 'cancelled' || s == 'canceled') return 'iptal';

    // ---- eski status string'leri (geriye uyum) ----
    if (s.contains('cancel')) return 'iptal';
    if (s == 'iptal') return 'iptal';

    if (s.contains('deliver') || s == 'delivered' || s == 'delivered_full') {
      return 'teslim edildi';
    }

    // "yolda" artık kullanılmıyor -> transit/away/on the way → sevk edildi
    if (s == 'away' ||
        s.contains('transit') ||
        s.contains('on the way') ||
        s.contains('yol')) {
      return 'sevk edildi';
    }

    if (s == 'shipped' || s.contains('sevk') || s.contains('ship')) {
      return 'sevk edildi';
    }

    if (s == 'pending' ||
        s == 'processing' ||
        s.contains('hazır') ||
        s.contains('confirm')) {
      return 'hazırlanıyor';
    }

    return s;
  }

  String _statusLabelFrom(String? status) {
    switch (_normStatus(status)) {
      case 'hazırlanıyor':
        return 'Hazırlanıyor';
      case 'sevk edildi':
        return 'Sevk edildi';
      case 'teslim edildi':
        return 'Teslim edildi';
      case 'iptal':
        return 'İptal';
      default:
        return _normStatus(status);
    }
  }

  IconData _statusIconFrom(String? status) {
    switch (_normStatus(status)) {
      case 'hazırlanıyor':
        return Icons.inventory_2_outlined;
      case 'sevk edildi':
        return Icons.local_shipping_outlined;
      case 'teslim edildi':
        return Icons.check_circle_outline;
      case 'iptal':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  // Light theme status background
  Color _statusBgFrom(String? status) {
    switch (_normStatus(status)) {
      case 'hazırlanıyor':
        return const Color(0xFFFFFBEB); // amber-50
      case 'sevk edildi':
        return const Color(0xFFEFF6FF); // blue-50
      case 'teslim edildi':
        return const Color(0xFFECFDF5); // green-50
      case 'iptal':
        return const Color(0xFFFEF2F2); // red-50
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  // Light theme status icon color
  Color _statusFgFrom(String? status) {
    switch (_normStatus(status)) {
      case 'hazırlanıyor':
        return const Color(0xFFD97706); // amber-600
      case 'sevk edildi':
        return const Color(0xFF2563EB); // blue-600
      case 'teslim edildi':
        return const Color(0xFF16A34A); // green-600
      case 'iptal':
        return const Color(0xFFDC2626); // red-600
      default:
        return kMuted;
    }
  }

  /// Timeline için stage:
  /// 0: Hazırlanıyor, 1: Sevk edildi, 2: Teslim edildi, -1: İptal
  int _statusStageFrom(String? status) {
    switch (_normStatus(status)) {
      case 'iptal':
        return -1;
      case 'teslim edildi':
        return 2;
      case 'sevk edildi':
        return 1;
      case 'hazırlanıyor':
      default:
        return 0;
    }
  }

  // ================== API ==================
  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _fetchOrdersApi();
      if (!mounted) return;
      setState(() {
        _all = data;
        _visible = List.of(_all);
        _applySort();
        _recomputeTop();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Siparişler yüklenemedi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Order>> _fetchOrdersApi() async {
    final dio = context.read<ApiClient>().dio;
    final api = context.read<ApiClient>();
    final dealerEmail = api.currentEmail;

    try {
      final r = await dio.post(
        AppConfig.dealerOrdersPath,
        data: {'email': dealerEmail},
        queryParameters: {'page': 1},
      );
      final list = _extractList(r.data);
      final parsed = _safeParseOrders(list);
      if (parsed.isNotEmpty) return parsed;
    } on DioException catch (e) {
      ////debugprint('dealer-orders POST failed → ${e.message}');
    } catch (e) {
      ////debugprint('dealer-orders POST error → $e');
    }

    try {
      final r2 = await dio.get(
        'dealer-orders',
        queryParameters: {'page': 1},
      );
      final list2 = _extractList(r2.data);
      return _safeParseOrders(list2);
    } on DioException catch (e) {
      throw Exception('Orders isteği başarısız: ${e.message}');
    } catch (e) {
      throw Exception('Orders isteği başarısız: $e');
    }
  }

  List<Order> _safeParseOrders(List<Map<String, dynamic>> list) {
    final out = <Order>[];
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      try {
        out.add(Order.fromJson(e));
      } catch (err) {
        ////debugprint('Order.fromJson FAILED @ index $i → $err');
        ////debugprint(const JsonEncoder.withIndent('  ').convert(e));
      }
    }
    return out;
  }

  // ---- JSON yardımcıları ----
  double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) {
      final s = v.replaceAll('₺', '').replaceAll(' ', '').replaceAll(',', '.');
      return double.tryParse(s) ?? 0.0;
    }
    return 0.0;
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Map<String, dynamic> _normalizeOrderJson(Map<String, dynamic> j) {
    final m = Map<String, dynamic>.from(j);

    for (final k in const [
      'total',
      'total_amount',
      'grand_total',
      'amount',
      'subtotal',
      'sub_total',
      'sum',
      'items_total',
      'vat',
      'tax',
      'kdv',
    ]) {
      if (m.containsKey(k)) m[k] = _asDouble(m[k]);
    }

    final itemsKey = ['items', 'order_items', 'lines', 'cart_items']
        .firstWhere((k) => m[k] is List, orElse: () => '');
    if (itemsKey.isNotEmpty) {
      final list = (m[itemsKey] as List).whereType<Map>().map((raw0) {
        final raw = Map<String, dynamic>.from(raw0);
        for (final k in const [
          'qty',
          'quantity',
          'qtyCases',
          'approxKgPerCase',
          'kg_per_case',
          'weight_per_case',
          'weightPerCase',
          'price',
          'unit_price',
          'average_price',
          'pricePerKg',
          'price_per_kg',
          'line_total',
          'lineTotal',
          'line_amount',
          'total_price',
          'total',
        ]) {
          if (raw.containsKey(k)) {
            if (k == 'qty' || k == 'quantity' || k == 'qtyCases') {
              raw[k] = _asInt(raw[k]);
            } else {
              raw[k] = _asDouble(raw[k]);
            }
          }
        }
        return raw;
      }).toList();
      m[itemsKey] = list;
    }

    return m;
  }

  List<Map<String, dynamic>> _extractList(dynamic payload) {
    dynamic body = payload;
    if (body is Map && body['data'] != null) body = body['data'];

    List rawList;
    if (body is List) {
      rawList = body;
    } else if (body is Map) {
      final m = Map<String, dynamic>.from(body);
      rawList = (m['orders'] ??
          m['items'] ??
          m['results'] ??
          m['data'] ??
          const []) as List;
    } else {
      rawList = const [];
    }

    return rawList
        .whereType<Map>()
        .map((e) => _normalizeOrderJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ================== Filtre & Sıralama ==================
  void _applyFilters() {
    final q = _search.text.trim().toLowerCase();
    setState(() {
      _visible = _all.where((o) {
        final norm = _normStatus(o.dealer_status ?? o.status);

        final okStatus = _statusFilter == null || norm == _statusFilter;

        final okQuery = q.isEmpty ||
            o.orderNumber.toLowerCase().contains(q) ||
            (o.shippingAddress ?? '').toLowerCase().contains(q) ||
            o.createdByName.toLowerCase().contains(q);

        // --- Tarih filtresi (createdAt üzerinden) ---
        final DateTime? date = o.createdAt;
        final okDate = () {
          if (_startDate == null && _endDate == null) return true;
          if (date == null) return true;

          if (_startDate != null && _endDate == null) {
            return !date.isBefore(_startDate!);
          }

          if (_startDate == null && _endDate != null) {
            return !date.isAfter(_endDate!.add(const Duration(
              hours: 23,
              minutes: 59,
              seconds: 59,
            )));
          }

          final start =
              DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
          final end = DateTime(
              _endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
          return !date.isBefore(start) && !date.isAfter(end);
        }();

        return okStatus && okQuery && okDate;
      }).toList();

      _applySort();
      _recomputeTop();
    });
  }

  void _applySort() {
    if (_sortColumnIndex == null) return;
    _visible.sort((a, b) {
      int cmp = 0;
      switch (_sortColumnIndex) {
        case 0:
          cmp = a.orderNumber.compareTo(b.orderNumber);
          break;
        case 1:
          cmp = _normStatus(a.dealer_status ?? a.status)
              .compareTo(_normStatus(b.dealer_status ?? b.status));
          break;
        case 2:
          cmp = a.totalAmount.compareTo(b.totalAmount);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _applySort();
    });
  }

  // ================== Tablo (responsive) ==================
  Widget _ordersResponsiveTable(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1700;

        if (isCompact) {
          return RefreshIndicator(
            onRefresh: _loadOrders,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _visible.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final o = _visible[i];
                final st = o.dealer_status ?? o.status;
                return ListTile(
                  title: Text(
                    o.orderNumber,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: kText),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [_statusChip(st)],
                        ),
                        const SizedBox(height: 8),
                        _shipmentTimeline(st),
                      ],
                    ),
                  ),
                  trailing: Text(
                    tl(o.totalAmount),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: kText),
                  ),
                );
              },
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadOrders,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 32,
                  sortColumnIndex: _sortColumnIndex,
                  sortAscending: _sortAscending,
                  columns: [
                    DataColumn(label: const Text('Sipariş'), onSort: _onSort),
                    DataColumn(label: const Text('Durum'), onSort: _onSort),
                    DataColumn(
                      numeric: true,
                      label: const Text('Tutar'),
                      onSort: _onSort,
                    ),
                  ],
                  rows: [
                    for (final o in _visible)
                      DataRow(
                        cells: [
                          DataCell(Text(o.orderNumber)),
                          DataCell(_statusChip(o.dealer_status ?? o.status)),
                          DataCell(Text(tl(o.totalAmount))),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Basit timeline
  Widget _shipmentTimeline(String? status) {
    final current = _statusStageFrom(status);
    const stages = [
      ('Hazırlanıyor', Icons.inventory_2_outlined),
      ('Sevk Edildi', Icons.local_shipping_outlined),
      ('Teslim Edildi', Icons.verified_outlined),
    ];

    if (current == -1) {
      return Row(
        children: const [
          CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFFFEF2F2),
            child: Icon(Icons.cancel_outlined, color: Color(0xFFDC2626)),
          ),
          SizedBox(width: 8),
          Text(
            'Sipariş İptal Edildi',
            style: TextStyle(fontWeight: FontWeight.w800, color: kText),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: List.generate(stages.length, (i) {
        final done = i < current;
        final now = i == current;

        final Color fg =
            done ? const Color(0xFF16A34A) : (now ? kPrimary : kMuted);
        final Color bg = done
            ? const Color(0xFFECFDF5)
            : (now ? kPrimary.withOpacity(.10) : kSoft2);

        return Chip(
          avatar: Icon(stages[i].$2, size: 16, color: fg),
          label: Text(stages[i].$1),
          backgroundColor: bg,
          side: const BorderSide(color: kOutline),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        );
      }),
    );
  }

  // ================== Top ürün hesaplama ==================
  void _recomputeTop() {
    final map = <String, _TopStat>{};
    for (final o in _visible) {
      for (final it in o.items) {
        final baseName = it.productTitle.split(' - ').first;
        final ex = map[baseName];
        map[baseName] = ex == null
            ? _TopStat(
                name: baseName,
                qtyCases: it.qtyCases,
                revenue: it.lineTotal,
              )
            : _TopStat(
                name: baseName,
                qtyCases: ex.qtyCases + it.qtyCases,
                revenue: ex.revenue + it.lineTotal,
              );
      }
    }
    _topByQty = map.values.toList()
      ..sort((a, b) => b.qtyCases.compareTo(a.qtyCases));
    _topByRevenue = map.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
  }

  // ================== Status aggregate ==================
  List<_StatusAgg> _computeStatusAgg() {
    int cPrep = 0, cShip = 0, cDel = 0, cCan = 0;
    double aPrep = 0, aShip = 0, aDel = 0, aCan = 0;

    for (final o in _visible) {
      final norm = _normStatus(o.dealer_status ?? o.status);
      switch (norm) {
        case 'hazırlanıyor':
          cPrep++;
          aPrep += o.totalAmount;
          break;
        case 'sevk edildi':
          cShip++;
          aShip += o.totalAmount;
          break;
        case 'teslim edildi':
          cDel++;
          aDel += o.totalAmount;
          break;
        case 'iptal':
          cCan++;
          aCan += o.totalAmount;
          break;
      }
    }

    return [
      _StatusAgg('hazırlanıyor', 'Hazırlanıyor', Icons.inventory_2_outlined,
          const Color(0xFFD97706), cPrep, aPrep),
      _StatusAgg('sevk edildi', 'Sevk edildi', Icons.local_shipping_outlined,
          const Color(0xFF2563EB), cShip, aShip),
      _StatusAgg('teslim edildi', 'Teslim Edildi', Icons.check_circle_outline,
          const Color(0xFF16A34A), cDel, aDel),
      _StatusAgg('iptal', 'İptal', Icons.cancel_outlined,
          const Color(0xFFDC2626), cCan, aCan),
    ];
  }

  // ---------- “Tutar” kartı ----------
  Widget _amountCard(double amount) {
    return Card(
      child: SizedBox(
        height: _metricHeight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.paid_outlined, size: 40, color: kPrimary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Tutar', style: TextStyle(color: kMuted)),
                    Text(
                      tl(amount),
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900, color: kText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 5 kartlık TEK SATIR (Tutar + 4 durum) ----------
  Widget _statusAggRow(double totalSales) {
    final list = _computeStatusAgg();
    const double minCardWidth = 220;

    return LayoutBuilder(
      builder: (context, c) {
        final itemCount = 1 + list.length; // 1: Tutar + 4 durum
        final needed = minCardWidth * itemCount + _gap * (itemCount - 1);

        if (c.maxWidth >= needed) {
          return Row(
            children: [
              Expanded(child: _amountCard(totalSales)),
              const SizedBox(width: _gap),
              for (int i = 0; i < list.length; i++) ...[
                Expanded(child: _statusAggCard(list[i])),
                if (i < list.length - 1) const SizedBox(width: _gap),
              ],
            ],
          );
        }

        return SizedBox(
          height: _metricHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(width: _gap),
            itemBuilder: (_, i) {
              if (i == 0) {
                return SizedBox(
                    width: minCardWidth, child: _amountCard(totalSales));
              }
              final a = list[i - 1];
              return SizedBox(width: minCardWidth, child: _statusAggCard(a));
            },
          ),
        );
      },
    );
  }

  Widget _statusAggCard(_StatusAgg a) {
    return Card(
      child: SizedBox(
        height: _metricHeight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(a.icon, size: 40, color: a.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(a.label, style: const TextStyle(color: kMuted)),
                    Text(
                      tl(a.amount),
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900, color: kText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${a.count} sipariş',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: kMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================== Build ==================
  @override
  Widget build(BuildContext context) {
    final scheme = const ColorScheme.light(
      primary: kPrimary,
      onPrimary: Colors.white,
      secondary: kAccent,
      onSecondary: Color(0xFF003828),
      surface: kSurface,
      onSurface: kText,
      surfaceContainerHighest: kSoft,
      onSurfaceVariant: kMuted,
      outline: kOutline,
      outlineVariant: kOutline,
      error: Color(0xFFEF4444),
      onError: Colors.white,
    );

    final themed = Theme.of(context).copyWith(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: kBg,

      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: kOutline),
        ),
      ),

      inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
            filled: true,
            fillColor: const Color(0xFFF8FAF9),
            labelStyle: const TextStyle(color: Color(0xFF374151)),
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            prefixIconColor: const Color(0xFF6B7280),
            suffixIconColor: const Color(0xFF6B7280),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kOutline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kOutline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kPrimary, width: 1.4),
            ),
          ),

      chipTheme: ChipThemeData(
        backgroundColor: kSoft2,
        selectedColor: kPrimary.withOpacity(.12),
        side: const BorderSide(color: kOutline),
        labelStyle: const TextStyle(color: kText),
        secondaryLabelStyle: const TextStyle(color: kText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),

      dataTableTheme: const DataTableThemeData(
        headingRowColor: MaterialStatePropertyAll(Color(0xFFF8FAFC)),
        dividerThickness: 1,
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.w800,
          color: kText,
        ),
        dataTextStyle: TextStyle(color: kText),
      ),

      // LinearProgressIndicator rengi primary olsun
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        linearMinHeight: 2,
        color: kPrimary,
      ),
    );

    return Theme(
      data: themed,
      child: _DashboardBody(),
    );
  }

  Widget _DashboardBody() {
    final totalSales = _visible.fold<double>(0, (s, o) => s + o.totalAmount);
    final preparing = _visible
        .where(
            (o) => _normStatus(o.dealer_status ?? o.status) == 'hazırlanıyor')
        .length;
    final shipped = _visible
        .where((o) => _normStatus(o.dealer_status ?? o.status) == 'sevk edildi')
        .length;
    final delivered = _visible
        .where(
            (o) => _normStatus(o.dealer_status ?? o.status) == 'teslim edildi')
        .length;
    final canceled = _visible
        .where((o) => _normStatus(o.dealer_status ?? o.status) == 'iptal')
        .length;
    final ordersCount = _visible.length;

    return Padding(
      padding: const EdgeInsets.all(_gap),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: LayoutBuilder(
            builder: (context, box) {
              final isWide = box.maxWidth >= 1200;

              if (!isWide) {
                // DAR EKRAN
                return ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    Text(
                      'Genel Bakış',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900, color: kText),
                    ),
                    const SizedBox(height: 16),
                    if (_loading) const LinearProgressIndicator(minHeight: 2),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    _statusAggRow(totalSales),
                    const SizedBox(height: 24),
                    _statusDonutCard(
                      ordersCount,
                      preparing,
                      shipped,
                      delivered,
                      canceled,
                      fixedHeight: _smallCardHeight,
                    ),
                    const SizedBox(height: _gap),
                    _topProductsCard(fixedHeight: _smallCardHeight),
                    const SizedBox(height: _gap),
                    _ordersCard(fixedHeight: _smallCardHeight + 80),
                    const SizedBox(height: 24),
                  ],
                );
              }

              // GENİŞ EKRAN
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Genel Bakış',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900, color: kText),
                  ),
                  const SizedBox(height: 16),
                  if (_loading) const LinearProgressIndicator(minHeight: 2),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  _statusAggRow(totalSales),
                  const SizedBox(height: 24),
                  _filtersBar(context),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: _panelHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _ordersCard(fixedHeight: _panelHeight),
                        ),
                        const SizedBox(width: _gap),
                        SizedBox(
                          width: _donutWidth,
                          child: _statusDonutCard(
                            ordersCount,
                            preparing,
                            shipped,
                            delivered,
                            canceled,
                            fixedHeight: _panelHeight,
                          ),
                        ),
                        const SizedBox(width: _gap),
                        SizedBox(
                          width: _sideCardWidth,
                          child: _topProductsCard(fixedHeight: _panelHeight),
                        ),
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

  // ---------- Kartlar ----------
  Widget _ordersCard({required double fixedHeight}) {
    return Card(
      child: SizedBox(
        height: fixedHeight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Son Siparişler',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800, color: kText),
              ),
              const SizedBox(height: 12),
              Expanded(child: _ordersResponsiveTable(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusDonutCard(
    int ordersCount,
    int preparing,
    int shipped,
    int delivered,
    int canceled, {
    required double fixedHeight,
  }) {
    final slices = [
      DonutSlice(
        value: preparing.toDouble(),
        color: const Color(0xFFD97706),
        label: 'Hazırlanıyor',
      ),
      DonutSlice(
        value: shipped.toDouble(),
        color: const Color(0xFF2563EB),
        label: 'Sevk edildi',
      ),
      DonutSlice(
        value: delivered.toDouble(),
        color: const Color(0xFF16A34A),
        label: 'Teslim edildi',
      ),
      DonutSlice(
        value: canceled.toDouble(),
        color: const Color(0xFFDC2626),
        label: 'İptal',
      ),
    ];

    return Card(
      child: SizedBox(
        height: fixedHeight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 420;
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Durum Dağılımı',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800, color: kText),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: DonutChart(
                        slices: slices,
                        thickness: 22,
                        centerText: '$ordersCount\nsipariş',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _legendDot(
                        const Color(0xFFD97706), 'Hazırlanıyor ($preparing)'),
                    _legendDot(
                        const Color(0xFF2563EB), 'Sevk edildi ($shipped)'),
                    _legendDot(
                        const Color(0xFF16A34A), 'Teslim edildi ($delivered)'),
                    _legendDot(const Color(0xFFDC2626), 'İptal ($canceled)'),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Durum Dağılımı',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800, color: kText),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: DonutChart(
                            slices: slices,
                            thickness: 22,
                            centerText: '$ordersCount\nsipariş',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _legendDot(const Color(0xFFD97706),
                                'Hazırlanıyor ($preparing)'),
                            _legendDot(const Color(0xFF2563EB),
                                'Sevk edildi ($shipped)'),
                            _legendDot(const Color(0xFF16A34A),
                                'Teslim edildi ($delivered)'),
                            _legendDot(
                                const Color(0xFFDC2626), 'İptal ($canceled)'),
                          ],
                        ),
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

  Widget _legendDot(Color c, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: kText)),
        ],
      ),
    );
  }

  Widget _topProductsCard({required double fixedHeight}) {
    final list = _topSortByRevenue ? _topByRevenue : _topByQty;
    final maxVal = list.isEmpty
        ? 1.0
        : (_topSortByRevenue ? list.first.revenue : list.first.qtyCases);

    return Card(
      child: SizedBox(
        height: fixedHeight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'En Çok Sipariş Verilen Ürünler',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800, color: kText),
                    ),
                  ),
                  FilterChip(
                    label: const Text('Adet'),
                    selected: !_topSortByRevenue,
                    onSelected: (_) =>
                        setState(() => _topSortByRevenue = false),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    label: const Text('Tutar'),
                    selected: _topSortByRevenue,
                    onSelected: (_) => setState(() => _topSortByRevenue = true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                const Expanded(
                  child: Center(child: Text('Gösterilecek veri yok.')),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: list.length.clamp(0, 10),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final it = list[i];
                      final value =
                          _topSortByRevenue ? it.revenue : it.qtyCases;
                      final ratio = (value / maxVal).clamp(0.0, 1.0);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  it.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: kText),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _topSortByRevenue
                                    ? tl(it.revenue)
                                    : '${it.qtyCases.toStringAsFixed(0)} koli',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: kText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: ratio,
                              color: kPrimary,
                              backgroundColor: kSoft2,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Filtre barı ----------
  Widget _filtersBar(BuildContext context) {
    final statuses = const [
      'hazırlanıyor',
      'sevk edildi',
      'teslim edildi',
      'iptal',
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: TextField(
            controller: _search,
            style: const TextStyle(color: kText), // ✅ girilen yazı siyah
            decoration: const InputDecoration(
              hintText: 'Sipariş, adres veya kullanıcı ara…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (_) => _applyFilters(),
          ),
        ),

        // Başlangıç tarihi
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDate: _startDate ?? DateTime.now(),
            );
            if (picked != null) {
              setState(() {
                _startDate = DateTime(picked.year, picked.month, picked.day);
                _applyFilters();
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: kSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kOutline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.date_range, size: 18, color: kMuted),
                const SizedBox(width: 8),
                Text(
                  _startDate == null
                      ? 'Başlangıç'
                      : '${_startDate!.day}.${_startDate!.month}.${_startDate!.year}',
                  style: const TextStyle(
                      color: kText, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),

        // Bitiş tarihi
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDate: _endDate ?? DateTime.now(),
            );
            if (picked != null) {
              setState(() {
                _endDate = DateTime(picked.year, picked.month, picked.day);
                _applyFilters();
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: kSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kOutline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.date_range, size: 18, color: kMuted),
                const SizedBox(width: 8),
                Text(
                  _endDate == null
                      ? 'Bitiş'
                      : '${_endDate!.day}.${_endDate!.month}.${_endDate!.year}',
                  style: const TextStyle(
                      color: kText, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),

        // Tarihleri temizle
        if (_startDate != null || _endDate != null)
          TextButton(
            onPressed: () {
              setState(() {
                _startDate = null;
                _endDate = null;
                _applyFilters();
              });
            },
            child: const Text('Tarihi Temizle'),
          ),

        FilterChip(
          label: const Text('Hepsi'),
          selected: _statusFilter == null,
          onSelected: (_) {
            _statusFilter = null;
            _applyFilters();
          },
        ),
        for (final s in statuses)
          FilterChip(
            label: Text(_statusLabelFrom(s)),
            selected: _statusFilter == s,
            onSelected: (_) {
              _statusFilter = s;
              _applyFilters();
            },
            avatar: Icon(_statusIconFrom(s), size: 18),
          ),
      ],
    );
  }

  // ---------- UI yardımcıları ----------
  Widget _statusChip(String? status) {
    final norm = _normStatus(status);
    final bg = _statusBgFrom(norm);
    final fg = _statusFgFrom(norm);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kOutline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIconFrom(norm), size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            _statusLabelFrom(norm),
            style: TextStyle(color: fg, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

// --- küçük struct'lar ---
class _TopStat {
  final String name;
  final double qtyCases;
  final double revenue;
  const _TopStat({
    required this.name,
    required this.qtyCases,
    required this.revenue,
  });
}

class _StatusAgg {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final int count;
  final double amount;
  const _StatusAgg(
    this.key,
    this.label,
    this.icon,
    this.color,
    this.count,
    this.amount,
  );
}
