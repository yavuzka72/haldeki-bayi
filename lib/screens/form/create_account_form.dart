import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:haldeki_admin_web/utils/message_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../models/models.dart'; // City, UserMinimal, Wallet
import '../../../models/district.dart'
    hide District; // District model name conflict
import '../../../services/api_client.dart'; // ApiClient
import '../haldeki_ui.dart';

// ===== Primary UI (Purple + Grey + Orange) =====
const kPurple = Color(0xFF4F46B6);
const kPurple2 = Color(0xFF2E2A78);
const kOrange = Color(0xFFF4B000);

const kBg = Color(0xFFF3F4FB);
const kCard = Color(0xFFFFFFFF);
const kSoft = Color(0xFFF8FAFC);
const kLine = Color(0xFFE6E8F2);

const kText = Color(0xFF0F172A);
const kMuted = Color(0xFF64748B);

class CreateAccountForm extends StatefulWidget {
  /// userType:
  ///  - 'client'       => İşletme
  ///  - 'delivery_man' => Kurye
  ///  - 'user'         => Müşteri
  final String userType;
  final String title;

  const CreateAccountForm({
    super.key,
    required this.userType,
    required this.title,
  });

  @override
  State<CreateAccountForm> createState() => _CreateAccountFormState();
}

class _CreateAccountFormState extends State<CreateAccountForm> {
  final _formKey = GlobalKey<FormState>();

  // --- temel alanlar
  final nameC = TextEditingController();
  final lastNameC = TextEditingController(); // kurye & müşteri için
  final emailC = TextEditingController();
  final passC = TextEditingController();
  final userC = TextEditingController();
  final phoneC = TextEditingController();
  final addrC = TextEditingController();
  final latC = TextEditingController();
  final lngC = TextEditingController();

  // --- kurye ek alanlar
  final plateC = TextEditingController();
  final ibanC = TextEditingController();
  final bankOwnerC = TextEditingController();
  final commissionRateC = TextEditingController(text: '10.00');
  String commissionType = 'percent'; // percent | fixed
  bool canTakeOrders = true;
  bool hasHadi = false;
  final hiddenNoteC = TextEditingController();

  // --- şehir/ilçe
  List<City> cities = [];
  List<District> districts = [];
  int? selectedCityId;
  int? selectedDistrictId;

  // --- belgeler
  File? residencePdf;
  File? driverFrontImage;
  File? goodConductPdf;
  List<File> extraDocuments = [];

  // --- sonuç & cüzdan
  UserMinimal? createdUser;
  Wallet? wallet;
  final topupAmountC = TextEditingController();
  final topupNoteC = TextEditingController();

  bool loading = false;
  bool _obscurePass = true;
  Timer? _geoDebounce;

  bool get _isCourier => widget.userType == 'delivery_man';
  bool get _isClient => widget.userType == 'client';
  bool get _isUser => widget.userType == 'user';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final api = context.read<ApiClient>();
      final cityList = await api.fetchCitiesFromCountries(perPage: -1);

      if (!mounted) return;
      if (cityList.isEmpty) {
        _snack('Şehir listesi boş döndü');
        return;
      }

      setState(() {
        cities = cityList;
        selectedCityId = cityList.first.id;
      });

