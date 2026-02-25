// lib/screens/supplier_profile_screen.dart
import 'package:flutter/material.dart';
import '../services/api_client.dart';

class SupplierProfileScreen extends StatefulWidget {
  final ApiClient api;
 
  const SupplierProfileScreen({
    super.key,
    required this.api,
 
  });

  @override
  State<SupplierProfileScreen> createState() => _SupplierProfileScreenState();
}

class _SupplierProfileScreenState extends State<SupplierProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  bool _loading = true;
  String? _error;

  // ------ PROFİL BİLGİLERİ
  String name = '—';
  String? email;
  String? phone;
  String? address;
  String? appVersion;
  String? appSource;
  bool notificationsEnabled = false;
  String? avatarUrl;

  // ------ METRİKLER
  num walletBalance = 0;
  num totalWithdraw = 0;
  num adminCommission = 0;
  num commission = 0;
  int totalOrders = 0;
  int paidOrders = 0;

  // ------ BANKA
  String? bankName;
  String? bankHolder;
  String? bankAccountNumber;
  String? ibanOrIfsc;

  // ------ KONUM
  double? lastLat;
  double? lastLng;

  // ------ FORMLAR
  final _formAccount = GlobalKey<FormState>();
  final _formAddress = GlobalKey<FormState>();

  // Account controllers
  final _emailC = TextEditingController();
  final _phoneC = TextEditingController();
  final _passwordC = TextEditingController();
  final _password2C = TextEditingController();

  // Address controllers
  final _addressC = TextEditingController();
  final _cityC = TextEditingController();
  final _districtC = TextEditingController();
  final _postalC = TextEditingController();

  bool _savingAccount = false;
  bool _savingAddress = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  //  _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _emailC.dispose();
    _phoneC.dispose();
    _passwordC.dispose();
    _password2C.dispose();
    _addressC.dispose();
    _cityC.dispose();
    _districtC.dispose();
    _postalC.dispose();
    super.dispose();
  }
