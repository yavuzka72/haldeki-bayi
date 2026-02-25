import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import 'form/create_account_form.dart';
import 'haldeki_ui.dart';

/// -------------------- MODEL --------------------

class Client {
  final int id;
  final String name;
  final String phone;
  final String email;
  final String? address;
  final String? city;
  final String? district;
  final int? countryId;
  final int? cityId;
  final String? latitude;
  final String? longitude;
  final String createdAt;
  final bool isOpen;
  final String? avatarUrl;

  // Optional UI fields (backend bağlanınca doldur)
  final String? plate;
  final String? iban;
  final String? accountName;
  final num? balance;

  Client({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.address,
    this.city,
    this.district,
    this.countryId,
    this.cityId,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.isOpen,
    this.avatarUrl,
    this.plate,
    this.iban,
    this.accountName,
    this.balance,
  });

  factory Client.fromAnyJson(Map<String, dynamic> j) {
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

        if (T == bool) {
          if (v is bool) return v as T;
          if (v is num) return (v != 0) as T;
          final s = '$v'.toLowerCase();
          if (['1', 'true', 'açık', 'acik', 'open', 'aktif', 'active']
              .contains(s)) {
            return true as T;
          }
          if (['0', 'false', 'kapalı', 'kapali', 'closed', 'pasif', 'inactive']
              .contains(s)) {
            return false as T;
          }
        }

        if (T == num) {
          if (v is num) return v as T;
          final p = num.tryParse('$v');
          if (p != null) return p as T;
        }
      }
      return null;
    }

    String _str(List<String> keys, {String d = ''}) => pick<String>(keys) ?? d;
    int _int(List<String> keys, {int d = 0}) => pick<int>(keys) ?? d;
    bool _bool(List<String> keys, {bool d = true}) => pick<bool>(keys) ?? d;
    num? _num(List<String> keys) => pick<num>(keys);

    final id = _int(['id', 'client_id', 'user_id']);
    final name = _str(['name', 'ad_soyad', 'title', 'full_name'], d: '—');
    final phone =
        _str(['phone', 'telefon', 'contact_number', 'mobile'], d: '—');
    final email = _str(['email', 'eposta', 'mail'], d: '—');
    final address = _str(['address', 'adres'], d: '');
    final city = _str(['city', 'sehir'], d: '');
    final district = _str(['district', 'ilce'], d: '');
    final countryId = pick<int>(['country_id', 'countryId']);
    final cityId = pick<int>(['city_id', 'cityId']);
    final latitude =
        _str(['latitude', 'lat', 'location_lat', 'pickup_lat'], d: '');
    final longitude =
        _str(['longitude', 'lng', 'location_lng', 'pickup_lng'], d: '');
    final createdAt = _str(['created_at', 'kayit_tarihi', 'createdAt'], d: '—');
    final isOpen = _bool(
        ['is_open', 'siparis_alma_durumu', 'order_open', 'status'],
        d: true);
    final avatar = _str(['avatar', 'avatar_url', 'photo', 'image_url'], d: '');

    // opsiyonel alanlar (yoksa null kalır)
    final plate = _str(['plate', 'plaka'], d: '');
    final iban = _str(['iban'], d: '');
    final accountName = _str(['account_name', 'hesap_sahibi'], d: '');
    final balance = _num(['balance', 'bakiye']);

    return Client(
      id: id,
      name: name,
      phone: phone,
      email: email,
      address: address.isEmpty ? null : address,
      city: city.isEmpty ? null : city,
      district: district.isEmpty ? null : district,
      countryId: countryId,
      cityId: cityId,
      latitude: latitude.isEmpty ? null : latitude,
      longitude: longitude.isEmpty ? null : longitude,
      createdAt: createdAt,
      isOpen: isOpen,
      avatarUrl: avatar.isEmpty ? null : avatar,
      plate: plate.isEmpty ? null : plate,
      iban: iban.isEmpty ? null : iban,
      accountName: accountName.isEmpty ? null : accountName,
      balance: balance,
    );
  }
}

/// -------------------- PRIMARY THEME TOKENS --------------------

class KClientsColors {
  // Brand
  static const purple = Color(0xFF0D4631);
  static const purple2 = Color(0xFF0D4631);
  static const orange = Color(0xFFF4B000);

  // Neutral
  static const bg = Color(0xFFF3F4FB);
  static const card = Color(0xFFFFFFFF);
  static const soft = Color(0xFFF8FAFC);
  static const line = Color(0xFFE6E8F2);

  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);

  // Status
  static const passive = Color(0xFF475569);
}

