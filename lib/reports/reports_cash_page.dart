import 'package:flutter/material.dart';
import 'package:haldeki_admin_web/screens/shell.dart';

import 'widgets/report_screen.dart';

class ReportsCashPage extends StatelessWidget {
  const ReportsCashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReportScreen(
      title: 'Kasa Raporu',
      endpoint: 'reports/cash',
      columns: ['Gün', 'Sipariş', 'Toplam', 'Bayi Kârı'],
      mapRow: _mapCashRow,
    );
  }
}

List<String> _mapCashRow(Map<String, dynamic> row) => [
      (row['day'] ?? '-').toString(),
      (row['order_count'] ?? 0).toString(),
      _fmt(row['gross_total']),
      _fmt(row['dealer_profit']),
    ];

String _fmt(dynamic n) {
  final v = (n is num) ? n.toDouble() : double.tryParse('$n') ?? 0.0;
  return '${v.toStringAsFixed(2)} ₺';
}
