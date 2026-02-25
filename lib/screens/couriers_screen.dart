// lib/screens/couriers_screen.dart
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import 'form/create_account_form.dart';

/// =====================
///  UI TOKENS (görseldeki stil)
/// =====================
class _UI {
  // Backgrounds
  static const Color bg = Color(0xFFF3F4FB); // ekran arkası
  static const Color card = Colors.white; // kart
  static const Color border = Color(0xFFE6E8F2);

  // Text
  static const Color text = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);

  // Brand
  static const Color primary = Color(0xFF0D4631);
  static const Color primaryDark = Color(0xFF0D4631);
  static const Color primarySoft = Color(0xFFE9E8FA); // seçili satır bg
  static const Color primarySoft2 = Color(0xFFEFEEFF); // seçili pill bg

  // Table header
  static const Color headerBg = Color(0xFFF0EFFE);

  // Status
  static const Color ok = Color(0xFF0F766E);
  static const Color danger = Color(0xFFB91C1C);
}

/// =====================
///  MODEL
/// =====================
class Courier {
  final int id;
  final String name;
  final String phone;
  final String createdAt;
  final bool isActive;

  // opsiyonel/ek alanlar
  final String? avatarUrl;
  final double balance; // ₺
  final int jobCount;
  final String approvalStatus;

  // ekstra (detail panelde göstermek için)
  final String? plate;
  final String? iban;
  final String? accountHolder;

  Courier({
    required this.id,
    required this.name,
    required this.phone,
    required this.createdAt,
    required this.isActive,
    this.avatarUrl,
    this.balance = 0.0,
    this.jobCount = 0,
    this.approvalStatus = '—',
    this.plate,
    this.iban,
    this.accountHolder,
  });

  /// Backend çok farklı alan isimleri döndürebilir; hepsini tolere et.
  factory Courier.fromAnyJson(Map<String, dynamic> j) {
    T? pick<T>(List<String> keys) {
      for (final k in keys) {
        final v = j[k];
        if (v == null) continue;

        if (T == String) return (v is String ? v : '$v') as T;

        if (T == int) {
          if (v is int) return v as T;
          if (v is num) return v.toInt() as T;
          final p = int.tryParse('$v');
          if (p != null) return p as T;
        }

        if (T == double) {
          if (v is num) return v.toDouble() as T;
          final p = double.tryParse('$v'.replaceAll(',', '.'));
          if (p != null) return p as T;
        }

        if (T == bool) {
          if (v is bool) return v as T;
          if (v is num) return (v != 0) as T;
          final s = '$v'.toLowerCase();
          if (s == '1' || s == 'true' || s == 'aktif' || s == 'active')
            return true as T;
          if (s == '0' || s == 'false' || s == 'pasif' || s == 'inactive')
            return false as T;
        }
      }
      return null;
    }

    String _str(List<String> keys, {String d = ''}) => pick<String>(keys) ?? d;
    int _int(List<String> keys, {int d = 0}) => pick<int>(keys) ?? d;
    double _dbl(List<String> keys, {double d = 0}) => pick<double>(keys) ?? d;
    bool _bool(List<String> keys, {bool d = false}) => pick<bool>(keys) ?? d;

    final id = _int(['id', 'user_id', 'courier_id']);
    final name = _str(['name', 'ad_soyad', 'full_name']);
    final phone = _str(['phone', 'telefon', 'contact_number', 'mobile']);
    final createdAt = _str(['created_at', 'kayit_tarihi', 'createdAt'], d: '');
    final isActive = _bool(['is_active', 'active', 'durum', 'status']);

    final avatarUrl =
        _str(['avatar', 'avatar_url', 'photo', 'image_url'], d: '');
    final balance = _dbl(['balance', 'wallet_balance', 'bakiye']);
    final jobCount = _int(['jobs_count', 'job_count', 'is_sayisi']);
    final approvalStatus = _str(
        ['approval_status', 'approval', 'onay', 'can_take_orders'],
        d: '—');

    final plate = _str(['plate', 'plaka'], d: '');
    final iban = _str(['iban', 'iban_no'], d: '');
    final accountHolder =
        _str(['account_holder', 'hesap_sahibi', 'iban_name'], d: '');

    return Courier(
      id: id,
      name: name.isEmpty ? '—' : name,
      phone: phone.isEmpty ? '—' : phone,
      createdAt: createdAt.isEmpty ? '—' : createdAt,
      isActive: isActive,
      avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
      balance: balance,
      jobCount: jobCount,
      approvalStatus: approvalStatus,
      plate: plate.isEmpty ? null : plate,
      iban: iban.isEmpty ? null : iban,
      accountHolder: accountHolder.isEmpty ? null : accountHolder,
    );
  }
}

