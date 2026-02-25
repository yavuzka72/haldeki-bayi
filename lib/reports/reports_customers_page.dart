import 'package:flutter/material.dart';
import 'package:haldeki_admin_web/screens/shell.dart';

import 'widgets/report_screen.dart';

class ReportsCustomersPage extends StatelessWidget {
  const ReportsCustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReportScreen(
      title: 'İşletme Raporu',
      endpoint: 'reports/businesses',
      columns: ['İşletme', 'Sipariş', 'Toplam', 'Ort. Sipariş', 'Bayi Kârı'],
      mapRow: _mapRow,
    );
  }
}

List<String> _mapRow(Map<String, dynamic> row) => [
      (row['business'] ?? '-').toString(),
      (row['order_count'] ?? 0).toString(),
      _fmt(row['gross_total']),
      _fmt(row['avg_order']),
      _fmt(row['dealer_profit']),
    ];

String _fmt(dynamic n) {
  final v = (n is num) ? n.toDouble() : double.tryParse('$n') ?? 0.0;
  return '${v.toStringAsFixed(2)} ₺';
}
