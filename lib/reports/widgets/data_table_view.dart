import 'package:flutter/material.dart';

class DataTableView extends StatelessWidget {
  const DataTableView({
    super.key,
    required this.columns,
    required this.rows,
    required this.totalGross,
    required this.totalDealerProfit,
  });

  final List<String> columns;
  final List<List<String>> rows;
  final double totalGross;
  final double totalDealerProfit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              headingRowColor:
                  MaterialStateProperty.all(const Color(0xFFF6F7FB)),
              columns: columns
                  .map((c) => DataColumn(
                        label: Text(
                          c,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ))
                  .toList(),
              rows: rows
                  .map((r) => DataRow(
                        cells: r.map((c) => DataCell(Text(c))).toList(),
                      ))
                  .toList(),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE6E8EF))),
            color: Color(0xFFFBFCFF),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text('Özet — Brüt Toplam: ${_fmt(totalGross)}'),
              ),
              Text(
                'Bayi Kârı (Toplam × 0.15): ${_fmt(totalDealerProfit)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _fmt(double n) => '${n.toStringAsFixed(2)} ₺';
}