/// -------------------- SCREEN --------------------

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final TextEditingController _searchC = TextEditingController();
  String _statusFilter = 'Tümü';

  List<Client> _all = [];
  List<Client> _filtered = [];

  Client? _selected;

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
      final res = await api.getPartnerClients(page: 1, perPage: 200);

      final items = _extractArray(res);
      final parsed = items
          .whereType<Map>()
          .map((e) => Client.fromAnyJson(Map<String, dynamic>.from(e)))
          .toList();

      setState(() {
        _all = parsed;
        _filtered = List.of(_all);
        _selected = _filtered.isEmpty ? null : (_selected ?? _filtered.first);
      });
    } catch (e) {
      setState(() => _error = 'İşletmeler yüklenemedi: $e');
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

  void _applyFilter() {
    final q = _trLower(_searchC.text.trim());
    setState(() {
      Iterable<Client> list = _all;

      if (_statusFilter != 'Tümü') {
        final wantOpen = _statusFilter == 'Açık';
        list = list.where((c) => c.isOpen == wantOpen);
      }

      if (q.isNotEmpty) {
        list = list.where((c) =>
            _trLower(c.name).contains(q) ||
            _trLower(c.phone).contains(q) ||
            _trLower(c.email).contains(q) ||
            c.id.toString().contains(q));
      }

      _filtered = list.toList();

      if (_filtered.isEmpty) {
        _selected = null;
      } else {
        final stillExists =
            _selected != null && _filtered.any((x) => x.id == _selected!.id);
        _selected = stillExists ? _selected : _filtered.first;
      }
    });
  }

  void _clearSearch() {
    _searchC.clear();
    _applyFilter();
  }

  void _clearAllFilters() {
    setState(() {
      _statusFilter = 'Tümü';
      _searchC.clear();
      _filtered = List.of(_all);
      _selected = _filtered.isEmpty ? null : _filtered.first;
    });
  }

  Future<void> _openCreateClientSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.98,
        widthFactor: 0.98,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1600),
                child: const CreateAccountForm(
                  userType: 'client',
                  title: 'İşletme Ekle',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _loadFromBackend();
  }

  void _goDetail(Client c) => context.go('/customers/${c.id}');

  void _goCreateDeliveryOrderForClient(Client c) {
    final location = Uri(
      path: '/delivery-orders/new',
      queryParameters: {
        'clientId': c.id.toString(),
        'clientName': c.name,
        'clientPhone': c.phone == '—' ? '' : c.phone,
        'clientAddress': c.address ?? '',
        'clientCity': c.city ?? '',
        'clientDistrict': c.district ?? '',
        if (c.countryId != null) 'clientCountryId': c.countryId.toString(),
        if (c.cityId != null) 'clientCityId': c.cityId.toString(),
        'clientLat': c.latitude ?? '',
        'clientLng': c.longitude ?? '',
      },
    ).toString();
    context.go(location);
  }

  ThemeData _primaryTheme(BuildContext context) {
    final base = Theme.of(context);
    final cs = base.colorScheme;

    // HaldekiUI rect buttons + dense input korunur, ama primary rengi mor sistemle override edilir
    final themed = HaldekiUI.withRectButtons(context, cs).copyWith(
      inputDecorationTheme: HaldekiUI.inputDense(context).copyWith(
        filled: true,
        fillColor: KClientsColors.soft,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: KClientsColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: KClientsColors.purple.withOpacity(.55), width: 1.4),
        ),
      ),
      colorScheme: cs.copyWith(
        primary: KClientsColors.purple,
        secondary: KClientsColors.orange,
      ),
    );

    return themed;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loadFromBackend,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      );
    }

    final total = _all.length;
    final openCount = _all.where((c) => c.isOpen).length;
    final closedCount = total - openCount;

    return Theme(
      data: _primaryTheme(context),
      child: Scaffold(
        backgroundColor: KClientsColors.bg,
        body: Padding(
          padding: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
          child: Column(
            children: [
              _headerBar(context, total, openCount, closedCount),
              const SizedBox(height: 12),
              _filtersCard(context),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final wide = box.maxWidth >= 1100;

                    if (!wide) {
                      return _listCard(context, masterDetail: false);
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            flex: 7,
                            child: _listCard(context, masterDetail: true)),
                        const SizedBox(width: 12),
                        Expanded(flex: 4, child: _rightDetailPanel(context)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ---------------- HEADER ----------------

  Widget _headerBar(
      BuildContext context, int total, int openCount, int closedCount) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'İşletmeler',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: KClientsColors.text,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _countChip('Toplam', '$total'),
                _countChip('Aktif', '$openCount', tone: KClientsColors.purple),
                _countChip('Pasif', '$closedCount',
                    tone: KClientsColors.orange),
              ],
            ),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _loadFromBackend,
          icon: const Icon(Icons.refresh),
          label: const Text('Yenile'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _openCreateClientSheet,
          icon: const Icon(Icons.store_mall_directory_rounded),
          label: const Text('Yeni İşletme'),
        ),
      ],
    );
  }

  Widget _countChip(String label, String value, {Color? tone}) {
    final t = tone ?? KClientsColors.purple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.withOpacity(.22)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: KClientsColors.text,
        ),
      ),
    );
  }

  /// ---------------- FILTERS (resimdeki gibi) ----------------

  Widget _filtersCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KClientsColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KClientsColors.line),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(.05),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Filtreler',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const Spacer(),
              TextButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.close),
                label: const Text('Temizle'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill('Tümü', selected: _statusFilter == 'Tümü', onTap: () {
                setState(() => _statusFilter = 'Tümü');
                _applyFilter();
              }),
              _pill('Açık', selected: _statusFilter == 'Açık', onTap: () {
                setState(() => _statusFilter = 'Açık');
                _applyFilter();
              }),
              _pill('Kapalı', selected: _statusFilter == 'Kapalı', onTap: () {
                setState(() => _statusFilter = 'Kapalı');
                _applyFilter();
              }),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: TextField(
              controller: _searchC,
              decoration: InputDecoration(
                hintText: 'İşletme no, ad, telefon, e-posta ara...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchC.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close),
                        tooltip: 'Temizle',
                      ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _applyFilter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text,
      {required bool selected, required VoidCallback onTap}) {
    final c = selected ? KClientsColors.purple : KClientsColors.text;
    final bg =
        selected ? KClientsColors.purple.withOpacity(.12) : KClientsColors.card;
    final br =
        selected ? KClientsColors.purple.withOpacity(.35) : KClientsColors.line;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: br),
        ),
        child:
            Text(text, style: TextStyle(fontWeight: FontWeight.w900, color: c)),
      ),
    );
  }

  /// ---------------- LIST (Orders hissi) ----------------

  Widget _listCard(BuildContext context, {required bool masterDetail}) {
    return Container(
      decoration: BoxDecoration(
        color: KClientsColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KClientsColors.line),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(.05),
          ),
        ],
      ),
      child: _filtered.isEmpty
          ? const Center(child: Text('Kayıt bulunamadı'))
          : Column(
              children: [
                _listHeader(),
                const Divider(height: 1, color: KClientsColors.line),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final c = _filtered[i];
                      final selected = _selected?.id == c.id;
                      final zebra = i.isEven;

                      return _clientRow(
                        c,
                        zebra: zebra,
                        selected: selected,
                        onTap: () {
                          if (!masterDetail) {
                            _goDetail(c);
                          } else {
                            setState(() => _selected = c);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _listHeader() {
    const h =
        TextStyle(fontWeight: FontWeight.w900, color: KClientsColors.text);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: KClientsColors.purple.withOpacity(.06),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        children: const [
          SizedBox(width: 84, child: Text('No', style: h)),
          SizedBox(width: 10),
          Expanded(flex: 5, child: Text('İşletme • Telefon', style: h)),
          Expanded(flex: 4, child: Text('E-posta • Kayıt', style: h)),
          Expanded(flex: 2, child: Text('Durum', style: h)),
          SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _clientRow(
    Client c, {
    required bool zebra,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final bg = selected
        ? KClientsColors.purple.withOpacity(.10)
        : zebra
            ? const Color(0xFFF7FAFC)
            : KClientsColors.card;

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          border: const Border(bottom: BorderSide(color: KClientsColors.line)),
          boxShadow: selected
              ? [
                  BoxShadow(
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                    color: KClientsColors.purple.withOpacity(.12),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 84,
              child: Text(
                c.id.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: KClientsColors.purple,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  _avatar(c, r: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _twoLineCell(
                      title: c.name,
                      subtitle: c.phone,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: _twoLineCell(
                title: c.email,
                subtitle: c.createdAt.isEmpty ? '—' : c.createdAt,
              ),
            ),
            Expanded(flex: 2, child: _statusPill(c.isOpen)),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Detay',
              onPressed: () => _goDetail(c),
              icon: const Icon(Icons.open_in_new),
            ),
          ],
        ),
      ),
    );
  }

  Widget _twoLineCell({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.trim().isEmpty ? '—' : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: KClientsColors.text,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle.trim().isEmpty ? '—' : subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  Widget _statusPillold(bool open) {
    final border = open ? KClientsColors.purple : KClientsColors.passive;
    final bg =
        open ? KClientsColors.purple.withOpacity(.10) : KClientsColors.soft;
    final fg = open ? KClientsColors.purple : KClientsColors.passive;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border.withOpacity(.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(open ? Icons.check_circle : Icons.pause_circle_filled,
                size: 16, color: fg),
            const SizedBox(width: 6),
            Text(open ? 'Aktif' : 'Pasif',
                style: TextStyle(fontWeight: FontWeight.w900, color: fg)),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(bool open) {
    final border = open ? KClientsColors.purple : KClientsColors.passive;
    final bg =
        open ? KClientsColors.purple.withOpacity(.10) : KClientsColors.soft;
    final fg = open ? KClientsColors.purple : KClientsColors.passive;

    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        // ✅ kritik
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120), // ✅ kritik
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border.withOpacity(.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(open ? Icons.check_circle : Icons.pause_circle_filled,
                    size: 16, color: fg),
                const SizedBox(width: 6),
                Text(open ? 'Aktif' : 'Pasif',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w900, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ---------------- RIGHT PANEL (resimdeki gibi) ----------------

  Widget _rightDetailPanel(BuildContext context) {
    final c = _selected;

    return Container(
      decoration: BoxDecoration(
        color: KClientsColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KClientsColors.line),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(.05),
          ),
        ],
      ),
      child: c == null
          ? const Center(child: Text('Soldan bir işletme seç'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                // ✅ overflow kilitlemesin
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 520),
                  child: Column(
                    children: [
                      _profileHero(context, c),
                      const SizedBox(height: 14),
                      _balanceCard(context, c),
                      const SizedBox(height: 10),
                      _infoTile(
                          icon: Icons.account_balance,
                          label: 'IBAN',
                          value: c.iban ?? '—'),
                      const SizedBox(height: 10),
                      /*  _infoTile(
                          icon: Icons.person,
                          label: 'Hesap Sahibi',
                          value: c.accountName ?? '—'),
                      const SizedBox(height: 10),
                      */
                      _infoTile(
                          icon: Icons.email_outlined,
                          label: 'E-posta',
                          value: c.email),
                      const SizedBox(height: 10),
                      _infoTile(
                          icon: Icons.calendar_month,
                          label: 'Kayıt',
                          value: c.createdAt.isEmpty ? '—' : c.createdAt),
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
                              onPressed: () => _goDetail(c),
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Detaya Git'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _profileHero(BuildContext context, Client c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: KClientsColors.line),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            KClientsColors.purple.withOpacity(.10),
            KClientsColors.orange.withOpacity(.10),
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: KClientsColors.purple.withOpacity(.12),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Center(child: _avatar(c, r: 28)),
          ),
          const SizedBox(height: 12),
          _statusPill(c.isOpen),
          const SizedBox(height: 12),
          Text(
            c.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: KClientsColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {}, // istersen tel: link
            child: Text(
              c.phone,
              style: const TextStyle(
                color: KClientsColors.purple,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceCard(BuildContext context, Client c) {
    final bal = c.balance ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KClientsColors.soft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: KClientsColors.line),
      ),
      child: Column(
        children: [
          Text(
            '${bal.toStringAsFixed(2)} ₺',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 30,
              color: KClientsColors.text,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          const Text('Bakiye',
              style: TextStyle(
                  fontWeight: FontWeight.w900, color: KClientsColors.muted)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add_card),
                  label: const Text('Yükle'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KClientsColors.purple,
                    side: BorderSide(
                        color: KClientsColors.purple.withOpacity(.35)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Tahsil'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KClientsColors.orange,
                    side: BorderSide(
                        color: KClientsColors.orange.withOpacity(.45)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoTile(
      {required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: KClientsColors.soft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KClientsColors.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: KClientsColors.muted),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w900, color: KClientsColors.muted)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                  fontWeight: FontWeight.w900, color: KClientsColors.text),
            ),
          ),
        ],
      ),
    );
  }

  /// ---------------- AVATAR ----------------

  Widget _avatar(Client c, {required double r}) {
    final initials = _initials(c.name);
    if (c.avatarUrl != null && c.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
          radius: r, backgroundImage: NetworkImage(c.avatarUrl!));
    }
    return CircleAvatar(
      radius: r,
      backgroundColor: KClientsColors.purple.withOpacity(.14),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: r * .55,
          fontWeight: FontWeight.w900,
          color: KClientsColors.purple,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1)
      return parts.first.characters.take(2).toString().toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}