      await _loadDistrictsByCity();
    } catch (_) {
      if (!mounted) return;
      _snack('Başlangıç verileri alınamadı');
    }
  }

  @override
  void dispose() {
    nameC.dispose();
    lastNameC.dispose();
    emailC.dispose();
    passC.dispose();
    userC.dispose();
    phoneC.dispose();
    addrC.dispose();
    latC.dispose();
    lngC.dispose();

    plateC.dispose();
    ibanC.dispose();
    bankOwnerC.dispose();
    commissionRateC.dispose();
    hiddenNoteC.dispose();

    topupAmountC.dispose();
    topupNoteC.dispose();

    _geoDebounce?.cancel();
    super.dispose();
  }

  // ===== Primary UI theme wrapper (local) =====
  ThemeData _primaryTheme(BuildContext context) {
    final base = Theme.of(context);
    final cs = base.colorScheme;

    final themed = HaldekiUI.withRectButtons(context, cs).copyWith(
      scaffoldBackgroundColor: kBg,
      colorScheme: cs.copyWith(
        primary: kPurple,
        secondary: kOrange,
        surface: kCard,
      ),
      dividerColor: kLine,
      iconTheme: const IconThemeData(color: kMuted),
      inputDecorationTheme: HaldekiUI.inputDense(context).copyWith(
        filled: true,
        fillColor: kSoft,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: kPurple.withOpacity(.60), width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: kPurple,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: kText,
          side: const BorderSide(color: kLine),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: kPurple,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return kPurple;
          return null;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );

    return themed;
  }

  /// Geoapify Geocoding – metin adresini lat/lon’a çevirir
  Future<({double lat, double lon})?> geoapifyGeocode(String address) async {
    const apiKey = '6ca1f774874b4d3099be549f503310a4';

    final url = Uri.parse(
      'https://api.geoapify.com/v1/geocode/search'
      '?text=${Uri.encodeComponent(address)}'
      '&filter=countrycode:tr'
      '&limit=1'
      '&lang=tr'
      '&apiKey=$apiKey',
    );

    final r = await http.get(url);
    if (r.statusCode != 200) return null;

    final data = jsonDecode(r.body);
    if (data is! Map || data['features'] is! List || data['features'].isEmpty) {
      return null;
    }

    final feature = data['features'][0];
    final geometry = feature['geometry']?['coordinates'];
    if (geometry == null || geometry.length < 2) return null;

    // Geoapify: [lon, lat]
    final lon = (geometry[0] as num).toDouble();
    final lat = (geometry[1] as num).toDouble();
    return (lat: lat, lon: lon);
  }

  Future<void> _loadDistrictsByCity() async {
    final cid = selectedCityId;
    if (cid == null) {
      setState(() {
        districts = [];
        selectedDistrictId = null;
      });
      return;
    }

    try {
      final api = context.read<ApiClient>();
      final L = await api.fetchDistrictsByCountry(countryId: cid, perPage: -1);

      if (!mounted) return;
      setState(() {
        districts = L;
        final konak =
            L.where((d) => d.name.toLowerCase().startsWith('konak')).toList();
        selectedDistrictId = konak.isNotEmpty
            ? konak.first.id
            : (L.isNotEmpty ? L.first.id : null);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        districts = [];
        selectedDistrictId = null;
      });
      _snack('İlçeler alınamadı');
    }
  }

  Future<void> _pickGenericDocuments() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res == null) return;
    final files = <File>[];
    for (final f in res.files) {
      if (f.path != null) files.add(File(f.path!));
    }
    setState(() => extraDocuments = files);
  }

  Future<void> _pickOne({
    required List<String> extensions,
    required void Function(File) onPick,
  }) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      allowMultiple: false,
    );
    if (res == null || res.files.isEmpty || res.files.first.path == null)
      return;
    onPick(File(res.files.first.path!));
  }

  void _onAddressChanged(String _) {
    _geoDebounce?.cancel();
    _geoDebounce = Timer(const Duration(milliseconds: 600), _geocodeAddress);
  }

  Future<void> _geocodeAddress() async {
    final addr = addrC.text.trim();
    if (addr.length < 6) return;

    final cityName = cities
        .firstWhere((c) => c.id == selectedCityId,
            orElse: () => City(id: 0, name: ''))
        .name;

    final districtName = districts
        .firstWhere((d) => d.id == selectedDistrictId,
            orElse: () => District(id: 0, name: '', countryId: 0))
        .name;

    final query = '$addr, $districtName, $cityName, Türkiye';

    final result = await geoapifyGeocode(query);
    if (result != null) {
      setState(() {
        latC.text = result.lat.toStringAsFixed(6);
        lngC.text = result.lon.toStringAsFixed(6);
      });
    } else {
      _snack('Adres bulunamadı');
    }
  }

  double? _toDoubleOrNull(String s) {
    if (s.isEmpty) return null;
    return double.tryParse(s.replaceAll(',', '.'));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isCourier) {
      if (ibanC.text.trim().isEmpty) return _snack('IBAN numarası zorunludur');
      if (bankOwnerC.text.trim().isEmpty)
        return _snack('Hesap sahibi zorunludur');
      if (commissionRateC.text.trim().isEmpty)
        return _snack('Komisyon oranı zorunludur');
    }

    setState(() => loading = true);

    try {
      final api = context.read<ApiClient>();

      final fullName = (_isCourier || _isUser)
          ? [nameC.text.trim(), lastNameC.text.trim()]
              .where((e) => e.isNotEmpty)
              .join(' ')
          : nameC.text.trim();

      final districtName = districts
          .firstWhere((d) => d.id == selectedDistrictId,
              orElse: () => District(id: 0, name: '', countryId: 0))
          .name;

      final cityName = cities
          .firstWhere((c) => c.id == selectedCityId,
              orElse: () => City(id: 0, name: ''))
          .name;

      final locLat = _toDoubleOrNull(latC.text.trim());
      final locLng = _toDoubleOrNull(lngC.text.trim());

      final String userTypeForApi =
          _isCourier ? 'delivery_man' : (_isUser ? 'user' : 'client');

      late final UserMinimal u;

      if (_isClient) {
        // ✅ Partner Client create
        final pc = await api.createPartnerClient(
          name: fullName,
          email: emailC.text.trim().isEmpty ? null : emailC.text.trim(),
          phone: phoneC.text.trim().isEmpty ? null : phoneC.text.trim(),
          contactNumber: phoneC.text.trim().isEmpty ? null : phoneC.text.trim(),
          address: addrC.text.trim().isEmpty ? null : addrC.text.trim(),
          countryId: selectedCityId,
          cityId: selectedDistrictId,
          city: cityName.isEmpty ? null : cityName,
          district: districtName.isEmpty ? null : districtName,
          latitude: (locLat == null && latC.text.trim().isNotEmpty)
              ? latC.text.trim()
              : null,
          longitude: (locLng == null && lngC.text.trim().isNotEmpty)
              ? lngC.text.trim()
              : null,
          locationLat: locLat,
          locationLng: locLng,
          dealer_id: context.read<ApiClient>().currentUserId,
          webhookUrl: 'nul',
          //      webhookUrlC.text.trim().isEmpty ? null : webhookUrlC.text.trim(),
          meta: {
            'brand': 'XXX', // brandC.text.trim(),
            'sector': 'XXX', //sectorC.text.trim(),
            /*     if (dailyOrderAvgC.text.trim().isNotEmpty)
              'daily_order_avg': int.tryParse(dailyOrderAvgC.text.trim()) ??
                  dailyOrderAvgC.text.trim(),
*/
          },
        );

        showMessageDialog(
          context,
          title: 'Başarılı',
          message:
              'Partner Client oluşturuldu.\nID: ${pc.id}\nKey: ${pc.partnerKey ?? "-"}\nSecret: ${pc.partnerSecret ?? "-"}',
          type: MessageType.success,
        );

        Navigator.of(context).pop(true);
        return;
      } else {
        // ✅ Kurye + User aynı şekilde devam
        u = await api.createUser(
          userType: userTypeForApi,
          isCourier: _isCourier,
          name: fullName,
          email: emailC.text.trim().isEmpty ? null : emailC.text.trim(),
          password: passC.text,
          username: userC.text.trim().isEmpty ? null : userC.text.trim(),
          contactNumber: phoneC.text.trim().isEmpty ? null : phoneC.text.trim(),

          countryId: selectedCityId,
          cityId: selectedDistrictId,
          address: addrC.text.trim().isEmpty ? null : addrC.text.trim(),

          latitude: locLat == null
              ? (latC.text.trim().isEmpty ? null : latC.text.trim())
              : null,
          longitude: locLng == null
              ? (lngC.text.trim().isEmpty ? null : lngC.text.trim())
              : null,
          locationLat: locLat,
          locationLng: locLng,

          district: districtName.isEmpty ? null : districtName,
          cityName: cityName.isEmpty ? null : cityName,

          vehiclePlate: _isCourier && plateC.text.trim().isNotEmpty
              ? plateC.text.trim()
              : null,
          iban: _isCourier ? ibanC.text.trim() : null,
          bankAccountOwner: _isCourier ? bankOwnerC.text.trim() : null,
          commissionRate: _isCourier ? commissionRateC.text.trim() : null,
          commissionType: commissionType,
          canTakeOrders: _isCourier ? canTakeOrders : null,
          hasHadiAccount: _isCourier ? hasHadi : null,
          secretNote: _isCourier && hiddenNoteC.text.trim().isNotEmpty
              ? hiddenNoteC.text.trim()
              : null,

          // dealerId eskiden users/clients içindi, partner_client tarafında yok:
          dealerId: context.read<ApiClient>().currentUserId,

          residencePdf: residencePdf,
          driverFront: driverFrontImage,
          goodConductPdf: goodConductPdf,
          documents: extraDocuments.isEmpty ? null : extraDocuments,
        );
      }
      setState(() => createdUser = u);

      showMessageDialog(
        context,
        title: 'Başarılı',
        message: 'Kullanıcı oluşturuldu. ID: ${u.id}',
        type: MessageType.success,
      );

      Navigator.of(context).pop(true);

      try {
        final w = await api.getWallet(u.id);
        if (mounted) setState(() => wallet = w);
      } on DioException {
        // sessiz
      } catch (_) {
        // sessiz
      }
    } on DioException catch (e) {
      _snack(_prettyDioError(e));
    } catch (_) {
      _snack('Kayıt başarısız. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _prettyDioError(DioException e) {
    final res = e.response;
    final data = res?.data;

    if (data is Map<String, dynamic>) {
      final errors = data['errors'];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) {
            final msg = value.first.toString();
            final lower = msg.toLowerCase();

            if (lower.contains('email') &&
                lower.contains('already been taken')) {
              return 'Bu e-posta adresi zaten kayıtlı.';
            }
            if (lower.contains('phone') &&
                lower.contains('already been taken')) {
              return 'Bu telefon numarası zaten kayıtlı.';
            }
            if (lower.contains('required')) return 'Zorunlu alanları doldurun.';
            return msg;
          }
        }
      }
      if (data['message'] != null) return data['message'].toString();
    }

    if (res?.statusCode == 422) {
      return 'Girilen bilgiler eksik veya hatalı. Lütfen formu kontrol edin.';
    }
    if (res?.statusCode == 409) {
      return 'Bu bilgilerle kayıtlı başka bir kullanıcı zaten var.';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edin.';
    }

    return 'Kayıt başarısız. Lütfen bilgileri kontrol edip tekrar deneyin.';
  }

  void _snack(String m) {
    showMessageDialog(
      context,
      title: 'Bilgi',
      message: m,
      type: MessageType.warning,
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _primaryTheme(context),
      child: Align(
        alignment: Alignment.topCenter,
        child: LayoutBuilder(
          builder: (context, box) {
            final maxW = box.maxWidth > 1600 ? 1600.0 : box.maxWidth;
            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _topHeader(),
                    const SizedBox(height: 12),
                    _formSurface(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _topHeader() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: kText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isCourier
                  ? 'Kurye kaydı oluşturun'
                  : (_isClient
                      ? 'İşletme kaydı oluşturun'
                      : 'Müşteri kaydı oluşturun'),
              style:
                  const TextStyle(fontWeight: FontWeight.w800, color: kMuted),
            ),
          ],
        ),
        const Spacer(),
        if (!loading)
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).maybePop(false),
            icon: const Icon(Icons.close),
            label: const Text('Kapat'),
          ),
      ],
    );
  }

  Widget _formSurface() {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kLine),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(.05),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, c) {
            const gap = 16.0;
            final colW = (c.maxWidth - gap) / 2;

            return Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('Temel Bilgiler'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: gap,
                    runSpacing: 12,
                    children: [
                      _tf(
                        nameC,
                        _isClient ? 'Ad/Ünvan *' : 'Adı *',
                        width: colW,
                        validator: _req,
                      ),
                      if (!_isClient)
                        _tf(
                          lastNameC,
                          'Soyadı *',
                          width: colW,
                          validator: _req,
                        ),
                      _tf(
                        phoneC,
                        'Telefon Numarası *',
                        width: colW,
                        keyboard: TextInputType.phone,
                        validator: _req,
                      ),

                      // Password
                      SizedBox(
                        width: colW,
                        child: TextFormField(
                          controller: passC,
                          obscureText: _obscurePass,
                          validator: _req,
                          decoration: InputDecoration(
                            labelText: 'Şifre *',
                            suffixIcon: IconButton(
                              tooltip: _obscurePass
                                  ? 'Şifreyi göster'
                                  : 'Şifreyi gizle',
                              icon: Icon(_obscurePass
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                              onPressed: () =>
                                  setState(() => _obscurePass = !_obscurePass),
                            ),
                          ),
                        ),
                      ),

                      _tf(userC, 'Kullanıcı Adı', width: colW),
                      _tf(emailC, 'E-posta',
                          width: colW, keyboard: TextInputType.emailAddress),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _sectionHeader('Adres ve Konum (Opsiyonel)'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: gap,
                    runSpacing: 12,
                    children: [
                      SizedBox(width: colW * 2, child: _cityDistrictRow()),
                      SizedBox(
                        width: colW * 2,
                        child: TextFormField(
                          controller: addrC,
                          maxLines: 3,
                          onChanged: _onAddressChanged,
                          decoration:
                              const InputDecoration(labelText: 'Adres (ops.)'),
                        ),
                      ),
                      SizedBox(
                        width: colW * 2,
                        child: Row(
                          children: [
                            Expanded(
                              child: _tf(
                                latC,
                                'Latitude (ops.)',
                                keyboard: const TextInputType.numberWithOptions(
                                    decimal: true),
                              ),
                            ),
                            const SizedBox(width: gap),
                            Expanded(
                              child: _tf(
                                lngC,
                                'Longitude (ops.)',
                                keyboard: const TextInputType.numberWithOptions(
                                    decimal: true),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_isCourier) ...[
                    const SizedBox(height: 18),
                    _sectionHeader('Kurye Bilgileri'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: gap,
                      runSpacing: 12,
                      children: [
                        _tf(plateC, 'Plaka', width: colW),
                        _tf(ibanC, 'IBAN *', width: colW, validator: _req),
                        _tf(bankOwnerC, 'Hesap Sahibi *',
                            width: colW, validator: _req),
                        SizedBox(
                          width: colW,
                          child: DropdownButtonFormField<String>(
                            value: commissionType,
                            decoration: const InputDecoration(
                                labelText: 'Komisyon Tipi *'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'percent', child: Text('Yüzde')),
                              DropdownMenuItem(
                                  value: 'fixed', child: Text('Sabit Fiyat')),
                            ],
                            onChanged: (v) =>
                                setState(() => commissionType = v ?? 'percent'),
                          ),
                        ),
                        _tf(
                          commissionRateC,
                          'Komisyon Oranı *',
                          width: colW,
                          validator: _req,
                          keyboard: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 18,
                      runSpacing: 6,
                      children: [
                        _checkPill(
                          label: 'Sipariş alabilir',
                          value: canTakeOrders,
                          onChanged: (v) => setState(() => canTakeOrders = v),
                        ),
                        _checkPill(
                          label: 'HADİ hesabı var',
                          value: hasHadi,
                          onChanged: (v) => setState(() => hasHadi = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ta(hiddenNoteC, 'Gizli Not (ops.)', width: colW * 2),
                  ],
                  const SizedBox(height: 18),
                  _sectionHeader('Belgeler (Opsiyonel)'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _docButton(
                        label: residencePdf == null
                            ? 'İkametgah PDF seç'
                            : 'İkametgah: seçildi',
                        icon: Icons.picture_as_pdf,
                        onTap: () => _pickOne(
                          extensions: ['pdf'],
                          onPick: (f) => setState(() => residencePdf = f),
                        ),
                      ),
                      _docButton(
                        label: driverFrontImage == null
                            ? 'Ehliyet ön seç'
                            : 'Ehliyet: seçildi',
                        icon: Icons.badge_outlined,
                        onTap: () => _pickOne(
                          extensions: ['png', 'jpg', 'jpeg', 'pdf'],
                          onPick: (f) => setState(() => driverFrontImage = f),
                        ),
                      ),
                      _docButton(
                        label: goodConductPdf == null
                            ? 'İyi hal PDF seç'
                            : 'İyi hal: seçildi',
                        icon: Icons.verified_outlined,
                        onTap: () => _pickOne(
                          extensions: ['pdf'],
                          onPick: (f) => setState(() => goodConductPdf = f),
                        ),
                      ),
                      _docButton(
                        label: extraDocuments.isEmpty
                            ? 'Ek belge seç (çoklu)'
                            : 'Ek belgeler: ${extraDocuments.length}',
                        icon: Icons.attach_file,
                        onTap: _pickGenericDocuments,
                        tone: kOrange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: kSoft,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kLine),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.info_outline, size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Zorunlu alanları doldurduktan sonra Kaydet’e bas.',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: kMuted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 46,
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
            );
          },
        ),
      ),
    );
  }

  Widget _cityDistrictRow() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Şehir (İl)'),
            value: selectedCityId,
            items: cities
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: (v) async {
              setState(() {
                selectedCityId = v;
                selectedDistrictId = null;
                districts = [];
              });
              await _loadDistrictsByCity();
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DropdownButtonFormField<int>(
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'İlçe'),
            value: selectedDistrictId,
            items: districts
                .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
                .toList(),
            onChanged: (v) => setState(() => selectedDistrictId = v),
          ),
        ),
      ],
    );
  }

  // ===== UI helpers =====

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Zorunlu' : null;

  Widget _tf(
    TextEditingController c,
    String label, {
    TextInputType? keyboard,
    bool obscure = false,
    String? Function(String?)? validator,
    double? width,
  }) {
    return SizedBox(
      width: width ?? double.infinity,
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        obscureText: obscure,
        decoration: InputDecoration(labelText: label),
        validator: validator,
      ),
    );
  }

  Widget _ta(TextEditingController c, String label, {double? width}) {
    return SizedBox(
      width: width ?? double.infinity,
      child: TextFormField(
        controller: c,
        maxLines: 3,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: kPurple,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: kText,
            fontSize: 15,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: kPurple.withOpacity(.08),
            border: Border.all(color: kPurple.withOpacity(.18)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            '',
            style: TextStyle(
                fontWeight: FontWeight.w900, color: kMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _checkPill({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final border = value ? kPurple.withOpacity(.45) : kLine;
    final bg = value ? kPurple.withOpacity(.10) : kSoft;
    final fg = value ? kPurple : kMuted;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(value ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 18, color: fg),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(fontWeight: FontWeight.w900, color: fg)),
          ],
        ),
      ),
    );
  }

  Widget _docButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color tone = kPurple,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: tone),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: tone.withOpacity(.25)),
        foregroundColor: kText,
        backgroundColor: kCard,
      ),
    );
  }
}
