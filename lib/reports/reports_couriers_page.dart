import 'package:flutter/material.dart';
import 'package:haldeki_admin_web/screens/shell.dart' show ShellScaffold;

import 'widgets/report_screen.dart';

class ReportsCouriersPage extends StatelessWidget {
  const ReportsCouriersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReportScreen(
      title: 'Kurye Raporu',
      endpoint: 'reports/couriers',
      columns: ['Kurye', 'Teslim', 'Toplam', 'Bayi Kârı'],
      mapRow: _mapRow,
    );
  }
}

List<String> _mapRow(Map<String, dynamic> row) => [
      (row['courier'] ?? '-').toString(),
      (row['delivered_orders'] ?? 0).toString(),
      _fmt(row['gross_total']),
      _fmt(row['dealer_profit']),
    ];

String _fmt(dynamic n) {
  final v = (n is num) ? n.toDouble() : double.tryParse('$n') ?? 0.0;
  return '${v.toStringAsFixed(2)} ₺';
}
