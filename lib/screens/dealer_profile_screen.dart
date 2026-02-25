// lib/screens/dealer_profile_screen.dart

import 'dart:ui' show FontFeature;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:haldeki_admin_web/screens/profile_ui.dart';
import 'package:provider/provider.dart';

import '../models/dealer_profile.dart';
import '../services/api_client.dart';
import 'haldeki_ui.dart';

class DealerProfileScreen extends StatefulWidget {
  const DealerProfileScreen({super.key});

  @override
  State<DealerProfileScreen> createState() => _DealerProfileScreenState();
}

class _DealerProfileScreenState extends State<DealerProfileScreen>
    with SingleTickerProviderStateMixin {
  DealerProfile? _profile;
  bool _loading = true;
  String? _error;

  late TabController _tabController;

  // ---- PROFİL FORM CONTROLLER’LARI ----
  final _phoneC = TextEditingController();
  final _vehiclePlateC = TextEditingController();
  final _ibanC = TextEditingController();
  final _cityC = TextEditingController();
  final _districtC = TextEditingController();
  final _addressC = TextEditingController();

  bool _savingProfile = false;

  // ---- ŞİFRE FORMU ----
  final _oldPwC = TextEditingController();
  final _newPwC = TextEditingController();
  final _newPw2C = TextEditingController();
  bool _changingPw = false;

  // ---- BELGE YÜKLEME ----
  bool _uploadingDoc = false;
  String _selectedDocType = 'ikametgah';
  final List<_UploadedDoc> _docs = [];

  @override
  void initState() {
    super.initState();
    // ✅ SENDE HATA VARDI: 4 TAB var → length 4 olmalı
    _tabController = TabController(length: 4, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneC.dispose();
    _vehiclePlateC.dispose();
    _ibanC.dispose();
    _cityC.dispose();
    _districtC.dispose();
    _addressC.dispose();
    _oldPwC.dispose();
    _newPwC.dispose();
    _newPw2C.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final p = await api.fetchMyProfile();
      setState(() {
        _profile = p;
        _initFormFromProfile(p);
      });
    } catch (e) {
      setState(() => _error = 'Profil yüklenemedi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _initFormFromProfile(DealerProfile p) {
    _phoneC.text = p.phone ?? '';
    _vehiclePlateC.text = p.vehiclePlate ?? '';
    _ibanC.text = p.iban ?? '';
    _cityC.text = p.city ?? '';
    _districtC.text = p.district ?? '';
    _addressC.text = p.address ?? '';
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return dt.toIso8601String().substring(0, 10);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themed = HaldekiUI.withRectButtons(context, cs).copyWith(
      scaffoldBackgroundColor: ProfileUiTokens.bg,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ProfileUiTokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ProfileUiTokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ProfileUiTokens.blue, width: 1.6),
        ),
      ),
    );

    return Theme(
      data: themed,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: ProfileUiTokens.bg,
          title: const Text(
            'Bayi • Profil',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: ProfileUiTokens.text,
            ),
          ),
          actions: [
            IconButton(
              tooltip: "Yenile",
              onPressed: _loading ? null : _loadProfile,
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text(
                'Geri',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: _loading
                ? const LinearProgressIndicator(minHeight: 3)
                : const SizedBox(height: 3),
          ),
        ),
        body: Stack(
          children: [
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_profile == null && _error == null)
              const Center(child: Text('Profil bulunamadı'))
            else if (_profile == null && _error != null)
              const SizedBox.shrink()
            else
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 1100;
                  final p = _profile!;

                  final left = _buildLeftPremiumCard(context, p);
                  final right = _buildRightPremiumPanel(context, p);

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
                                  SizedBox(width: 420, child: left),
                                  const SizedBox(width: 14),
                                  Expanded(child: right),
                                ],
                              )
                            : ListView(
                                children: [
                                  left,
                                  const SizedBox(height: 14),
                                  right,
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),

            // ✅ Supplier’daki gibi üst hata bandı
            if (_error != null)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ProfileAlertBar(
                    tone: ProfileAlertTone.danger,
                    title: "Hata",
                    message: _error!,
                    actionLabel: "Tekrar Dene",
                    onAction: _loadProfile,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SOL KART (Supplier mantığı: avatar + chips + quick info)
  // ---------------------------------------------------------------------------

  Widget _buildLeftPremiumCard(BuildContext context, DealerProfile p) {
    final isActive = p.isActive;
    final statusColor = isActive ? ProfileUiTokens.green : ProfileUiTokens.red;
    final initials = _initials(p.name);

    return ProfileSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // avatar + ad + chipler
          Row(
            children: [
              _avatar(initials),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: ProfileUiTokens.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip(
                          icon: Icons.verified_outlined,
                          label: isActive ? "Durum: Aktif" : "Durum: Pasif",
                          color: statusColor,
                        ),
                        if ((p.vehiclePlate ?? '').isNotEmpty)
                          _chip(
                            icon: Icons.directions_car_outlined,
                            label: "Plaka: ${p.vehiclePlate}",
                            color: ProfileUiTokens.blue,
                          ),
                        if ((p.iban ?? '').isNotEmpty)
                          _chip(
                            icon: Icons.account_balance_outlined,
                            label: "IBAN: Kayıtlı",
                            color: ProfileUiTokens.amber,
                          ),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          ProfileInfoLine(
            icon: Icons.phone_outlined,
            label: "Telefon",
            value: p.phone ?? "—",
          ),
          const SizedBox(height: 8),
          ProfileInfoLine(
            icon: Icons.location_on_outlined,
            label: "Adres",
            value: (p.address ?? '').isNotEmpty ? p.address! : "—",
          ),
          const SizedBox(height: 8),
          ProfileInfoLine(
            icon: Icons.calendar_month_outlined,
            label: "Kayıt",
            value: _formatDate(p.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String initials) {
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ProfileUiTokens.border),
        gradient: LinearGradient(
          colors: [
            ProfileUiTokens.blue.withOpacity(.18),
            ProfileUiTokens.green.withOpacity(.14),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Center(
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: ProfileUiTokens.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SAĞ PANEL (Supplier mantığı: tek büyük SectionCard içinde tablar)
  // ---------------------------------------------------------------------------

  Widget _buildRightPremiumPanel(BuildContext context, DealerProfile p) {
    final cs = Theme.of(context).colorScheme;

    return ProfileSectionCard(
      title: "Bayi Detay — ${p.name}",
      subtitle: "Profil • Belgeler • Şifre",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: ProfileUiTokens.blue,
            unselectedLabelColor: ProfileUiTokens.muted,
            indicatorColor: ProfileUiTokens.blue,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: 'Genel'),
              Tab(text: 'Profil'),
              Tab(text: 'Belgeler'),
              Tab(text: 'Şifre'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height:
                640, // geniş panel yüksekliği; istersen LayoutBuilder ile dinamik yaparız
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabGenel(context, p),
                _buildTabProfil(context, p),
                _buildTabBelgeler(context),
                _buildTabSifre(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB: GENEL (read-only)
  // ---------------------------------------------------------------------------

  Widget _buildTabGenel(BuildContext context, DealerProfile p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, right: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Genel Bilgiler'),
          const SizedBox(height: 8),
          _infoRow('ADI SOYADI', p.name),
          _infoRow('TELEFON NUMARASI', p.phone ?? '—'),
          _infoRow('KAYIT TARİHİ', _formatDate(p.createdAt)),
          _infoRow('PLAKA', p.vehiclePlate ?? '—'),
          const SizedBox(height: 12),
          _sectionTitle('Banka Bilgileri'),
          const SizedBox(height: 8),
          _infoRowWithCopy('BANKA HESAP SAHİBİ AD SOYAD', p.name),
          _infoRowWithCopy('IBAN NUMARASI', p.iban ?? '—'),
          const SizedBox(height: 12),
          _sectionTitle('Durum'),
          const SizedBox(height: 8),
          _infoRow('Aktiflik', p.isActive ? 'Aktif' : 'Pasif'),
          _infoRow('Durum Kodu', (p.status ?? 0).toString()),
          _infoRow(
            'Komisyon',
            p.commissionRate == null
                ? '—'
                : '${p.commissionRate!.toStringAsFixed(2)} ${p.commissionType ?? '%'}',
          ),
          _infoRow('Hadi Hesabı', p.hasHadiAccount ? 'Var' : 'Yok'),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB: PROFİL (editlenebilir form)
  // ---------------------------------------------------------------------------

  Widget _buildTabProfil(BuildContext context, DealerProfile p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, right: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('İletişim'),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneC,
            decoration: const InputDecoration(
              labelText: 'Telefon Numarası',
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _sectionTitle('Adres Bilgileri'),
          const SizedBox(height: 8),
          TextField(
            controller: _cityC,
            decoration: const InputDecoration(labelText: 'Şehir'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _districtC,
            decoration: const InputDecoration(labelText: 'İlçe'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _addressC,
            decoration: const InputDecoration(labelText: 'Adres'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          _sectionTitle('Araç / Banka'),
          const SizedBox(height: 8),
          TextField(
            controller: _vehiclePlateC,
            decoration: const InputDecoration(labelText: 'Plaka'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ibanC,
            decoration: const InputDecoration(labelText: 'IBAN'),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _savingProfile ? null : () => _saveProfile(p),
              icon: _savingProfile
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _savingProfile ? 'Kaydediliyor...' : 'Kaydet',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ProfileUiTokens.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile(DealerProfile p) async {
    setState(() => _savingProfile = true);
    try {
      final api = context.read<ApiClient>();

      final payload = <String, dynamic>{
        'id': p.id,
        'phone': _phoneC.text.trim(),
        'city': _cityC.text.trim(),
        'district': _districtC.text.trim(),
        'address': _addressC.text.trim(),
        'vehicle_plate': _vehiclePlateC.text.trim(),
        'iban': _ibanC.text.trim(),
      };

      final updated = await api.updateMyProfile(payload);
      setState(() => _profile = updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil güncellendi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil güncellenemedi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  // ---------------------------------------------------------------------------
  // TAB: BELGELER
  // ---------------------------------------------------------------------------

  Widget _buildTabBelgeler(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Belgeler'),
        const SizedBox(height: 8),
        Row(
          children: [
            DropdownButton<String>(
              value: _selectedDocType,
              items: const [
                DropdownMenuItem(value: 'ikametgah', child: Text('İkametgah')),
                DropdownMenuItem(
                    value: 'nufus_cuzdani',
                    child: Text('Kimlik / Nüfus Cüzdanı')),
                DropdownMenuItem(value: 'sabıka', child: Text('Adli Sicil')),
                DropdownMenuItem(
                    value: 'ehliyet', child: Text('Vergi Levhası')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _selectedDocType = v);
              },
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _uploadingDoc ? null : _pickAndUploadDocument,
              icon: _uploadingDoc
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: const Text('Belge Yükle',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(
                backgroundColor: ProfileUiTokens.amber,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _docs.isEmpty
              ? Center(
                  child: Text(
                    'Henüz herhangi bir belge yüklenmemiş.',
                    style: TextStyle(color: cs.tertiary),
                  ),
                )
              : ListView.separated(
                  itemCount: _docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final d = _docs[i];
                    return ListTile(
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(d.title),
                      subtitle: Text(d.typeLabel),
                      trailing: Text(
                        _formatDate(d.createdAt),
                        style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _mapDocTypeForApi(String uiValue) {
    // uiValue burada aslında key: ikametgah / nufus_cuzdani / sabıka / ehliyet
    switch (uiValue) {
      case 'ikametgah':
        return 'residence';
      case 'nufus_cuzdani':
        return 'identity_card';
      case 'sabıka':
        return 'good_conduct';
      case 'ehliyet':
        return 'tax_plate';
      default:
        return 'residence';
    }
  }

  Future<void> _pickAndUploadDocument() async {
    try {
      setState(() => _uploadingDoc = true);

      final res = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (res == null || res.files.isEmpty) {
        setState(() => _uploadingDoc = false);
        return;
      }

      final file = res.files.first;
      final Uint8List? bytes = file.bytes;
      if (bytes == null) throw 'Dosya içeriği okunamadı (bytes null).';

      final api = context.read<ApiClient>();
      await api.uploadProfileDocument(
        type: _mapDocTypeForApi(_selectedDocType),
        fileName: file.name,
        bytes: bytes,
      );

      setState(() {
        _docs.add(_UploadedDoc(
          title: file.name,
          type: _selectedDocType,
          createdAt: DateTime.now(),
        ));
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Belge yüklendi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Belge yüklenemedi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingDoc = false);
    }
  }

  // ---------------------------------------------------------------------------
  // TAB: ŞİFRE
  // ---------------------------------------------------------------------------

  Widget _buildTabSifre(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, right: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Şifre Değiştir'),
          const SizedBox(height: 8),
          TextField(
            controller: _oldPwC,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mevcut Şifre',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newPwC,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Yeni Şifre',
              prefixIcon: Icon(Icons.lock_reset_rounded),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newPw2C,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Yeni Şifre (Tekrar)',
              prefixIcon: Icon(Icons.lock_reset_rounded),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _changingPw ? null : _changePassword,
              icon: _changingPw
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Şifreyi Güncelle',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(
                backgroundColor: ProfileUiTokens.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final oldPw = _oldPwC.text.trim();
    final newPw = _newPwC.text.trim();
    final newPw2 = _newPw2C.text.trim();

    if (oldPw.isEmpty || newPw.isEmpty || newPw2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldurun')),
      );
      return;
    }
    if (newPw != newPw2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yeni şifreler uyuşmuyor')),
      );
      return;
    }

    setState(() => _changingPw = true);
    try {
      final api = context.read<ApiClient>();
      await api.changePassword(oldPw, newPw);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şifre başarıyla güncellendi')),
        );
        _oldPwC.clear();
        _newPwC.clear();
        _newPw2C.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Şifre güncellenemedi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _changingPw = false);
    }
  }

  // ---------------------------------------------------------------------------
  // GENEL HELPER’LAR (senin mevcutlar)
  // ---------------------------------------------------------------------------

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: cs.tertiary,
                letterSpacing: .4,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRowWithCopy(String label, String value) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: cs.tertiary,
                letterSpacing: .4,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: value == '—'
                      ? null
                      : () async {
                          await Clipboard.setData(
                              ClipboardData(text: value.trim()));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$label kopyalandı'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Kopyala'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Basit lokal belge modeli
class _UploadedDoc {
  final String title;
  final String type;
  final DateTime createdAt;

  _UploadedDoc({
    required this.title,
    required this.type,
    required this.createdAt,
  });

  String get typeLabel {
    switch (type) {
      case 'ikametgah':
        return 'İkametgah';
      case 'nufus_cuzdani':
        return 'Kimlik / Nüfus Cüzdanı';
      case 'sabıka':
        return 'Adli Sicil';
      case 'ehliyet':
        return 'Vergi Levhası';
      default:
        return type;
    }
  }
}
