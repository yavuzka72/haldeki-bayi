import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../models/models.dart';

class ClientCreatePanel extends StatefulWidget {
  final ApiClient api;
  const ClientCreatePanel({super.key, required this.api});

  @override
  State<ClientCreatePanel> createState() => _ClientCreatePanelState();
}

class _ClientCreatePanelState extends State<ClientCreatePanel> {
  final _formKey = GlobalKey<FormState>();
  final nameC = TextEditingController();
  final emailC = TextEditingController();
  final passC = TextEditingController();
  final phoneC = TextEditingController();
  final addrC = TextEditingController();

  List<Country> countries = [];
  List<City> cities = [];
  int? selectedCountryId;
  int? selectedCityId;

  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    final L = await widget.api.fetchCountries();
    setState(() => countries = L);
  }

  Future<void> _loadCities() async {
    if (selectedCountryId == null) return;
    final L = await widget.api.fetchCities(countryId: selectedCountryId);
    setState(() => cities = L);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      await widget.api.createUser(
        isCourier: false,
        userType: 'client',
        name: nameC.text,
        email: emailC.text,
        password: passC.text,
        contactNumber: phoneC.text,
        countryId: selectedCountryId,
        cityId: selectedCityId,
        address: addrC.text,
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('İşletme eklendi')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Hata: $e')));
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
              const Text('İşletme Ekle',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const Divider(),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _tf(nameC, 'İşletme Adı', required: true),
                  _tf(emailC, 'E-posta', required: true),
                  _tf(passC, 'Şifre', required: true, obscure: true),
                  _tf(phoneC, 'Telefon'),
                  _dropdownCountry(),
                  _dropdownCity(),
                  _ta(addrC, 'Adres'),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: loading ? null : _submit,
                      icon: const Icon(Icons.save),
                      label: Text(loading ? 'Kaydediliyor...' : 'Kaydet'),
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _tf(TextEditingController c, String label,
      {bool required = false, bool obscure = false}) {
    return SizedBox(
      width: 420,
      child: TextFormField(
        controller: c,
        obscureText: obscure,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        validator: required ? (v) => v!.isEmpty ? 'Zorunlu' : null : null,
      ),
    );
  }

  Widget _ta(TextEditingController c, String label) {
    return SizedBox(
      width: 860,
      child: TextFormField(
        controller: c,
        maxLines: 3,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }

  Widget _dropdownCountry() {
    return SizedBox(
      width: 420,
      child: DropdownButtonFormField<int>(
        decoration: const InputDecoration(labelText: 'Ülke'),
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
        decoration: const InputDecoration(labelText: 'Şehir'),
        value: selectedCityId,
        items: cities
            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
            .toList(),
        onChanged: (v) => setState(() => selectedCityId = v),
      ),
    );
  }
}
