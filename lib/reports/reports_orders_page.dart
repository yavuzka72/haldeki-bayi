import 'package:flutter/material.dart';
import 'widgets/report_screen.dart';

class ReportsOrdersPage extends StatelessWidget {
  const ReportsOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReportScreen(
      title: 'Sipariş Raporu',
      endpoint: 'reports/orders',
      columns: ['ID', 'Tarih', 'İşletme', 'Durum', 'Toplam', 'Bayi Kârı'],
      mapRow: _mapRow,
    );
  }
}

List<String> _mapRow(Map<String, dynamic> row) => [
      (row['id'] ?? '').toString(),
      (row['created_at'] ?? '').toString(),
      (row['business'] ?? '-').toString(),
      (row['status'] ?? '-').toString(),
      _fmt(row['gross_total']),
      _fmt(row['dealer_profit']),
    ];

String _fmt(dynamic n) {
  final v = (n is num) ? n.toDouble() : double.tryParse('$n') ?? 0.0;
  return '${v.toStringAsFixed(2)} ₺';
}
