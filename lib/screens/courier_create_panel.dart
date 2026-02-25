import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:haldeki_admin_web/utils/message_screen.dart';
import 'package:provider/provider.dart';
import '../../services/api_client.dart';
import '../../models/models.dart';

class CourierCreatePanel extends StatefulWidget {
  final ApiClient api;
  const CourierCreatePanel({super.key, required this.api});

  @override
  State<CourierCreatePanel> createState() => _CourierCreatePanelState();
}

class _CourierCreatePanelState extends State<CourierCreatePanel> {
  final _formKey = GlobalKey<FormState>();

  // Temel
  final nameC = TextEditingController();
  final emailC = TextEditingController();
  final passC = TextEditingController();
  final phoneC = TextEditingController();

  // Adres / konum
  final addrC = TextEditingController();
  final latC = TextEditingController();
  final lngC = TextEditingController();

  // Kurye finans / araç
  final ibanC = TextEditingController();
  final bankOwnerC = TextEditingController();
  final vehiclePlateC = TextEditingController();
  final commissionRateC = TextEditingController(text: '10.00');
  String commissionType = 'percent'; // 'percent' | 'fixed'
  bool canTakeOrders = true;
  bool hasHadi = false;
  final secretNoteC = TextEditingController();

  // Ülke/Şehir
  List<Country> countries = [];
  List<City> cities = [];
  int? selectedCountryId;
  int? selectedCityId;

