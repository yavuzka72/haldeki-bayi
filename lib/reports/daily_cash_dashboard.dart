import 'package:flutter/material.dart';
import 'package:haldeki_admin_web/services/api_client.dart';
import 'package:haldeki_admin_web/models/cash_report_models.dart';
import 'package:haldeki_admin_web/theme/primary_theme.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

/// Günlük Kasa & Komisyon Özeti
/// - ApiClient().fetchCashReport(...) ile backend /api/v1/cash çağrılır.
/// - from/to tarih aralığı HER ZAMAN gönderilir.
/// - initState: Bu ay başı -> bugün aralığı.
/// - Quick filter chip’ler: Bugün, Dün, Bu Hafta, Bu Ay.

class DailyCashDashboard extends StatefulWidget {
  const DailyCashDashboard({super.key});

  @override
  State<DailyCashDashboard> createState() => _DailyCashDashboardState();
}

class _DailyCashDashboardState extends State<DailyCashDashboard>
    with SingleTickerProviderStateMixin {
  static const Color _brandGreen = kPurple;
  static const Color _brandGreenSoft = Color(0xFFEDE9FE);
  static const Color _brandInk = kText;
  static const Color _pageBg = kBg;
  static const Color _darkGreen = kPurple;
  static const Color _lightGreen = kOrange;
  final NumberFormat _moneyFmt =
      NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);

  late TabController _tabController;

  // ---------------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------------

  bool _loading = false;
  bool _payingCourier = false;
  bool _collectingCustomer = false;
  String? _errorMessage;

  // aktif filtre
  DateTime? _fromDate;
  DateTime? _toDate;
  int? _dealerId;
  String _selectedQuickFilter = 'Bu Ay';

  // Günlük kasa özeti (vw_gunluk_kasa_ozet)
  List<DailyCashDay> dailyCash = [];

  // Müşteri tahsilat detayı (vw_musteri_tahsilat_detay)
  List<CustomerCollectionRow> customerRows = [];
  List<SupplierPaymentRow> supplierRows = [];
  List<CourierPaymentRow> courierRows = [];

  // Bayi komisyonları / işletme bazlı ciro-hakediş (vw_bayi_komisyon_detay)
  List<VendorCommissionRow> vendorRows = [];
  CashSummary? cashSummary;
  List<SourceBreakdownRow> sourceBreakdown = [];

  // Toplamları hesapla
  double get totalTahsilat =>
      dailyCash.fold(0, (p, e) => p + e.musteriTahsilat);
  double get totalBayi => dailyCash.fold(0, (p, e) => p + e.bayiKomisyonu);
  double get ciroTotal => cashSummary?.orderTotal ?? totalTahsilat;
  double get komisyonTotal => cashSummary?.commissionTotal ?? totalBayi;
  double get hakedisTotal => cashSummary?.hakedisTotal ?? komisyonTotal;
  double get finalNetTotal =>
      cashSummary?.netTotal ?? (ciroTotal - hakedisTotal);
  int get businessOrderCount =>
      partnerTotalsRows.fold<int>(0, (p, e) => p + e.orderCount);
  double get businessCiroTotal =>
      partnerTotalsRows.fold<double>(0, (p, e) => p + e.ciro);
  double get ecommerceCiroTotal {
    final v = ciroTotal - businessCiroTotal;
    return v > 0 ? v : 0;
  }

  List<_DailyTotalsRow> get _dailyTotalsRows {
    final map = <String, _DailyTotalsRow>{};
    for (final d in dailyCash) {
      final day = DateTime(d.date.year, d.date.month, d.date.day);
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final existing = map[key];
      if (existing == null) {
        map[key] = _DailyTotalsRow(
          date: day,
          ciro: d.musteriTahsilat,
          hakedis: d.bayiKomisyonu,
          net: d.netKasa,
        );
      } else {
        map[key] = _DailyTotalsRow(
          date: day,
          ciro: existing.ciro + d.musteriTahsilat,
          hakedis: existing.hakedis + d.bayiKomisyonu,
          net: existing.net + d.netKasa,
        );
      }
    }
    final rows = map.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    return rows;
  }

  double get _commissionRatePercent {
    final raw = cashSummary?.commissionRate ?? 10;
    return raw <= 1 ? raw * 100 : raw;
  }

  List<_PartnerTotalsRow> get partnerTotalsRows {
    final map = <String, _PartnerTotalsRow>{};
    for (final r in vendorRows) {
      final key = '${r.partnerClientId ?? 'null'}|${r.businessName}';
      final resolvedCiro = r.ciro > 0 ? r.ciro : r.amount;
      final resolvedHakedis = r.hakedis > 0 ? r.hakedis : r.commission;
      final existing = map[key];
      if (existing == null) {
        map[key] = _PartnerTotalsRow(
          partnerClientId: r.partnerClientId,
          businessName: r.businessName,
          orderCount: r.orderCount,
          ciro: resolvedCiro,
          hakedis: resolvedHakedis,
          commissionRate: r.commissionRate,
          status: r.status,
        );
      } else {
        map[key] = _PartnerTotalsRow(
          partnerClientId: existing.partnerClientId,
          businessName: existing.businessName,
          orderCount: existing.orderCount + r.orderCount,
          ciro: existing.ciro + resolvedCiro,
          hakedis: existing.hakedis + resolvedHakedis,
          commissionRate: existing.commissionRate,
          status: existing.status,
        );
      }
    }
    final list = map.values.toList()
      ..sort((a, b) {
        final nameCmp = a.businessName
            .toLowerCase()
            .compareTo(b.businessName.toLowerCase());
        if (nameCmp != 0) return nameCmp;
        return (a.partnerClientId ?? 0).compareTo(b.partnerClientId ?? 0);
      });
    return list;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Login olan kullanıcının dealer_id'sini kullan
    final api = ApiClient();
    _dealerId = api.dealerId;

    // Default: Bu ay başı - bugün
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = DateTime(now.year, now.month, now.day);
    _selectedQuickFilter = 'Bu Ay';

    _fetchFromApi(
      from: _fromDate,
      to: _toDate,
      dealerId: _dealerId,
    );
  }

  // ---------------------------------------------------------------------------
  // API
  // ---------------------------------------------------------------------------

  Future<void> _fetchFromApi({
    DateTime? from,
    DateTime? to,
    int? dealerId,
  }) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final api = ApiClient();

      // Eğer null geldiyse, state’teki son değerleri kullan
      from ??= _fromDate ?? DateTime.now();
      to ??= _toDate ?? DateTime.now();
      dealerId ??= _dealerId;

      // state’e kaydet (filtre alanı güncel kalsın)
      _fromDate = from;
      _toDate = to;
      _dealerId = dealerId;

      final res = await api.fetchCashReport(
        from: from,
        to: to,
        dealerId: dealerId,
      );

      setState(() {
        dailyCash = res.dailyCash;
        customerRows = res.customerCollections;
        supplierRows = res.supplierPayments;
        courierRows = res.courierPayments;
        vendorRows = res.vendorCommissions;
        cashSummary = res.summary;
        sourceBreakdown = res.sourceBreakdown;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = _friendlyErrorMessage(e);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        foregroundColor: _brandInk,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Günlük Kasa & Komisyon Özeti',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth > 1400
                ? 1400.0
                : constraints.maxWidth - 32;

            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loading)
                      const LinearProgressIndicator(
                        minHeight: 3,
                        color: _brandGreen,
                      ),
                    if (_errorMessage != null && !_loading)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    _buildFinancialHeader(),
                    const SizedBox(height: 12),
                    _buildFilterBar(context),
                    const SizedBox(height: 14),
                    _buildFinancialGrid(context),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFinancialHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F0FF),
        border: Border.all(color: kLine),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: kPurple,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.analytics_outlined,
                size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Günlük Kasa & Komisyon Özeti',
              style: TextStyle(
                fontSize: 28 / 2,
                fontWeight: FontWeight.w800,
                color: kText,
              ),
            ),
          ),
          Text(
            'Rapor Tarihi: ${_toDate != null ? _fmtDate(_toDate!) : '-'}',
            style: const TextStyle(fontSize: 11, color: kMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 1200;
        if (narrow) {
          return Column(
            children: [
              _buildGridTitle('İşletme Kârlılığı'),
              const SizedBox(height: 8),
              _buildFinancialRow1(singleColumn: true),
              const SizedBox(height: 10),
              _buildGridTitle('Nakit Akışı'),
              const SizedBox(height: 8),
              _buildFinancialRow2(singleColumn: true),
              const SizedBox(height: 10),
              _buildGridTitle('Detaylar'),
              const SizedBox(height: 8),
              _buildTabs(context),
            ],
          );
        }
        return Column(
          children: [
            _buildGridTitle('İşletme Kârlılığı'),
            const SizedBox(height: 8),
            _buildFinancialRow1(singleColumn: false),
            const SizedBox(height: 10),
            _buildGridTitle('Nakit Akışı'),
            const SizedBox(height: 8),
            _buildFinancialRow2(singleColumn: false),
            const SizedBox(height: 10),
            _buildGridTitle('Detaylar'),
            const SizedBox(height: 8),
            _buildTabs(context),
          ],
        );
      },
    );
  }

  Widget _buildGridTitle(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF566771),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Divider(height: 1, color: Color(0xFFD4DDE2)),
        ),
      ],
    );
  }

  Widget _buildFinancialRow1({required bool singleColumn}) {
    final cards = [
      _financialPanel(
        title: 'İşletme Ciro',
        child: _miniTable(
          const ['Partner adı', 'Ciro', 'Hakediş'],
          _businessGroupedRows(),
        ),
      ),
      _financialPanel(
        title: 'Ciro vs Hakediş',
        child: _doubleBarChart(
          leftLabel: 'Ciro',
          leftValue: businessCiroTotal,
          rightLabel: 'Hakediş',
          rightValue: hakedisTotal,
          maxValue: (businessCiroTotal > hakedisTotal
                  ? businessCiroTotal
                  : hakedisTotal) +
              1,
          leftColor: _darkGreen,
          rightColor: _lightGreen,
        ),
      ),
      _financialPanel(
        title: 'Top Partner Ciro vs Hakediş',
        child: _doubleBarChart(
          leftLabel: 'Ciro',
          leftValue: _topPartnerCiro(),
          rightLabel: 'Hakediş',
          rightValue: _topPartnerHakedis(),
          maxValue: (_topPartnerCiro() > _topPartnerHakedis()
                  ? _topPartnerCiro()
                  : _topPartnerHakedis()) +
              1,
          leftColor: _darkGreen,
          rightColor: _lightGreen,
        ),
      ),
    ];
    if (singleColumn) {
      return Column(
        children: cards
            .map((w) =>
                Padding(padding: const EdgeInsets.only(bottom: 10), child: w))
            .toList(),
      );
    }
    return _buildPanelRow(cards);
  }

  Widget _buildFinancialRow2({required bool singleColumn}) {
    final cards = [
      _financialPanel(
        title: 'Tarih Bazlı Ciro & Hakediş',
        child: _miniTable(
          const ['Tarih', 'Ciro', 'Hakediş'],
          _dateBasedCiroHakedisRows(),
        ),
      ),
      _financialPanel(
        title: 'Gün Gün Ciro ve Hakediş',
        child: _dailyGroupedBarsChart(),
      ),
      _financialPanel(
        title: 'Toplam Ciro vs Hakediş',
        child: _doubleBarChart(
          leftLabel: 'Ciro',
          leftValue: ciroTotal,
          rightLabel: 'Hakediş',
          rightValue: hakedisTotal,
          maxValue: (ciroTotal > hakedisTotal ? ciroTotal : hakedisTotal) + 1,
          leftColor: _darkGreen,
          rightColor: _lightGreen,
        ),
      ),
    ];
    if (singleColumn) {
      return Column(
        children: cards
            .map((w) =>
                Padding(padding: const EdgeInsets.only(bottom: 10), child: w))
            .toList(),
      );
    }
    return _buildPanelRow(cards);
  }

  Widget _buildPanelRow(List<Widget> cards) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cards.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == cards.length - 1 ? 0 : 10),
              child: cards[i],
            ),
          ),
      ],
    );
  }

  Widget _financialPanel({required String title, required Widget child}) {
    return Container(
      height: 232,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD8E1E6)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF2D3A42),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _miniTable(List<String> headers, List<List<String>> rows) {
    final displayRows = rows.isEmpty
        ? const [
            ['Veri bulunamadı', '-', '-']
          ]
        : rows;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: const Color(0xFFF2F5F7),
          child: Row(
            children: headers
                .map((h) => Expanded(
                      child: Text(
                        h,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF6B7B85),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: Column(
                children: displayRows.map(
                  (r) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE8EDF0)),
                      ),
                    ),
                    child: Row(
                      children: r.asMap().entries.map((entry) {
                        final colIndex = entry.key;
                        final c = entry.value;
                        return Expanded(
                          child: Text(
                            c,
                            maxLines: colIndex == 0 ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF2B3A43),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _doubleBarChart({
    required String leftLabel,
    required double leftValue,
    required String rightLabel,
    required double rightValue,
    required double maxValue,
    Color leftColor = _darkGreen,
    Color rightColor = _lightGreen,
    bool showNegativeBase = false,
  }) {
    final leftRatio = (leftValue / maxValue).clamp(0.02, 1.0);
    final rightRatio = (rightValue / maxValue).clamp(0.02, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showNegativeBase)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Divider(height: 1, color: Color(0xFFDDE5EA)),
          ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _chartBar(
                  label: leftLabel,
                  value: leftValue,
                  ratio: leftRatio,
                  color: leftColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _chartBar(
                  label: rightLabel,
                  value: rightValue,
                  ratio: rightRatio,
                  color: rightColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chartBar({
    required String label,
    required double value,
    required double ratio,
    required Color color,
  }) {
    final barHeight = 130 * ratio;
    final placeInside = barHeight > 28;
    final isLightBar = color.computeLuminance() > 0.45;
    final valueColor = placeInside
        ? (isLightBar ? const Color(0xFF1F2A25) : Colors.white)
        : const Color(0xFF39534A);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: 146,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                height: barHeight,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Positioned(
                top: placeInside
                    ? (146 - barHeight + 4)
                    : (146 - barHeight - 14),
                child: Text(
                  _fmtCurrency(value),
                  style: TextStyle(
                    fontSize: 10,
                    color: valueColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF5F707A))),
      ],
    );
  }

  Widget _dailyLineChart() {
    final rows = _dailyTotalsRows;
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'Çizgi grafik için veri yok',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B7B85)),
        ),
      );
    }

    final maxValue = rows
            .map((e) => e.ciro > e.hakedis ? e.ciro : e.hakedis)
            .fold<double>(0, (p, e) => e > p ? e : p) +
        1;

    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            painter: _DualLineChartPainter(
              rows: rows,
              maxValue: maxValue,
              ciroColor: _darkGreen,
              hakedisColor: _lightGreen,
            ),
            child: Container(),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 14,
          children: const [
            _LegendDot(color: _darkGreen, label: 'Ciro'),
            _LegendDot(color: _lightGreen, label: 'Hakediş'),
          ],
        ),
      ],
    );
  }

  Widget _dailyGroupedBarsChart() {
    final rows = _dailyTotalsRows;
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'Çubuk grafik için veri yok',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B7B85)),
        ),
      );
    }

    final maxValue = rows
            .map((e) => e.ciro > e.hakedis ? e.ciro : e.hakedis)
            .fold<double>(0, (p, e) => e > p ? e : p) +
        1;

    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            painter: _DailyGroupedBarPainter(
              rows: rows,
              maxValue: maxValue,
              ciroColor: _darkGreen,
              hakedisColor: _lightGreen,
            ),
            child: Container(),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 14,
          children: const [
            _LegendDot(color: _darkGreen, label: 'Ciro'),
            _LegendDot(color: _lightGreen, label: 'Hakediş'),
          ],
        ),
      ],
    );
  }

  double _sumLastMonth() {
    final ref = _toDate ?? DateTime.now();
    final lastMonthStart = DateTime(ref.year, ref.month - 1, 1);
    final thisMonthStart = DateTime(ref.year, ref.month, 1);
    final sum = _dailyTotalsRows
        .where((d) =>
            d.date.isAfter(lastMonthStart.subtract(const Duration(days: 1))) &&
            d.date.isBefore(thisMonthStart))
        .fold<double>(0, (p, e) => p + e.ciro);
    return sum > 0 ? sum : ciroTotal;
  }

  List<List<String>> _businessGroupedRows() {
    final rows = partnerTotalsRows;
    if (rows.isEmpty) return const [];
    return rows
        .map(
          (r) => [
            r.businessName.trim().isEmpty
                ? 'partner_client_id: ${r.partnerClientId ?? '-'}'
                : r.businessName,
            _fmtCurrency(r.ciro),
            _fmtCurrency(r.hakedis),
          ],
        )
        .toList();
  }

  List<List<String>> _dateBasedCiroHakedisRows() {
    final rows = [..._dailyTotalsRows]
      ..sort((a, b) => b.date.compareTo(a.date));
    if (rows.isEmpty) return const [];
    return rows
        .map(
          (d) => [
            _fmtDate(d.date),
            _fmtCurrency(d.ciro),
            _fmtCurrency(d.hakedis),
          ],
        )
        .toList();
  }

  double _latestDailyCiro() {
    final rows = [..._dailyTotalsRows]
      ..sort((a, b) => b.date.compareTo(a.date));
    if (rows.isEmpty) return 0;
    return rows.first.ciro;
  }

  double _latestDailyHakedis() {
    final rows = [..._dailyTotalsRows]
      ..sort((a, b) => b.date.compareTo(a.date));
    if (rows.isEmpty) return 0;
    return rows.first.hakedis;
  }

  double _topPartnerCiro() {
    if (partnerTotalsRows.isEmpty) return 0;
    return partnerTotalsRows
        .map((e) => e.ciro)
        .fold<double>(0, (p, e) => e > p ? e : p);
  }

  double _topPartnerHakedis() {
    if (partnerTotalsRows.isEmpty) return 0;
    final maxCiro = _topPartnerCiro();
    final top = partnerTotalsRows.firstWhere(
      (e) => e.ciro == maxCiro,
      orElse: () => partnerTotalsRows.first,
    );
    return top.hakedis;
  }

  Widget _buildHeroHeader() {
    final todayLabel = _toDate != null ? _fmtDate(_toDate!) : '-';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF6F1), Color(0xFFF8FCFA), Color(0xFFEFF7F3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFD5E7DF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14185D49),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Wrap(
        runSpacing: 10,
        spacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _brandGreen,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x220F5A45),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child:
                const Icon(Icons.account_balance_wallet, color: Colors.white),
          ),
          const Text(
            'Nakit akışınızı günlük olarak izleyin',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _brandInk,
            ),
          ),
          Text(
            'Son güncelleme: $todayLabel',
            style: const TextStyle(
              color: Color(0xFF557066),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (cashSummary != null)
            Text(
              'Komisyon oranı: %${_commissionRatePercent.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Color(0xFF557066),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _brandInk,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 26,
          height: 2,
          color: const Color(0xFFBFD3CB),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 1) FİLTRE BAR
  // ---------------------------------------------------------------------------

  Widget _buildFilterBar(BuildContext context) {
    String dateRangeLabel;
    if (_fromDate != null && _toDate != null) {
      if (_fromDate == _toDate) {
        dateRangeLabel = _fmtDate(_fromDate!); // tek gün ise sadece tarihi yaz
      } else {
        dateRangeLabel = '${_fmtDate(_fromDate!)} - ${_fmtDate(_toDate!)}';
      }
    } else {
      dateRangeLabel = 'Seçili aralık';
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FCFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE9E3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(Icons.tune, size: 18, color: _brandGreen),
            const Text(
              'Filtreler',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _brandInk,
              ),
            ),
            const SizedBox(width: 12),
            _quickFilterChip('Bugün'),
            _quickFilterChip('Dün'),
            _quickFilterChip('Bu Hafta'),
            _quickFilterChip('Bu Ay'),
            const SizedBox(width: 10),
            Text(
              dateRangeLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: _brandGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickFilterChip(String label) {
    final isSelected = _selectedQuickFilter == label;

    return FilterChip(
      selected: isSelected,
      backgroundColor: const Color(0xFFF3F8F5),
      selectedColor: _brandGreenSoft,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      side: BorderSide(
        color: isSelected ? _brandGreen : const Color(0xFFD5E2DC),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (_) {
        final now = DateTime.now();
        DateTime from;
        DateTime to;

        if (label == 'Bugün') {
          from = DateTime(now.year, now.month, now.day);
          to = from;
        } else if (label == 'Dün') {
          final d = now.subtract(const Duration(days: 1));
          from = DateTime(d.year, d.month, d.day);
          to = from;
        } else if (label == 'Bu Hafta') {
          final weekStart =
              now.subtract(Duration(days: now.weekday - 1)); // Pazartesi
          from = DateTime(weekStart.year, weekStart.month, weekStart.day);
          to = DateTime(now.year, now.month, now.day);
        } else {
          // Bu Ay
          from = DateTime(now.year, now.month, 1);
          to = DateTime(now.year, now.month, now.day);
        }

        setState(() {
          _selectedQuickFilter = label;
        });

        _fetchFromApi(
          from: from,
          to: to,
          dealerId: _dealerId,
        );
      },
      showCheckmark: false,
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? _brandGreen : const Color(0xFF4D665D),
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2) ÖZET KARTLAR
  // ---------------------------------------------------------------------------

  Widget _buildSummaryRow(BuildContext context) {
    final cards = [
      _SummaryCardConfig(
        title: 'Sipariş Toplamı (Ciro)',
        value: ciroTotal,
        subtitle: 'Orders tablosu toplam sipariş cirosu',
        icon: Icons.shopping_bag_outlined,
        accent: kPurple,
      ),
      _SummaryCardConfig(
        title: 'Komisyon (%${_commissionRatePercent.toStringAsFixed(0)})',
        value: komisyonTotal,
        subtitle: 'İşletme bazlı komisyon toplamı',
        icon: Icons.account_tree_outlined,
        accent: kOrange,
      ),
      _SummaryCardConfig(
        title: 'Hakediş Toplam',
        value: hakedisTotal,
        subtitle: 'Partner işletmelerden toplam hakediş',
        icon: Icons.paid_outlined,
        accent: kPurple2,
      ),
      _SummaryCardConfig(
        title: 'Net Kasa',
        value: finalNetTotal,
        subtitle: 'Sipariş toplamı - hakediş',
        highlight: true,
        icon: Icons.account_balance_wallet_outlined,
        accent: kOrange,
      ),
    ];

    return LayoutBuilder(builder: (context, c) {
      final isNarrow = c.maxWidth < 1000;
      if (isNarrow) {
        return Column(
          children: cards
              .map(
                (cfg) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SummaryCard(cfg: cfg),
                ),
              )
              .toList(),
        );
      }
      return Row(
        children: cards
            .map(
              (cfg) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _SummaryCard(cfg: cfg),
                ),
              ),
            )
            .toList(),
      );
    });
  }

  Widget _buildSourceBreakdownCard() {
    final partners = partnerTotalsRows;
    final fallbackBusiness = businessCiroTotal > 0
        ? businessCiroTotal
        : vendorRows.fold<double>(
            0,
            (p, e) => p + (e.ciro > 0 ? e.ciro : e.amount),
          );
    final double businessTotal = (cashSummary?.businessTotal ?? 0) > 0
        ? cashSummary!.businessTotal
        : fallbackBusiness;
    final double ecommerceTotal = (cashSummary?.ecommerceTotal ?? 0) > 0
        ? cashSummary!.ecommerceTotal
        : ((ciroTotal - businessTotal) > 0 ? (ciroTotal - businessTotal) : 0.0);
    final total = ecommerceTotal + businessTotal;
    final ecommercePct = total == 0 ? 0.0 : (ecommerceTotal / total) * 100;
    final businessPct = total == 0 ? 0.0 : (businessTotal / total) * 100;

    return _buildSectionCard(
      title: 'Sipariş Kaynağı Dağılımı',
      subtitle: 'E-ticaret ve işletme sipariş katkısı',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _sourceRow(
              'E-Ticaret',
              0,
              ecommerceTotal,
              ecommercePct,
            ),
          ),
          _sourceRow(
            'İşletme (Toplam)',
            businessOrderCount,
            businessTotal,
            businessPct,
          ),
          if (partners.isNotEmpty) const SizedBox(height: 10),
          ...partners.map((p) {
            final partnerPct =
                businessTotal == 0 ? 0.0 : (p.ciro / businessTotal) * 100;
            final label = p.businessName.trim().isEmpty
                ? 'partner_client_id: ${p.partnerClientId}'
                : 'partner_client_id: ${p.partnerClientId} - ${p.businessName}';
            return Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 8),
              child: _sourceRow(
                label,
                p.orderCount,
                p.ciro,
                partnerPct,
                compact: true,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _sourceRow(
    String source,
    int orderCount,
    double total,
    double pct, {
    bool compact = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: compact ? 7 : 9,
            ),
            decoration: BoxDecoration(
              color:
                  compact ? const Color(0xFFF7FBF9) : const Color(0xFFF3F8F6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE1ECE7)),
            ),
            child: Text(
              source,
              style: TextStyle(
                fontWeight: compact ? FontWeight.w600 : FontWeight.w700,
                fontSize: compact ? 12.5 : 14,
                color: _brandInk,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: compact ? 86 : 94,
          child: Text(
            orderCount > 0 ? '$orderCount sipariş' : '-',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: const Color(0xFF6A7F76),
              fontSize: compact ? 11 : 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (pct > 0)
          SizedBox(
            width: compact ? 60 : 64,
            child: Text(
              '${pct.toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: const Color(0xFF6A7F76),
                fontSize: compact ? 11 : 12,
              ),
            ),
          ),
        const SizedBox(width: 8),
        SizedBox(
          width: compact ? 130 : 140,
          child: Text(
            _fmtCurrency(total),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: compact ? FontWeight.w700 : FontWeight.w800,
              fontSize: compact ? 13 : 15,
              color: _brandGreen,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3) GRAFİK BENZERİ ORTA ALAN
  // ---------------------------------------------------------------------------

  Widget _buildChartsRow(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final isNarrow = c.maxWidth < 1000;
      if (isNarrow) {
        return Column(
          children: [
            _buildDailyNetBarChart(),
            const SizedBox(height: 12),
            _buildExpensePieLike(),
          ],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildDailyNetBarChart()),
          const SizedBox(width: 12),
          SizedBox(width: 320, child: _buildExpensePieLike()),
        ],
      );
    });
  }

  /// Günlük net kasa bar grafiği (API verisiyle)
  Widget _buildDailyNetBarChart() {
    final rows = _dailyTotalsRows;
    if (rows.isEmpty) {
      return _buildSectionCard(
        title: 'Günlük Net Kasa',
        subtitle: 'Grafik için görüntülenecek veri bulunamadı',
        child: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Seçili tarihlerde kayıt bulunmuyor.'),
        ),
      );
    }

    final maxNet =
        rows.map((e) => e.net.abs()).fold<double>(0, (p, e) => e > p ? e : p) +
            1; // 0’a bölünmesin

    return _buildSectionCard(
      title: 'Günlük Net Kasa',
      subtitle: 'Her gün için tahsilat - (tedarikçi + kurye + bayi)',
      child: Column(
        children: rows.map((d) {
          final ratio = (d.net.abs() / maxNet).clamp(0.05, 1.0);
          final isNegative = d.net < 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    _fmtDate(d.date),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4D665D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F5F3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: ratio,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color:
                                isNegative ? Colors.red.shade400 : _brandGreen,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              _fmtCurrency(d.net),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Sipariş bazlı dağılım (Tahsilat / Komisyon / Hakediş)
  Widget _buildExpensePieLike() {
    final totalExpense = totalTahsilat + komisyonTotal + hakedisTotal;
    double pct(double v) => totalExpense == 0 ? 0 : ((v / totalExpense) * 100);

    return _buildSectionCard(
      title: 'Sipariş Bazlı Dağılım',
      subtitle: 'Tahsilat, komisyon ve hakediş kırılımı',
      child: Column(
        children: [
          _expenseRow(
            'Müşteri Tahsilatı',
            totalTahsilat,
            pct(totalTahsilat),
            const Color(0xFF0F5A45),
          ),
          const SizedBox(height: 6),
          _expenseRow(
            'Bayi Komisyonu',
            komisyonTotal,
            pct(komisyonTotal),
            const Color(0xFF2E7D64),
          ),
          const SizedBox(height: 6),
          _expenseRow(
            'Hakediş',
            hakedisTotal,
            pct(hakedisTotal),
            const Color(0xFF5FA790),
          ),
          const Divider(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Toplam',
                style: TextStyle(fontWeight: FontWeight.w600, color: _brandInk),
              ),
              Text(
                _fmtCurrency(totalExpense),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _brandGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _expenseRow(String label, double value, double pct, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _brandInk,
                ),
              ),
            ),
            Text(
              '${pct.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6A7F76)),
            ),
            const SizedBox(width: 8),
            Text(
              _fmtCurrency(value),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: _brandInk,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (pct / 100).clamp(0, 1),
            minHeight: 6,
            backgroundColor: const Color(0xFFE7EFEB),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4) TABLAR (SEKMELER)
  // ---------------------------------------------------------------------------

  Widget _buildTabs(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE5E1)),
      ),
      child: SizedBox(
        height: 540,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2EE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD5E5DD)),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                labelColor: _brandGreen,
                unselectedLabelColor: const Color(0xFF6A7F76),
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x120F5A45),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                tabs: const [
                  Tab(text: 'Müşteri Tahsilatları'),
                  Tab(text: 'Kurye Ödemeleri'),
                  Tab(text: 'İşletme Ciro ve Hakediş'),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE8EFEC)),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCustomerTable(),
                  _buildCourierTable(),
                  _buildVendorTable(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerTable() {
    final total = customerRows.fold<double>(0, (p, e) => p + e.collected);

    return Column(
      children: [
        _tableHeaderSummary('Toplam Tahsilat', total),
        const Divider(height: 1),
        Expanded(
          child: _buildDataTableContainer(
            child: DataTable(
              headingRowHeight: 44,
              dataRowMinHeight: 54,
              dataRowMaxHeight: 54,
              columnSpacing: 26,
              horizontalMargin: 16,
              dividerThickness: 0.6,
              border: const TableBorder(
                horizontalInside:
                    BorderSide(color: Color(0xFFE8EFEC), width: 0.9),
              ),
              headingRowColor: const WidgetStatePropertyAll(Color(0xFFEAF2EE)),
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _brandInk,
                fontSize: 13,
              ),
              dataTextStyle: const TextStyle(
                color: Color(0xFF34443F),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              columns: const [
                DataColumn(label: Text('Tarih')),
                DataColumn(label: Text('Teslimat Kodu')),
                DataColumn(label: Text('Müşteri')),
                DataColumn(label: Text('Sipariş Tutarı')),
                DataColumn(label: Text('Tahsil Edilen')),
                DataColumn(label: Text('Ödeme Durumu')),
                DataColumn(label: Text('Sipariş Durumu')),
                DataColumn(label: Text('İşlem')),
              ],
              rows: customerRows.asMap().entries.map((entry) {
                final i = entry.key;
                final r = entry.value;
                final rowBg = i.isEven ? Colors.white : const Color(0xFFFAFCFB);
                final orderId =
                    r.deliveryOrderId > 0 ? r.deliveryOrderId : r.sourceOrderId;
                final isPaid = _isPaidStatus(r.paymentStatus);
                final canCollect = orderId > 0 && !isPaid;
                return DataRow(
                  color: WidgetStatePropertyAll(rowBg),
                  cells: [
                    DataCell(Text(
                      _fmtDate(r.date),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    )),
                    DataCell(Text(r.code)),
                    DataCell(Text(r.customerName)),
                    DataCell(Text(_fmtCurrency(r.amount))),
                    DataCell(Text(_fmtCurrency(r.collected))),
                    DataCell(_statusPill(r.paymentStatus)),
                    DataCell(_statusPill(r.orderStatus)),
                    DataCell(
                      SizedBox(
                        height: 34,
                        child: ElevatedButton.icon(
                          onPressed: (!canCollect || _collectingCustomer)
                              ? null
                              : () => _collectSingleCustomerPayment(r),
                          icon: (_collectingCustomer && canCollect)
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  isPaid
                                      ? Icons.check_circle
                                      : Icons.point_of_sale,
                                  size: 16,
                                ),
                          label:
                              Text(isPaid ? 'Tahsil Edildi' : 'Tahsilat Yap'),
                          style: _paymentActionStyle(isPaid: isPaid),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _collectSingleCustomerPayment(CustomerCollectionRow row) async {
    final email = _resolveDealerEmail();
    if (email == null || email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tahsilat için bayi e-posta bilgisi bulunamadı.'),
        ),
      );
      return;
    }

    final orderId =
        row.deliveryOrderId > 0 ? row.deliveryOrderId : row.sourceOrderId;
    if (orderId <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tahsilat için geçerli sipariş ID bulunamadı.'),
        ),
      );
      return;
    }

    final ok = await _confirmAction(
      title: 'Tahsilat Yap',
      message: '${row.code} için müşteri tahsilatı yapılsın mı?\n\n'
          'Tahsilat: ${_fmtCurrency(row.amount)}',
    );
    if (!ok) return;

    setState(() => _collectingCustomer = true);
    try {
      final api = ApiClient();
      final resp = await api.bulkMarkCollected(
        email: email,
        orderIds: [orderId],
      );
      if (resp['success'] != true && resp['ok'] != true) {
        throw Exception(resp['message'] ?? 'Tahsilat işlemi başarısız.');
      }

      if (!mounted) return;
      _markCustomerRowPaid(orderId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${row.code} için tahsilat tamamlandı.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tahsilat hatası: ${_friendlyErrorMessage(e)}')),
      );
    } finally {
      if (mounted) setState(() => _collectingCustomer = false);
    }
  }

  Widget _buildVendorTable() {
    final rows = partnerTotalsRows;
    final totalCiro = rows.fold<double>(0, (p, e) => p + e.ciro);
    final totalHakedis = rows.fold<double>(0, (p, e) => p + e.hakedis);
    final netTotal = totalCiro - totalHakedis;

    return Column(
      children: [
        _tableHeaderSummary(
          'Partner Net Toplamı (${rows.length} işletme)',
          netTotal,
        ),
        const Divider(height: 1),
        Expanded(
          child: _buildDataTableContainer(
            child: DataTable(
              headingRowHeight: 44,
              dataRowMinHeight: 54,
              dataRowMaxHeight: 54,
              columnSpacing: 26,
              horizontalMargin: 16,
              dividerThickness: 0.6,
              border: const TableBorder(
                horizontalInside:
                    BorderSide(color: Color(0xFFE8EFEC), width: 0.9),
              ),
              headingRowColor: const WidgetStatePropertyAll(Color(0xFFEAF2EE)),
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _brandInk,
                fontSize: 13,
              ),
              dataTextStyle: const TextStyle(
                color: Color(0xFF34443F),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              columns: const [
                DataColumn(label: Text('Partner ID')),
                DataColumn(label: Text('İşletme')),
                DataColumn(label: Text('Sipariş Adedi')),
                DataColumn(label: Text('Komisyon %')),
                DataColumn(label: Text('Ciro')),
                DataColumn(label: Text('Hakediş')),
                DataColumn(label: Text('Durum')),
              ],
              rows: rows.asMap().entries.map((entry) {
                final i = entry.key;
                final r = entry.value;
                final rowBg = i.isEven ? Colors.white : const Color(0xFFFAFCFB);
                return DataRow(
                  color: WidgetStatePropertyAll(rowBg),
                  cells: [
                    DataCell(Text(
                      r.partnerClientId?.toString() ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    )),
                    DataCell(
                        Text(r.businessName.isEmpty ? '-' : r.businessName)),
                    DataCell(Text(r.orderCount.toString())),
                    DataCell(Text(r.commissionRate.toStringAsFixed(0))),
                    DataCell(Text(_fmtCurrency(r.ciro))),
                    DataCell(Text(_fmtCurrency(r.hakedis))),
                    DataCell(_statusPill(r.status)),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourierTable() {
    final totalCourier =
        courierRows.fold<double>(0, (p, e) => p + e.courierPayment);

    return Column(
      children: [
        _tableHeaderSummary('Toplam Kurye Ödeme', totalCourier),
        const Divider(height: 1),
        Expanded(
          child: _buildDataTableContainer(
            child: DataTable(
              headingRowHeight: 44,
              dataRowMinHeight: 54,
              dataRowMaxHeight: 62,
              columnSpacing: 20,
              horizontalMargin: 16,
              dividerThickness: 0.6,
              border: const TableBorder(
                horizontalInside:
                    BorderSide(color: Color(0xFFE8EFEC), width: 0.9),
              ),
              headingRowColor: const WidgetStatePropertyAll(Color(0xFFEAF2EE)),
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _brandInk,
                fontSize: 13,
              ),
              dataTextStyle: const TextStyle(
                color: Color(0xFF34443F),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              columns: const [
                DataColumn(label: Text('Tarih')),
                DataColumn(label: Text('Teslimat Kodu')),
                DataColumn(label: Text('Kurye')),
                DataColumn(label: Text('Sipariş Tutarı')),
                DataColumn(label: Text('Kurye Ücreti')),
                DataColumn(label: Text('Ödeme Durumu')),
                DataColumn(label: Text('Teslimat Durumu')),
                DataColumn(label: Text('İşlem')),
              ],
              rows: courierRows.asMap().entries.map((entry) {
                final i = entry.key;
                final r = entry.value;
                final rowBg = i.isEven ? Colors.white : const Color(0xFFFAFCFB);
                final isPaid = _isPaidStatus(r.paymentStatus);
                final canPay = r.deliveryOrderId > 0 && !isPaid;
                return DataRow(
                  color: WidgetStatePropertyAll(rowBg),
                  cells: [
                    DataCell(Text(
                      _fmtDate(r.date),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    )),
                    DataCell(Text(r.code)),
                    DataCell(Text(r.courierName.isEmpty ? '-' : r.courierName)),
                    DataCell(Text(_fmtCurrency(r.amount))),
                    DataCell(Text(_fmtCurrency(r.courierPayment))),
                    DataCell(_statusPill(r.paymentStatus)),
                    DataCell(_statusPill(r.status)),
                    DataCell(
                      SizedBox(
                        height: 34,
                        child: ElevatedButton.icon(
                          onPressed: (!canPay || _payingCourier)
                              ? null
                              : () => _paySingleCourierPayment(r),
                          icon: (_payingCourier && canPay)
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  isPaid
                                      ? Icons.check_circle
                                      : Icons.payments_outlined,
                                  size: 16,
                                ),
                          label:
                              Text(isPaid ? 'Kurye Ödendi' : 'Kurye Ödeme Yap'),
                          style: _paymentActionStyle(isPaid: isPaid),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _paySingleCourierPayment(CourierPaymentRow row) async {
    final email = _resolveDealerEmail();
    if (email == null || email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kurye ödeme için bayi e-posta bilgisi bulunamadı.'),
        ),
      );
      return;
    }

    final ok = await _confirmAction(
      title: 'Kurye Ödeme Yap',
      message:
          '${row.code} için ${row.courierName.isEmpty ? 'kurye' : row.courierName} ödemesi yapılsın mı?\n\n'
          'Ödeme: ${_fmtCurrency(row.courierPayment)}',
    );
    if (!ok) return;

    setState(() => _payingCourier = true);
    try {
      final api = ApiClient();
      final resp = await api.bulkPayCourier(
        email: email,
        orderIds: [row.deliveryOrderId],
      );
      if (resp['success'] != true && resp['ok'] != true) {
        throw Exception(resp['message'] ?? 'Kurye ödeme işlemi başarısız.');
      }

      if (!mounted) return;
      _markCourierRowPaid(row.deliveryOrderId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${row.code} için kurye ödemesi tamamlandı.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Kurye ödeme hatası: ${_friendlyErrorMessage(e)}')),
      );
    } finally {
      if (mounted) setState(() => _payingCourier = false);
    }
  }

  String? _resolveDealerEmail() {
    final api = ApiClient();
    final e1 = (api.currentEmail ?? '').trim();
    final e2 = (api.session?.email ?? '').trim();
    final e3 = (api.currentProfile?.email ?? '').trim();
    if (e1.isNotEmpty) return e1;
    if (e2.isNotEmpty) return e2;
    if (e3.isNotEmpty) return e3;
    return null;
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Widget _tableHeaderSummary(String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _brandInk,
              )),
          Text(
            _fmtCurrency(value),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: _brandGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE5E1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F5A45),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _brandInk,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6A7F76),
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildDataTableContainer({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDCE8E2)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F5A45),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statusPill(String value) {
    final normalized = value.trim().toLowerCase();
    final isGood = normalized == 'completed' ||
        normalized == 'delivered' ||
        normalized == 'paid';
    final isWarn = normalized == 'pending' || normalized == 'create';
    final Color bg = isGood
        ? const Color(0xFFE3F3ED)
        : isWarn
            ? const Color(0xFFFFF4DF)
            : const Color(0xFFF1F3F2);
    final Color fg = isGood
        ? const Color(0xFF0F5A45)
        : isWarn
            ? const Color(0xFF996300)
            : const Color(0xFF55625E);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value.isEmpty ? '-' : _trStatus(value),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  String _fmtCurrency(double v) {
    return _moneyFmt.format(v);
  }

  String _fmtDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year}';
  }

  String _trStatus(String value) {
    final v = value.trim().toLowerCase();
    switch (v) {
      case 'pending':
        return 'beklemede';
      case 'create':
        return 'oluşturuldu';
      case 'courier':
        return 'kuryede';
      case 'paid':
        return 'ödendi';
      case 'completed':
        return 'tamamlandı';
      case 'delivered':
        return 'teslim edildi';
      case 'cancelled':
        return 'iptal';
      default:
        return value;
    }
  }

  bool _isPaidStatus(String value) {
    final v = value.trim().toLowerCase();
    return v == 'paid' ||
        v == 'odendi' ||
        v == 'ödendi' ||
        v == 'completed' ||
        v == 'charged' ||
        v == 'collected' ||
        v == 'success' ||
        v == 'true' ||
        v == '1' ||
        v == 'loan_charged' ||
        v == 'tahsil_edildi' ||
        v == 'tahsil edildi';
  }

  void _markCustomerRowPaid(int orderId) {
    setState(() {
      customerRows = customerRows.map((r) {
        final id = r.deliveryOrderId > 0 ? r.deliveryOrderId : r.sourceOrderId;
        if (id != orderId) return r;
        return CustomerCollectionRow(
          date: r.date,
          dealerId: r.dealerId,
          dealerName: r.dealerName,
          deliveryOrderId: r.deliveryOrderId,
          sourceOrderId: r.sourceOrderId,
          code: r.code,
          customerName: r.customerName,
          amount: r.amount,
          collected: r.amount > 0 ? r.amount : r.collected,
          paymentStatus: 'paid',
          orderStatus: r.orderStatus,
        );
      }).toList();
    });
  }

  void _markCourierRowPaid(int deliveryOrderId) {
    setState(() {
      courierRows = courierRows.map((r) {
        if (r.deliveryOrderId != deliveryOrderId) return r;
        return CourierPaymentRow(
          date: r.date,
          dealerId: r.dealerId,
          dealerName: r.dealerName,
          deliveryOrderId: r.deliveryOrderId,
          sourceOrderId: r.sourceOrderId,
          code: r.code,
          courierName: r.courierName,
          amount: r.amount,
          courierPayment: r.courierPayment,
          status: r.status,
          paymentStatus: 'paid',
        );
      }).toList();
    });
  }

  ButtonStyle _paymentActionStyle({required bool isPaid}) {
    final bg = isPaid ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    return ElevatedButton.styleFrom(
      backgroundColor: bg,
      disabledBackgroundColor: bg,
      foregroundColor: Colors.white,
      disabledForegroundColor: Colors.white,
      textStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
    );
  }

  String _friendlyErrorMessage(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();

    if (lower.contains('sqlstate') ||
        lower.contains('only_full_group_by') ||
        lower.contains('syntax error or access violation') ||
        lower.contains('http 500')) {
      return 'Kasa raporu şu anda alınamıyor. Lütfen kısa süre sonra tekrar deneyin.';
    }

    // Dio/Laravel hata metnindeki teknik trace'i ayıkla.
    final messageMatch =
        RegExp(r'message:\s*([^,\n]+)', caseSensitive: false).firstMatch(raw);
    if (messageMatch != null) {
      final msg = messageMatch.group(1)?.trim();
      if (msg != null && msg.isNotEmpty) return msg;
    }

    // "Exception: xxx" kalıbında sadece mesajı göster.
    final cleaned = raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    if (cleaned.isNotEmpty) {
      final firstLine = cleaned.split('\n').first.trim();
      if (firstLine.isNotEmpty) return firstLine;
    }

    return 'Kasa raporu alınamadı. Lütfen tekrar deneyin.';
  }
}

// ---------------------------------------------------------------------------
// Özet kart struct'ı
// ---------------------------------------------------------------------------

class _SummaryCardConfig {
  final String title;
  final double value;
  final String subtitle;
  final bool highlight;
  final IconData icon;
  final Color accent;

  _SummaryCardConfig({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.highlight = false,
  });
}

class _PartnerTotalsRow {
  final int? partnerClientId;
  final String businessName;
  final int orderCount;
  final double ciro;
  final double hakedis;
  final double commissionRate;
  final String status;

  _PartnerTotalsRow({
    required this.partnerClientId,
    required this.businessName,
    required this.orderCount,
    required this.ciro,
    required this.hakedis,
    required this.commissionRate,
    required this.status,
  });
}

class _DailyTotalsRow {
  final DateTime date;
  final double ciro;
  final double hakedis;
  final double net;

  _DailyTotalsRow({
    required this.date,
    required this.ciro,
    required this.hakedis,
    required this.net,
  });
}

class _SummaryCard extends StatelessWidget {
  static const Color _brandGreen = kPurple;
  static const Color _brandInk = kText;

  final _SummaryCardConfig cfg;

  const _SummaryCard({required this.cfg, super.key});

  @override
  Widget build(BuildContext context) {
    final isPositive = cfg.highlight && cfg.value >= 0;
    final valueColor = cfg.highlight
        ? (isPositive ? _brandGreen : Colors.red.shade700)
        : _brandInk;
    final trendIcon = cfg.value >= 0 ? Icons.north : Icons.south;
    final trendColor = cfg.value >= 0 ? kOrange : Colors.red;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E7E3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F5A45),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    cfg.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4F5E58),
                    ),
                  ),
                ),
                Icon(
                  cfg.icon,
                  size: 14,
                  color: cfg.accent,
                ),
                const SizedBox(width: 6),
                Icon(trendIcon, size: 16, color: trendColor),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              NumberFormat.currency(
                locale: 'tr_TR',
                symbol: '₺',
                decimalDigits: 2,
              ).format(cfg.value),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              cfg.subtitle,
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFF6A7F76),
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF556671)),
        ),
      ],
    );
  }
}

class _DualLineChartPainter extends CustomPainter {
  final List<_DailyTotalsRow> rows;
  final double maxValue;
  final Color ciroColor;
  final Color hakedisColor;

  _DualLineChartPainter({
    required this.rows,
    required this.maxValue,
    required this.ciroColor,
    required this.hakedisColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rows.length < 2) return;

    const padL = 12.0;
    const padR = 8.0;
    const padT = 8.0;
    const padB = 16.0;

    final chartW = size.width - padL - padR;
    final chartH = size.height - padT - padB;
    if (chartW <= 0 || chartH <= 0) return;

    final gridPaint = Paint()
      ..color = const Color(0xFFE4EBEF)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = padT + (chartH * i / 3);
      canvas.drawLine(Offset(padL, y), Offset(padL + chartW, y), gridPaint);
    }

    Offset pointFor(int i, double value) {
      final x = padL + (chartW * i / (rows.length - 1));
      final y = padT + chartH - ((value / maxValue) * chartH);
      return Offset(x, y);
    }

    final ciroPath = Path();
    final hakedisPath = Path();
    for (var i = 0; i < rows.length; i++) {
      final c = pointFor(i, rows[i].ciro);
      final h = pointFor(i, rows[i].hakedis);
      if (i == 0) {
        ciroPath.moveTo(c.dx, c.dy);
        hakedisPath.moveTo(h.dx, h.dy);
      } else {
        ciroPath.lineTo(c.dx, c.dy);
        hakedisPath.lineTo(h.dx, h.dy);
      }
    }

    final ciroPaint = Paint()
      ..color = ciroColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final hakPaint = Paint()
      ..color = hakedisColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    canvas.drawPath(ciroPath, ciroPaint);
    canvas.drawPath(hakedisPath, hakPaint);

    final dotC = Paint()..color = ciroColor;
    final dotH = Paint()..color = hakedisColor;
    for (var i = 0; i < rows.length; i++) {
      canvas.drawCircle(pointFor(i, rows[i].ciro), 2.5, dotC);
      canvas.drawCircle(pointFor(i, rows[i].hakedis), 2.5, dotH);
    }
  }

  @override
  bool shouldRepaint(covariant _DualLineChartPainter oldDelegate) {
    return oldDelegate.rows != rows || oldDelegate.maxValue != maxValue;
  }
}

class _DailyGroupedBarPainter extends CustomPainter {
  final List<_DailyTotalsRow> rows;
  final double maxValue;
  final Color ciroColor;
  final Color hakedisColor;

  _DailyGroupedBarPainter({
    required this.rows,
    required this.maxValue,
    required this.ciroColor,
    required this.hakedisColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rows.isEmpty) return;

    const padL = 86.0;
    const padR = 8.0;
    const padT = 8.0;
    const padB = 22.0;

    final chartW = size.width - padL - padR;
    final chartH = size.height - padT - padB;
    if (chartW <= 0 || chartH <= 0) return;
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    final gridPaint = Paint()
      ..color = const Color(0xFFE4EBEF)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = padT + (chartH * i / 3);
      canvas.drawLine(Offset(padL, y), Offset(padL + chartW, y), gridPaint);
      final tickValue = maxValue * (3 - i) / 3;
      textPainter.text = TextSpan(
        text: _formatMoneyFull(tickValue),
        style: const TextStyle(
          fontSize: 9,
          color: Color(0xFF6B7B85),
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(6, y - (textPainter.height / 2)),
      );
    }

    final groups = rows.length;
    final groupW = chartW / groups;
    final barW = (groupW * 0.34).clamp(4.0, 24.0);
    final gap = (groupW * 0.08).clamp(2.0, 8.0);

    final barPaintCiro = Paint()..color = ciroColor;
    final barPaintHak = Paint()..color = hakedisColor;
    const minVisibleBarHeight = 3.0;

    double scaledBarHeight(double value) {
      if (value <= 0) return 0;
      final normalized = value / maxValue;
      final eased = math.pow(normalized, 0.65).toDouble();
      final h = eased * chartH;
      return h < minVisibleBarHeight ? minVisibleBarHeight : h;
    }

    for (var i = 0; i < groups; i++) {
      final x0 = padL + i * groupW + (groupW - (barW * 2 + gap)) / 2;
      final cVal = rows[i].ciro;
      final hVal = rows[i].hakedis;
      final cH = scaledBarHeight(cVal);
      final hH = scaledBarHeight(hVal);

      final cRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x0, padT + chartH - cH, barW, cH),
        const Radius.circular(2),
      );
      final hRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x0 + barW + gap, padT + chartH - hH, barW, hH),
        const Radius.circular(2),
      );
      canvas.drawRRect(cRect, barPaintCiro);
      canvas.drawRRect(hRect, barPaintHak);

      void drawValue(double value, double x, double barTopY, Color barColor) {
        final isLight = barColor.computeLuminance() > 0.45;
        final inside = (chartH - (barTopY - padT)) > 24;
        textPainter.text = TextSpan(
          text: _formatMoneyFull(value),
          style: TextStyle(
            fontSize: 8.5,
            color: inside
                ? (isLight ? const Color(0xFF1F2A25) : Colors.white)
                : const Color(0xFF405650),
            fontWeight: FontWeight.w700,
          ),
        );
        textPainter.layout();
        final dy = inside ? (barTopY + 2) : (barTopY - 11);
        textPainter.paint(
            canvas, Offset(x + (barW - textPainter.width) / 2, dy));
      }

      drawValue(cVal, x0, padT + chartH - cH, ciroColor);
      drawValue(hVal, x0 + barW + gap, padT + chartH - hH, hakedisColor);

      if (i % ((groups / 4).ceil().clamp(1, groups)) == 0 || i == groups - 1) {
        final d = rows[i].date;
        final label =
            '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
        textPainter.text = TextSpan(
          text: label,
          style: const TextStyle(fontSize: 9, color: Color(0xFF6B7B85)),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            x0 + (barW * 2 + gap - textPainter.width) / 2,
            padT + chartH + 3,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DailyGroupedBarPainter oldDelegate) {
    return oldDelegate.rows != rows || oldDelegate.maxValue != maxValue;
  }

  String _formatMoneyFull(double value) {
    final fmt =
        NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);
    return fmt.format(value);
  }
}
