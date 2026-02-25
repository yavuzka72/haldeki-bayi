// lib/screens/reports/widgets/report_screen.dart
import 'dart:convert';
import 'dart:ui' show FontFeature;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/api_client.dart';
import '../../../services/api_config.dart';
import '../../screens/haldeki_ui.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.title,
    required this.endpoint,
    required this.columns,
    required this.mapRow,
  });

  final String title;
  final String endpoint;
  final List<String> columns;
  final List<String> Function(Map<String, dynamic>) mapRow;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DateTimeRange? _range;
  String? _status; // null = Tümü
  int? _businessId;

  List<Map<String, dynamic>> _businesses = [];
  bool _bizLoading = true;
  String? _errBiz;

  bool loading = true;
  String? errorText;
  List<List<String>> rows = [];
  double totalGross = 0.0;
  double totalDealerProfit = 0.0;

  static const _kBreakWide = 1000.0;
  static const _kBreakCompact = 680.0;

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
    _fetch();
  }

  Future<Map<String, String>> _headers(ApiClient api) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, String> _query() {
    final m = <String, String>{};
    if (_businessId != null) m['business_id'] = '$_businessId';
    if (_status != null && _status!.isNotEmpty) m['status'] = _status!;
    if (_range != null) {
      m['start'] = _range!.start.toIso8601String().substring(0, 10);
      m['end'] = _range!.end.toIso8601String().substring(0, 10);
    }
    return m;
  }

  Future<void> _loadBusinesses() async {
    setState(() {
      _bizLoading = true;
      _errBiz = null;
    });

    try {
      final api = context.read<ApiClient>();
      final res = await api.dio.get('me/businesses');

      final raw = res.data;
      List<Map<String, dynamic>> list;
      if (raw is List) {
        list = raw.cast<Map<String, dynamic>>();
      } else if (raw is Map && raw['data'] is List) {
        list = (raw['data'] as List).cast<Map<String, dynamic>>();
      } else {
        list = const [];
      }

      setState(() {
        _businesses = list;
        _bizLoading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _bizLoading = false;
        _errBiz =
            'İşletmeler getirilemedi: ${e.response?.statusCode ?? ''} ${e.message}';
      });
    } catch (e) {
      setState(() {
        _bizLoading = false;
        _errBiz = 'Hata: $e';
      });
    }
  }

  Future<void> _fetch() async {
    setState(() {
      loading = true;
      errorText = null;
    });

    try {
      final api = context.read<ApiClient>();

      final qp = <String, dynamic>{
        if (_businessId != null) 'business_id': _businessId,
        if (_status != null && _status!.isNotEmpty) 'status': _status,
        if (_range != null) ...{
          'start': _range!.start.toIso8601String().substring(0, 10),
          'end': _range!.end.toIso8601String().substring(0, 10),
        },
      };

      final res = await api.dio.get(widget.endpoint, queryParameters: qp);
      final body = res.data as Map<String, dynamic>? ?? const {};

      final data = ((body['data'] ?? []) as List).cast<Map<String, dynamic>>();
      final meta = (body['meta'] as Map<String, dynamic>?) ?? {};

      setState(() {
        rows = data.map(widget.mapRow).toList();
        totalGross = _asDouble(meta['total_gross']);
        totalDealerProfit = _asDouble(meta['total_dealer_profit']);
        loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        loading = false;
        errorText = 'Sunucu: ${e.response?.statusCode ?? ''} ${e.message}';
      });
    } catch (e) {
      setState(() {
        loading = false;
        errorText = 'Hata: $e';
      });
    }
  }

  Future<void> _fetch2() async {
    final api = context.read<ApiClient>();
    setState(() {
      loading = true;
      errorText = null;
    });
    try {
      final uri = Uri.parse('${ApiConfig.base}${widget.endpoint}')
          .replace(queryParameters: _query());
      final res = await http.get(uri, headers: await _headers(api));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        setState(() {
          loading = false;
          errorText = 'Sunucu hatası: ${res.statusCode}';
        });
        return;
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = ((body['data'] ?? []) as List).cast<Map<String, dynamic>>();
      final meta = (body['meta'] as Map<String, dynamic>?) ?? {};

      setState(() {
        rows = data.map(widget.mapRow).toList();
        totalGross = _asDouble(meta['total_gross']);
        totalDealerProfit = _asDouble(meta['total_dealer_profit']);
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        errorText = 'Hata: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = MediaQuery.of(context).size.width;
    final compact = w < _kBreakCompact;
    final wide = w >= _kBreakWide;

    final themed = HaldekiUI.withRectButtons(context, cs)
        .copyWith(inputDecorationTheme: HaldekiUI.inputDense(context));

    return Theme(
      data: themed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _fetch,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Yenile'),
                ),
              ],
            ),
          ),
          FilterBar(
            businesses: _businesses,
            loading: _bizLoading,
            errorText: _errBiz,
            selectedBusinessId: _businessId,
            onBusinessChanged: (v) {
              setState(() => _businessId = v);
              _fetch();
            },
            status: _status,
            onStatusChanged: (v) {
              setState(() => _status = v);
              _fetch();
            },
            range: _range,
            onRangeChanged: (r) {
              setState(() => _range = r);
              _fetch();
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : (errorText != null)
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(errorText!,
                                style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 8),
                            FilledButton(
                                onPressed: _fetch,
                                child: const Text('Tekrar Dene')),
                          ],
                        ),
                      )
                    : DataTableView(
                        columns: widget.columns,
                        rows: rows,
                        totalGross: totalGross,
                        totalDealerProfit: totalDealerProfit,
                        compact: compact,
                        wide: wide,
                      ),
          ),
        ],
      ),
    );
  }

  static double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }
}

