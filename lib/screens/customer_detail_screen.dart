import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:haldeki_admin_web/models/models.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import 'package:haldeki_admin_web/models/client_adress.dart';
import 'package:haldeki_admin_web/models/client_order_lite.dart';

/// ---------------- BASİT MODEL ----------------
class CustomerLite {
  final int id;
  final String name;
  final String phone;
  final bool isOpen;
  CustomerLite({
    required this.id,
    required this.name,
    required this.phone,
    required this.isOpen,
  });
}

/// ---------------- EKRAN ----------------
class CustomerDetailScreen extends StatefulWidget {
  final int id;
  final CustomerLite? initial;
  const CustomerDetailScreen({super.key, required this.id, this.initial});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  // ----- state -----
  bool _loading = true;
  String? _error;
  bool _saving = false;

  // form
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameC;
  late final TextEditingController _phoneC;
  late final TextEditingController _commissionC; // paket başı komisyon
  late final TextEditingController _partnerKeyC;
  late final TextEditingController _partnerSecretC;
  late final TextEditingController _tokenC;

  late final TextEditingController _addrC;
  late final TextEditingController _latC;
  late final TextEditingController _lngC;
  late final TextEditingController _emailC;

  List<City> _cities = [];
  List<District> _districts = [];
  int? _selectedCityId;
  int? _selectedDistrictId;

  Timer? _geoDebounce;
  bool _geoLoading = false;

  bool _isOpen = true;
  bool _hasPickupPhoto = false;
  bool _hasDeliveryPhoto = false;

  bool _payReceiver = false;
  bool _paySender = false;
  bool _payAdmin = false;

  late final TabController _tabs;

  final TextEditingController _priceSearchC = TextEditingController();
  String _selectedCategory = 'Tümü';
  late Future<List<_CatalogProduct>> _catalogFuture;

// =================== FİYAT LİSTESİ STATE ===================

  static const int _kPartnerClientId = 1;

  bool _priceLoading = false;
  String? _priceError;

  final Map<int, TextEditingController> _priceCtrlsByVariantId = {};
  final Set<int> _dirtyVariantIds = {};

// Eğer farklı host kullanıyorsan burayı değiştir:
// - Flutter Web’de aynı domaindeysen: baseUrl = '' bırakıp relative url kullanabilirsin.
  String get _apiBase => 'https://api.haldeki.com';

// Catalog endpoint
  Uri _catalogUri({required int page, int perPage = 100}) {
    return Uri.parse(
        '$_apiBase/api/partner/v1/catalog?per_page=$perPage&page=$page');
  }

  TextEditingController _ctrlForVariant(_CatalogVariant v) {
    return _priceCtrlsByVariantId.putIfAbsent(
      v.id,
      () => TextEditingController(
          text: (v.price ?? 0).toStringAsFixed(2).replaceAll('.', ',')),
    );
  }

  String _cleanNum(String s) =>
      s.replaceAll(' ', '').replaceAll('.', '').replaceAll(',', '.').trim();

  Future<List<_CatalogProduct>> _fetchCatalogAllPages2() async {
    // ✅ ŞİMDİLİK STATİK (test için)
    const String baseUrl = 'https://api.haldeki.com';
    const String partnerKey = 'p_iqutpvdzjextzccwtnykyqba';
    const String partnerSecret =
        'DVVsfxHTLiiszorquScr3KN5E59GHcSDed4xGoNXO5yYePUp';
    const String token =
        '2fede37ade6d539dd75713471a67a8818083a5f726d8689ed80dc08d2e407d09'; // boşsa '' bırak

    final uri = Uri.parse('$baseUrl/api/partner/v1/catalog').replace(
      queryParameters: {
        'per_page': '100',
        'page': '1',
      },
    );

    final headers = <String, String>{
      'Accept': 'application/json',
      // ✅ Backend’in istediği isimler:
      'X-Partner-Key': partnerKey,
      'X-Partner-Secret': partnerSecret,
    };

    // Token gerçekten gerekiyorsa kalsın (çoğu sistemde partner key/secret yeter)
    if (token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }

    final r = await http.get(uri, headers: headers);

    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('Catalog alınamadı (${r.statusCode}): ${r.body}');
    }

    final data = jsonDecode(r.body);

    final list = (data is Map && data['data'] is List)
        ? (data['data'] as List)
        : (data is List ? data : const []);

    return list
        .whereType<Map>()
        .map((m) => _CatalogProduct.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<List<_CatalogProduct>> _fetchCatalogAllPages() async {
    // ✅ ŞİMDİLİK STATİK (test için)
    const String baseUrl = 'https://api.haldeki.com';
    /*  const String partnerKey = 'p_iqutpvdzjextzccwtnykyqba';
    const String partnerSecret =
        'DVVsfxHTLiiszorquScr3KN5E59GHcSDed4xGoNXO5yYePUp';
    const String token =
        '2fede37ade6d539dd75713471a67a8818083a5f726d8689ed80dc08d2e407d09'; // boşsa '' bırak
*/

    final partnerKey = _partnerKeyC.text.trim();
    final partnerSecret = _partnerSecretC.text.trim();
    final token = _tokenC.text.trim();

    //debugprint('Fetching catalog with key=$partnerKey, secret=$partnerSecret');

    if (partnerKey.isEmpty || partnerSecret.isEmpty) {
      throw Exception(
          'Partner-Key / Partner-Secret boş. Önce partner detay yüklenmeli.');
    }

    final uri = Uri.parse('$baseUrl/api/partner/v1/catalog').replace(
      queryParameters: {'per_page': '100', 'page': '1'},
    );

    final headers = <String, String>{
      'Accept': 'application/json',
      // ✅ Backend hint: bunlar olmalı
      'X-Partner-Key': partnerKey,
      'X-Partner-Secret': partnerSecret,
    };

    // token gerçekten gerekiyorsa kalsın (gerekmiyorsa hiç gönderme)
    if (token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }

    final r = await http.get(uri, headers: headers);

    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('Catalog alınamadı (${r.statusCode}): ${r.body}');
    }

    final data = jsonDecode(r.body);

    // backend: { partner: {...}, data: [...] }
    final list = (data is Map && data['data'] is List)
        ? (data['data'] as List)
        : (data is List ? data : const []);

    // ✅ null-safe map parse
    final products = <_CatalogProduct>[];
    for (final item in list) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item as Map);

      // ✅ partner_client_id = 1 olacak şekilde variant filtreleme:
      // (Bunu _CatalogProduct.fromJson içinde de yapabilirsin; burada da güvenli.)
      final variants =
          (m['variants'] is List) ? (m['variants'] as List) : const [];
      /* final filteredVariants = variants.where((v) {
        if (v is! Map) return false;
        final pv = v['partner_client_id'];
        final id = (pv is num) ? pv.toInt() : int.tryParse('$pv');
        return id == 2;
        //_kPartnerClientId; // ✅ bool
      }).toList();
*/
      final merged = Map<String, dynamic>.from(m);
      merged['variants'] = variants;
      //filteredVariants;

