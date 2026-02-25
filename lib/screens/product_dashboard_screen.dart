import 'dart:ui'; // FontFeature için

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';

class ProductDashboardScreen extends StatefulWidget {
  const ProductDashboardScreen({super.key});

  @override
  State<ProductDashboardScreen> createState() => _ProductDashboardScreenState();
}

class _ProductDashboardScreenState extends State<ProductDashboardScreen> {
  bool _loading = true;
  String? _error;

  List<_ProductRow> _all = [];
  List<_ProductRow> _visible = [];

  // filtre
  final TextEditingController _searchC = TextEditingController();
  String _statusFilter = 'Hepsi'; // Hepsi / Stokta / Az Stok / Stokta Yok

  bool _isTableView = true; // 👈 tablo / kart görünümü

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiClient>();

      // baseUrl'in sonunda /api/v1/ varsa:
      // -> /api/v1/productdashboard/products
      final res = await api.dio.get('productdashboard/products');

      final data = res.data;
      List list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['data'] is List) {
        list = data['data'] as List;
      } else {
        list = const [];
      }

      final rows = list
          .whereType<Map>()
          .map((m) => _ProductRow.fromJson(Map<String, dynamic>.from(m)))
          .toList();

      setState(() {
        _all = rows;
        _visible = List.of(_all);
      });
      _applyFilter();
    } catch (e) {
      setState(() => _error = 'Ürün raporu yüklenemedi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _searchC.text.trim().toLowerCase();
    Iterable<_ProductRow> list = _all;

    if (_statusFilter != 'Hepsi') {
      list = list.where((row) {
        final s = row.status.toLowerCase();
        switch (_statusFilter) {
          case 'Stokta':
            return s.contains('in_stock') || s.contains('in stock');
          case 'Stokta Yok':
            return s.contains('out');
          case 'Az Stok':
            return s.contains('low');
        }
        return true;
      });
    }

    if (q.isNotEmpty) {
      list = list.where((row) {
        final vName = row.variantName?.toLowerCase() ?? '';
        final sku = (row.sku ?? '').toLowerCase();
        return row.productName.toLowerCase().contains(q) ||
            vName.contains(q) ||
            sku.contains(q);
      });
    }

    setState(() => _visible = list.toList());
  }

  // Belirli bir filtreye göre trend datası (mini bar grafik için)
  List<double> _buildTrend(bool Function(_ProductRow row) where) {
    final values = _all
        .where(where)
        .map((e) => (e.totalRevenue ?? 0).toDouble())
        .where((v) => v > 0)
        .toList();

    if (values.isEmpty) return [0, 0, 0, 0, 0, 0];

    values.sort();
    const barCount = 6;
    final step = (values.length / barCount).clamp(1, values.length).toInt();

    final trend = <double>[];
    for (int i = 0; i < values.length && trend.length < barCount; i += step) {
      trend.add(values[i]);
    }
    while (trend.length < barCount) {
      trend.add(trend.last);
    }
    return trend;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenW = MediaQuery.of(context).size.width;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
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
      );
    }

    // ----- TOPLAMLAR -----
    // Varyant tipine göre (KG / ADET / BAĞ) toplam miktar & ciro
    final Map<String, _VariantSummary> byVariant = {};
    for (final row in _all) {
      final key = (row.variantName ?? '-').toUpperCase();
      byVariant.putIfAbsent(key, () => _VariantSummary(unit: key));
      final s = byVariant[key]!;
      s.totalQty += (row.totalQty ?? 0);
      s.totalRevenue += (row.totalRevenue ?? 0);
    }

    final summaries = byVariant.values.toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    // En fazla 3 kart gösterelim
    final showSummaries = summaries.take(3).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            children: [
              Text(
                'Ürün Paneli',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  // yeni ürün ekleme ekranına gidebilirsin
                },
                icon: const Icon(Icons.add),
                label: const Text('Yeni Ürün Ekle'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ----- VARYANT BAZLI KARTLAR -----
          if (showSummaries.isNotEmpty)
            Row(
              children: [
                for (final s in showSummaries) ...[
                  _MetricCard(
                    title: 'Toplam Satış (${s.unit})',
                    value: '${s.totalQty.toStringAsFixed(0)} ${s.unit}',
                    subtitle: 'Ciro: ₺${s.totalRevenue.toStringAsFixed(2)}',
                    trend: _buildTrend(
                      (row) => (row.variantName ?? '').toUpperCase() == s.unit,
                    ),
                  ),
                  if (s != showSummaries.last) const SizedBox(width: 16),
                ],
              ],
            ),

          const SizedBox(height: 24),

          // ----- FİLTRE BAR -----
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                // Sol etiket
                Row(
                  children: [
                    const Text(
                      'Ürünler',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 1,
                      height: 20,
                      color: cs.outlineVariant,
                    ),
                  ],
                ),
                const SizedBox(width: 8),

                // Durum filtresi
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    items: const [
                      DropdownMenuItem(
                        value: 'Hepsi',
                        child: Text('Tüm stok durumları'),
                      ),
                      DropdownMenuItem(
                        value: 'Stokta',
                        child: Text('Stokta'),
                      ),
                      DropdownMenuItem(
                        value: 'Az Stok',
                        child: Text('Az stok'),
                      ),
                      DropdownMenuItem(
                        value: 'Stokta Yok',
                        child: Text('Stokta yok'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _statusFilter = v);
                      _applyFilter();
                    },
                  ),
                ),

                const Spacer(),

                // Arama
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _searchC,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Ürün, varyant, SKU ara...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchC.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchC.clear();
                                _applyFilter();
                              },
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onChanged: (_) => _applyFilter(),
                  ),
                ),
                const SizedBox(width: 8),

                // Görünüm toggle (tablo / kart)
                IconButton.outlined(
                  onPressed: () {
                    setState(() => _isTableView = true);
                  },
                  icon: Icon(
                    Icons.view_week_outlined,
                    color: _isTableView ? cs.primary : cs.onSurfaceVariant,
                  ),
                  tooltip: 'Tablo görünümü',
                ),
                const SizedBox(width: 4),
                IconButton.outlined(
                  onPressed: () {
                    setState(() => _isTableView = false);
                  },
                  icon: Icon(
                    Icons.grid_view_outlined,
                    color: !_isTableView ? cs.primary : cs.onSurfaceVariant,
                  ),
                  tooltip: 'Kart görünümü',
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ----- ANA İÇERİK: TABLO veya KART -----
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: _visible.isEmpty
                  ? Center(
                      child: Text(
                        'Kayıt bulunamadı',
                        style: TextStyle(color: cs.tertiary),
                      ),
                    )
                  : _isTableView
                      ? _buildTableView(screenW, cs)
                      : _buildCardView(cs),
            ),
          ),
        ],
      ),
    );
  }

  // ----- TABLO GÖRÜNÜMÜ -----

  Widget _buildTableView(double screenW, ColorScheme cs) {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: screenW),
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Ürün Adı')),
                DataColumn(label: Text('Varyant')),
                DataColumn(label: Text('Satış Miktarı')),
                DataColumn(label: Text('Ort. Fiyat')),
                DataColumn(label: Text('Ciro')),
                DataColumn(label: Text('Son Sipariş Tarihi')),
              ],
              rows: List.generate(_visible.length, (i) {
                final row = _visible[i];
                return _buildDataRow(row, i, cs);
              }),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _buildDataRow(_ProductRow row, int index, ColorScheme cs) {
    final baseColor =
        index.isEven ? Colors.transparent : cs.primary.withOpacity(0.015);

    String miktarText;
    final unit = row.variantName ?? '';
    miktarText = '${row.totalQty ?? 0} ${unit.isNotEmpty ? unit : ''}'.trim();

    String lastDate = row.lastOrderAt ?? '-';
    if (lastDate.contains(' ')) {
      lastDate = lastDate.split(' ').first;
    }

    return DataRow(
      color: MaterialStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return cs.primary.withOpacity(.06);
        }
        return baseColor;
      }),
      cells: [
        // Ürün adı (avatar + text)
        DataCell(
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.orange.withOpacity(.12),
                child: Text(
                  row.productName.isNotEmpty ? row.productName[0] : '?',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                row.productName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        DataCell(Text(row.variantName ?? '-')),
        DataCell(
          Text(
            miktarText,
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        DataCell(
          Text(
            '₺${(row.price ?? 0).toStringAsFixed(2)}',
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        DataCell(
          Text(
            '₺${(row.totalRevenue ?? 0).toStringAsFixed(2)}',
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        DataCell(Text(lastDate)),
      ],
    );
  }

  // ----- KART GÖRÜNÜMÜ -----

  Widget _buildCardView(ColorScheme cs) {
    return Scrollbar(
      thumbVisibility: true,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final row = _visible[i];

          String miktarText;
          final unit = row.variantName ?? '';
          miktarText =
              '${row.totalQty ?? 0} ${unit.isNotEmpty ? unit : ''}'.trim();

          String lastDate = row.lastOrderAt ?? '-';
          if (lastDate.contains(' ')) {
            lastDate = lastDate.split(' ').first;
          }

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.orange.withOpacity(.12),
                  child: Text(
                    row.productName.isNotEmpty ? row.productName[0] : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),

                // Sol taraf bilgiler
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Chip(
                            label: Text(row.variantName ?? '-'),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Satış: $miktarText',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Sağ taraf rakamlar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Ciro: ₺${(row.totalRevenue ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ort. Fiyat: ₺${(row.price ?? 0).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.tertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Son: $lastDate',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.tertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// ------------------------ MODELLER & WIDGETLER ------------------------

class _ProductRow {
  final int id;
  final String productName;
  final String? variantName;
  final String? sku;
  final double? price;
  final double? totalRevenue;
  final int? totalQty;
  final int? stock;
  final String status; // in_stock / out_of_stock / low_stock
  final String? lastOrderAt;

  _ProductRow({
    required this.id,
    required this.productName,
    this.variantName,
    this.sku,
    this.price,
    this.totalRevenue,
    this.totalQty,
    this.stock,
    required this.status,
    this.lastOrderAt,
  });

  factory _ProductRow.fromJson(Map<String, dynamic> j) {
    double? _d(dynamic v) => v == null ? null : double.tryParse(v.toString());
    int? _i(dynamic v) => v == null ? null : int.tryParse(v.toString());

    return _ProductRow(
      id: _i(j['product_id']) ?? _i(j['id']) ?? 0,
      productName: (j['product_name'] ?? j['name'] ?? '').toString(),
      variantName: j['variant_name']?.toString(),
      sku: j['sku']?.toString(),
      price: _d(j['avg_price'] ?? j['price']),
      totalRevenue: _d(j['total_revenue']),
      totalQty: _i(j['total_qty']),
      stock: _i(j['stock']),
      status: (j['stock_status'] ?? j['status'] ?? 'in_stock').toString(),
      lastOrderAt: j['last_order_at']?.toString(),
    );
  }
}

class _VariantSummary {
  final String unit;
  double totalQty;
  double totalRevenue;

  _VariantSummary({
    required this.unit,
    this.totalQty = 0,
    this.totalRevenue = 0,
  });
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final List<double>? trend;

  const _MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = trend ?? const [0, 0, 0, 0, 0, 0];
    final maxVal =
        (t.isNotEmpty ? t.reduce((a, b) => a > b ? a : b) : 0) + 0.01;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(.08),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                Icons.bar_chart_rounded,
                size: 20,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final v in t)
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: Container(
                                height: (v / maxVal) * 28,
                                decoration: BoxDecoration(
                                  color: cs.primary.withOpacity(.55),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
