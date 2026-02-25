import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../utils/format.dart';
import 'haldeki_ui.dart';

class DeliveryOrdersScreen extends StatefulWidget {
  const DeliveryOrdersScreen({super.key});
  @override
  State<DeliveryOrdersScreen> createState() => _DeliveryOrdersScreenState();
}

class _DeliveryOrdersScreenState extends State<DeliveryOrdersScreen> {
  // ===== Premium Colors =====
  static const Color kGreen = Color(0xFF0D4631);
  static const Color kGreenDark = Color(0xFF0D4631);
  static const Color kAmber = Color(0xFF0D4631); // Color(0xFF98F090);
  static const Color kGray = Color(0xFF6B7280);
  static const Color kBg = Color(0xFFF3F4FB);
  static const Color kBorder = Color(0xFFE6E8F2);

  // Data
  List<_DOrder> _all = [];
  List<_DOrder> _visible = [];

  // ✅ Master-detail seçili kayıt
  _DOrder? _selected;

  // Search & Sort
  final _search = TextEditingController();

  int? _sortColumnIndex = 0; // 0 = Tarih
  bool _sortAscending = false;

  // Date filters
  DateTime? _fromDate;
  DateTime? _toDate;
  String _quickRange = 'all'; // all | today | week | month | custom

  // UI state
  bool _loading = true;
  String? _error;

  static const List<String> _statusOptions = [
    'Oluşturuldu',
    'Kuryede',
    'Teslim Aldı',
    'Teslim Edildi',
    'İptal',
  ];

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

  // ---------- Status mapping ----------
  String _dbToUi(String db) {
    final t = (db).toLowerCase().trim();
    switch (t) {
      case 'create':
        return 'Oluşturuldu';
      case 'active':
        return 'Kuryede';
      case 'courier_picked_up':
        return 'Teslim Aldı';
      case 'completed':
        return 'Teslim Edildi';
      case 'cancelled':
        return 'İptal';
      default:
        return 'Oluşturuldu';
    }
  }

  String _normalizeToDb(String any) {
    final t = any
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .trim();

    if (['create', 'active', 'courier_picked_up', 'completed', 'cancelled']
        .contains(t)) {
      return t;
    }

    if (t.contains('olustur')) return 'create';
    if (t.contains('kuryede') || t.contains('aktif') || t.contains('active')) {
      return 'active';
    }
    if (t.contains('teslim al')) return 'courier_picked_up';
    if (t.contains('teslim et') || t.contains('tamam')) return 'completed';
    if (t.contains('cancel') || t.contains('iptal')) return 'cancelled';

    return 'create';
  }

  String _uiToDb(String ui) {
    switch (ui) {
      case 'Oluşturuldu':
        return 'create';
      case 'Kuryede':
        return 'active';
      case 'Teslim Aldı':
        return 'courier_picked_up';
      case 'Teslim Edildi':
        return 'completed';
      case 'İptal':
        return 'cancelled';
      default:
        return _normalizeToDb(ui);
    }
  }

  IconData _statusIcon(String db) {
    switch (_normalizeToDb(db)) {
      case 'create':
        return Icons.receipt_long_outlined;
      case 'active':
        return Icons.local_shipping_outlined;
      case 'courier_picked_up':
        return Icons.inventory_2_outlined;
      case 'completed':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color _statusColor(String db) {
    switch (_normalizeToDb(db)) {
      case 'create':
        return kGray;
      case 'active':
        return kGreen;
      case 'courier_picked_up':
        return kAmber;
      case 'completed':
        return kGreen;
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return kGray;
    }
  }

  List<Color> _statusGradient(String db) {
    final c = _statusColor(db);
    return [c.withOpacity(.18), c.withOpacity(.06)];
  }

  // ---------- Date helpers ----------
  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  void _setToday() {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day);
    setState(() {
      _quickRange = 'today';
      _fromDate = d;
      _toDate = d;
    });
    _applyFilters();
  }

  void _setThisWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start =
        today.subtract(Duration(days: today.weekday - DateTime.monday));
    final end = start.add(const Duration(days: 6));
    setState(() {
      _quickRange = 'week';
      _fromDate = start;
      _toDate = end;
    });
    _applyFilters();
  }

