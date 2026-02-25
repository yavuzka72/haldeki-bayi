import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:dio/dio.dart'; // FormData / MultipartFile
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../services/api_client.dart';
import 'package:haldeki_admin_web/models/courier_models.dart';

// ====== SERVER ENDPOINT SABİTLERİ ======
// DeliveryManDocumentController
const String kDocListPath = 'delivery-man-docs';
const String kDocSavePath = 'delivery-man-document-save';

// WalletController
const String kWalletSavePath = 'save-wallet';
const String kWalletListPath = 'wallet-list';

// Şifre değiştirme
String kChangePasswordPath(int id) => 'couriers/$id/change-password';

class CourierDetailScreen extends StatefulWidget {
  final int id;
  final CourierLite? initial;

  const CourierDetailScreen({
    super.key,
    required this.id,
    this.initial,
  });

  @override
  State<CourierDetailScreen> createState() => _CourierDetailScreenState();
}

class _CourierDetailScreenState extends State<CourierDetailScreen> {
  // ----- state -----
  bool _loading = true;
  String? _error;

  late String _name;
  late String _phone;
  late String _plate;
  late String _bankOwner;
  late String _iban;
  late double _balance;
  bool _deleted = false;

  // forms
  final _editForm = GlobalKey<FormState>();
  late final TextEditingController _nameC;
  late final TextEditingController _phoneC;
  late final TextEditingController _plateC;
  late final TextEditingController _bankOwnerC;
  late final TextEditingController _ibanC;

  final _pass1 = TextEditingController();
  final _pass2 = TextEditingController();

  // belgeler
  List<Map<String, dynamic>> _documents = [];

  // tablolar
  List<List<String>> _walletRows = []; // [Tarih, Açıklama, Tutar]
  List<List<String>> _accountRows = []; // [Tarih, İşlem, Tutar]

  // ---- UI tokens (değiştirilebilir) ----
  static const Color kBg = Color(0xFFF3F4FB);
  static const Color kCard = Colors.white;
  static const Color kText = Color(0xFF0F172A);
  static const Color kMuted = Color(0xFF64748B);
  static const Color kBorder = Color(0xFFE6E8F2);

  static const Color kBlue = Color(0xFF0EA5E9);
  static const Color kGreen = Color(0xFF4F46B6);
  static const Color kAmber = Color(0xFFF4B000);
  static const Color kRed = Color(0xFFEF4444);

  BorderRadius get _r12 => BorderRadius.circular(16);
  BorderRadius get _r18 => BorderRadius.circular(18);

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _name = c?.name ?? '';
    _phone = c?.phone ?? '';
    _balance = c?.balance ?? 0;
    _deleted = c?.deleted ?? false;

    _plate = '—';
    _bankOwner = _name.isEmpty ? '—' : _name;
    _iban = '—';

    _nameC = TextEditingController(text: _name);
    _phoneC = TextEditingController(text: _phone);
    _plateC = TextEditingController(text: _plate);
    _bankOwnerC = TextEditingController(text: _bankOwner);
    _ibanC = TextEditingController(text: _iban);