class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.businesses,
    required this.loading,
    required this.errorText,
    required this.selectedBusinessId,
    required this.onBusinessChanged,
    required this.status,
    required this.onStatusChanged,
    required this.range,
    required this.onRangeChanged,
  });

  final List<Map<String, dynamic>> businesses;
  final bool loading;
  final String? errorText;

  final int? selectedBusinessId;
  final ValueChanged<int?> onBusinessChanged;

  final String? status; // null = Tümü
  final ValueChanged<String?> onStatusChanged;

  final DateTimeRange? range;
  final ValueChanged<DateTimeRange?> onRangeChanged;

  static const _segmentStatuses = <String?>[
    null,
    'pending',
    'completed',
    'delivered',
    'cancelled',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = MediaQuery.of(context).size.width;
    final compact = w < 680;

    final dateButton = FilledButton.icon(
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(now.year - 2),
          lastDate: DateTime(now.year + 1),
          initialDateRange: range,
        );
        onRangeChanged(picked);
      },
      icon: const Icon(Icons.date_range),
      label: Text(_labelForRange(range)),
    );

    final statusSegments = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _segmentStatuses.map((val) {
        final text = _statusLabel(val);
        final selected = status == val;
        return HaldekiUI.rectOption(
          context: context,
          text: text,
          selected: selected,
          onTap: () => onStatusChanged(val),
        );
      }).toList(),
    );

    final businessField = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: compact ? double.infinity : 260,
        maxWidth: compact ? double.infinity : 420,
      ),
      child: loading
          ? const _ShimmerBox(height: 44)
          : (errorText != null)
              ? Text('İşletmeler yüklenemedi: $errorText',
                  style: const TextStyle(color: Colors.red))
              : DropdownButtonFormField<int?>(
                  value: selectedBusinessId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'İşletme (opsiyonel)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('Tümü')),
                    ...businesses.map((b) {
                      final id = (b['id'] as num?)?.toInt();
                      final name = (b['name'] ?? '—').toString();
                      return DropdownMenuItem<int?>(
                          value: id, child: Text(name));
                    }),
                  ],
                  onChanged: onBusinessChanged,
                ),
    );

    final content = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              dateButton,
              const SizedBox(height: 10),
              statusSegments,
              const SizedBox(height: 10),
              businessField,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              dateButton,
              const SizedBox(width: 12),
              Expanded(child: statusSegments),
              const SizedBox(width: 12),
              Flexible(child: businessField),
            ],
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: content,
    );
  }

  static String _statusLabel(String? v) {
    if (v == null) return 'Tümü';
    switch (v) {
      case 'pending':
        return 'pending';
      case 'completed':
        return 'completed';
      case 'delivered':
        return 'delivered';
      case 'cancelled':
        return 'cancelled';
      default:
        return v;
    }
  }

  static String _labelForRange(DateTimeRange? r) {
    if (r == null) return 'Tarih Aralığı';
    String f(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    return '${f(r.start)} – ${f(r.end)}';
  }
}

class DataTableView extends StatelessWidget {
  const DataTableView({
    super.key,
    required this.columns,
    required this.rows,
    required this.totalGross,
    required this.totalDealerProfit,
    this.compact = false,
    this.wide = false,
  });

  final List<String> columns;
  final List<List<String>> rows;
  final double totalGross;
  final double totalDealerProfit;
  final bool compact; // <680px
  final bool wide; // ≥1000px

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget body;

    if (compact) {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        itemBuilder: (ctx, i) {
          final cells = rows[i];
          return Card(
            elevation: 0,
            color: cs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(
                  columns.length,
                  (j) => _KVRow(
                    title: columns[j],
                    value: cells.length > j ? cells[j] : '',
                  ),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemCount: rows.length,
      );
    } else {
      // 💻 Masaüstü — tam genişliğe yay + zebra + hover
      final themed = Theme.of(context).copyWith(
        dataTableTheme: HaldekiUI.dataTableTheme(cs),
      );

      body = Theme(
        data: themed,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minW = constraints.maxWidth;

            final table = DataTable(
              columns: columns
                  .map((c) => DataColumn(
                        label: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            c,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: .2,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
              rows: List.generate(rows.length, (i) {
                final r = rows[i];
                final base =
                    i.isEven ? cs.surface : cs.primary.withOpacity(.015);
                return DataRow(
                  color: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return cs.primary.withOpacity(.06);
                    }
                    return base;
                  }),
                  cells: r
                      .map((c) => DataCell(
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                c,
                                textAlign: TextAlign.left,
                                style: const TextStyle(
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                );
              }),
            );

            return DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      // kritik satır: tablo en az görünür genişlik kadar olsun
                      constraints: BoxConstraints(minWidth: minW),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: table,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return Column(
      children: [
        Expanded(child: body),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: cs.outlineVariant)),
            color: cs.surface,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Özet — Brüt Toplam: ${_fmt(totalGross)}',
                  style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
              Text(
                'Bayi Kârı: ${_fmt(totalDealerProfit)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _fmt(double n) => '${n.toStringAsFixed(2)} ₺';
}

class _KVRow extends StatelessWidget {
  const _KVRow({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              title,
              style: TextStyle(
                color: cs.tertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({this.height = 16, this.width = double.infinity});
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
    );
  }
}