  // Belgeler
  List<File> documents = [];

  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    nameC.dispose();
    emailC.dispose();
    passC.dispose();
    phoneC.dispose();
    addrC.dispose();
    latC.dispose();
    lngC.dispose();
    ibanC.dispose();
    bankOwnerC.dispose();
    vehiclePlateC.dispose();
    commissionRateC.dispose();
    secretNoteC.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    try {
      final L = await widget.api.fetchCountries();
      if (!mounted) return;
      setState(() => countries = L);
    } catch (_) {}
  }

  Future<void> _loadCities() async {
    if (selectedCountryId == null) return;
    try {
      final L = await widget.api.fetchCities(countryId: selectedCountryId);
      if (!mounted) return;
      setState(() => cities = L);
    } catch (_) {}
  }

  Future<void> _pickDocs() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res != null) {
      setState(() {
        documents = res.paths.whereType<String>().map((p) => File(p)).toList();
      });
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  double? _toDoubleOrNull(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Kurye zorunluları
    if (ibanC.text.trim().isEmpty) {
      _snack('IBAN zorunlu');
      return;
    }
    if (bankOwnerC.text.trim().isEmpty) {
      _snack('Hesap sahibi zorunlu');
      return;
    }
    if (commissionRateC.text.trim().isEmpty) {
      _snack('Komisyon oranı zorunlu');
      return;
    }

    setState(() => loading = true);
    try {
      // Konum (sayısal tercih, yoksa string)
      final locLat = _toDoubleOrNull(latC.text);
      final locLng = _toDoubleOrNull(lngC.text);

      final user = await widget.api.createUser(
        userType: 'delivery_man',
        isCourier: true, // bu panel sadece kurye
        name: nameC.text.trim(),
        email: emailC.text.trim().isEmpty ? null : emailC.text.trim(),
        password: passC.text,
        username: null,
        contactNumber: phoneC.text.trim().isEmpty ? null : phoneC.text.trim(),
        dealerId: widget.api.currentUserId,
        countryId: selectedCityId,
        cityId: selectedCountryId,
        address: addrC.text.trim().isEmpty ? null : addrC.text.trim(),
        locationLat: locLat,
        locationLng: locLng,
        latitude: (locLat == null && latC.text.trim().isNotEmpty)
            ? latC.text.trim()
            : null,
        longitude: (locLng == null && lngC.text.trim().isNotEmpty)
            ? lngC.text.trim()
            : null,

        iban: ibanC.text.trim(),
        bankAccountOwner: bankOwnerC.text.trim(),
        vehiclePlate: vehiclePlateC.text.trim().isEmpty
            ? null
            : vehiclePlateC.text.trim(),
        commissionRate: commissionRateC.text.trim(),
        commissionType: commissionType,
        canTakeOrders: canTakeOrders,
        hasHadiAccount: hasHadi,
        secretNote:
            secretNoteC.text.trim().isEmpty ? null : secretNoteC.text.trim(),

        documents: documents.isEmpty ? null : documents,
      );

      _snack('Kurye oluşturuldu (ID: ${user.id})');

      Navigator.of(context).pop(true);

      // İstersen cüzdanı çek:
      // final wallet = await widget.api.getWallet(user.id);

      // Formu sıfırla (opsiyonel)
      // _formKey.currentState!.reset();
      // setState(() { documents.clear(); });
    } catch (e) {
      _snack('Kayıt başarısız: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kurye Ekle',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const Divider(),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _tf(nameC, 'Ad Soyad', required: true, width: 420),
                  _tf(emailC, 'E-posta', required: true, width: 420),
                  _tf(passC, 'Şifre',
                      required: true, obscure: true, width: 420),
                  _tf(phoneC, 'Telefon', width: 420),

                  _dropdownCountry(),
                  _dropdownCity(),
                  _tf(addrC, 'Adres', width: 852),
                  Row(children: [
                    Expanded(child: _tf(latC, 'Latitude')),
                    const SizedBox(width: 12),
                    Expanded(child: _tf(lngC, 'Longitude')),
                  ]),

                  // Kurye alanları
                  _tf(ibanC, 'IBAN *', required: true, width: 420),
                  _tf(bankOwnerC, 'Hesap Sahibi *', required: true, width: 420),
                  _tf(vehiclePlateC, 'Plaka', width: 420),

                  SizedBox(
                    width: 420,
                    child: DropdownButtonFormField<String>(
                      value: commissionType,
                      decoration: const InputDecoration(
                        labelText: 'Komisyon Tipi *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'percent', child: Text('Yüzde')),
                        DropdownMenuItem(value: 'fixed', child: Text('Sabit')),
                      ],
                      onChanged: (v) =>
                          setState(() => commissionType = v ?? 'percent'),
                    ),
                  ),
                  _tf(commissionRateC, 'Komisyon Oranı *',
                      required: true, width: 420),

                  SizedBox(
                    width: 852,
                    child: Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Sipariş alabilir'),
                            value: canTakeOrders,
                            onChanged: (v) =>
                                setState(() => canTakeOrders = v ?? true),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('HADİ hesabı var'),
                            value: hasHadi,
                            onChanged: (v) =>
                                setState(() => hasHadi = v ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ),
                      ],
                    ),
                  ),

                  _ta(secretNoteC, 'Gizli Not (ops.)', width: 852),

                  Row(children: [
                    ElevatedButton.icon(
                      onPressed: _pickDocs,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Evrak Yükle'),
                    ),
                    const SizedBox(width: 12),
                    Text('${documents.length} dosya seçildi'),
                  ]),

                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: loading ? null : _submit,
                      icon: const Icon(Icons.save),
                      label: Text(loading ? 'Kaydediliyor...' : 'Kaydet'),
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

  Widget _tf(TextEditingController c, String label,
      {bool required = false, bool obscure = false, double? width}) {
    return SizedBox(
      width: width ?? 420,
      child: TextFormField(
        controller: c,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu' : null
            : null,
      ),
    );
  }

  Widget _ta(TextEditingController c, String label, {double? width}) {
    return SizedBox(
      width: width ?? 420,
      child: TextFormField(
        controller: c,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dropdownCountry() {
    return SizedBox(
      width: 420,
      child: DropdownButtonFormField<int>(
        decoration: const InputDecoration(
            labelText: 'Ülke', border: OutlineInputBorder()),
        value: selectedCountryId,
        items: countries
            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
            .toList(),
        onChanged: (v) async {
          setState(() => selectedCountryId = v);
          await _loadCities();
        },
      ),
    );
  }

  Widget _dropdownCity() {
    return SizedBox(
      width: 420,
      child: DropdownButtonFormField<int>(
        decoration: const InputDecoration(
            labelText: 'Şehir', border: OutlineInputBorder()),
        value: selectedCityId,
        items: cities
            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
            .toList(),
        onChanged: (v) => setState(() => selectedCityId = v),
      ),
    );
  }
}