    _load();
    _loadWalletBalance();
  }

  @override
  void dispose() {
    _nameC.dispose();
    _phoneC.dispose();
    _plateC.dispose();
    _bankOwnerC.dispose();
    _ibanC.dispose();
    _pass1.dispose();
    _pass2.dispose();
    super.dispose();
  }

  // ---------------- DATA ----------------

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();

      // 1) Kurye detay
      Map<String, dynamic> data;
      try {
        final res = await api.dio.get('couriers/${widget.id}');
        data = (res.data is Map && res.data['data'] is Map)
            ? Map<String, dynamic>.from(res.data['data'])
            : Map<String, dynamic>.from(res.data as Map);
      } on Exception {
        final res = await api.dio.get('api/couriers/${widget.id}');
        data = (res.data is Map && res.data['data'] is Map)
            ? Map<String, dynamic>.from(res.data['data'])
            : Map<String, dynamic>.from(res.data as Map);
      }

      String pickS(List<String> keys, {String d = ''}) {
        for (final k in keys) {
          final v = data[k];
          if (v == null) continue;
          return v.toString();
        }
        return d;
      }

      bool pickB(List<String> keys, {bool d = false}) {
        for (final k in keys) {
          final v = data[k];
          if (v == null) continue;
          if (v is bool) return v;
          if (v is num) return v != 0;
          final s = v.toString().toLowerCase();
          if (s == '1' || s == 'true' || s == 'active' || s == 'aktif') {
            return true;
          }
          if (s == '0' || s == 'false' || s == 'inactive' || s == 'pasif') {
            return false;
          }
        }
        return d;
      }

      final name = pickS(['name', 'full_name'], d: _name);
      final phone = pickS(['contact_number', 'phone', 'mobile'], d: _phone);
      final plate = pickS(['plate', 'vehicle_plate', 'plaka'], d: _plate);
      final bankOwner =
          pickS(['bank_owner', 'bank_account_owner'], d: _bankOwner);
      final iban = pickS(['iban'], d: _iban);
      final isActive = pickB(['is_active', 'active', 'status'], d: !_deleted);

      final docs = (data['documents'] is List)
          ? List<Map<String, dynamic>>.from(
              (data['documents'] as List).whereType<Map>(),
            )
          : <Map<String, dynamic>>[];

      // 2) Cüzdan
      double balance = _balance;
      try {
        final w = await api.getWallet(widget.id);
        balance = w.balance.toDouble();
      } catch (_) {}

      setState(() {
        _name = name;
        _phone = phone;
        _plate = plate.isEmpty ? '—' : plate;
        _bankOwner = bankOwner.isEmpty ? '—' : bankOwner;
        _iban = iban.isEmpty ? '—' : iban;
        _deleted = !isActive;
        _balance = balance;
        _documents = docs;

        _nameC.text = _name;
        _phoneC.text = _phone;
        _plateC.text = _plate == '—' ? '' : _plate;
        _bankOwnerC.text = _bankOwner == '—' ? '' : _bankOwner;
        _ibanC.text = _iban == '—' ? '' : _iban;
      });

      // 3) liste ve belgeleri tazele
      await _loadWalletTx();
      await _reloadDocuments();
    } catch (e) {
      setState(() => _error = 'Kurye bilgisi alınamadı: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!(_editForm.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final api = context.read<ApiClient>();
      final body = {
        'name': _nameC.text.trim(),
        'contact_number': _phoneC.text.trim(),
        'plate': _plateC.text.trim(),
        'bank_owner': _bankOwnerC.text.trim(),
        'iban': _ibanC.text.trim(),
        'is_active': _deleted ? 0 : 1,
      };
      try {
        await api.dio.put('couriers/${widget.id}', data: body);
      } on Exception {
        await api.dio.put('api/couriers/${widget.id}', data: body);
      }
      setState(() {
        _name = _nameC.text.trim();
        _phone = _phoneC.text.trim();
        _plate = _plateC.text.trim().isEmpty ? '—' : _plateC.text.trim();
        _bankOwner =
            _bankOwnerC.text.trim().isEmpty ? '—' : _bankOwnerC.text.trim();
        _iban = _ibanC.text.trim().isEmpty ? '—' : _ibanC.text.trim();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil güncellendi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Güncelleme başarısız: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive() async {
    setState(() => _deleted = !_deleted);
    try {
      final api = context.read<ApiClient>();
      final body = {'is_active': _deleted ? 0 : 1};
      try {
        await api.dio.put('couriers/${widget.id}', data: body);
      } on Exception {
        await api.dio.put('api/couriers/${widget.id}', data: body);
      }
    } catch (_) {
      setState(() => _deleted = !_deleted);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Durum değiştirilemedi.')),
      );
    }
  }

  // ------- WALLET LISTE + ISLEMLER -------

  Future<void> _loadWalletTx() async {
    try {
      final api = context.read<ApiClient>();
      Map<String, dynamic> data = {};
      try {
        final res = await api.dio
            .get(kWalletListPath, queryParameters: {'user_id': widget.id});
        if (res.data is Map) data = Map<String, dynamic>.from(res.data);
      } on Exception {
        final res = await api.dio.get('api/$kWalletListPath',
            queryParameters: {'user_id': widget.id});
        if (res.data is Map) data = Map<String, dynamic>.from(res.data);
      }

      final list = (data['data'] is List)
          ? List.from(data['data'])
          : (data['transactions'] as List? ?? []);

      final rows = <List<String>>[];
      for (final it in list) {
        final m = Map<String, dynamic>.from(it as Map);
        final dt = (m['date'] ?? m['created_at'] ?? '').toString();
        final desc = (m['description'] ?? m['note'] ?? '').toString();
        final amt = (m['amount'] ?? m['total'] ?? m['value'] ?? '').toString();
        rows.add([dt, desc, amt]);
      }
      setState(() {
        _walletRows = rows;
        _accountRows = rows
            .map((r) => [r[0], r[1].isEmpty ? 'İşlem' : r[1], r[2]])
            .toList();
      });
    } catch (_) {/* sessiz */}
  }

  Future<void> _openWalletDialog({required bool isTopup}) async {
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final actionLabel = isTopup ? 'Para Yükle' : 'Tahsil Et';

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(actionLabel),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Tutar (₺)'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: noteC,
                decoration: const InputDecoration(labelText: 'Açıklama (ops.)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal')),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(context);
              await _walletOperation(
                isTopup: isTopup,
                amount: amountC.text.trim(),
                note: noteC.text.trim().isEmpty ? null : noteC.text.trim(),
              );
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _loadWalletBalance() async {
    try {
      final api = context.read<ApiClient>();
      Response res;
      try {
        res = await api.dio.get('wallet/balance/${widget.id}');
      } on DioException {
        res = await api.dio.get('wallet/balance/${widget.id}');
      }

      final data = res.data;
      if (data is Map && data['balance'] != null) {
        setState(
          () => _balance = double.tryParse(data['balance'].toString()) ?? 0,
        );
      }
    } catch (e) {
      debugPrint('Bakiye alınamadı: $e');
    }
  }

  Future<void> _walletOperation(
      {required bool isTopup, required String amount, String? note}) async {
    try {
      final api = context.read<ApiClient>();
      final body = {
        'user_id': widget.id,
        'amount': amount,
        'type': isTopup ? 'credit' : 'debit',
        if (note != null) 'note': note,
      };
      try {
        await api.dio.post(kWalletSavePath, data: body);
      } on Exception {
        await api.dio.post('api/$kWalletSavePath', data: body);
      }

      // Bakiye + listeler
      try {
        final w = await api.getWallet(widget.id);
        setState(() => _balance = w.balance.toDouble());
      } catch (_) {}
      await _loadWalletTx();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('İşlem başarılı')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('İşlem başarısız: $e')));
    }
  }

  // ------- BELGELER -------

  Future<void> _reloadDocuments() async {
    try {
      final api = context.read<ApiClient>();
      final url = 'delivery-man-docs/${widget.id}';
      Response res;

      try {
        res = await api.dio.get(url);
      } on DioException {
        res = await api.dio.get(url);
      }

      final data = res.data;
      final list = (data is Map && data['data'] is List)
          ? List<Map<String, dynamic>>.from(
              (data['data'] as List).whereType<Map>(),
            )
          : <Map<String, dynamic>>[];

      setState(() => _documents = list);
    } catch (e) {
      debugPrint('Belge listesi alınamadı: $e');
    }
  }

  Future<void> _uploadDocuments() async {
    final picked = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (picked == null || picked.files.isEmpty) return;

    final api = context.read<ApiClient>();
    int ok = 0, fail = 0;

    for (final f in picked.files) {
      try {
        MultipartFile part;

        if (kIsWeb) {
          if (f.bytes == null) {
            fail++;
            continue;
          }
          part = MultipartFile.fromBytes(f.bytes!, filename: f.name);
        } else {
          if (f.path != null) {
            part = await MultipartFile.fromFile(f.path!, filename: f.name);
          } else if (f.bytes != null) {
            part = MultipartFile.fromBytes(f.bytes!, filename: f.name);
          } else {
            fail++;
            continue;
          }
        }

        FormData build(String field) => FormData.fromMap({
              'user_id': widget.id,
              'title': f.name,
              field: part,
            });

        DioException? lastErr;
        for (final field in const [
          'delivery_man_document',
          'document',
          'file',
          'image'
        ]) {
          try {
            await api.dio.post(kDocSavePath, data: build(field));
            lastErr = null;
            break;
          } on DioException catch (e) {
            lastErr = e;
            try {
              await api.dio.post(kDocSavePath, data: build(field));
              lastErr = null;
              break;
            } on DioException catch (e2) {
              lastErr = e2;
            }
          }
        }

        if (lastErr != null) {
          fail++;
          continue;
        }
        ok++;
      } catch (_) {
        fail++;
      }
    }

    await _reloadDocuments();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Yüklendi: $ok • Hata: $fail')),
    );
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final shortName =
        (_name.isEmpty ? '—' : _name).split(' ').take(2).join(' ');

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: kBg,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: kBlue, width: 1.6),
          ),
        ),
      ),
      child: Scaffold(
        appBar: _premiumAppBar(shortName),

        // ✅ KİTLENMEYEN body (bounded height fix)
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenH = MediaQuery.sizeOf(context).height;
              final appBarH =
                  kToolbarHeight + MediaQuery.of(context).padding.top;
              final boundedH = constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : (screenH - appBarH);

              return SizedBox(
                height: boundedH,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                              ? _errorState()
                              : _content(shortName),
                    ),
                    if (_error != null && !_loading)
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: _AlertBar(
                            tone: _AlertTone.danger,
                            title: "Hata",
                            message: _error!,
                            actionLabel: "Tekrar Dene",
                            onAction: _load,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _premiumAppBar(String shortName) {
    return AppBar(
      elevation: 0,
      backgroundColor: kBg,
      title: Text(
        'Kurye • Detay — $shortName',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: kText,
        ),
      ),
      leadingWidth: 118,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: _backPill(onTap: () => context.go('/couriers')),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(3),
        child: _loading
            ? const LinearProgressIndicator(minHeight: 3)
            : const SizedBox(height: 3),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: _Card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40, color: kRed),
              const SizedBox(height: 10),
              Text(
                _error ?? 'Bir hata oluştu',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(String shortName) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 1100;

        final left = _leftCard(shortName);
        final right = _rightPanel();

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 380, child: left),
                        const SizedBox(width: 14),
                        Expanded(child: right),
                      ],
                    )
                  : Column(
                      children: [
                        SizedBox(
                          height: 440,
                          child: SingleChildScrollView(child: left),
                        ),
                        const SizedBox(height: 14),
                        Expanded(child: right),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _leftCard(String shortName) {
    return _Card(
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: kBorder),
              gradient: LinearGradient(
                colors: [
                  kBlue.withOpacity(.18),
                  kGreen.withOpacity(.14),
                ],
              ),
            ),
            child: const Icon(Icons.delivery_dining, size: 48, color: kText),
          ),
          const SizedBox(height: 12),
          _statusChip(!_deleted),
          const SizedBox(height: 10),
          Text(
            shortName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: kText,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _phone.isEmpty ? '—' : _phone,
            style: const TextStyle(
              color: kBlue,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          _balanceCard(),
          const SizedBox(height: 12),
          _infoLine(icon: Icons.directions_bike, label: 'Plaka', value: _plate),
          const SizedBox(height: 8),
          _infoLine(
              icon: Icons.account_balance_outlined,
              label: 'IBAN',
              value: _iban),
          const SizedBox(height: 8),
          _infoLine(
              icon: Icons.person_outline,
              label: 'Hesap Sahibi',
              value: _bankOwner),
        ],
      ),
    );
  }

  Widget _balanceCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: _r12,
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Text(
            '${_balance.toStringAsFixed(2)} ₺',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: kText,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Bakiye',
            style: TextStyle(color: kMuted, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _rightPanel() {
    return _Card(
      child: DefaultTabController(
        length: 6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row + quick actions
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Detay Paneli',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: kText,
                    ),
                  ),
                ),
                _pillButton(
                  icon: Icons.power_settings_new,
                  label: _deleted ? 'Pasif' : 'Aktif',
                  color: _deleted ? kRed : kGreen,
                  onTap: _toggleActive,
                ),
                const SizedBox(width: 8),
                _pillButton(
                  icon: Icons.save_outlined,
                  label: 'Kaydet',
                  color: kBlue,
                  onTap: _saveProfile,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tabs
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: TabBar(
                isScrollable: true,
                labelColor: kText,
                unselectedLabelColor: kMuted,
                indicatorColor: kBlue,
                tabs: const [
                  Tab(icon: Icon(Icons.info_outline), text: 'Genel'),
                  Tab(icon: Icon(Icons.edit_square), text: 'Profil'),
                  Tab(icon: Icon(Icons.folder_copy_outlined), text: 'Belgeler'),
                  Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Hesap'),
                  Tab(
                      icon: Icon(Icons.account_balance_wallet_outlined),
                      text: 'Cüzdan'),
                  Tab(icon: Icon(Icons.lock_reset), text: 'Şifre'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Views
            Expanded(
              child: TabBarView(
                children: [
                  _tabGenel(context),
                  _tabProfilDuzenle(context),
                  _tabBelgeler(context),
                  _tabHesapOzeti(context),
                  _tabCuzdanOzeti(context),
                  _tabSifre(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- TABS ----------

  Widget _tabGenel(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _lr('ADI SOYADI', _name.isEmpty ? '—' : _name),
          _lr('TELEFON NUMARASI', _phone.isEmpty ? '—' : _phone, link: true),
          _lr('KAYIT TARİHİ', '—'),
          _lr('PLAKA', _plate),
          _lr('BANKA HESAP SAHİBİ AD SOYAD', _bankOwner, copy: true),
          _lr('IBAN NUMARASI', _iban, copy: true),
        ],
      ),
    );
  }

  Widget _tabProfilDuzenle(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Form(
        key: _editForm,
        child: Column(
          children: [
            _editField('ADI SOYADI *', _nameC, required: true),
            _editField('TELEFON NUMARASI *', _phoneC,
                required: true, hint: '(5xx) xxx xx xx'),
            _editField('PLAKA', _plateC),
            _editField('BANKA HESAP SAHİBİ AD SOYAD', _bankOwnerC),
            _editField('IBAN NUMARASI', _ibanC),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _saveProfile,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(
                  _loading ? 'Kaydediliyor...' : 'Kaydet',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: _r12),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBelgeler(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _uploadDocuments,
                icon: const Icon(Icons.upload_file),
                label: const Text('Belge Yükle',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: _r12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_documents.length} belge',
                style:
                    const TextStyle(color: kMuted, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          (_documents.isEmpty)
              ? const Text(
                  'Belge bulunamadı',
                  style: TextStyle(color: kMuted, fontWeight: FontWeight.w800),
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _documents.map((d) {
                    final title =
                        (d['name'] ?? d['title'] ?? 'Belge').toString();
                    final url = (d['url'] ?? d['path'] ?? '').toString();
                    final thumb = url;

                    return _docCard(
                      title: title,
                      onView: url.isEmpty ? null : () => _launchUrl(url),
                      onDownload: url.isEmpty ? null : () => _launchUrl(url),
                      child: Container(
                        width: 220,
                        height: 140,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: _r12,
                          border: Border.all(color: kBorder),
                        ),
                        child: (thumb.isEmpty)
                            ? const Icon(Icons.insert_drive_file_outlined,
                                size: 44, color: kMuted)
                            : Image.network(
                                thumb,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.insert_drive_file_outlined,
                                  size: 44,
                                  color: kMuted,
                                ),
                              ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _tabHesapOzeti(BuildContext context) {
    final rows = [
      ['Tarih', 'İşlem', 'Tutar'],
      ..._accountRows,
    ];
    return _sectionTable('Hesap Özeti', rows);
  }

  Widget _tabCuzdanOzeti(BuildContext context) {
    final rows = [
      ['Tarih', 'Açıklama', 'Tutar'],
      ..._walletRows,
    ];
    return _sectionTable('Cüzdan Özeti', rows);
  }

  Widget _tabSifre(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_deleted)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AlertBar(
                tone: _AlertTone.info,
                title: "Uyarı",
                message: "Bu kurye şu anda pasif.",
                actionLabel: "Aktif Yap",
                onAction: _toggleActive,
              ),
            ),
          TextFormField(
            enabled: false,
            initialValue: '******',
            decoration: const InputDecoration(
              labelText: 'Mevcut Şifre',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _pass1,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Yeni Şifre',
              prefixIcon: Icon(Icons.lock_reset_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _pass2,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Şifreyi Tekrar Giriniz',
              prefixIcon: Icon(Icons.lock_reset_rounded),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (_pass1.text.isEmpty || _pass1.text != _pass2.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Şifreler eşleşmiyor.')),
                  );
                  return;
                }
                try {
                  final api = context.read<ApiClient>();
                  final p = kChangePasswordPath(widget.id);
                  try {
                    await api.dio.post(p, data: {'password': _pass1.text});
                  } on Exception {
                    await api.dio
                        .post('api/$p', data: {'password': _pass1.text});
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Şifre güncellendi.')),
                  );
                  _pass1.clear();
                  _pass2.clear();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Hata: $e')));
                  }
                }
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Kaydet',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: _r12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- UI helpers ----------

  Widget _statusChip(bool active) {
    final color = active ? kGreen : kRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active ? Icons.check_circle_outline : Icons.pause_circle_outline,
              size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            active ? 'Aktif' : 'Pasif',
            style: TextStyle(fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backPill({required VoidCallback onTap}) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        side: const BorderSide(color: kBorder),
        backgroundColor: Colors.white,
      ),
      onPressed: onTap,
      icon: const Icon(Icons.chevron_left, color: kText),
      label: const Text('Geri',
          style: TextStyle(fontWeight: FontWeight.w900, color: kText)),
    );
  }

  Widget _lr(String label, String value,
      {bool link = false, bool copy = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: kMuted,
                fontWeight: FontWeight.w900,
                letterSpacing: .3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: link
                      ? InkWell(
                          onTap: () =>
                              _launchUrl('tel:${value.replaceAll(' ', '')}'),
                          child: Text(
                            value,
                            style: const TextStyle(
                              color: kBlue,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                      : Text(
                          value,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: kText,
                          ),
                        ),
                ),
                if (copy) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: value.trim().isEmpty || value == '—'
                        ? null
                        : () async {
                            await Clipboard.setData(
                              ClipboardData(text: value.trim()),
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Kopyalandı')),
                              );
                            }
                          },
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                    label: const Text('Kopyala'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: _r12),
                      side: const BorderSide(color: kBorder),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editField(
    String label,
    TextEditingController controller, {
    bool required = false,
    String? hint,
    bool obscure = false,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 260,
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: kMuted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.info_outline, size: 16, color: kMuted),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: controller,
              enabled: enabled,
              obscureText: obscure,
              validator: required
                  ? (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu' : null
                  : null,
              decoration: InputDecoration(hintText: hint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _docCard({
    required String title,
    required Widget child,
    VoidCallback? onView,
    VoidCallback? onDownload,
  }) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, color: kText)),
          const SizedBox(height: 10),
          child,
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onView,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBlue.withOpacity(.12),
                    foregroundColor: kBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: _r12),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Görüntüle',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onDownload,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: _r12),
                    side: const BorderSide(color: kBorder),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('İndir',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTable(String title, List<List<String>> rows) {
    final headers = rows.first;
    final body = rows.skip(1).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: kText,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          _premiumTable(headers: headers, rows: body),
        ],
      ),
    );
  }

  Widget _premiumTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: kBorder),
        borderRadius: _r12,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 42,
          dataRowMinHeight: 46,
          dataRowMaxHeight: 52,
          columns: headers
              .map(
                (h) => DataColumn(
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      h,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: kMuted,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
          rows: rows
              .map(
                (r) => DataRow(
                  cells: r
                      .map(
                        (c) => DataCell(
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              c,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: kText,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _infoLine({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: _r12,
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: kMuted),
          const SizedBox(width: 10),
          SizedBox(
            width: 105,
            child: Text(
              label,
              style:
                  const TextStyle(color: kMuted, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: kText, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    // url_launcher kullanacaksan burada aç.
    // (Sende yorumlu bırakılmıştı, aynı şekilde bıraktım.)
  }
}

// ====== UI BİLEŞENLERİ (premium) ======

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  static const Color kBorder = Color(0xFFE6E8F2);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

enum _AlertTone { danger, info }

class _AlertBar extends StatelessWidget {
  final _AlertTone tone;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _AlertBar({
    required this.tone,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final Color c = tone == _AlertTone.danger
        ? const Color(0xFFEF4444)
        : const Color(0xFF0EA5E9);

    return Material(
      color: c.withOpacity(.10),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withOpacity(.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: c),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "$title: $message",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}