/// =====================
///  SCREEN
/// =====================
class CouriersScreen extends StatefulWidget {
  const CouriersScreen({super.key});

  @override
  State<CouriersScreen> createState() => _CouriersScreenState();
}

class _CouriersScreenState extends State<CouriersScreen> {
  final TextEditingController _searchC = TextEditingController();
  String _statusFilter = 'Tümü'; // Tümü / Aktif / Pasif

  List<Courier> _all = [];
  List<Courier> _filtered = [];
  Courier? _selected;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFromBackend();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _loadFromBackend() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiClient>();
      final res = await api.getCouriers(page: 1, perPage: 200);

      final items = _extractArray(res);
      final parsed = items
          .whereType<Map>()
          .map((e) => Courier.fromAnyJson(Map<String, dynamic>.from(e)))
          .toList();

      setState(() {
        _all = parsed;
        _filtered = List.of(_all);
        _selected = _filtered.isNotEmpty ? _filtered.first : null;
      });
    } catch (e) {
      setState(() => _error = 'Kuryeler yüklenemedi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> _extractArray(dynamic payload) {
    if (payload is List) return payload;
    if (payload is Map) {
      final data = payload['data'];
      if (data is List) return data;
      if (data is Map && data['data'] is List) return data['data'] as List;
      if (payload['results'] is List) return payload['results'] as List;
    }
    return const [];
  }

  String _trLower(String s) =>
      s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

  int get _totalCount => _all.length;
  int get _activeCount => _all.where((e) => e.isActive).length;
  int get _passiveCount => _all.where((e) => !e.isActive).length;

  void _applyFilter() {
    final q = _trLower(_searchC.text.trim());

    setState(() {
      Iterable<Courier> list = _all;

      if (_statusFilter != 'Tümü') {
        final wantActive = _statusFilter == 'Aktif';
        list = list.where((c) => c.isActive == wantActive);
      }

      if (q.isNotEmpty) {
        list = list.where((c) =>
            _trLower(c.name).contains(q) ||
            _trLower(c.phone).contains(q) ||
            c.id.toString().contains(q));
      }

      _filtered = list.toList();

      // ✅ seçim korunur, yoksa ilk kayıt
      if (_filtered.isEmpty) {
        _selected = null;
      } else if (_selected == null ||
          !_filtered.any((x) => x.id == _selected!.id)) {
        _selected = _filtered.first;
      }
    });
  }

  void _clearAllFilters() {
    setState(() {
      _statusFilter = 'Tümü';
      _searchC.clear();
      _filtered = List.of(_all);
      if (_filtered.isNotEmpty) _selected = _filtered.first;
    });
  }

  Future<void> _openCreateCourierSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.98,
        widthFactor: 0.98,
        child: Material(
          color: _UI.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1600),
                child: const CreateAccountForm(
                  userType: 'delivery_man',
                  title: 'Yeni Kurye',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await _loadFromBackend();
  }

  void _openCourier(Courier c) {
    final w = MediaQuery.of(context).size.width;

    // dar ekranda route
    if (w < 980) {
      context.go('/couriers/${c.id}');
      return;
    }

    // wide: sağ panel
    setState(() => _selected = c);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Scaffold(
        backgroundColor: _UI.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: _UI.text)),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _loadFromBackend,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _UI.bg,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          hintStyle:
              const TextStyle(color: _UI.muted, fontWeight: FontWeight.w600),
          prefixIconColor: _UI.muted,
          suffixIconColor: _UI.muted,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _UI.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _UI.primary, width: 2),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: _UI.bg,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadFromBackend,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
              children: [
                _heroHeader(),
                const SizedBox(height: 14),
                _filtersCard(),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, box) {
                    final wide = box.maxWidth >= 1100;
                    if (!wide) {
                      return _ordersContainer(child: _tableCard());
                    }
                    return SizedBox(
                      height: 680,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: _ordersContainer(child: _tableCard()),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 4,
                            child: _detailRight(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ordersContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _UI.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _UI.primary.withOpacity(0.45),
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            color: Color(0x14000000),
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }

  Widget _heroHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [_UI.primaryDark, _UI.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            color: _UI.primary.withOpacity(.22),
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(.55),
                      blurRadius: 16,
                    )
                  ],
                ),
                child: const CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.delivery_dining, color: _UI.primaryDark),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Kuryeler",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Kurye kayıtları • filtrele • görüntüle",
                      style: TextStyle(
                        color: Color(0xEEFFFFFF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loadFromBackend,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x66FFFFFF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text("Yenile",
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _openCreateCourierSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _UI.primaryDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add),
                label: const Text("Yeni Kurye",
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _miniStat("Toplam", "$_totalCount", Icons.people_alt)),
              const SizedBox(width: 10),
              Expanded(
                  child: _miniStat(
                      "Aktif", "$_activeCount", Icons.check_circle_outline)),
              const SizedBox(width: 10),
              Expanded(
                  child: _miniStat(
                      "Pasif", "$_passiveCount", Icons.remove_circle_outline)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x22FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xEEFFFFFF),
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _filtersCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _UI.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _UI.primary, width: 1.4),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            color: _UI.primary.withOpacity(0.24),
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // title row + temizle
          Row(
            children: [
              const Text('Filtreler',
                  style:
                      TextStyle(fontWeight: FontWeight.w900, color: _UI.text)),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: _UI.primary),
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Temizle',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // pills row
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pillOption('Tümü', selected: _statusFilter == 'Tümü', onTap: () {
                _statusFilter = 'Tümü';
                _applyFilter();
              }),
              _pillOption('Aktif', selected: _statusFilter == 'Aktif',
                  onTap: () {
                _statusFilter = 'Aktif';
                _applyFilter();
              }),
              _pillOption('Pasif', selected: _statusFilter == 'Pasif',
                  onTap: () {
                _statusFilter = 'Pasif';
                _applyFilter();
              }),
            ],
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _searchC,
            decoration: InputDecoration(
              hintText: 'Kurye no, ad, telefon ara…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: (_searchC.text.isEmpty)
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchC.clear();
                        _applyFilter();
                      },
                      icon: const Icon(Icons.close),
                      tooltip: 'Temizle',
                    ),
            ),
            onChanged: (_) => setState(() {}), // suffix icon güncellensin
            onSubmitted: (_) => _applyFilter(),
          ),
        ],
      ),
    );
  }

  Widget _pillOption(String text,
      {required bool selected, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [_UI.primary, _UI.primary.withOpacity(.0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : _UI.bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? _UI.primary : _UI.border),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _UI.primary.withOpacity(.2),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  )
                ]
              : const [],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.white : _UI.text,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  /// =====================
  ///  TABLE CARD (master)
  /// =====================
  Widget _tableCard() {
    final screenW = MediaQuery.of(context).size.width;

    return Container(
      decoration: BoxDecoration(
        color: _UI.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _UI.primary.withOpacity(0.45), width: 1.4),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            color: Color(0x14000000),
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: _filtered.isEmpty
          ? const Center(
              child: Text('Kayıt bulunamadı',
                  style:
                      TextStyle(color: _UI.muted, fontWeight: FontWeight.w800)),
            )
          : Theme(
              data: Theme.of(context).copyWith(
                dataTableTheme: DataTableThemeData(
                  headingRowColor: MaterialStateProperty.all(_UI.headerBg),
                  dataRowMinHeight: 72,
                  dataRowMaxHeight: 92,
                  headingRowHeight: 56,
                  dividerThickness: 0.7,
                  headingTextStyle: const TextStyle(
                      fontWeight: FontWeight.w900, color: _UI.text),
                  dataTextStyle: const TextStyle(
                      color: _UI.text, fontWeight: FontWeight.w700),
                ),
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: screenW),
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Kurye')),
                          DataColumn(label: Text('Telefon')),
                          DataColumn(label: Text('Durum')),
                          DataColumn(label: Text('Kayıt')),
                          DataColumn(label: Text('')),
                        ],
                        rows: List.generate(_filtered.length, (i) {
                          final c = _filtered[i];
                          return _row(c, i);
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  DataRow _row(Courier c, int index) {
    final isSelected = _selected?.id == c.id;
    final zebra = index.isEven ? _UI.card : const Color(0xFFFBFCFD);

    return DataRow(
      selected: isSelected,
      color: MaterialStateProperty.resolveWith((states) {
        if (isSelected)
          return _UI.primarySoft; // ✅ seçili satır (görseldeki gibi)
        if (states.contains(MaterialState.hovered))
          return _UI.primary.withOpacity(.06);
        return zebra;
      }),
      onSelectChanged: (_) => _openCourier(c),
      cells: [
        DataCell(_twoLineCell(
          title: c.name,
          subtitle:
              c.approvalStatus == '—' ? 'Onay: —' : 'Onay: ${c.approvalStatus}',
        )),
        DataCell(_twoLineCell(
          title: c.phone,
          subtitle: c.plate == null || c.plate!.trim().isEmpty
              ? 'Plaka: —'
              : 'Plaka: ${c.plate!}',
        )),
        DataCell(_activeChip(c.isActive)),
        DataCell(_twoLineCell(
          title: c.createdAt,
          subtitle: 'İş: ${c.jobCount}',
          tabular: true,
        )),
        DataCell(
          IconButton(
            tooltip: 'Aç',
            onPressed: () => _openCourier(c),
            icon: const Icon(Icons.open_in_new, color: _UI.muted),
          ),
        ),
      ],
    );
  }

  Widget _twoLineCell({
    required String title,
    required String subtitle,
    bool tabular = false,
  }) {
    final titleStyle = TextStyle(
      fontWeight: FontWeight.w900,
      color: _UI.text,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    );
    final subtitleStyle = const TextStyle(
      fontSize: 12,
      color: _UI.muted,
      fontWeight: FontWeight.w700,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.trim().isEmpty ? '—' : title.trim(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        const SizedBox(height: 2),
        Text(
          subtitle.trim().isEmpty ? '—' : subtitle.trim(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: subtitleStyle,
        ),
      ],
    );
  }

  /// =====================
  ///  RIGHT DETAIL (master-detail)
  /// =====================
  Widget _detailRight() {
    final c = _selected;

    return Container(
      decoration: BoxDecoration(
        color: _UI.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _UI.border),
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            offset: Offset(0, 8),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: c == null
          ? const Center(child: Text('Soldan bir kurye seç'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _profileCard(c),
                    const SizedBox(height: 14),
                    _detailTile(
                      icon: Icons.local_shipping_outlined,
                      label: 'Durum',
                      value: c.isActive ? 'Aktif' : 'Pasif',
                    ),
                    const SizedBox(height: 10),
                    _detailTile(
                      icon: Icons.calendar_month,
                      label: 'Kayıt',
                      value: c.createdAt,
                    ),
                    const SizedBox(height: 10),
                    _detailTile(
                      icon: Icons.paid_outlined,
                      label: 'Bakiye',
                      value: _formatTL(c.balance),
                    ),
                    const SizedBox(height: 10),
                    _detailTile(
                      icon: Icons.task_alt_outlined,
                      label: 'İş Sayısı',
                      value: c.jobCount.toString(),
                    ),
                    const SizedBox(height: 14),
                    _detailBlock(title: 'Plaka', subtitle: c.plate),
                    const SizedBox(height: 10),
                    _detailBlock(title: 'IBAN', subtitle: c.iban),
                    const SizedBox(height: 10),
                    _detailBlock(
                        title: 'Hesap Sahibi', subtitle: c.accountHolder),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _loadFromBackend,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Yenile'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => context.go('/couriers/${c.id}'),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Detaya Git'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _profileCard(Courier c) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: _UI.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _UI.border),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3F4FB), Color(0xFFE9E8FA)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: 14, left: 14, child: _activeChip(c.isActive)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: const Color(0xFFE3E2FB),
                  backgroundImage:
                      (c.avatarUrl != null && c.avatarUrl!.isNotEmpty)
                          ? NetworkImage(c.avatarUrl!)
                          : null,
                  child: (c.avatarUrl != null && c.avatarUrl!.isNotEmpty)
                      ? null
                      : Text(
                          _initials(c.name),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, color: _UI.primary),
                        ),
                ),
                const SizedBox(height: 14),
                Text(c.name,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _UI.text)),
                const SizedBox(height: 6),
                Text(
                  c.phone,
                  style: const TextStyle(
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w800,
                    color: _UI.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceCard(Courier c) {
    return Container(
      decoration: BoxDecoration(
        color: _UI.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _UI.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            _formatTL(c.balance),
            style: const TextStyle(
                fontSize: 32, fontWeight: FontWeight.w900, color: _UI.text),
          ),
          const SizedBox(height: 6),
          const Text('Bakiye',
              style: TextStyle(color: _UI.muted, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          /*    Row(
            children: [
              Expanded(
                child: _outlinePillButton(
                  icon: Icons.add,
                  text: 'Yükle',
                  onTap: () {
                    // TODO: bakiye yükleme modalı
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _outlinePillButton(
                  icon: Icons.remove,
                  text: 'Tahsil',
                  onTap: () {
                    // TODO: tahsil modalı
                  },
                ),
              ),
            ],
          ),*/
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => context.go('/couriers/${c.id}'),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Detaya Git'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _UI.primary,
              side: const BorderSide(color: _UI.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _UI.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _UI.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: _UI.muted),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w900, color: _UI.muted)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailBlock({required String title, required String? subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _UI.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _UI.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          if ((subtitle ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!.trim(),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _UI.muted,
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            const Text('—',
                style: TextStyle(fontWeight: FontWeight.w700, color: _UI.muted))
          ],
        ],
      ),
    );
  }

  /// =====================
  ///  SMALL UI PARTS
  /// =====================
  Widget _activeChip(bool active) {
    final tone = active ? _UI.primary : _UI.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _UI.primarySoft2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withOpacity(.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active ? Icons.check_circle : Icons.cancel,
              size: 18, color: tone),
          const SizedBox(width: 6),
          Text(
            active ? 'Aktif' : 'Pasif',
            style: TextStyle(fontWeight: FontWeight.w900, color: tone),
          ),
        ],
      ),
    );
  }

  Widget _softButton(
      {required IconData icon,
      required String text,
      required VoidCallback onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(text),
      style: OutlinedButton.styleFrom(
        foregroundColor: _UI.text,
        side: const BorderSide(color: _UI.border),
        backgroundColor: _UI.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _primaryButton(
      {required IconData icon,
      required String text,
      required VoidCallback onTap}) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(text),
      style: FilledButton.styleFrom(
        backgroundColor: _UI.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _outlinePillButton(
      {required IconData icon,
      required String text,
      required VoidCallback onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(text),
      style: OutlinedButton.styleFrom(
        foregroundColor: _UI.primary,
        side: const BorderSide(color: _UI.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }

  String _formatTL(double v) {
    final sign = v < 0 ? '-' : '';
    final abs = v.abs();
    return '$sign${abs.toStringAsFixed(2)} ₺';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return (s.characters.take(2).toString()).toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}
