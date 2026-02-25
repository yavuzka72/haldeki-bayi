import 'dart:ui'; // FontFeature için

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';

class ClientProductDashboardScreen extends StatefulWidget {
  const ClientProductDashboardScreen({super.key});

  @override
  State<ClientProductDashboardScreen> createState() =>
      _ClientProductDashboardScreenState();
}

class _ClientProductDashboardScreenState
    extends State<ClientProductDashboardScreen> {
  bool _loading = true;
  String? _error;

  // summary
  int _clientCount = 0;
  int _totalQty = 0;
  double _totalRevenue = 0;

  // liste
  final TextEditingController _searchC = TextEditingController();
  bool _isTableView = true;

  List<_ClientProductRow> _all = [];
  List<_ClientProductRow> _visible = [];

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
      // /api/v1/clientdashboard/clients
      final res = await api.dio.get('clientdashboard/clients');

      final map = Map<String, dynamic>.from(res.data as Map);

      final summary = Map<String, dynamic>.from(
        map['summary'] as Map? ?? <String, dynamic>{},
      );
      final products = (map['products'] as List? ?? <dynamic>[]);

      final rows = products
          .whereType<Map>()
          .map((m) => _ClientProductRow.fromJson(
                Map<String, dynamic>.from(m),
              ))
          .toList();

      // summary alanları + fallback
      /*  final clientCountFromApi = _asInt(summary['client_count']);
      final totalQtyFromApi = _asInt(summary['total_qty']);
      final totalRevenueFromApi = _asDouble(summary['total_revenue']);

      setState(() {
        _clientCount = clientCountFromApi ??
            rows.map((e) => e.clientId).toSet().length; // eşsiz client sayısı
        _totalQty = totalQtyFromApi ??
            rows.fold<int>(0, (p, e) => p + (e.totalQty ?? 0));
        _totalRevenue = totalRevenueFromApi ??
            rows.fold<double>(0, (p, e) => p + (e.totalRevenue ?? 0));

        _all = rows;
        _visible = List.of(_all);
      });
      */
      setState(() {
        _all = rows;
      });

      _applyFilter();
    } catch (e) {
      setState(() => _error = 'İşletme ürün raporu yüklenemedi: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applyFilter2() {
    final q = _searchC.text.trim().toLowerCase();
    Iterable<_ClientProductRow> list = _all;

    if (q.isNotEmpty) {
      list = list.where((row) {
        final v = row.variantName?.toLowerCase() ?? '';
        final c = row.clientName.toLowerCase();
        return row.productName.toLowerCase().contains(q) ||
            v.contains(q) ||
            c.contains(q);
      });
    }

    setState(() => _visible = list.toList());
  }

  void _applyFilter() {
    final q = _searchC.text.trim().toLowerCase();
    Iterable<_ClientProductRow> list = _all;

    if (q.isNotEmpty) {
      list = list.where((row) {
        final v = row.variantName?.toLowerCase() ?? '';
        final c = row.clientName.toLowerCase();
        return row.productName.toLowerCase().contains(q) ||
            v.contains(q) ||
            c.contains(q);
      });
    }

    final visibleList = list.toList();

    // 👇 Özetleri GÖRÜNEN listeye göre hesapla
    final clientCount =
        visibleList.map((e) => e.clientId).toSet().length; // eşsiz işletme
    final totalQty = visibleList.fold<int>(0, (p, e) => p + (e.totalQty ?? 0));
    final totalRevenue =
        visibleList.fold<double>(0, (p, e) => p + (e.totalRevenue ?? 0));

    setState(() {
      _visible = visibleList;
      _clientCount = clientCount;
      _totalQty = totalQty;
      _totalRevenue = totalRevenue;
    });
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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            children: [
              Text(
                'İşletme Ürün Paneli',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  // İstersen genel özet ekranına götürebilirsin
                },
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Genel Özet'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ÜST KARTLAR
          Row(
            children: [
              _ClientMetricCard(
                title: 'Toplam İşletme',
                value: _clientCount.toString(),
                subtitle: 'Sipariş veren müşteri sayısı',
              ),
              const SizedBox(width: 16),
              _ClientMetricCard(
                title: 'Toplam Ciro',
                value: '₺${_totalRevenue.toStringAsFixed(2)}',
                subtitle: 'Tüm müşteriler',
              ),
              const SizedBox(width: 16),
              _ClientMetricCard(
                title: 'Toplam Satış Miktarı',
                value: _totalQty.toString(),
                subtitle: 'KG / Adet / Bağ toplamı',
              ),
            ],
          ),

          const SizedBox(height: 24),

          // FİLTRE BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                const Text(
                  'Ürünler',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 20,
                  color: cs.outlineVariant,
                ),
                const SizedBox(width: 8),
                const Spacer(),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _searchC,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'İşletme, ürün veya varyant ara...',
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

          // ANA İÇERİK
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

  // ---------- TABLO GÖRÜNÜMÜ ----------

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
                DataColumn(label: Text('İşletme')),
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

  DataRow _buildDataRow(_ClientProductRow row, int index, ColorScheme cs) {
    final baseColor =
        index.isEven ? Colors.transparent : cs.primary.withOpacity(0.015);

    final unit = row.variantName ?? '';
    final miktarText =
        '${row.totalQty ?? 0} ${unit.isNotEmpty ? unit : ''}'.trim();

    String lastDate = row.lastOrderAt ?? '-';
    if (lastDate.contains(' ')) {
      lastDate = lastDate.split(' ').first;
    }

    return DataRow(
      color: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.hovered)) {
          return cs.primary.withOpacity(.06);
        }
        return baseColor;
      }),
      cells: [
        DataCell(Text(row.clientName)),
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
        // Varyant
        DataCell(Text(row.variantName ?? '-')),
        // İşletme adı

        // Miktar
        DataCell(
          Text(
            miktarText,
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        // Ort. fiyat
        DataCell(
          Text(
            '₺${(row.avgPrice ?? 0).toStringAsFixed(2)}',
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        // Ciro
        DataCell(
          Text(
            '₺${(row.totalRevenue ?? 0).toStringAsFixed(2)}',
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        // Son sipariş
        DataCell(Text(lastDate)),
      ],
    );
  }

  // ---------- KART GÖRÜNÜMÜ ----------

  Widget _buildCardView(ColorScheme cs) {
    return Scrollbar(
      thumbVisibility: true,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final row = _visible[i];

          final unit = row.variantName ?? '';
          final miktarText =
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
                      const SizedBox(height: 4),
                      Text(
                        'İşletme: ${row.clientName}',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
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
                      'Ort. Fiyat: ₺${(row.avgPrice ?? 0).toStringAsFixed(2)}',
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

  int? _asInt(dynamic v) => v == null ? null : int.tryParse(v.toString());

  double? _asDouble(dynamic v) =>
      v == null ? null : double.tryParse(v.toString());
}

/// ------------ MODEL ------------

class _ClientProductRow {
  final int clientId;
  final String clientName;

  final int productId;
  final int? variantId;
  final String productName;
  final String? variantName;
  final int? totalQty;
  final double? totalRevenue;
  final double? avgPrice;
  final String? lastOrderAt;

  _ClientProductRow({
    required this.clientId,
    required this.clientName,
    required this.productId,
    this.variantId,
    required this.productName,
    this.variantName,
    this.totalQty,
    this.totalRevenue,
    this.avgPrice,
    this.lastOrderAt,
  });

  factory _ClientProductRow.fromJson(Map<String, dynamic> j) {
    int? _i(dynamic v) => v == null ? null : int.tryParse(v.toString());
    double? _d(dynamic v) => v == null ? null : double.tryParse(v.toString());

    return _ClientProductRow(
      clientId: _i(j['client_id']) ?? 0,
      clientName: (j['client_name'] ?? '').toString(),
      productId: _i(j['product_id']) ?? 0,
      variantId: _i(j['variant_id']),
      productName: (j['product_name'] ?? '').toString(),
      variantName: j['variant_name']?.toString(),
      totalQty: _i(j['total_qty']),
      totalRevenue: _d(j['total_revenue']),
      avgPrice: _d(j['avg_price']),
      lastOrderAt: j['last_order_at']?.toString(),
    );
  }
}

/// ------------ METRIC CARD ------------

class _ClientMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _ClientMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
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
            Column(
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
              ],
            )
          ],
        ),
      ),
    );
  }
}
