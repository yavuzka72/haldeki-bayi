import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomerReportScreen extends StatefulWidget {
  const CustomerReportScreen({super.key});

  @override
  State<CustomerReportScreen> createState() => _CustomerReportScreenState();
}

/* ----------------------------- MOCK VERİ ----------------------------- */
class CustomerRow {
  final int id;
  final String name;
  final double totalAmount;
  final double totalCommission;
  final int totalOrders;

  const CustomerRow({
    required this.id,
    required this.name,
    required this.totalAmount,
    required this.totalCommission,
    required this.totalOrders,
  });
}

final _mockRows = <CustomerRow>[
  const CustomerRow(id: 983,  name: 'BUCA BAKLAVA **',        totalAmount: 36955,  totalCommission: 3695.5, totalOrders: 323),
  const CustomerRow(id: 4,    name: 'VERONAS LUXURY **',      totalAmount: 22411,  totalCommission: 2223.9, totalOrders: 104),
  const CustomerRow(id: 1272, name: 'DENT ARBA DİsLAB',       totalAmount: 13355,  totalCommission: 1335.5, totalOrders: 61),
  const CustomerRow(id: 395,  name: 'MY NOVA DİŞ **',         totalAmount: 12083,  totalCommission: 1080.2, totalOrders: 50),
  const CustomerRow(id: 1883, name: 'TUTKU SHOP **',          totalAmount: 8151,   totalCommission: 743,    totalOrders: 36),
  const CustomerRow(id: 179,  name: 'EN YAKIN ECZANEDEN',     totalAmount: 7540,   totalCommission: 679.5,  totalOrders: 32),
  const CustomerRow(id: 869,  name: 'NOVAS KATIK DÖNER **',   totalAmount: 6897,   totalCommission: 679.5,  totalOrders: 17),
  const CustomerRow(id: 1554, name: 'KİNG PERUK **',          totalAmount: 6070,   totalCommission: 607,    totalOrders: 40),
  const CustomerRow(id: 1790, name: 'SİROGLU ÇİKOLATA **',    totalAmount: 6056,   totalCommission: 605.6,  totalOrders: 12),
];

/* ----------------------------- EKRAN ----------------------------- */
class _CustomerReportScreenState extends State<CustomerReportScreen> {
  late DateTime _from;
  late DateTime _to;
  late List<CustomerRow> _rows;

  @override
  void initState() {
    super.initState();
    _from = DateTime.now().subtract(const Duration(days: 30));
    _to = DateTime.now();
    _rows = List.of(_mockRows);
  }

  double get _kpiTotalAmount => _rows.fold(0.0, (p, e) => p + e.totalAmount);
  double get _kpiTotalCommission => _rows.fold(0.0, (p, e) => p + e.totalCommission);
  int get _kpiTotalOrders => _rows.fold(0, (p, e) => p + e.totalOrders);

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _from = d);
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _to = d);
  }

  void _applyFilter() {
    // servis çağrısı sonrası _rows güncellenir
    setState(() {
      _rows = List.of(_mockRows); // demo
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width > 900;
    final pad = EdgeInsets.only(top: 16, right: 16, bottom: 16, left: isWide ? 0 : 8);

    return Scaffold(
      backgroundColor: cs.surface,
      body: Padding(
        padding: pad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI'lar
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _KpiTile(
                 icon: Icons.account_balance_wallet_outlined,
                  label: '',
                  value: '', // değerler aşağıda set ediliyor (Expanded içinde değilse const kaldıramazsın)
                ),
              ],
            ),
            // Yukarıdaki const _KpiTile yerine aşağıyı kullan:
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KpiTile(
                  icon: Icons.payments_rounded,
                  label: 'Toplam Tutar',
                  value: _tl(_kpiTotalAmount),
                ),
                const SizedBox(width: 12),
                _KpiTile(
                  icon: Icons.percent_rounded,
                  label: 'Toplam Komisyon',
                  value: _tl(_kpiTotalCommission),
                ),
                const SizedBox(width: 12),
                _KpiTile(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Toplam Sipariş Sayısı',
                  value: '$_kpiTotalOrders adet',
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Tarih & filtre — KPI’ların ALTINDA
            Text(
              'Başlangıç Tarihi',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _DateChip(icon: Icons.event_rounded, text: _fmtDate(_from), onTap: _pickFrom),
                _DateChip(icon: Icons.check_box_rounded, text: _fmtDate(_to), onTap: _pickTo),
                OutlinedButton.icon(
                  onPressed: _applyFilter,
                  icon: const Icon(Icons.filter_alt_rounded),
                  label: const Text('Filtrele'),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Text('İşletme Raporu', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),

            // Tablo
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                child: DataTableTheme(
                  data: DataTableThemeData(
                    headingRowColor: MaterialStateProperty.all(cs.surfaceVariant),
                    headingTextStyle: const TextStyle(fontWeight: FontWeight.w700),
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 56,
                    horizontalMargin: 12,
                    columnSpacing: isWide ? 48 : 28,
                    dividerThickness: 0.6,
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('NO')),
                          DataColumn(label: Text('ADI SOYADI')),
                          DataColumn(label: Text('TOPLAM TUTAR')),
                          DataColumn(label: Text('TOPLAM KOMİSYON')),
                          DataColumn(label: Text('TOPLAM SİPARİŞ SAYISI')),
                          DataColumn(label: Text('')),
                        ],
                        rows: _rows.asMap().entries.map((e) {
                          final i = e.key;
                          final r = e.value;
                          final zebra = i.isEven
                              ? Colors.transparent
                              : cs.surfaceVariant.withOpacity(.25);
                          return DataRow(
                            color: MaterialStateProperty.all(zebra),
                            cells: [
                              DataCell(Text(r.id.toString())),
                              DataCell(
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => context.go('/customers/${r.id}'),
                                    child: Text(
                                      r.name,
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(_tl(r.totalAmount))),
                              DataCell(Text(_tl(r.totalCommission))),
                              DataCell(Text(r.totalOrders.toString())),
                              DataCell(
                                OutlinedButton(
                                  onPressed: () => context.go('/customers/${r.id}'),
                                  child: const Text('Detay'),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------- WIDGETS ----------------------------- */

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _KpiTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4EE),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: const Color(0xFF2E7D32)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _DateChip({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
            const SizedBox(width: 8),
            Text(text),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------- HELPERS ----------------------------- */

String _fmtDate(DateTime d) {
  String two(int x) => x.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year}';
}

/// TR biçimi: 12.345,67 ₺ (intl paketi olmadan basit format)
String _tl(num v) {
  final s = v.toStringAsFixed(2);
  final parts = s.split('.');
  final intPart = parts[0];
  final frac = parts[1];
  final buf = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    final r = intPart.length - i;
    buf.write(intPart[i]);
    if (r > 1 && r % 3 == 1) buf.write('.');
  }
  return '${buf.toString()},$frac ₺';
}