  void _setThisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final nextMonth = (now.month == 12)
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    final end = nextMonth.subtract(const Duration(days: 1));
    setState(() {
      _quickRange = 'month';
      _fromDate = start;
      _toDate = end;
    });
    _applyFilters();
  }

  void _clearDateFilters() {
    setState(() {
      _quickRange = 'all';
      _fromDate = null;
      _toDate = null;
    });
    _applyFilters();
  }

  // ---------- Load ----------
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiClient>();
      final res = await api.deliveryOrders(page: 1, perPage: 50);
      final list = _parseDeliveryPayload(res);

      setState(() {
        _all = list;
        _visible = List.of(_all);
      });

      _applyFilters(); // filtre + sort + selection keep
    } catch (e) {
      setState(() => _error = 'Kayıtlar yüklenemedi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- Parse ----------
  List<_DOrder> _parseDeliveryPayload(Map<String, dynamic> payload) {
    final items =
        (payload['data'] is List) ? (payload['data'] as List) : <dynamic>[];

    String pickS(Map m, List<String> ks, {String fallback = ''}) {
      for (final k in ks) {
        final v = m[k];
        if (v == null) continue;
        if (v is String && v.isNotEmpty) return v;
        if (v is num) return v.toString();
      }
      return fallback;
    }

    double pickD(Map m, List<String> ks) {
      for (final k in ks) {
        final v = m[k];
        if (v is num) return v.toDouble();
        if (v is String) {
          final d = double.tryParse(v.replaceAll(',', '.'));
          if (d != null) return d;
        }
      }
      return 0.0;
    }

    DateTime pickDate(Map m, List<String> ks) {
      for (final k in ks) {
        final v = m[k];
        if (v is String) {
          final d = DateTime.tryParse(v);
          if (d != null) return d;
        }
      }
      return DateTime.now();
    }

    Map<String, dynamic>? parseJsonField(dynamic val) {
      if (val == null) return null;
      if (val is Map<String, dynamic>) return val;
      if (val is String && val.isNotEmpty) {
        try {
          final o = jsonDecode(val);
          if (o is Map<String, dynamic>) return o;
        } catch (_) {}
      }
      return null;
    }

    return items.whereType<Map>().map((raw0) {
      final raw = Map<String, dynamic>.from(raw0);

      final id = pickS(raw, ['id']);
      final parentOrderId = pickS(raw, ['parent_order_id']);

      final pickup = parseJsonField(raw['pickup_point']) ?? {};
      final delivery = parseJsonField(raw['delivery_point']) ?? {};
      final extra = parseJsonField(raw['extra_charges']) ?? {};

      final number = (raw['customer_fcm_token'] ??
              raw['order_number'] ??
              extra['order_no'] ??
              delivery['reference'] ??
              pickup['reference'] ??
              '#$id')
          .toString();

      final statusDb = _normalizeToDb(pickS(raw, ['status']));
      final createdAt = pickDate(raw, ['date', 'created_at', 'updated_at']);
      final total = pickD(raw, ['total_amount']);

      final courierId = pickS(raw, ['delivery_man_id', 'courier_id']);
      final courierName =
          pickS(raw, ['delivery_man_name', 'courier_name', 'courierName']);

      final pickupLine =
          _joinNonEmpty([pickup['name']?.toString(), _cityDistrict(pickup)]);
      final deliveryLine = _joinNonEmpty(
          [delivery['name']?.toString(), _cityDistrict(delivery)]);

      return _DOrder(
        id: id,
        parentOrderId: parentOrderId.isEmpty ? null : parentOrderId,
        orderNumber: number,
        statusDb: statusDb,
        createdAt: createdAt,
        totalAmount: total,
        pickupName: pickup['name']?.toString(),
        pickupAddress: pickup['address']?.toString(),
        deliveryName: delivery['name']?.toString(),
        deliveryAddress: delivery['address']?.toString(),
        pickupLine: pickupLine,
        deliveryLine: deliveryLine,
        autoAssign: (raw['auto_assign'] == 1 || raw['auto_assign'] == true),
        courierId: courierId.isEmpty ? null : courierId,
        courierName: courierName.isEmpty ? null : courierName,
      );
    }).toList();
  }

  String _cityDistrict(Map m) {
    final c = (m['city'] ?? '').toString();
    final d = (m['district'] ?? '').toString();
    if (c.isNotEmpty && d.isNotEmpty) return '$c/$d';
    if (c.isNotEmpty) return c;
    if (d.isNotEmpty) return d;
    return '';
  }

  String _joinNonEmpty(List<String?> parts, {String sep = ' • '}) {
    return parts
        .where((e) => (e ?? '').trim().isNotEmpty)
        .map((e) => e!.trim())
        .join(sep);
  }

  // ---------- Filters + Sort ----------
  void _applyFilters() {
    final q = _search.text.trim().toLowerCase();
    final from = _fromDate;
    final to = _toDate;

    final nextVisible = _all.where((o) {
      final okQuery = q.isEmpty ||
          o.orderNumber.toLowerCase().contains(q) ||
          o.pickupLine.toLowerCase().contains(q) ||
          o.deliveryLine.toLowerCase().contains(q) ||
          (o.pickupAddress ?? '').toLowerCase().contains(q) ||
          (o.deliveryAddress ?? '').toLowerCase().contains(q) ||
          (o.courierName ?? '').toLowerCase().contains(q);

      bool okDate = true;
      final d = o.createdAt;
      if (from != null) {
        okDate =
            okDate && !d.isBefore(DateTime(from.year, from.month, from.day));
      }
      if (to != null) {
        okDate = okDate &&
            !d.isAfter(DateTime(to.year, to.month, to.day, 23, 59, 59));
      }

      return okQuery && okDate;
    }).toList();

    setState(() {
      _visible = nextVisible;
      _applySort();

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
          cmp = a.createdAt.compareTo(b.createdAt);
          break;
        case 1:
          cmp = a.pickupLine.compareTo(b.pickupLine);
          break;
        case 2:
          cmp = a.deliveryLine.compareTo(b.deliveryLine);
          break;
        case 3:
          cmp = _dbToUi(a.statusDb).compareTo(_dbToUi(b.statusDb));
          break;
        case 4:
          cmp = a.totalAmount.compareTo(b.totalAmount);
          break;
        case 5:
          cmp = (a.courierName ?? '').compareTo(b.courierName ?? '');
          break;
        default:
          cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _applySort();
      // sort sonrası seçim korunuyor zaten
    });
  }

  // ---------- Actions ----------
  Future<void> _pickAndUpdateStatus(_DOrder o) async {
    String selected = _dbToUi(o.statusDb);

    final newStatusUi = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Durumu Güncelle'),
        content: StatefulBuilder(
          builder: (ctx, setS) {
            return DropdownButton<String>(
              value: _statusOptions.contains(selected)
                  ? selected
                  : _statusOptions.first,
              isExpanded: true,
              items: _statusOptions
                  .map((s) => DropdownMenuItem<String>(
                        value: s,
                        child: Text(s,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ))
                  .toList(),
              onChanged: (v) => setS(() => selected = v ?? selected),
            );
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: kGreenDark,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('Kaydet',
                  style: TextStyle(fontWeight: FontWeight.w900))),
        ],
      ),
    );

    if (newStatusUi == null) return;
    final newDb = _uiToDb(newStatusUi);
    if (newDb == o.statusDb) return;

    try {
      final api = context.read<ApiClient>();
      await api.updateDeliveryOrder(int.parse(o.id), {'status': newDb});

      setState(() {
        final ix = _all.indexWhere((e) => e.id == o.id);
        if (ix >= 0) _all[ix] = _all[ix].copyWith(statusDb: newDb);
        final vx = _visible.indexWhere((e) => e.id == o.id);
        if (vx >= 0) _visible[vx] = _visible[vx].copyWith(statusDb: newDb);

        if (_selected?.id == o.id) {
          _selected = _selected!.copyWith(statusDb: newDb);
        }
      });

      if (!mounted) return;
      final c = _statusColor(newDb);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.white,
          content: Row(
            children: [
              Icon(_statusIcon(newDb), color: c),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Durum güncellendi: ${_dbToUi(newDb)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          elevation: 10,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Güncelleme başarısız: $e')));
    }
  }

  void _openDetail(_DOrder o) {
    final location = Uri(
      path: '/delivery-orders/${Uri.encodeComponent(o.orderNumber)}',
      queryParameters: {
        'status': o.statusDb,
        'id': o.id,
      },
    ).toString();
    context.go(location);
  }

  Future<void> _openNewOrderPage() async {
    context.go('/delivery-orders/new');
  }

  // ---------- BUILD ----------
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
          child: const Center(child: CircularProgressIndicator()));
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

    final total = _visible.fold<double>(0, (s, o) => s + o.totalAmount);
    final completed = _visible.where((o) => o.statusDb == 'completed').length;
    final active = _visible.where((o) => o.statusDb == 'active').length;

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
                  total: total,
                  completed: completed,
                  active: active,
                  count: _visible.length,
                  onRefresh: _load,
                  onNew: _openNewOrderPage,
                ),
                const SizedBox(height: 14),
                _filtersCard(),
                const SizedBox(height: 14),

                // ✅ Responsive container: wide => master-detail
                LayoutBuilder(
                  builder: (context, box) {
                    final wide = box.maxWidth >= 1100;

                    if (!wide) {
                      return _ordersContainer(
                        child: _visible.isEmpty
                            ? _emptyState()
                            : _ordersCardList(),
                      );
                    }

                    return SizedBox(
                      height:
                          680, // sağ panel scroll için sabit bir yükseklik iyi olur
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: _ordersContainer(
                              child: _visible.isEmpty
                                  ? _emptyState()
                                  : _ordersWideTable(masterDetail: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 4,
                            child: _rightOrderDetailPanel(),
                          ),
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
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }

  // ================= UI =================

  Widget _heroHeader({
    required double total,
    required int completed,
    required int active,
    required int count,
    required VoidCallback onRefresh,
    required VoidCallback onNew,
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
                  child: Icon(Icons.receipt_long, color: kGreenDark),
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
                    Text("Kurye gönderi kayıtları • filtrele • güncelle",
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
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: onNew,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: kGreenDark,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add),
                label: const Text("Yeni Sipariş",
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, box) {
              final isWide = box.maxWidth >= 860;
              final cards = [
                _miniStat("Toplam", tl(total), Icons.paid_outlined),
                _miniStat("Aktif", "$active", Icons.local_shipping_outlined),
                _miniStat("Tamam", "$completed", Icons.check_circle_outline),
                _miniStat("Kayıt", "$count", Icons.receipt_long_outlined),
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
        border: Border.all(color: kAmber, width: 1.4),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            color: kAmber.withOpacity(0.24),
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
            children: [
              _rangeChip(
                label: "Bugün",
                active: _quickRange == 'today',
                color: kGreen,
                onTap: _setToday,
              ),
              _rangeChip(
                label: "Bu Hafta",
                active: _quickRange == 'week',
                color: kAmber,
                onTap: _setThisWeek,
              ),
              _rangeChip(
                label: "Bu Ay",
                active: _quickRange == 'month',
                color: kGreenDark,
                onTap: _setThisMonth,
              ),
              _rangeChip(
                label: "Tümü",
                active: _quickRange == 'all',
                color: kGray,
                onTap: _clearDateFilters,
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAmber,
                  side: BorderSide(color: kAmber.withOpacity(.45)),
                ),
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(_fromDate == null
                    ? 'Başlangıç'
                    : 'Başlangıç: ${_formatDate(_fromDate!)}'),
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _fromDate ?? now,
                    firstDate: DateTime(now.year - 3),
                    lastDate: DateTime(now.year + 1),
                  );
                  if (picked != null) {
                    setState(() {
                      _quickRange = 'custom';
                      _fromDate = picked;
                    });
                    _applyFilters();
                  }
                },
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAmber,
                  side: BorderSide(color: kAmber.withOpacity(.45)),
                ),
                icon: const Icon(Icons.calendar_month, size: 16),
                label: Text(_toDate == null
                    ? 'Bitiş'
                    : 'Bitiş: ${_formatDate(_toDate!)}'),
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _toDate ?? _fromDate ?? now,
                    firstDate: DateTime(now.year - 3),
                    lastDate: DateTime(now.year + 1),
                  );
                  if (picked != null) {
                    setState(() {
                      _quickRange = 'custom';
                      _toDate = picked;
                    });
                    _applyFilters();
                  }
                },
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: kAmber),
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Tarihleri temizle'),
                onPressed: _clearDateFilters,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Sipariş no, adres, çıkış/varış, kurye ara…',
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
                  colors: [color, color.withOpacity(.0)],
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
                    color: color.withOpacity(.2),
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

  // ---------- Mobile card list ----------
  Widget _ordersCardList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _visible.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final o = _visible[i];
        final statusC = _statusColor(o.statusDb);

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openDetail(o),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kAmber.withOpacity(0.6), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: statusC.withOpacity(.10),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: statusC,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: statusC.withOpacity(.35),
                            blurRadius: 10,
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${o.id} • ${o.orderNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: kGreen,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      dt(o.createdAt),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _twoLine(
                        label: "Çıkış",
                        title: (o.pickupName ?? '').trim().isNotEmpty
                            ? o.pickupName!.trim()
                            : (o.pickupLine.isNotEmpty ? o.pickupLine : '—'),
                        subtitle: o.pickupAddress,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _twoLine(
                        label: "Varış",
                        title: (o.deliveryName ?? '').trim().isNotEmpty
                            ? o.deliveryName!.trim()
                            : (o.deliveryLine.isNotEmpty
                                ? o.deliveryLine
                                : '—'),
                        subtitle: o.deliveryAddress,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _premiumStatusChip(o),
                    const Spacer(),
                    Text(tl(o.totalAmount),
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 14)),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: "Durumu değiştir",
                      onPressed: () => _pickAndUpdateStatus(o),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
                if ((o.courierName ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 16, color: Color(0xFF6B7280)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          o.courierName!.trim(),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF374151)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _twoLine({
    required String label,
    required String title,
    required String? subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: Color(0xFF6B7280))),
        const SizedBox(height: 4),
        Text(title.isEmpty ? '—' : title,
            style: const TextStyle(fontWeight: FontWeight.w900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        if ((subtitle ?? '').trim().isNotEmpty)
          Text(
            subtitle!.trim(),
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _premiumStatusChip(_DOrder o) {
    final db = o.statusDb;
    final ui = _dbToUi(db);
    final c = _statusColor(db);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _statusGradient(db),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(.45)),
        boxShadow: [
          BoxShadow(
            color: c.withOpacity(.22),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(db), size: 16, color: c),
          const SizedBox(width: 6),
          Text(ui, style: TextStyle(fontWeight: FontWeight.w900, color: c)),
        ],
      ),
    );
  }

  // ---------- Wide table ----------
  Widget _ordersWideTable({required bool masterDetail}) {
    final cs = Theme.of(context).colorScheme;
    final onVar = cs.onSurfaceVariant;

    Widget twoLineCell({required String title, required String? subtitle}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title.isEmpty ? '—' : title,
              style: const TextStyle(fontWeight: FontWeight.w900)),
          if ((subtitle ?? '').trim().isNotEmpty)
            Text(
              subtitle!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: onVar),
            ),
        ],
      );
    }

    final hoverGray = const Color(0xFF111827).withOpacity(.05);

    final table = DataTable(
      columnSpacing: 28,
      dataRowMinHeight: 72,
      dataRowMaxHeight: 92,
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      headingRowColor: MaterialStatePropertyAll(kGreen.withOpacity(.07)),
      columns: [
        DataColumn(
          label: const Align(
              alignment: Alignment.centerLeft, child: Text('Tarih')),
          onSort: _onSort,
        ),
        DataColumn(
          label: const Align(
              alignment: Alignment.centerLeft, child: Text('Çıkış')),
          onSort: _onSort,
        ),
        DataColumn(
          label: const Align(
              alignment: Alignment.centerLeft, child: Text('Varış')),
          onSort: _onSort,
        ),
        DataColumn(
          label: const Align(
              alignment: Alignment.centerLeft, child: Text('Durum')),
          onSort: _onSort,
        ),
        DataColumn(
          numeric: true,
          label: const Align(
              alignment: Alignment.centerLeft, child: Text('Tutar')),
          onSort: _onSort,
        ),
        DataColumn(
          label: const Align(
              alignment: Alignment.centerLeft, child: Text('Kurye')),
          onSort: _onSort,
        ),
        const DataColumn(
          label:
              Align(alignment: Alignment.centerLeft, child: Text('İşlemler')),
        ),
      ],
      rows: List.generate(_visible.length, (i) {
        final o = _visible[i];
        final base = i.isEven ? cs.surface : kBg;
        final selected = (_selected?.id == o.id);

        return DataRow(
          selected: selected,
          onSelectChanged: (v) {
            if (!masterDetail) return;
            setState(() => _selected = o);
          },
          color: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const Color(0xFF111827).withOpacity(.07);
            }
            if (states.contains(MaterialState.hovered)) return hoverGray;
            return base;
          }),
          cells: [
            DataCell(Align(
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dt(o.createdAt),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    o.orderNumber,
                    style: TextStyle(
                      fontSize: 12,
                      color: onVar,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )),
            DataCell(Align(
              alignment: Alignment.centerLeft,
              child: twoLineCell(
                title: (o.pickupName ?? '').trim().isNotEmpty
                    ? o.pickupName!.trim()
                    : (o.pickupLine.isNotEmpty ? o.pickupLine : '—'),
                subtitle: o.pickupAddress,
              ),
            )),
            DataCell(Align(
              alignment: Alignment.centerLeft,
              child: twoLineCell(
                title: (o.deliveryName ?? '').trim().isNotEmpty
                    ? o.deliveryName!.trim()
                    : (o.deliveryLine.isNotEmpty ? o.deliveryLine : '—'),
                subtitle: o.deliveryAddress,
              ),
            )),
            DataCell(Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _premiumStatusChip(o),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Durumu güncelle',
                    icon: Icon(Icons.edit_outlined,
                        size: 18, color: _statusColor(o.statusDb)),
                    onPressed: () => _pickAndUpdateStatus(o),
                  ),
                ],
              ),
            )),
            DataCell(Align(
              alignment: Alignment.centerLeft,
              child: Text(tl(o.totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            )),
            DataCell(Align(
              alignment: Alignment.centerLeft,
              child: Text(o.courierName ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            )),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: masterDetail ? 'Detaya git' : 'Detay',
                  onPressed: () => _openDetail(o),
                  icon: const Icon(Icons.open_in_new),
                ),
              ],
            )),
          ],
        );
      }),
    );

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1100),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: table,
          ),
        ),
      ),
    );
  }

  // ---------- Right detail panel ----------
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
                            '${o.id} • ${o.orderNumber}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Detaya git',
                          onPressed: () => _openDetail(o),
                          icon: const Icon(Icons.open_in_new),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _premiumStatusChip(o),
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
                      icon: Icons.local_shipping_outlined,
                      label: 'Kurye',
                      value: (o.courierName ?? '').trim().isEmpty
                          ? '—'
                          : o.courierName!.trim(),
                    ),
                    const SizedBox(height: 14),
                    const Text('Çıkış',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    _detailBlock(
                      title: (o.pickupName ?? '').trim().isNotEmpty
                          ? o.pickupName!.trim()
                          : (o.pickupLine.isNotEmpty ? o.pickupLine : '—'),
                      subtitle: o.pickupAddress,
                    ),
                    const SizedBox(height: 14),
                    const Text('Varış',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    _detailBlock(
                      title: (o.deliveryName ?? '').trim().isNotEmpty
                          ? o.deliveryName!.trim()
                          : (o.deliveryLine.isNotEmpty ? o.deliveryLine : '—'),
                      subtitle: o.deliveryAddress,
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
                            onPressed: () => _pickAndUpdateStatus(o),
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

  Widget _detailBlock({required String title, required String? subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.isEmpty ? '—' : title,
              style: const TextStyle(fontWeight: FontWeight.w900)),
          if ((subtitle ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!.trim(),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyState() => const Padding(
        padding: EdgeInsets.all(10.0),
        child: Center(child: Text('Eşleşen kayıt bulunamadı')),
      );
}

// --------------------- View-model ---------------------
class _DOrder {
  final String id;
  final String? parentOrderId;
  final String orderNumber;
  final String statusDb;
  final DateTime createdAt;
  final double totalAmount;

  final String? pickupName;
  final String? pickupAddress;
  final String? deliveryName;
  final String? deliveryAddress;

  final String pickupLine;
  final String deliveryLine;

  final bool autoAssign;

  final String? courierId;
  final String? courierName;

  _DOrder({
    required this.id,
    required this.parentOrderId,
    required this.orderNumber,
    required this.statusDb,
    required this.createdAt,
    required this.totalAmount,
    required this.pickupName,
    required this.pickupAddress,
    required this.deliveryName,
    required this.deliveryAddress,
    required this.pickupLine,
    required this.deliveryLine,
    required this.autoAssign,
    this.courierId,
    this.courierName,
  });

  _DOrder copyWith({
    String? statusDb,
  }) {
    return _DOrder(
      id: id,
      parentOrderId: parentOrderId,
      orderNumber: orderNumber,
      statusDb: statusDb ?? this.statusDb,
      createdAt: createdAt,
      totalAmount: totalAmount,
      pickupName: pickupName,
      pickupAddress: pickupAddress,
      deliveryName: deliveryName,
      deliveryAddress: deliveryAddress,
      pickupLine: pickupLine,
      deliveryLine: deliveryLine,
      autoAssign: autoAssign,
      courierId: courierId,
      courierName: courierName,
    );
  }
}