      products.add(_CatalogProduct.fromJson(merged));
    }

    return products;
  }

  @override
  void initState() {
    super.initState();

    final c = widget.initial ??
        CustomerLite(id: widget.id, name: '—', phone: '', isOpen: true);

    _nameC = TextEditingController(text: c.name);
    _phoneC = TextEditingController(text: c.phone);
    _commissionC = TextEditingController(text: '0,00');
    _partnerKeyC = TextEditingController();
    _partnerSecretC = TextEditingController();
    _tokenC = TextEditingController();
    _isOpen = c.isOpen;
    _addrC = TextEditingController();
    _latC = TextEditingController();
    _lngC = TextEditingController();
    _emailC = TextEditingController();
    _tabs = TabController(length: 5, vsync: this);
    _bootstrapCities();
    _catalogFuture = Future.value(const <_CatalogProduct>[]);
    _loadFromApi();
    //_catalogFuture = _fetchCatalogAllPages();
  }

  @override
  void dispose() {
    _nameC.dispose();
    _phoneC.dispose();
    _commissionC.dispose();
    _partnerKeyC.dispose();
    _partnerSecretC.dispose();
    _addrC.dispose();
    _latC.dispose();
    _lngC.dispose();
    _geoDebounce?.cancel();
    _emailC.dispose();
    _tokenC.dispose();
    _tabs.dispose();
    _priceSearchC.dispose();
    super.dispose();
  }

  // ---------------- Address + Geo helpers ----------------

  Future<void> _bootstrapCities() async {
    try {
      final api = context.read<ApiClient>();
      final cityList = await api.fetchCitiesFromCountries(perPage: -1);
      if (!mounted) return;

      setState(() {
        _cities = cityList;
        _selectedCityId ??= cityList.isNotEmpty ? cityList.first.id : null;
      });

      await _loadDistrictsByCity();
    } catch (_) {
      // sessiz geç
    }
  }

  Future<void> _loadDistrictsByCity() async {
    final cid = _selectedCityId;
    if (cid == null) {
      if (!mounted) return;
      setState(() {
        _districts = [];
        _selectedDistrictId = null;
      });
      return;
    }

    try {
      final api = context.read<ApiClient>();
      final L = await api.fetchDistrictsByCountry(countryId: cid, perPage: -1);

      if (!mounted) return;
      setState(() {
        _districts = L;
        _selectedDistrictId ??= (L.isNotEmpty ? L.first.id : null);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _districts = [];
        _selectedDistrictId = null;
      });
    }
  }

  void _onAddressChanged(String _) {
    _geoDebounce?.cancel();
    _geoDebounce = Timer(const Duration(milliseconds: 600), _geocodeAddress);
  }

  Future<({double lat, double lon})?> _geoapifyGeocode(String address) async {
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
    if (data is! Map) return null;
    final features = data['features'];
    if (features is! List || features.isEmpty) return null;

    final feature = features.first;
    final geometry = feature['geometry']?['coordinates'];
    if (geometry == null || geometry.length < 2) return null;

    final lon = (geometry[0] as num).toDouble();
    final lat = (geometry[1] as num).toDouble();
    return (lat: lat, lon: lon);
  }

  Future<void> _geocodeAddress() async {
    final addr = _addrC.text.trim();
    if (addr.length < 6) return;

    final cityName = _cities
        .firstWhere((c) => c.id == _selectedCityId,
            orElse: () => City(id: 0, name: ''))
        .name;

    final districtName = _districts
        .firstWhere((d) => d.id == _selectedDistrictId,
            orElse: () => District(id: 0, name: '', countryId: 0))
        .name;

    final query = '$addr, $districtName, $cityName, Türkiye';

    if (!mounted) return;
    setState(() => _geoLoading = true);

    final result = await _geoapifyGeocode(query);

    if (!mounted) return;
    setState(() => _geoLoading = false);

    if (result != null) {
      _latC.text = result.lat.toStringAsFixed(6);
      _lngC.text = result.lon.toStringAsFixed(6);
    }
  }

  Future<void> _copyToClipboard(String text, String label) async {
    // Clipboard için: import 'package:flutter/services.dart';
    // dosyanın en üstüne eklemeyi unutma.
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label kopyalandı')),
    );
  }

  // ---------------- API ----------------
  Future<void> _loadFromApi() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiClient>();

      // raw response
      final raw = await api.getPartnerClientDetail(widget.id);

      // ✅ Eğer response { data: {...} } ise asıl map = data
      final Map<String, dynamic> mm = (raw['data'] is Map)
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : Map<String, dynamic>.from(raw);

      // (İstersen debug kapat)
      //debugprint('PartnerClientDetail keys: ${mm.keys.toList()}');
      //debugprint('PartnerClientDetail address: ${mm['address']}');

      T? pick<T>(List<String> keys) {
        for (final k in keys) {
          final v = mm[k];
          if (v == null) continue;

          if (T == String) {
            // boş string gelirse de kabul et (bazı backendler "" döner)
            return (v is String ? v : '$v') as T;
          }

          if (T == bool) {
            if (v is bool) return v as T;
            if (v is num) return (v != 0) as T;

            final s = '$v'.trim().toLowerCase();
            if (['1', 'true', 'açık', 'open', 'aktif', 'active', 'yes']
                .contains(s)) return true as T;
            if (['0', 'false', 'kapalı', 'closed', 'pasif', 'inactive', 'no']
                .contains(s)) return false as T;
          }

          if (T == int) {
            if (v is int) return v as T;
            if (v is num) return v.toInt() as T;
            return int.tryParse('$v') as T?;
          }

          if (T == double) {
            if (v is double) return v as T;
            if (v is num) return v.toDouble() as T;
            return double.tryParse('$v'.replaceAll(',', '.')) as T?;
          }
        }
        return null;
      }

      // ----- BASIC -----
      final name =
          pick<String>(['name', 'ad_soyad', 'title', 'full_name']) ?? '—';

      final phone =
          pick<String>(['phone', 'telefon', 'contact_number', 'mobile']) ?? '';

      final isOpen = pick<bool>(
              ['is_open', 'siparis_alma_durumu', 'order_open', 'status']) ??
          true;

      // ----- COMMISSION -----
      final comm = pick<String>(['commission_amount', 'paket_komisyon']) ?? '0';

      // ----- PHOTO RULES -----
      final reqPick =
          pick<bool>(['require_pickup_photo', 'pickup_photo_required']) ??
              false;

      final reqDel =
          pick<bool>(['require_delivery_photo', 'delivery_photo_required']) ??
              false;

      // ----- PARTNER CREDS -----
      final pKey = pick<String>([
        'partner_key',
        'Partner-Key',
        'partnerKey',
        'partner_client_key',
        'key',
        'api_key',
      ]);

      final pSecret = pick<String>([
        'partner_secret',
        'Partner-Secret',
        'partnerSecret',
        'partner_client_secret',
        'secret',
        'api_secret',
      ]);

      final token = pick<String>([
        'token',
        'partner_token',
        'access_token',
        'api_token',
      ]);

      final email = pick<String>(['email', 'e_mail', 'mail']);

      // ----- PAYMENT SIDE -----
      final payRecv = pick<bool>(['pay_receiver', 'odeme_alici']) ?? false;
      final paySend = pick<bool>(['pay_sender', 'odeme_gonderici']) ?? false;
      final payAdm = pick<bool>(['pay_admin', 'odeme_yonetici']) ?? false;

      // ----- ADDRESS & LOCATION -----
      // Bazı backendler address’i farklı key ile döndürür
      final address = pick<String>([
            'address',
            'adres',
            'full_address',
            'location_address',
            'pickup_address',
          ]) ??
          '';

      // lat/lng bazen string bazen num gelir
      final latStr = pick<String>(['latitude', 'lat', 'location_lat']) ?? '';
      final lngStr = pick<String>(['longitude', 'lng', 'location_lng']) ?? '';

      // city/district id mapping (sende karışık olabiliyor)
      // ✅ burada olabildiğince fazla olası key ekledim
      final cityIdStr = pick<String>([
        'city_id',
        'cityId',
        'il_id',
        'ilId',
        'province_id',
        'provinceId',
      ]);

      final districtIdStr = pick<String>([
        'district_id',
        'districtId',
        'ilce_id',
        'ilceId',
        'town_id',
        'townId',
      ]);

      // bazı backendler country_id = il diye kullanıyor (sen bunu demiştin)
      // bu durumda district id hiç yoksa city/districti buna göre doldururuz
      final maybeCityFromCountryId = pick<String>(['country_id', 'countryId']);

      // ✅ Öncelik: city_id -> district_id, yoksa country_id / city_id karışıklığına düş
      int? parsedCityId =
          int.tryParse((cityIdStr ?? '').toString()) ?? _selectedCityId;

      int? parsedDistrictId =
          int.tryParse((districtIdStr ?? '').toString()) ?? _selectedDistrictId;

      if (districtIdStr == null &&
          cityIdStr == null &&
          maybeCityFromCountryId != null) {
        // Senin sistemde country_id=il, city_id=ilçe gibi kullanılıyorsa:
        // - mm['country_id'] il
        // - mm['city_id'] ilçe
        // Bu yüzden fallback:
        final fallbackCity = int.tryParse(maybeCityFromCountryId.toString());
        final fallbackDistrict = int.tryParse(
            (pick<String>(['city_id', 'cityId']) ?? '').toString());

        parsedCityId = fallbackCity ?? parsedCityId;
        parsedDistrictId = fallbackDistrict ?? parsedDistrictId;
      }

      // ----- SET STATE -----
      setState(() {
        _nameC.text = name;
        _phoneC.text = phone;
        _isOpen = isOpen;

        _commissionC.text = comm;

        _hasPickupPhoto = reqPick;
        _hasDeliveryPhoto = reqDel;

        _payReceiver = payRecv;
        _paySender = paySend;
        _payAdmin = payAdm;

        _partnerKeyC.text = pKey ?? '';
        _partnerSecretC.text = pSecret ?? '';
        _tokenC.text = token ?? '';

        _emailC.text = email ?? '';

        _addrC.text = address;

        // lat/lng inputlarınız TextEditingController olduğu için string basıyoruz
        _latC.text = latStr;
        _lngC.text = lngStr;

        _selectedCityId = parsedCityId;
        _selectedDistrictId = parsedDistrictId;
        _partnerKeyC.text = pKey ?? '';
        _partnerSecretC.text = pSecret ?? '';
        _tokenC.text = token ?? '';
      });
      // ✅ partner dolduysa catalog’u şimdi çek
      if ((_partnerKeyC.text.trim().isNotEmpty) &&
          (_partnerSecretC.text.trim().isNotEmpty)) {
        setState(() {
          _catalogFuture = _fetchCatalogAllPages();
        });
      }
      // ✅ City seçildiyse district listesi yeniden çekilsin,
      // yoksa dropdown’da ilçe görünmeyebilir
      await _loadDistrictsByCity();
    } catch (e) {
      setState(() => _error = 'Detay getirilemedi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveToApi() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      final api = context.read<ApiClient>();

      String cleanNum(String s) =>
          s.replaceAll(' ', '').replaceAll('.', '').replaceAll(',', '.').trim();

/*
      await api.updateClient(
        widget.id,
        name: _nameC.text.trim(),
        contactNumber: _phoneC.text.trim().isEmpty ? null : _phoneC.text.trim(),
        isOpen: _isOpen,
        requirePickupPhoto: _hasPickupPhoto,
        requireDeliveryPhoto: _hasDeliveryPhoto,

        // senin eski çağrın böyleydi, bozmuyorum:
        commission_type: 'fixed',
        commission_rate: cleanNum(_commissionC.text), // "100.00"
        kmPrice: '0',

        payReceiver: _payReceiver,
        paySender: _paySender,
        payAdmin: _payAdmin,
      );

*/

      await api.updatePartnerClient2(
        widget.id,

        // ---- temel ----
        name: _nameC.text.trim(),
        contactNumber: _phoneC.text.trim().isEmpty ? null : _phoneC.text.trim(),

        // ---- adres & konum ----
        address: _addrC.text.trim().isEmpty ? null : _addrC.text.trim(),

        countryId: _selectedCityId,
        cityId: _selectedDistrictId,

        city: _cities
                .firstWhere(
                  (c) => c.id == _selectedCityId,
                  orElse: () => City(id: 0, name: ''),
                )
                .name
                .trim()
                .isEmpty
            ? null
            : _cities
                .firstWhere(
                  (c) => c.id == _selectedCityId,
                  orElse: () => City(id: 0, name: ''),
                )
                .name,

        district: _districts
                .firstWhere(
                  (d) => d.id == _selectedDistrictId,
                  orElse: () => District(id: 0, name: '', countryId: 0),
                )
                .name
                .trim()
                .isEmpty
            ? null
            : _districts
                .firstWhere(
                  (d) => d.id == _selectedDistrictId,
                  orElse: () => District(id: 0, name: '', countryId: 0),
                )
                .name,

        latitude: _latC.text.trim().isEmpty ? null : _latC.text.trim(),
        longitude: _lngC.text.trim().isEmpty ? null : _lngC.text.trim(),
        locationLat: double.tryParse(_latC.text),
        locationLng: double.tryParse(_lngC.text),

        // ---- mevcut iş kuralları ----
        isOpen: _isOpen,
        requirePickupPhoto: _hasPickupPhoto,
        requireDeliveryPhoto: _hasDeliveryPhoto,
        commissionAmount: cleanNum(_commissionC.text),

        payReceiver: _payReceiver,
        paySender: _paySender,
        payAdmin: _payAdmin,

        // ---- opsiyonel (istersen sonra bağlarız) ----
        webhookUrl: null,
        meta: null,
      );

      await api.updatePartnerClient(
        widget.id,

        // ---- temel ----
        name: _nameC.text.trim(),
        email:
            _emailC.text.trim().isEmpty ? null : _emailC.text.trim(), // varsa
        phone: _phoneC.text.trim().isEmpty ? null : _phoneC.text.trim(),
        contactNumber: _phoneC.text.trim().isEmpty ? null : _phoneC.text.trim(),

        // ---- adres & konum ----
        address: _addrC.text.trim().isEmpty ? null : _addrC.text.trim(),

        countryId: 34, // Türkiye
        cityId: _selectedCityId, // Şehir (İl) id

        city: _cities
                .firstWhere(
                  (c) => c.id == _selectedCityId,
                  orElse: () => City(id: 0, name: ''),
                )
                .name
                .trim()
                .isEmpty
            ? null
            : _cities
                .firstWhere(
                  (c) => c.id == _selectedCityId,
                  orElse: () => City(id: 0, name: ''),
                )
                .name,

        district: _districts
                .firstWhere(
                  (d) => d.id == _selectedDistrictId,
                  orElse: () => District(id: 0, name: '', countryId: 0),
                )
                .name
                .trim()
                .isEmpty
            ? null
            : _districts
                .firstWhere(
                  (d) => d.id == _selectedDistrictId,
                  orElse: () => District(id: 0, name: '', countryId: 0),
                )
                .name,

        latitude: _latC.text.trim().isEmpty ? null : _latC.text.trim(),
        longitude: _lngC.text.trim().isEmpty ? null : _lngC.text.trim(),
        locationLat: double.tryParse(_latC.text.replaceAll(',', '.')),
        locationLng: double.tryParse(_lngC.text.replaceAll(',', '.')),

        // ---- mevcut iş kuralları ----
        isOpen: _isOpen,
        requirePickupPhoto: _hasPickupPhoto,
        requireDeliveryPhoto: _hasDeliveryPhoto,
        commissionAmount: cleanNum(_commissionC.text),

        payReceiver: _payReceiver,
        paySender: _paySender,
        payAdmin: _payAdmin,

        // ---- opsiyonel ----
        webhookUrl: null,
        meta: null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Kaydedildi')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Kaydetme hatası: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------- helpers ----------------

  Widget _productPriceCard(_CatalogProduct p) {
    final vars = p.variants
        //     .where((v) => v.partnerClientId == 1) // ✅ sadece partner_client_id=1
        .toList();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, color: kText, fontSize: 15),
                ),
              ),
              _miniBadge('${vars.length} varyant', kBlue),
            ],
          ),
          const SizedBox(height: 10),
          if (vars.isEmpty)
            Text('Bu üründe partner_client varyantı yok.',
                style:
                    const TextStyle(color: kMuted, fontWeight: FontWeight.w800))
          else
            ...vars.map((v) => _variantRow(v)).toList(),
        ],
      ),
    );
  }

  Widget _variantRow(_CatalogVariant v) {
    final c = TextEditingController(
      text: (v.price ?? 0).toStringAsFixed(2).replaceAll('.', ','),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.name ?? 'Varyant',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, color: kText)),
                const SizedBox(height: 6),
                Text('id: ${v.id} • partner_client_id: ${v.partnerClientId}',
                    style: const TextStyle(
                        color: kMuted,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ],
            ),
          ),
          SizedBox(
            width: 180,
            child: TextField(
              controller: c,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'Fiyat (₺)'),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  String _formatMoney(String raw) {
    if (raw.isEmpty) return '0,00';
    final s = raw.replaceAll(RegExp(r'[^0-9,\.]'), '');
    final asNum =
        double.tryParse(s.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
    return asNum.toStringAsFixed(2).replaceAll('.', ',');
  }

  // ---------------- UI TOKENS (Courier premium ile aynı yaklaşım) ----------------
  static const Color kBg = Color(0xFFF6F7FB);
  static const Color kText = Color(0xFF0F172A);
  static const Color kMuted = Color(0xFF64748B);
  static const Color kBorder = Color(0xFFE6E8EF);

  static const Color kBlue = Color(0xFF062F22);
  static const Color kGreen = Color(0xFF062F22); // koyu kartgreen
  static const Color kAmber = Color(0xFF062F22); // koyu kartgreen
  static const Color kRed = Color(0xFF062F22);

  BorderRadius get _r12 => BorderRadius.circular(16);

  @override
  Widget build(BuildContext context) {
    final shortName = (_nameC.text.trim().isEmpty ? '—' : _nameC.text.trim())
        .split(' ')
        .take(2)
        .join(' ');

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
/*
        floatingActionButton: _loading
            ? null
            : FloatingActionButton.extended(
                heroTag: 'save_customer',
                backgroundColor: kBlue,
                icon: const Icon(Icons.save),
                label: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
                onPressed: _saving ? null : _saveToApi,
              ),
*/

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
                            onAction: _loadFromApi,
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
        ' İşletme Detay  $shortName',
        style: const TextStyle(fontWeight: FontWeight.w900, color: kText),
      ),
      leadingWidth: 118,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: _backPill(onTap: () => context.replace('/customers')),
      ),
      actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: _loading ? null : _loadFromApi,
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 8),
      ],
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
                onPressed: _loadFromApi,
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
                          height: 420,
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

  // ---------------- LEFT CARD ----------------

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
            child: const Icon(Icons.storefront_rounded, size: 48, color: kText),
          ),
          const SizedBox(height: 12),
          _statusChip(_isOpen),
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
          const SizedBox(height: 6),
          Text(
            _phoneC.text.trim().isEmpty ? '—' : _phoneC.text.trim(),
            style: const TextStyle(
              color: kBlue,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _emailC.text.trim().isEmpty ? '—' : _emailC.text.trim(),
            style: const TextStyle(
              color: kBlue,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          _infoLine(
            icon: Icons.photo_camera_back_outlined,
            label: 'Alış Foto',
            value: _hasPickupPhoto ? 'Zorunlu' : 'Serbest',
          ),
          const SizedBox(height: 8),
          _infoLine(
            icon: Icons.photo_camera_front_outlined,
            label: 'Teslim Foto',
            value: _hasDeliveryPhoto ? 'Zorunlu' : 'Serbest',
          ),
          const SizedBox(height: 8),
          _infoLine(
            icon: Icons.payments_outlined,
            label: 'Eklenecek Satış Oranı (%)',
            value: '${_commissionC.text} ',
          ),
          const SizedBox(height: 12),
          /*    Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Ödeme Tarafı',
              style: TextStyle(
                color: kMuted,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),*/
          const SizedBox(height: 10),
          /*    Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniChip('Alıcı', _payReceiver, kGreen),
              _miniChip('Gönderici', _paySender, kBlue),
              _miniChip('Yönetici', _payAdmin, kAmber),
            ],
          ),*/
        ],
      ),
    );
  }

  Widget _miniChip(String text, bool on, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: on ? c.withOpacity(.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: (on ? c : kBorder).withOpacity(.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: on ? c : kMuted,
        ),
      ),
    );
  }

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
            active ? 'Sipariş Açık' : 'Sipariş Kapalı',
            style: TextStyle(fontWeight: FontWeight.w900, color: color),
          ),
        ],
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

  // ---------------- RIGHT PANEL ----------------

  Widget _rightPanel() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                label: _isOpen ? 'Açık' : 'Kapalı',
                color: _isOpen ? kGreen : kRed,
                onTap: () => setState(() => _isOpen = !_isOpen),
              ),
              const SizedBox(width: 8),
              _pillButton(
                icon: Icons.save_outlined,
                label: _saving ? '...' : 'Kaydet',
                color: kBlue,
                onTap: _saving ? () {} : _saveToApi,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              labelColor: kText,
              unselectedLabelColor: kMuted,
              indicatorColor: kBlue,
              tabs: const [
                Tab(icon: Icon(Icons.info_outline), text: 'Genel'),
                Tab(icon: Icon(Icons.location_on_outlined), text: 'Adres'),
                Tab(
                    icon: Icon(Icons.receipt_long_outlined),
                    text: 'Ürün Fiyat Listesi'),
                //     Tab(icon: Icon(Icons.directions_bike), text: 'Kuryeler'),
                Tab(icon: Icon(Icons.lock_reset), text: 'Güvenlik'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _tabGenel(),
                _tabAdresler(),
                //      _tabSiparisler(),
                _tabUrunFiyatListesi(),

                //    _tabKuryeler(),
                _tabSifre(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreatePriceListDialog() async {
    final multC = TextEditingController(text: '1,20'); // default %20
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fiyat Listesi Oluştur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Çarpan gir (örn: 1,20 = %20 zam)'),
            const SizedBox(height: 10),
            TextField(
              controller: multC,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Çarpan'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, multC.text.trim()),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );

    if (res == null || res.trim().isEmpty) return;
    await _createPriceList(multiplierRaw: res.trim());
  }

  Future<void> _createPriceList({required String multiplierRaw}) async {
    setState(() {
      _priceLoading = true;
      _priceError = null;
    });

    try {
      final partnerKey = _partnerKeyC.text.trim();
      final partnerSecret = _partnerSecretC.text.trim();
      final token = _tokenC.text.trim();

      final uri =
          Uri.parse('$_apiBase/api/partner/v1/catalog/build-price-list');

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Partner-Key': partnerKey,
        'X-Partner-Secret': partnerSecret,
      };
      if (token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final body = jsonEncode({
        "partner_client_id": _kPartnerClientId, // 1
        "multiplier": _cleanNum(multiplierRaw), // "1.20"
        "round": 2
      });

      final r = await http.post(uri, headers: headers, body: body);

      if (r.statusCode < 200 || r.statusCode >= 300) {
        throw Exception('Oluşturma başarısız (${r.statusCode}): ${r.body}');
      }

      // Başarılı -> katalog yenile
      setState(() {
        _catalogFuture = _fetchCatalogAllPages();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fiyat listesi oluşturuldu.')),
      );
    } catch (e) {
      setState(() => _priceError = e.toString());
    } finally {
      if (mounted) setState(() => _priceLoading = false);
    }
  }

  // ---------------- TABS ----------------

  Widget _tabUrunFiyatListesi() {
    return FutureBuilder<List<_CatalogProduct>>(
      future: _catalogFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _emptyCard(
              'Fiyat Listesi', 'Katalog yüklenemedi: ${snap.error}');
        }

        final all = snap.data ?? const <_CatalogProduct>[];
        /* if (all.isEmpty) {
          return _emptyCard('Fiyat Listesi', 'Ürün bulunamadı');
        }
        */
        if (all.isEmpty) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _Card(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Fiyat Listesi',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, color: kText)),
                    const SizedBox(height: 10),
                    const Text(
                      'Bu işletmenin fiyat listesi yok.\nİstersen çarpan ile otomatik oluşturabilirsin.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontWeight: FontWeight.w800, color: kMuted),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _priceLoading
                              ? null
                              : () => _openCreatePriceListDialog(),
                          icon: const Icon(Icons.auto_fix_high),
                          label: Text(
                              _priceLoading ? '...' : 'Fiyat Listesi Oluştur',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: _r12),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _priceLoading
                              ? null
                              : () {
                                  setState(() =>
                                      _catalogFuture = _fetchCatalogAllPages());
                                },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Yenile',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                    if (_priceError != null) ...[
                      const SizedBox(height: 12),
                      Text(_priceError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, color: Colors.red)),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        // ✅ Kategori listesi üret
        final cats = <String>{};
        for (final p in all) {
          for (final c in p.categories) {
            if (c.trim().isNotEmpty) cats.add(c.trim());
          }
        }
        final categories = ['Tümü', ...cats.toList()..sort()];

        // ✅ selected category yoksa reset
        if (!categories.contains(_selectedCategory)) {
          _selectedCategory = 'Tümü';
        }

        // ✅ filtre: kategori + arama
        final q = _priceSearchC.text.trim().toLowerCase();
        final filtered = all.where((p) {
          final okCat = (_selectedCategory == 'Tümü')
              ? true
              : p.categories.any(
                  (c) => c.toLowerCase() == _selectedCategory.toLowerCase());

          final okSearch = q.isEmpty ? true : p.name.toLowerCase().contains(q);

          return okCat && okSearch;
        }).toList();

        return Column(
          children: [
            // --- üst bar: arama ---
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: TextField(
                controller: _priceSearchC,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Ürün ara (örn. elma, armut...)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _priceSearchC.text.trim().isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _priceSearchC.clear();
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),

            // --- kategori "tab" (chip row) ---
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = categories[i];
                  final selected = c == _selectedCategory;
                  return ChoiceChip(
                    label: Text(c,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedCategory = c),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? _emptyCard('Sonuç yok',
                      'Arama/Kategori filtresine göre ürün bulunamadı')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 96),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _productPriceCard(filtered[i]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _tabGenel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _editField('İŞLETME ADI *', _nameC, required: true),
            _editField('TELEFON', _phoneC, hint: '(5xx) xxx xx xx'),
            _editField(
              'E-POSTA',
              _emailC,
              keyboardType: TextInputType.emailAddress,
              hint: 'ornek@firma.com',
            ),
            const SizedBox(height: 6),
            _switchRow(
              label: 'Sipariş alma açık',
              value: _isOpen,
              onChanged: (v) => setState(() => _isOpen = v),
              color: _isOpen ? kGreen : kRed,
            ),
            _switchRow(
              label: 'Alış fotoğrafı zorunlu',
              value: _hasPickupPhoto,
              onChanged: (v) => setState(() => _hasPickupPhoto = v),
              color: kBlue,
            ),
            _switchRow(
              label: 'Teslim fotoğrafı zorunlu',
              value: _hasDeliveryPhoto,
              onChanged: (v) => setState(() => _hasDeliveryPhoto = v),
              color: kBlue,
            ),
            const SizedBox(height: 10),
            _editField(
              ' Eklenecek Satış Oranı  (%)',
              _commissionC,
              hint: '0,00',
              keyboardType: TextInputType.number,
              alignRight: true,
            ),
            const SizedBox(height: 14),
            /*   Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ödeme Tarafı',
                style: TextStyle(
                    fontWeight: FontWeight.w900, color: kMuted, fontSize: 12),
              ),
            ),*/
            const SizedBox(height: 10),
            /*  Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _rectToggle('Alıcı', _payReceiver, kGreen,
                    () => setState(() => _payReceiver = !_payReceiver)),
                _rectToggle('Gönderici', _paySender, kBlue,
                    () => setState(() => _paySender = !_paySender)),
                _rectToggle('Yönetici', _payAdmin, kAmber,
                    () => setState(() => _payAdmin = !_payAdmin)),
              ],
            ),*/
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveToApi,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(
                  _saving ? 'Kaydediliyor...' : 'Kaydet',
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

  Widget _tabAdresler() {
    // Ana adres kartı için UI textlerini hazırlayalım
    String nz(String? v, [String fb = '—']) =>
        (v == null || v.trim().isEmpty) ? fb : v;

    String _cityNameById(int? id) {
      final c = _cities.firstWhere(
        (x) => x.id == id,
        orElse: () => City(id: 0, name: ''),
      );
      return nz(c.name);
    }

    String _districtNameById(int? id) {
      final d = _districts.firstWhere(
        (x) => x.id == id,
        orElse: () => District(id: 0, name: '', countryId: 0),
      );
      return nz(d.name);
    }

    // loadFromApi'den gelen ana adresi "model" gibi oluşturuyoruz
    ClientAddress _buildPrimaryFromDetail() {
      return ClientAddress(
        id: 0, // backend adres listesinde yoksa 0 bırak
        title: 'Ana Adres',
        contactName: _nameC.text.trim(),
        contactPhone: _phoneC.text.trim(),
        address: _addrC.text.trim(),
        city: _cityNameById(_selectedCityId),
        district: _districtNameById(_selectedDistrictId),
        latitude: double.tryParse(_latC.text.replaceAll(',', '.')),
        longitude: double.tryParse(_lngC.text.replaceAll(',', '.')),
        cityId: _selectedCityId,
        countryId:
            _selectedDistrictId, // senin mappingin karışık olabilir (kalsın)
        isDefault: true,
      );
    }

    Widget _addressCard(ClientAddress a, {String? badgeText}) {
      final title = nz(a.title, 'Adres');
      final contact = nz(a.contactName);
      final phone = nz(a.contactPhone);
      final addr = nz(a.address);
      final city = nz(a.city);
      final dist = nz(a.district);

      return _Card(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kBlue.withOpacity(.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder),
              ),
              child: const Icon(Icons.place_outlined, color: kText),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: kText,
                        ),
                      ),
                    ),
                    _miniBadge(badgeText ?? 'Adres', kBlue),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    addr,
                    style: const TextStyle(
                      color: kMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (dist != '—' || city != '—') ...[
                    const SizedBox(height: 6),
                    Text(
                      [dist, city].where((s) => s != '—').join(' • '),
                      style: const TextStyle(
                        color: kMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (contact != '—' || phone != '—') ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.person_2_outlined,
                          size: 16, color: kMuted),
                      const SizedBox(width: 6),
                      Text(
                        [contact, phone].where((s) => s != '—').join(' • '),
                        style: const TextStyle(
                          color: kMuted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ]),
                  ],
                  // lat/lng göster (varsa)
                  if ((a.latitude != null && a.longitude != null)) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.my_location_outlined,
                            size: 16, color: kMuted),
                        const SizedBox(width: 6),
                        Text(
                          '${a.latitude!.toStringAsFixed(6)}, ${a.longitude!.toStringAsFixed(6)}',
                          style: const TextStyle(
                            color: kMuted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    )
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Düzenle',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _openAddressSheet(existing: a),
            ),
          ],
        ),
      );
    }

    Widget _emptyState() {
      // ✅ Eğer detail'den adres geldiyse burada ana adres kartını göster
      final hasPrimary = _addrC.text.trim().isNotEmpty;

      if (hasPrimary) {
        final primary = _buildPrimaryFromDetail();
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 96),
          children: [
            _addressCard(primary, badgeText: 'Ana Adres'),
            const SizedBox(height: 10),
            _Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.info_outline, size: 28, color: kMuted),
                  SizedBox(height: 10),
                  Text(
                    'Adres listesi boş görünüyor',
                    style: TextStyle(fontWeight: FontWeight.w900, color: kText),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Detaydan gelen ana adres yukarıda gösterildi.\nSağ alttan yeni adres ekleyebilirsin.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontWeight: FontWeight.w800, color: kMuted),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      // ❌ detail'de de adres yoksa eski boş state
      return Center(
        child: _Card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.location_off_outlined, size: 44, color: kMuted),
              SizedBox(height: 10),
              Text(
                'Kayıtlı adres yok',
                style: TextStyle(fontWeight: FontWeight.w900, color: kText),
              ),
              SizedBox(height: 6),
              Text(
                'Sağ alttan yeni adres ekleyin',
                style: TextStyle(fontWeight: FontWeight.w800, color: kMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        FutureBuilder<List<ClientAddress>>(
          future: context
              .read<ApiClient>()
              .clientAddressesByUAController(widget.id, perPage: -1)
              .then((xs) => xs.map((m) => ClientAddress.fromJson(m)).toList()),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              // hata varsa yine de detail adresi varsa gösterelim:
              return _emptyCard(
                  'Adresler', 'Adresler yüklenemedi: ${snap.error}');
            }

            final items = snap.data ?? const <ClientAddress>[];

            // ✅ liste boşsa fallback
            if (items.isEmpty) return _emptyState();

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 96),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _addressCard(items[i]),
            );
          },
        ),
        Positioned(
          right: 18,
          bottom: 18,
          child: FloatingActionButton.extended(
            heroTag: 'add_addr',
            backgroundColor: kGreen,
            onPressed: () => _openAddressSheet(),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Adres Ekle'),
          ),
        ),
      ],
    );
  }

  Widget _tabSiparisler() {
    return FutureBuilder<List<ClientOrderLite>>(
      future: context.read<ApiClient>().listPartnerClientOrders(widget.id),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return Center(
            child: _emptyCard('ÜRÜN FİYAT LİSTESİ ', 'ÜRÜ bulunamadı'),
          );
        }

        Color statusColor(String s) {
          final t = s.toLowerCase();
          if (t.contains('delivered') || t.contains('teslim')) return kGreen;
          if (t.contains('cancel') || t.contains('iptal')) return kRed;
          return kBlue;
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final o = list[i];
            final amount = '₺${o.totalAmount.toStringAsFixed(2)}';
            final status = o.status ?? '-';
            final when = o.deliveredAt != null
                ? o.deliveredAt!.toString().substring(0, 16)
                : 'Teslim edilmedi';

            return _Card(
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: kBlue.withOpacity(.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kBorder),
                    ),
                    child: const Icon(Icons.delivery_dining_outlined,
                        color: kText),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text('${o.orderNo ?? o.id}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, color: kText)),
                          ),
                          _miniBadge(status, statusColor(status)),
                        ]),
                        const SizedBox(height: 8),
                        Text('${o.fromName} ➜ ${o.toName}',
                            style: const TextStyle(
                                color: kMuted, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.schedule, size: 16, color: kMuted),
                          const SizedBox(width: 6),
                          Text(when,
                              style: const TextStyle(
                                  color: kMuted, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          Text(amount,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, color: kText)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Detay',
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () {
                      // TODO: sipariş detay route
                      // context.go('/orders/${o.id}');
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _tabKuryeler() {
    return _emptyCard('Kuryeler', 'Bu sekme daha sonra bağlanacak.');
  }

  Widget _tabSifre() {
    final pass1 = TextEditingController();
    final pass2 = TextEditingController();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Şifre Değiştir',
                style: TextStyle(
                    fontWeight: FontWeight.w900, color: kText, fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              controller: pass1,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Yeni Şifre',
                prefixIcon: Icon(Icons.lock_reset_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pass2,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Yeni Şifre (Tekrar)',
                prefixIcon: Icon(Icons.lock_reset_rounded),
              ),
            ),
            const SizedBox(height: 14),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 14),
            const Text(
              'Partner Bilgileri',
              style: TextStyle(
                  fontWeight: FontWeight.w900, color: kText, fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _partnerKeyC,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Partner-Key',
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                suffixIcon: IconButton(
                  tooltip: 'Kopyala',
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () =>
                      _copyToClipboard(_partnerKeyC.text, 'Partner-Key'),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _partnerSecretC,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Partner-Secret',
                prefixIcon: const Icon(Icons.key_off_outlined),
                suffixIcon: IconButton(
                  tooltip: 'Kopyala',
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () =>
                      _copyToClipboard(_partnerSecretC.text, 'Partner-Secret'),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tokenC,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'token',
                prefixIcon: const Icon(Icons.token_outlined),
                suffixIcon: IconButton(
                  tooltip: 'Kopyala',
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () => _copyToClipboard(_tokenC.text, 'token'),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final p1 = pass1.text.trim();
                  final p2 = pass2.text.trim();

                  if (p1.isEmpty || p2.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Lütfen iki alanı doldurun.')),
                    );
                    return;
                  }
                  if (p1 != p2) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Şifreler eşleşmiyor.')),
                    );
                    return;
                  }

                  try {
                    final api = context.read<ApiClient>();
                    await api.changeUserPassword(
                        userId: widget.id, newPassword: p1);

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Şifre güncellendi.')),
                    );
                    pass1.clear();
                    pass2.clear();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('$e')));
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
      ),
    );
  }

  // ---------------- Address Sheet ----------------

  void _openAddressSheet({ClientAddress? existing}) {
    final tCtrl = TextEditingController(text: existing?.title ?? '');
    final nCtrl = TextEditingController(text: existing?.contactName ?? '');
    final pCtrl = TextEditingController(text: existing?.contactPhone ?? '');
    final aCtrl = TextEditingController(text: existing?.address ?? '');

    final latCtrl = TextEditingController(
      text: existing?.latitude != null ? existing!.latitude!.toString() : '',
    );
    final lngCtrl = TextEditingController(
      text: existing?.longitude != null ? existing!.longitude!.toString() : '',
    );

    int? selectedCityId = _selectedCityId;
    int? selectedDistrictId = _selectedDistrictId;

    // sheet-local district list (IMPORTANT: modal içinde UI güncellenirken çakışmasın)
    List<District> modalDistricts = List<District>.from(_districts);

    Timer? geoDebounce;
    bool geoLoading = false;
    bool loadingDistricts = false;

    Future<void> geocodeAddress(StateSetter setModalState) async {
      final addr = aCtrl.text.trim();
      if (addr.length < 6) return;

      final cityName = _cities
          .firstWhere((c) => c.id == selectedCityId,
              orElse: () => City(id: 0, name: ''))
          .name;

      final districtName = modalDistricts
          .firstWhere((d) => d.id == selectedDistrictId,
              orElse: () => District(id: 0, name: '', countryId: 0))
          .name;

      final query = '$addr, $districtName, $cityName, Türkiye';

      setModalState(() => geoLoading = true);
      final res = await _geoapifyGeocode(query);
      setModalState(() => geoLoading = false);

      if (res != null) {
        latCtrl.text = res.lat.toStringAsFixed(6);
        lngCtrl.text = res.lon.toStringAsFixed(6);
      }
    }

    InputDecoration _dec(String label, {Widget? suffix}) => InputDecoration(
          labelText: label,
          suffixIcon: suffix,
          filled: true,
          fillColor: const Color(0xFFF8FAFC), // primary soft
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: kGreen.withOpacity(.55), width: 1.4),
          ),
        );

    Widget _sectionTitle(String t) => Row(
          children: [
            Container(
              width: 4,
              height: 16,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: kGreen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              t,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: kText,
                fontSize: 14,
              ),
            ),
          ],
        );

    Widget _pillInfo(String text, {Color? tone}) {
      final c = tone ?? kGreen;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: c.withOpacity(.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.withOpacity(.22)),
        ),
        child: Text(
          text,
          style: TextStyle(fontWeight: FontWeight.w900, color: c, fontSize: 12),
        ),
      );
    }

    Future<List<District>> _loadDistrictsByCityForSheet(int? cityId) async {
      if (cityId == null) return [];
      try {
        final api = context.read<ApiClient>();
        final list =
            await api.fetchDistrictsByCountry(countryId: cityId, perPage: -1);
        return list;
      } catch (_) {
        return [];
      }
    }

    final int? safeCityValue =
        (selectedCityId != null && _cities.any((c) => c.id == selectedCityId))
            ? selectedCityId
            : null;
    final int? safeDistrictValue = (selectedDistrictId != null &&
            modalDistricts.any((d) => d.id == selectedDistrictId))
        ? selectedDistrictId
        : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // ⬅️ primary card gibi dursun
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 14,
            right: 14,
            top: 14,
          ),
          child: _Card(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          existing == null ? 'Adres Ekle' : 'Adresi Düzenle',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: kText,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      _pillInfo(existing == null ? 'Yeni' : 'Düzenle',
                          tone: existing == null ? kAmber : kGreen),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Kapat',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: kMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: _sectionTitle('Adres Bilgileri'),
                  ),
                  const SizedBox(height: 10),

                  TextField(controller: tCtrl, decoration: _dec('Başlık')),
                  const SizedBox(height: 10),
                  TextField(controller: nCtrl, decoration: _dec('İrtibat Adı')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: pCtrl,
                    decoration: _dec('Telefon'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: _sectionTitle('Şehir / İlçe'),
                  ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<int>(
                    value: safeCityValue,
                    decoration: _dec('Şehir (İl)'),
                    items: _cities
                        .map((c) => DropdownMenuItem<int>(
                            value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) async {
                      setModalState(() {
                        selectedCityId = v;
                        selectedDistrictId = null;
                        modalDistricts = [];
                        loadingDistricts = true;
                      });

                      final list = await _loadDistrictsByCityForSheet(v);

                      setModalState(() {
                        modalDistricts = list;
                        selectedDistrictId =
                            list.isNotEmpty ? list.first.id : null;
                        loadingDistricts = false;
                      });
                    },
                  ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<int>(
                    value: safeDistrictValue,
                    decoration: _dec(
                      'İlçe',
                      suffix: loadingDistricts
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                    items: modalDistricts
                        .map((d) => DropdownMenuItem<int>(
                            value: d.id, child: Text(d.name)))
                        .toList(),
                    onChanged: modalDistricts.isEmpty
                        ? null
                        : (v) => setModalState(() => selectedDistrictId = v),
                  ),

                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _sectionTitle('Adres & Konum'),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: aCtrl,
                    maxLines: 2,
                    onChanged: (_) {
                      geoDebounce?.cancel();
                      geoDebounce =
                          Timer(const Duration(milliseconds: 600), () {
                        geocodeAddress(setModalState);
                      });
                    },
                    decoration: _dec(
                      'Adres',
                      suffix: geoLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              tooltip: 'Konum Bul',
                              icon: Icon(Icons.my_location, color: kGreen),
                              onPressed: () => geocodeAddress(setModalState),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: latCtrl,
                          decoration: _dec('Latitude'),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: lngCtrl,
                          decoration: _dec('Longitude'),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Vazgeç',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kText,
                            side: const BorderSide(color: kBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Kaydet',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                kGreen, // primary purple/green tonu
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                          onPressed: () async {
                            final addressDraft = ClientAddress(
                              id: existing?.id ?? 0,

                              // bunlar UI’da kalsın
                              title: existing?.title ?? 'Adres',
                              contactName: existing?.contactName ?? '',
                              contactPhone: existing?.contactPhone ?? '',

                              address: aCtrl.text,
                              city: _cities
                                  .firstWhere((c) => c.id == selectedCityId,
                                      orElse: () => City(id: 0, name: ''))
                                  .name,
                              district: modalDistricts
                                  .firstWhere((d) => d.id == selectedDistrictId,
                                      orElse: () => District(
                                          id: 0, name: '', countryId: 0))
                                  .name,
                              latitude: latCtrl.text.trim().isEmpty
                                  ? null
                                  : double.tryParse(latCtrl.text.trim()),
                              longitude: lngCtrl.text.trim().isEmpty
                                  ? null
                                  : double.tryParse(lngCtrl.text.trim()),

                              countryId: selectedDistrictId, // sende varsa
                              cityId:
                                  selectedCityId == 0 ? null : selectedCityId,
                              isDefault: false,
                            );

                            final body =
                                addressDraft.toPartnerClientUpdateBody();

                            final api = context.read<ApiClient>();

// create/update AYRIMI YOK -> ikisi de aynı endpoint
                            await api.updatePartnerClientAddress(
                                widget.id, body);

                            if (!mounted) return;
                            Navigator.pop(context);
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- UI pieces ----------------

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
            Text(label,
                style: TextStyle(fontWeight: FontWeight.w900, color: color)),
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

  Widget _miniBadge(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(.25)),
      ),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w900, color: c, fontSize: 12),
      ),
    );
  }

  Widget _switchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: _r12,
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, color: kText)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
          ),
        ],
      ),
    );
  }

  Widget _rectToggle(String text, bool selected, Color c, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(.10) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? c : kBorder,
            width: 1.2,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (selected) ...[
            Icon(Icons.check, size: 16, color: c),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: selected ? kText : kMuted,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _editField(
    String label,
    TextEditingController controller, {
    bool required = false,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool alignRight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 260,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: kMuted,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              textAlign: alignRight ? TextAlign.right : TextAlign.left,
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

  Widget _emptyCard(String title, String text) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: _Card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, color: kText)),
              const SizedBox(height: 10),
              Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: kMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// ====== UI BİLEŞENLERİ (premium) ======

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  static const Color kBorder = Color(0xFFE6E8EF);

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

class _CatalogVariant {
  final int id;
  final int partnerClientId;
  final String? name;
  final double? price;

  _CatalogVariant({
    required this.id,
    required this.partnerClientId,
    this.name,
    this.price,
  });

  factory _CatalogVariant.fromJson(Map<String, dynamic> j) {
    double? _toD(dynamic v) {
      if (v == null) return null;

      // ✅ price bazen {price: 104, ...} geliyor
      if (v is Map && v['price'] != null) {
        return _toD(v['price']);
      }

      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().replaceAll(',', '.'));
    }

    return _CatalogVariant(
      id: (j['id'] as num).toInt(),
      partnerClientId: (j['partner_client_id'] as num?)?.toInt() ?? 0,
      name: (j['name'] ?? j['title'] ?? j['variant_name'])?.toString(),
      // ✅ önce price objesine bak
      price: _toD(j['price'] ?? j['sale_price'] ?? j['unit_price']),
    );
  }
}

class _CatalogProduct {
  final int id;
  final String name;
  final List<String> categories;
  final List<_CatalogVariant> variants;

  _CatalogProduct({
    required this.id,
    required this.name,
    required this.categories,
    required this.variants,
  });

  factory _CatalogProduct.fromJson(Map<String, dynamic> j) {
    // ✅ bazen ürün bilgisi j['product'] içinde
    final base =
        (j['product'] is Map) ? Map<String, dynamic>.from(j['product']) : j;

    final rawVariants =
        (j['variants'] is List) ? (j['variants'] as List) : const [];
    final vars = rawVariants
        .whereType<Map>()
        .map((m) => _CatalogVariant.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    final rawCats =
        (j['categories'] is List) ? (j['categories'] as List) : const [];
    final cats = rawCats
        .whereType<Map>()
        .map((m) => (m['name'] ?? '').toString())
        .where((s) => s.trim().isNotEmpty)
        .toList();

    return _CatalogProduct(
      id: (base['id'] as num).toInt(),
      name: (base['name'] ?? base['title'] ?? base['product_name'] ?? '—')
          .toString(),
      categories: cats,
      variants: vars,
    );
  }
}