/*
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Backend: supplier detail
      final json =
          await widget.api.getJson('api/suppliers/${widget.supplierId}');
      final map = (json['data'] ?? json) as Map<String, dynamic>;

      name = (map['name'] ?? '—') as String;
      email = map['email'] as String?;
      phone = map['phone'] as String?;
      address = map['address'] as String?;
      appVersion = map['app_version'] as String?;
      appSource = map['app_source'] as String?;
      notificationsEnabled =
          (map['notifications'] == true) || (map['notifications_enabled'] == true);
      avatarUrl = (map['logo_path'] ?? map['avatar'] ?? map['image']) as String?;

      walletBalance = _num(map['wallet_balance']);
      totalWithdraw = _num(map['total_withdraw']);
      adminCommission = _num(map['admin_commission']);
      commission = _num(map['commission']);
      totalOrders = _int(map['total_orders']);
      paidOrders = _int(map['paid_orders']);

      final bank = (map['bank'] ?? map['bank_info']) as Map<String, dynamic>?;
      bankName = (bank?['bank_name'] ?? bank?['name']) as String?;
      bankHolder = (bank?['account_holder'] ?? bank?['holder']) as String?;
      bankAccountNumber = (bank?['account_number'] ?? bank?['number']) as String?;
      ibanOrIfsc = (bank?['iban'] ?? bank?['ifsc']) as String?;

      final loc = (map['last_location'] ?? map['location']) as Map<String, dynamic>?;
      lastLat = _double(loc?['lat'] ?? loc?['latitude'] ?? map['lat']);
      lastLng = _double(loc?['lng'] ?? loc?['longitude'] ?? map['lng']);

      // Formlara doldur
      _emailC.text = email ?? '';
      _phoneC.text = phone ?? '';
      _addressC.text = address ?? '';
      _cityC.text = (map['city'] as String?) ?? '';
      _districtC.text = (map['district'] as String?) ?? '';
      _postalC.text = (map['postal_code'] as String?) ?? '';
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAccount() async {
    if (!_formAccount.currentState!.validate()) return;
    if (_passwordC.text.isNotEmpty && _passwordC.text != _password2C.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şifreler uyuşmuyor')),
      );
      return;
    }
    setState(() => _savingAccount = true);
    try {
      final body = {
        'email': _emailC.text.trim(),
        'phone': _phoneC.text.trim(),
        if (_passwordC.text.isNotEmpty) 'password': _passwordC.text,
      };
      await widget.api.postJson(
        'api/suppliers/${widget.supplierId}/update-account',
        body,
      );
      email = _emailC.text.trim();
      phone = _phoneC.text.trim();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hesap bilgileri kaydedildi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingAccount = false);
    }
  }

  Future<void> _saveAddress() async {
    if (!_formAddress.currentState!.validate()) return;
    setState(() => _savingAddress = true);
    try {
      final body = {
        'address': _addressC.text.trim(),
        'city': _cityC.text.trim(),
        'district': _districtC.text.trim(),
        'postal_code': _postalC.text.trim(),
      };
      await widget.api.postJson(
        'api/suppliers/${widget.supplierId}/update-address',
        body,
      );
      address = _addressC.text.trim();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adres bilgileri kaydedildi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingAddress = false);
    }
  }
*/
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 1100;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bayi • Profil'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Geri'),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Düzenleme (örnek)')),
              );
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Düzenlemek'),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sil (örnek)')),
              );
            },
            icon: const Icon(Icons.delete, color: Colors.red, size: 18),
            label: const Text('Silmek'),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBar(
                controller: _tabs,
                tabs: const [
                  Tab(text: ''),
               //   Tab(text: 'Wallet'),
              //    Tab(text: 'Earning'),
                ],
              ),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabs,
            children: [
              _buildProfileTab(wide),
          //    _buildWalletTab(),
      //       _buildEarningTab(),
            ],
          ),
          if (_error != null)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Material(
                  elevation: 2,
                  color: Colors.red.withOpacity(.10),
                  borderRadius: BorderRadius.circular(10),
                  child: ListTile(
                    leading:
                        const Icon(Icons.error_outline, color: Colors.red),
                    title: Text('Hata: $_error'),
                    trailing: TextButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tekrar Dene'),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- PROFILE TAB ----------
  Widget _buildProfileTab(bool wide) {
    final left = _profileCard();
    final right = Column(
      children: [
     //   _metricsRow(),
    //    const SizedBox(height: 16),
        _accountCard(), // yeni
        const SizedBox(height: 16),
        _addressCard(), // yeni
//        const SizedBox(height: 16),
    //    _bankCard(),
   //     const SizedBox(height: 16),
   //     _locationCard(),
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 380, child: left),
                const SizedBox(width: 16),
                Expanded(child: right),
              ],
            )
          : ListView(
              children: [
                left,
                const SizedBox(height: 16),
                right,
              ],
            ),
    );
  }

  // SOL PROFİL KARTI
  Widget _profileCard() {
    return _SectionCard(
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                child: avatarUrl == null
                    ? const Icon(Icons.person, size: 44)
                    : null,
              ),
              const SizedBox(width: 16),
         /*     Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.location_pin),
                          label: const Text('Olanak vermek'),
                        ),
                        OutlinedButton(
                          onPressed: () {},
                          child: const Text('Doğrulayın'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
           */ ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 6),
          _InfoRow(icon: Icons.mail_outline, text: email ?? '—'),
          _InfoRow(icon: Icons.phone_outlined, text: phone ?? '—'),
          _InfoRow(icon: Icons.location_on_outlined, text: address ?? '—'),
          _InfoRow(
              icon: Icons.build_outlined,
              text: 'Uygulama sürümü  ${appVersion ?? '—'}'),
          _InfoRow(
              icon: Icons.download_outlined,
              text: 'Uygulama Kaynağı  ${appSource ?? '—'}'),
          _InfoRow(
            icon: Icons.notifications_active_outlined,
            text:
                'Bildirimle Yapılandırıldı  ${notificationsEnabled ? 'Evet' : 'Hayır'}',
            iconColor: notificationsEnabled ? Colors.green : null,
          ),
        ],
      ),
    );
  }

  // METRİK KUTULARI
  Widget _metricsRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricTile(
            title: 'Cüzdan Toplam Bakiyesi',
            value: '₺ ${_money(walletBalance)}'),
        _MetricTile(
            title: 'Toplam geri çekilme',
            value: '₺ ${_money(totalWithdraw)}'),
        _MetricTile(
            title: 'Yönetici komisyonu',
            value: '₺ ${_money(adminCommission)}'),
        _MetricTile(title: 'komisyon', value: '₺ ${_money(commission)}'),
        _MetricTile(title: 'Genel sipariş toplamı', value: '$totalOrders'),
        _MetricTile(title: 'Ücretli Emir', value: '$paidOrders'),
      ],
    );
  }

  // HESAP BİLGİLERİ FORMU
  Widget _accountCard() {
    return _SectionCard(
      title: 'Hesap Bilgileri',
      child: Form(
        key: _formAccount,
        child: Column(
          children: [
            TextFormField(
              controller: _emailC,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'E-posta gerekli';
                if (!t.contains('@')) return 'Geçerli bir e-posta girin';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneC,
              decoration: const InputDecoration(
                labelText: 'Telefon',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Telefon gerekli' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordC,
              decoration: const InputDecoration(
                labelText: 'Yeni Şifre (opsiyonel)',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password2C,
              decoration: const InputDecoration(
                labelText: 'Yeni Şifre (tekrar)',
                prefixIcon: Icon(Icons.lock_reset_outlined),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _savingAccount ? null : null,
                icon: const Icon(Icons.save_outlined),
                label: _savingAccount
                    ? const Text('Kaydediliyor...')
                    : const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ADRES FORMU
  Widget _addressCard() {
    return _SectionCard(
      title: 'Adres Bilgileri',
      child: Form(
        key: _formAddress,
        child: Column(
          children: [
            TextFormField(
              controller: _addressC,
              decoration: const InputDecoration(
                labelText: 'Adres',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              minLines: 2,
              maxLines: 4,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Adres gerekli' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityC,
                    decoration: const InputDecoration(
                      labelText: 'Şehir',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Şehir' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _districtC,
                    decoration: const InputDecoration(
                      labelText: 'İlçe',
                      prefixIcon: Icon(Icons.apartment_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'İlçe' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _postalC,
              decoration: const InputDecoration(
                labelText: 'Posta Kodu',
                prefixIcon: Icon(Icons.local_post_office_outlined),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _savingAddress ? null : null,
                icon: const Icon(Icons.save_outlined),
                label: _savingAddress
                    ? const Text('Kaydediliyor...')
                    : const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // BANKA DETAYLARI
  Widget _bankCard() {
    return _SectionCard(
      title: 'Banka detayları',
      child: Column(
        children: [
          _KVRow('Banka adı', bankName ?? '—', boldValue: true),
          _KVRow('banka hesap sahibinin adı', bankHolder ?? '—', boldValue: true),
          _KVRow('Banka hesabı numarası', bankAccountNumber ?? '—', boldValue: true),
          const SizedBox(height: 8),
          _KVRow('Banka IBAN/IFSC Kodu', ibanOrIfsc ?? '—', mono: true),
        ],
      ),
    );
  }

  // SON KONUM
  Widget _locationCard() {
    return _SectionCard(
      title: 'Son Konum',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _MetricTile(title: 'Enlem', value: lastLat?.toString() ?? '—'),
          _MetricTile(title: 'Boylam', value: lastLng?.toString() ?? '—'),
        ],
      ),
    );
  }

  // WALLET / EARNING placeholder
  Widget _buildWalletTab() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Wallet: cüzdan hareketleri, çekim talepleri vb. tablo/grafik ile bağlanacak.',
            textAlign: TextAlign.center,
          ),
        ),
      );

  Widget _buildEarningTab() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Earning: tarih filtreli kazanç grafiği ve özet kutucuklar.',
            textAlign: TextAlign.center,
          ),
        ),
      );

  // ---- helpers
  num _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  double? _double(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String _money(num v) => v.toStringAsFixed(2);
}

// ====== UI küçük bileşenler ======

class _SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  const _SectionCard({this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withOpacity(.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Text(title!,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  const _MetricTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 240,
      height: 92,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outlineVariant.withOpacity(.6)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style:
                      const TextStyle(fontSize: 13, color: Colors.black54)),
              const Spacer(),
              Text(value,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _KVRow extends StatelessWidget {
  final String k;
  final String v;
  final bool mono;
  final bool boldValue;
  const _KVRow(this.k, this.v, {this.mono = false, this.boldValue = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 260,
              child: Text(k, style: const TextStyle(color: Colors.black54))),
          Expanded(
            child: Text(
              v,
              style: TextStyle(
                fontWeight: boldValue ? FontWeight.w700 : FontWeight.w600,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? iconColor;
  const _InfoRow({required this.icon, required this.text, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor),
      title: Text(text),
    );
    }
}
