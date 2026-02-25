import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:haldeki_admin_web/utils/message_screen.dart';

import '../../models/models.dart';
import '../../services/api_client.dart';

class UserCreateScreen extends StatefulWidget {
  final ApiClient api; // dışarıdan enjekte (Base URL burada)
  const UserCreateScreen({super.key, required this.api});

  @override
  State<UserCreateScreen> createState() => _UserCreateScreenState();
}

class _UserCreateScreenState extends State<UserCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  // form alanları
  bool isCourier = true; // true: Kurye, false: İşletme
  final nameC = TextEditingController();
  final emailC = TextEditingController();
  final passC = TextEditingController();
  final userC = TextEditingController();
  final phoneC = TextEditingController();
  final addrC = TextEditingController();
  final latC = TextEditingController();
  final lngC = TextEditingController();

  List<Country> countries = [];
  List<City> cities = [];
  int? selectedCountryId;
  int? selectedCityId;

  // evrak dosyaları
  List<File> documents = [];

  // cüzdan
  UserMinimal? createdUser;
  Wallet? wallet;
  final topupAmountC = TextEditingController();
  final topupNoteC = TextEditingController();

  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    try {
      final L = await widget.api.fetchCountries();
      setState(() => countries = L);
    } catch (e) {
      _snack('Ülkeler alınamadı: $e');
    }
  }

  Future<void> _loadCities() async {
    if (selectedCountryId == null) {
      setState(() => cities = []);
      return;
    }
    try {
      final L = await widget.api.fetchCities(countryId: selectedCountryId);
      setState(() => cities = L);
    } catch (e) {
      _snack('Şehirler alınamadı: $e');
    }
  }

  Future<void> _pickDocuments() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res != null && res.files.isNotEmpty) {
      final files = <File>[];
      for (final f in res.files) {
        final path = f.path;
        if (path != null) files.add(File(path));
      }
      setState(() => documents = files);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      final u = await widget.api.createUser(
        userType: 'user',
        isCourier: isCourier,
        name: nameC.text.trim(),
        email: emailC.text.trim(),
        password: passC.text,
        username: userC.text.trim().isEmpty ? null : userC.text.trim(),
        contactNumber: phoneC.text.trim().isEmpty ? null : phoneC.text.trim(),
        countryId: selectedCountryId,
        cityId: selectedCityId,
        address: addrC.text.trim().isEmpty ? null : addrC.text.trim(),
        latitude: latC.text.trim().isEmpty ? null : latC.text.trim(),
        longitude: lngC.text.trim().isEmpty ? null : lngC.text.trim(),
        documents: documents.isEmpty ? null : documents,
      );
      setState(() => createdUser = u);

      Navigator.of(context).pop(true);

      // cüzdan çek
      try {
        final w = await widget.api.getWallet(u.id);
        setState(() => wallet = w);
      } catch (_) {/* cüzdan yoksa sorun değil */}
    } catch (e) {
      _snack('Kayıt başarısız: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _topUp() async {
    if (createdUser == null) return;
    final txt = topupAmountC.text.trim();
    if (txt.isEmpty) return;
    final amount = num.tryParse(txt);
    if (amount == null || amount <= 0) {
      _snack('Geçerli bir tutar gir');

      return;
    }
    setState(() => loading = true);
    try {
      final w = await widget.api.topUpWallet(
        userId: createdUser!.id,
        amount: amount,
        note: topupNoteC.text.trim().isEmpty ? null : topupNoteC.text.trim(),
      );
      setState(() => wallet = w);
      _snack('Cüzdan yüklendi. Yeni bakiye: ${w.balance}');
    } catch (e) {
      _snack('Yükleme başarısız: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  void dispose() {
    nameC.dispose();
    emailC.dispose();
    passC.dispose();
    userC.dispose();
    phoneC.dispose();
    addrC.dispose();
    latC.dispose();
    lngC.dispose();
    topupAmountC.dispose();
    topupNoteC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Kurye / İşletme Ekle + Cüzdan')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildTypeSwitcher(theme),
                const SizedBox(height: 12),
                _buildFormCard(theme),
                const SizedBox(height: 16),
                _buildWalletCard(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSwitcher(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: const Text('Kurye'),
          selected: isCourier,
          onSelected: (_) => setState(() => isCourier = true),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('İşletme'),
          selected: !isCourier,
          onSelected: (_) => setState(() => isCourier = false),
        ),
      ],
    );
  }

  Widget _buildFormCard(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _tf(nameC, 'Ad Soyad / Ünvan', validator: _req),
                  _tf(emailC, 'E-posta',
                      keyboard: TextInputType.emailAddress, validator: _req),
                  _tf(passC, 'Şifre', obscure: true, validator: _req),
                  _tf(userC, 'Kullanıcı adı '),
                  _tf(phoneC, 'Telefon ', keyboard: TextInputType.phone),
                  _countryCityRow(),
                  _ta(addrC, 'Adres '),
                  Row(
                    children: [
                      Expanded(child: _tf(latC, 'Latitude (ops.)')),
                      const SizedBox(width: 12),
                      Expanded(child: _tf(lngC, 'Longitude (ops.)')),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickDocuments,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Evrak Yükle'),
                      ),
                      const SizedBox(width: 12),
                      Text('${documents.length} dosya seçildi'),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: loading ? null : _submit,
                        icon: const Icon(Icons.save),
                        label: Text(loading ? 'Kaydediliyor...' : 'Kaydet'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _countryCityRow() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Ülke'),
            value: selectedCountryId,
            items: countries
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: (v) async {
              setState(() {
                selectedCountryId = v;
                selectedCityId = null;
                cities = [];
              });
              await _loadCities();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<int>(
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Şehir / İlçe'),
            value: selectedCityId,
            items: cities
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: (v) => setState(() => selectedCityId = v),
          ),
        ),
      ],
    );
  }

  Widget _buildWalletCard(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cüzdan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (createdUser == null)
              const Text(
                  'Önce kullanıcı oluşturun; ardından cüzdan bilgisi görüntülenir.'),
            if (createdUser != null) ...[
              Row(
                children: [
                  Text(
                      'Kullanıcı ID: ${createdUser!.id}  |  Tip: ${createdUser!.type}'),
                  const Spacer(),
                  IconButton(
                    onPressed: () async {
                      try {
                        final w = await widget.api.getWallet(createdUser!.id);
                        setState(() => wallet = w);
                      } catch (e) {
                        _snack('Cüzdan alınamadı: $e');
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Cüzdanı yenile',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Bakiye: ${wallet?.balance ?? 0}'),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                      child: _tf(topupAmountC, 'Yükleme Tutarı',
                          keyboard: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _tf(topupNoteC, 'Not (ops.)')),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: loading ? null : _topUp,
                    icon: const Icon(Icons.add_card),
                    label: Text(loading ? 'Yükleniyor...' : 'Para Yükle'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Zorunlu' : null;

  Widget _tf(TextEditingController c, String label,
      {TextInputType? keyboard,
      bool obscure = false,
      String? Function(String?)? validator}) {
    return SizedBox(
      width: 440,
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        obscureText: obscure,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        validator: validator,
      ),
    );
  }

  Widget _ta(TextEditingController c, String label) {
    return SizedBox(
      width: 896,
      child: TextFormField(
        controller: c,
        maxLines: 3,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}
