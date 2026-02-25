// lib/services/api_client.dart
import 'dart:convert';
import 'dart:io'; // File için
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:haldeki_admin_web/models/category.dart';
import 'package:haldeki_admin_web/models/client_order_lite.dart';
import 'package:haldeki_admin_web/models/dealer_profile.dart';
import 'package:haldeki_admin_web/models/paginated.dart';
import 'package:haldeki_admin_web/models/supplier.dart';
import 'package:haldeki_admin_web/services/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'package:http/http.dart' as http;
import '../models/cash_report_models.dart';

import '../models/models.dart';
import '../models/district.dart' hide District;

class ApiClient {
  // --- Singleton ---
  ApiClient._internal();
  static final ApiClient _i = ApiClient._internal();
  factory ApiClient() => _i;
  DealerProfile? currentProfile;
  late final Dio _dio;
  late final SharedPreferences _prefs;
  int? currentUserId;
  String? currentEmail; // << EKLE
  String? currentName; // << EKLENDİ
  int? currentSupplierId; // 👈 EKLENDİ
  Dio get dio => _dio;

  UserSession? _session;
  UserSession? get session => _session;
  int? get currentPartnerClientId => _session?.partnerClientId;

  Uri _u(String path, [Map<String, dynamic>? q]) =>
      Uri.parse('$AppConfig.apiBase$path').replace(
        queryParameters: (q?.map((k, v) => MapEntry(k, v?.toString())) ?? {}),
      );

  Uri _uPartner2(String path, [Map<String, dynamic>? q]) =>
      Uri.parse('https://api.haldeki.com/api/partner/v1/partner-clients')
          .replace(
        queryParameters: (q?.map((k, v) => MapEntry(k, v?.toString())) ?? {}),
      );

  Uri _uPartner(String path, [Map<String, dynamic>? q]) {
    final base =
        Uri.parse('https://api.haldeki.com/api/partner/v1/partner-clients');
    final u = base.resolve(path); // path’i base’e ekler
    return u.replace(
      queryParameters: q?.map((k, v) => MapEntry(k, v?.toString())),
    );
  }

  Map<String, String> get _jsonHeaders => {
        HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
        HttpHeaders.acceptHeader: 'application/json',
      };

  Future<void> setCurrentSupplierId(int? id) async {
    currentSupplierId = id;
    if (id == null) {
      await _prefs.remove('current_supplier_id');
    } else {
      await _prefs.setInt('current_supplier_id', id);
    }
  }

  Future<Paginated<T>> _getPage<T>(
      String path, T Function(Map<String, dynamic>) fromJson,
      {Map<String, dynamic>? query}) async {
    final r = await http.get(_u(path, query));
    if (r.statusCode >= 400) {
      throw HttpException('GET $path failed: ${r.statusCode} ${r.body}');
    }
    final m = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    return Paginated<T>.fromLaravel(m, fromJson);
  }

  int? _userId;
  int? _dealerId;

  int? get userId => _userId ?? _prefs.getInt('user_id');
  int? get dealerId => _dealerId ?? _prefs.getInt('dealer_id');

  Future<void> setUserId(int? id) async {
    _userId = id;
    if (id == null) {
      await _prefs.remove('user_id');
    } else {
      await _prefs.setInt('user_id', id);
    }
  }

  Future<void> setDealerId(int? id) async {
    _dealerId = id;
    if (id == null) {
      await _prefs.remove('dealer_id');
    } else {
      await _prefs.setInt('dealer_id', id);
    }
  }

  Future<(int? countryId, int? cityId)> partnerClientCountryCity(int id) async {
    final pc = await getPartnerClientDetail(id);
    final countryId = (pc['country_id'] as num?)?.toInt();
    final cityId = (pc['city_id'] as num?)?.toInt();
    return (countryId, cityId);
  }

  Future<CashReportResponse> fetchCashReport2({
    DateTime? from,
    DateTime? to,
    int? dealerId,
    int? courierId,
  }) async {
    // Tarih formatını yyyy-MM-dd olarak elle hazırlayalım (intl'e gerek yok)
    String _fmtDate(DateTime d) {
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      return '$y-$m-$day';
    }

    final now = DateTime.now();
    from ??= DateTime(now.year, now.month, now.day);
    to ??= DateTime(now.year, now.month, now.day);

    final query = <String, dynamic>{
      'from': _fmtDate(from),
      'to': _fmtDate(to),
      // Eğer parametre verilmemişse, panelde login olan bayinin dealerId'sini kullanabiliriz
      if (dealerId != null) 'dealer_id': dealerId,
      if (courierId != null) 'courier_id': courierId,
    };

    try {
      // AppConfig.apiBase zaten /api ile bittiği için:
      // baseUrl: https://.../api/
      // burada 'reports/cash' -> https://.../api/reports/cash
      final res = await _dio.get(
        'cash',
        queryParameters: query,
      );

      final data = res.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Kasa raporu beklenen formatta değil');
      }

      return CashReportResponse.fromJson(data);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final msg = e.response?.data ?? e.message;
      throw Exception('Kasa raporu alınamadı (HTTP $code): $msg');
    } catch (e) {
      throw Exception('Kasa raporu alınamadı: $e');
    }
  }

  Future<DealerProfile> fetchMyProfile() async {
    final res = await _dio.get('profile'); // baseUrl: .../api/v1/

    // Eğer Laravel'de profile() şöyle:
    // return $this->json_custom_response([ 'id' => ..., 'name' => ...]);
    // ise:
    final data = res.data as Map<String, dynamic>;

    // Eğer şöyle döndürürsen:
    // return $this->json_custom_response(['data' => [ 'id' => ..., ...]]);
    // o zaman:
    // final data = res.data['data'] as Map<String, dynamic>;

    final profile = DealerProfile.fromJson(data);
    currentProfile = profile;
    return profile;
  }

// --- PROFİL GÜNCELLEME ---
  Future<DealerProfile> updateMyProfile(Map<String, dynamic> payload) async {
    // endpoint’i senin route’una göre değiştir:
    // örn: POST /api/v1/profile/update -> 'profile/update'
    final res = await _dio.post('profile/update', data: payload);
    final data = res.data;

    final Map<String, dynamic> json;
    if (data is Map<String, dynamic> && data['data'] is Map) {
      json = Map<String, dynamic>.from(data['data'] as Map);
    } else {
      json = Map<String, dynamic>.from(data as Map);
    }

    final profile = DealerProfile.fromJson(json);
    currentProfile = profile;
    return profile;
  }

  // --- ŞİFRE DEĞİŞTİRME ---
  Future<void> changePassword(String oldPassword, String newPassword) async {
    // Laravel UserController@changePassword route’u neyse onu kullan:
    // örn: POST /api/v1/change-password
    await _dio.post('change-password', data: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  Future<CashReportResponse> fetchCashReport({
    DateTime? from,
    DateTime? to,
    int? dealerId,
    int? courierId,
  }) async {
    String _fmtDate(DateTime d) {
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      return '$y-$m-$day';
    }

    final now = DateTime.now();
    from ??= DateTime(now.year, now.month, now.day);
    to ??= DateTime(now.year, now.month, now.day);
    dealerId ??= this.dealerId ?? session?.dealerId;

    final query = <String, dynamic>{
      'from': _fmtDate(from),
      'to': _fmtDate(to),
      // Eğer parametre verilmemişse, panelde login olan bayinin dealerId'sini kullanabiliriz
      if (dealerId != null) 'dealer_id': dealerId,
      if (courierId != null) 'courier_id': courierId,
    };

    try {
      final res = await _dio.get(
        'cash', // backend: /api/v1/cash
        queryParameters: query,
      );

      final data = res.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Kasa raporu beklenen formatta değil');
      }

      return CashReportResponse.fromJson(data);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final msg = e.response?.data ?? e.message;
      throw Exception('Kasa raporu alınamadı (HTTP $code): $msg');
    } catch (e) {
      throw Exception('Kasa raporu alınamadı: $e');
    }
  }

  Future<void> uploadProfileDocument({
    required String type,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final formData = FormData.fromMap({
      'type': type, // backend’de belge tipini ayırt etmek için
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
      ),
    });

    // Laravel tarafında UserController veya ayrı DocumentController’da
    // örn: Route::post('profile/documents', [UserController::class, 'uploadDocument']);
    await _dio.post('profile/documents', data: formData);
  }

  /// Tek seferde ikisini set etmek için:
  Future<void> setUserContext({int? userId, int? dealerId}) async {
    await setUserId(userId);
    await setDealerId(dealerId);
  }

  Future<void> init22() async {
    _prefs = await SharedPreferences.getInstance();

    _dio = Dio(
      BaseOptions(
        baseUrl: '${AppConfig.apiBase}/',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {
          'Accept': 'application/json',
          'Accept-Language': 'tr-TR',
        },
      ),
    );

    _userId = _prefs.getInt('user_id');
    _dealerId = _prefs.getInt('dealer_id');

    // Token
    final token = _prefs.getString('token');
    if (token?.isNotEmpty == true) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
    if (_session?.email != null && _session!.email!.isNotEmpty) {
      currentEmail = _session!.email;
      await _prefs.setString('current_email', _session!.email);
      currentSupplierId = _prefs.getInt('current_supplier_id');
    }
    // Log + 401 yakalama
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: false,
      requestHeader: false,
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (e, handler) async {
          if (e.response?.statusCode == 401) {
            await setToken(null);
          }
          handler.next(e);
        },
      ),
    );
  }

  Future<void> initOld() async {
    _prefs = await SharedPreferences.getInstance();

    _dio = Dio(
      BaseOptions(
        baseUrl: '${AppConfig.apiBase}/',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {
          'Accept': 'application/json',
          'Accept-Language': 'tr-TR',
        },
      ),
    );

    // ID'ler
    _userId = _prefs.getInt('user_id');
    _dealerId = _prefs.getInt('dealer_id');
    currentUserId = _userId;
    currentSupplierId = _prefs.getInt('current_supplier_id');

    // ⬇️ Email + Session geri yükle
    // 1) Session string'den yükle (eğer kaydettiysen)
    final encodedSession = _prefs.getString('user_session');
    if (encodedSession != null && encodedSession.isNotEmpty) {
      try {
        _session = UserSession.fromEncoded(encodedSession);

        if (_session!.userId != null) {
          currentUserId = _session!.userId;
          await setUserId(_session!.userId);
        }

        if (_session!.email != null && _session!.email!.isNotEmpty) {
          currentEmail = _session!.email;
          await _prefs.setString('current_email', _session!.email!);
        }
      } catch (_) {
        // bozuk session string'i varsa sessizce geç
      }
    }

    // 2) Eğer session'dan email gelmediyse, direkt prefs'ten dene
    currentEmail ??= _prefs.getString('current_email');

    // Token
    final token = _prefs.getString('token');
    if (token?.isNotEmpty == true) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }

    // Log + 401 interceptor
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: false,
      requestHeader: false,
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (e, handler) async {
          if (e.response?.statusCode == 401) {
            await setToken(null);
          }
          handler.next(e);
        },
      ),
    );
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    _dio = Dio(
      BaseOptions(
        baseUrl: '${AppConfig.apiBase}/',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {
          'Accept': 'application/json',
          'Accept-Language': 'tr-TR',
        },
      ),
    );

    // 1) Session geri yükle (varsa)
    final encodedSession = _prefs.getString('user_session');
    if (encodedSession != null && encodedSession.isNotEmpty) {
      try {
        _session = UserSession.fromEncoded(encodedSession);
        _userId = _session!.userId;
        _dealerId = _session!.dealerId;

        // persist garanti (bazı eski sürümler yazmamış olabilir)
        await _prefs.setInt('user_id', _userId!);
        await _prefs.setInt('dealer_id', _dealerId!);

        currentUserId = _userId;
        currentEmail = _session!.email;
      } catch (_) {
        // bozuk session ise sessiz geç
      }
    }

    // 2) Eğer session yoksa prefs'ten yükle
    _userId ??= _prefs.getInt('user_id');
    _dealerId ??= _prefs.getInt('dealer_id');
    currentUserId ??= _userId;
    currentEmail ??= _prefs.getString('current_email');
    currentSupplierId = _prefs.getInt('current_supplier_id');

    // 3) Token
    final token = _prefs.getString('token');
    if (token != null && token.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }

    // 4) Interceptors
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: false,
      requestHeader: false,
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (e, handler) async {
          if (e.response?.statusCode == 401) {
            await setToken(null);
          }
          handler.next(e);
        },
      ),
    );
  }

/*
  Future<void> setSession(UserSession session) async {
    _session = session;
    await _prefs.setString('user_session', session.toEncoded());
  }
*/
  Future<void> setSession(UserSession session) async {
    _session = session;

    // memory
    _userId = session.userId;
    _dealerId = session.dealerId;

    // globals
    currentUserId = session.userId;
    currentEmail = session.email;
    currentName = session.name; // 🔥 EKLENDİ

    // persist
    await _prefs.setInt('user_id', session.userId);
    await _prefs.setInt('dealer_id', session.dealerId);
    await _prefs.setString('current_email', session.email);
    await _prefs.setString('current_name', session.name); // 🔥 EKLENDİ
    await _prefs.setString('user_session', session.toEncoded());

    // notifyListeners(); // 🔥 ÇOK ÖNEMLİ
  }

  Future<void> setSessionOld(UserSession session) async {
    _session = session;

    // User + Email global
    if (session.userId != null) {
      currentUserId = session.userId;
      await setUserId(session.userId); // hem memory, hem SharedPreferences
    }

    if (session.email != null && session.email!.isNotEmpty) {
      currentEmail = session.email;
      await _prefs.setString('current_email', session.email!);
    }

    await _prefs.setString('user_session', session.toEncoded());
  }

  // ---- Token Yönetimi ----
  Future<bool> isLoggedIn() async => _prefs.getString('token') != null;

  Future<void> setToken(String? token) async {
    if (token == null || token.isEmpty) {
      await _prefs.remove('token');
      _dio.options.headers.remove('Authorization');
    } else {
      await _prefs.setString('token', token);
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  // ---- AUTH ----
  Future<Response> login(String email, String password) =>
      _dio.post('login', data: {'email': email, 'password': password});

  Future<Response> me() => _dio.get('auth/me');

  Future<void> logout() async {
    try {
      await _dio.post('logout');
    } catch (_) {}
    await setToken(null);
  }

  // ---- JSON helpers ----
  Future<Map<String, dynamic>> getJson(String path,
      {Map<String, dynamic>? query}) async {
    final res = await _dio.get(path, queryParameters: query);
    final data = res.data;
    return (data is Map<String, dynamic>) ? data : {'data': data};
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final res = await _dio.post(
      path,
      data: body,
      queryParameters: query,
      options: headers == null ? null : Options(headers: headers),
    );
    final data = res.data;
    return (data is Map<String, dynamic>) ? data : {'data': data};
  }

  // ---- CATALOG / ORDERS ----
  Future<Response> categories() => _dio.get('categories');

  Future<Response> listings({String? q, int? categoryId, int page = 1}) =>
      _dio.get('listings', queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (categoryId != null) 'category_id': categoryId,
        'page': page,
      });

  Future<Response> listing(int id) => _dio.get('listings/$id');

  Future<bool> toggleFavorite(int id) async {
    final r = await _dio.post('listings/$id/favorite');
    final d = r.data;
    if (d is Map) return d['liked'] == true;
    return true;
  }

  Future<List<dynamic>> previousOrdersByEmail(String email) async {
    final res = await _dio.post('previous-orders', data: {'email': email});
    final data = res.data;

    if (data is List) return data.cast<dynamic>();
    if (data is Map) {
      final d = data['data'];
      if (d is List) return d.cast<dynamic>();
      if (d is Map && d['data'] is List)
        return (d['data'] as List).cast<dynamic>();
    }
    return const [];
  }

  Future<Map<String, dynamic>> previousOrdersJson() =>
      getJson('previous-orders');
  Future<Map<String, dynamic>> ordersJson() => getJson('orders');

  // ============================================================
  // Products
  // ============================================================
  dynamic _body(dynamic req) {
    try {
      final m = req?.toJson();
      if (m is Map<String, dynamic>) return m;
    } catch (_) {}
    if (req is Map<String, dynamic>) return req;
    return req;
  }

  Future<int> createProduct(dynamic req) async {
    final res = await _dio.post('products', data: _body(req));
    final m = res.data;
    if (m is Map && m['id'] != null) {
      return (m['id'] as num).toInt();
    }
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      message: 'createProduct: Beklenen yanıt alınamadı',
    );
  }

  Future<void> updateProduct(int id, dynamic req) async {
    final res = await _dio.put('products/$id', data: _body(req));
    if ((res.statusCode ?? 200) >= 400) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        message: 'updateProduct başarısız (${res.statusCode})',
      );
    }
  }

  Future<void> deleteProduct(int id) async {
    final res = await _dio.delete('products/$id');
    if ((res.statusCode ?? 200) >= 400) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        message: 'deleteProduct başarısız (${res.statusCode})',
      );
    }
  }

  // Variants & Prices
  Future<Map<String, dynamic>> variants(
    int productId, {
    String? q,
    int page = 1,
  }) async {
    final res = await _dio.get(
      'products/$productId/variants',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        'page': page,
      },
    );
    final data = res.data;
    return (data is Map<String, dynamic>) ? data : {'data': data};
  }

  Future<int> createVariant(int productId, dynamic req) async {
    final res =
        await _dio.post('products/$productId/variants', data: _body(req));
    final m = res.data;
    if (m is Map && m['id'] != null) {
      return (m['id'] as num).toInt();
    }
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      message: 'createVariant: Beklenen yanıt alınamadı',
    );
  }

  Future<void> setVariantPrice(int variantId, dynamic req) async {
    final res =
        await _dio.post('variants/$variantId/set-price', data: _body(req));
    if ((res.statusCode ?? 200) >= 400) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        message: 'setVariantPrice başarısız (${res.statusCode})',
      );
    }
  }

  // Upload
  Future<String> uploadImage(File file) async {
    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(file.path),
    });
    final res = await _dio.post('upload', data: form);
    final m = res.data;
    if (m is Map && m['path'] is String) return m['path'] as String;
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      message: 'uploadImage: Beklenen yanıt alınamadı',
    );
  }

  // Suppliers & Categories (http tabanlı kısım)
  Future<Paginated<Supplier>> suppliers({String? q, int page = 1}) =>
      _getPage<Supplier>(
        'suppliers',
        (e) => Supplier.fromJson(e),
        query: {if (q?.isNotEmpty == true) 'q': q, 'page': page},
      );

  Future<int> createSupplier(SupplierCreate req) async {
    final r = await http.post(_u('suppliers'),
        headers: _jsonHeaders, body: jsonEncode(req.toJson()));
    if (r.statusCode >= 400) {
      throw HttpException('createSupplier failed: ${r.statusCode} ${r.body}');
    }
    final m = jsonDecode(r.body) as Map<String, dynamic>;
    return (m['id'] as num).toInt();
  }

  Future<void> updateSupplier(int id, SupplierUpdate req) async {
    final r = await http.put(_u('suppliers/$id'),
        headers: _jsonHeaders, body: jsonEncode(req.toJson()));
    if (r.statusCode >= 400) {
      throw HttpException('updateSupplier failed: ${r.statusCode} ${r.body}');
    }
  }

  Future<void> deleteSupplier(int id) async {
    final r = await http.delete(_u('suppliers/$id'));
    if (r.statusCode >= 400) {
      throw HttpException('deleteSupplier failed: ${r.statusCode} ${r.body}');
    }
  }

  Future<Paginated<Category>> categories2(
          {int? supplierId, String? q, int page = 1}) =>
      _getPage<Category>(
        'categories',
        (e) => Category.fromJson(e),
        query: {
          if (supplierId != null) 'supplier_id': supplierId,
          if (q?.isNotEmpty == true) 'q': q,
          'page': page,
        },
      );

  Future<int> createCategory(CategoryCreate req) async {
    final r = await http.post(_u('categories'),
        headers: _jsonHeaders, body: jsonEncode(req.toJson()));
    if (r.statusCode >= 400) {
      throw HttpException('createCategory failed: ${r.statusCode} ${r.body}');
    }
    final m = jsonDecode(r.body) as Map<String, dynamic>;
    return (m['id'] as num).toInt();
  }

  Future<void> updateCategory(int id, CategoryUpdate req) async {
    final r = await http.put(_u('categories/$id'),
        headers: _jsonHeaders, body: jsonEncode(req.toJson()));
    if (r.statusCode >= 400) {
      throw HttpException('updateCategory failed: ${r.statusCode} ${r.body}');
    }
  }

  Future<void> deleteCategory(int id) async {
    final r = await http.delete(_u('categories/$id'));
    if (r.statusCode >= 400) {
      throw HttpException('deleteCategory failed: ${r.statusCode} ${r.body}');
    }
  }

  Future<List<Country>> fetchCountries() async {
    final r = await http.get(_u('/countries'), headers: _jsonHeaders);
    if (r.statusCode != 200)
      throw Exception('Countries failed (${r.statusCode})');
    final List data = jsonDecode(r.body) as List;
    return data.map((e) => Country.fromJson(e)).toList();
  }

  Future<List<City>> fetchCities({int? countryId}) async {
    final r = await http.get(
      _u('/cities', countryId != null ? {'country_id': '$countryId'} : null),
      headers: _jsonHeaders,
    );
    if (r.statusCode != 200) throw Exception('Cities failed (${r.statusCode})');
    final List data = jsonDecode(r.body) as List;
    return data.map((e) => City.fromJson(e)).toList();
  }

  Future<UserMinimal> createUser({
    required bool isCourier,
    required String name,
    String? email,
    required String password,
    String? username,
    String? contactNumber,
    int? countryId,
    int? dealerId,
    int? cityId,
    String? districtId,
    String? address,
    String? latitude,
    String? longitude,
    double? locationLat,
    double? locationLng,
    String? iban,
    String? bankAccountOwner,
    String? vehiclePlate,
    String? commissionRate,
    String commissionType = 'percent',
    bool? canTakeOrders,
    bool? hasHadiAccount,
    String? secretNote,
    List<File>? documents,
    File? residencePdf,
    File? driverFront,
    File? goodConductPdf,
    String? cityName, // şehir ismi
    String? district, // ilçe ismi
    String? userType, // 'client' | 'user' | 'delivery_man'
  }) async {
    // 1) user_type'ı belirle
    // - Eğer userType parametresi geldiyse onu kullan
    // - Gelmediyse: kurye ise delivery_man, değilse client
    final String resolvedType =
        userType ?? (isCourier ? 'delivery_man' : 'client');

    // 2) Endpoint seçimi
    //  - delivery_man -> couriers
    //  - user         -> users
    //  - client       -> clients
    late final String endpoint;
    switch (resolvedType) {
      case 'delivery_man':
        endpoint = 'couriers';
        break;
      case 'user':
        endpoint = 'users';
        break;
      case 'client':
      default:
        endpoint = 'clients';
        break;
    }

    final baseFields = <String, dynamic>{
      'name': name,
      'password': password,
      'user_type': resolvedType, // client / user / delivery_man

      if (email != null && email.isNotEmpty) 'email': email,
      if (username != null && username.isNotEmpty) 'username': username,
      if (contactNumber != null && contactNumber.isNotEmpty)
        'contact_number': contactNumber,

      // City/district isimleri
      if (cityName != null && cityName.isNotEmpty) 'city': cityName,
      if (district != null && district.isNotEmpty) 'district': district,

      if (countryId != null) 'country_id': countryId,
      if (cityId != null) 'city_id': cityId,
      if (address != null && address.isNotEmpty) 'address': address,
      if (locationLat != null) 'location_lat': locationLat,
      if (locationLng != null) 'location_lng': locationLng,

      if (latitude != null && latitude.isNotEmpty && locationLat == null)
        'latitude': latitude,
      if (longitude != null && longitude.isNotEmpty && locationLng == null)
        'longitude': longitude,

      if (iban != null && iban.isNotEmpty) 'iban': iban,
      if (bankAccountOwner != null && bankAccountOwner.isNotEmpty)
        'bank_account_owner': bankAccountOwner,
      if (vehiclePlate != null && vehiclePlate.isNotEmpty)
        'vehicle_plate': vehiclePlate,
      if (commissionRate != null && commissionRate.isNotEmpty)
        'commission_rate': commissionRate,
      if (resolvedType == 'delivery_man') 'commission_type': commissionType,
      if (canTakeOrders != null) 'can_take_orders': canTakeOrders ? 1 : 0,
      if (hasHadiAccount != null) 'has_hadi_account': hasHadiAccount ? 1 : 0,
      if (secretNote != null && secretNote.isNotEmpty)
        'secret_note': secretNote,
      if (dealerId != null) 'dealer_id': dealerId,
    };

    Future<FormData> buildFormData() async {
      final map = Map<String, dynamic>.from(baseFields);

      if (documents != null && documents!.isNotEmpty) {
        final list = <MultipartFile>[];
        for (final f in documents!) {
          final fn = f.path.split(Platform.pathSeparator).last;
          list.add(await MultipartFile.fromFile(f.path, filename: fn));
        }
        map['attachments[]'] = list;
      }

      if (residencePdf != null) {
        map['residence_pdf'] = await MultipartFile.fromFile(
          residencePdf!.path,
          filename: residencePdf!.path.split(Platform.pathSeparator).last,
        );
      }
      if (driverFront != null) {
        map['driver_front'] = await MultipartFile.fromFile(
          driverFront!.path,
          filename: driverFront!.path.split(Platform.pathSeparator).last,
        );
      }
      if (goodConductPdf != null) {
        map['good_conduct'] = await MultipartFile.fromFile(
          goodConductPdf!.path,
          filename: goodConductPdf!.path.split(Platform.pathSeparator).last,
        );
      }

      return FormData.fromMap(map);
    }

    final urls = <String>['$endpoint', endpoint];

    Response res;
    DioException? lastErr;

    for (final url in urls) {
      try {
        final form = await buildFormData();
        res = await _dio.post(url, data: form);
        final data = res.data;
        int? id;
        String type = resolvedType; // default resolvedType

        if (data is Map) {
          final m = Map<String, dynamic>.from(data);
          final n = m['user_id'] ??
              m['id'] ??
              (m['data'] is Map ? (m['data'] as Map)['id'] : null);
          if (n is num) id = n.toInt();
          if (m['type'] is String && (m['type'] as String).isNotEmpty) {
            type = m['type'] as String;
          }
        }

        if (id == null) {
          throw DioException(
            requestOptions: res.requestOptions,
            response: res,
            message: 'createUser: ID bulunamadı',
          );
        }
        return UserMinimal(id: id, name: name, type: type);
      } on DioException catch (e) {
        lastErr = e;
        final code = e.response?.statusCode;
        if (code != 404 && code != 405) break;
      }
    }

    throw lastErr ??
        DioException(
          requestOptions: RequestOptions(path: urls.last),
          message: 'createUser: bilinmeyen hata',
        );
  }

  // ========= USERS (create) =========
  Future<UserMinimal> createUser12({
    required bool isCourier,
    required String name,
    String? email,
    required String password,
    String? username,
    String? contactNumber,
    int? countryId,
    int? dealerId,
    int? cityId,
    String? district,
    String? address,
    String? latitude,
    String? longitude,
    double? locationLat,
    double? locationLng,
    String? iban,
    String? bankAccountOwner,
    String? vehiclePlate,
    String? commissionRate,
    String commissionType = 'percent',
    bool? canTakeOrders,
    bool? hasHadiAccount,
    String? secretNote,
    List<File>? documents,
    File? residencePdf,
    File? driverFront,
    File? goodConductPdf,
  }) async {
    final endpoint = isCourier ? 'couriers' : 'clients';

    final fields = <String, dynamic>{
      'name': name,
      'password': password,
      'user_type': isCourier ? 'delivery_man' : 'client',
      if (email != null && email.isNotEmpty) 'email': email,
      if (username != null && username.isNotEmpty) 'username': username,
      if (contactNumber != null && contactNumber.isNotEmpty)
        'contact_number': contactNumber,
      if (countryId != null) 'country_id': countryId,
      if (cityId != null) 'city_id': cityId,
      if (district != null && district.isNotEmpty) 'district': district,
      if (address != null && address.isNotEmpty) 'address': address,
      if (locationLat != null) 'location_lat': locationLat,
      if (locationLng != null) 'location_lng': locationLng,
      if (latitude != null && latitude.isNotEmpty && locationLat == null)
        'latitude': latitude,
      if (longitude != null && longitude.isNotEmpty && locationLng == null)
        'longitude': longitude,
      if (iban != null && iban.isNotEmpty) 'iban': iban,
      if (bankAccountOwner != null && bankAccountOwner.isNotEmpty)
        'bank_account_owner': bankAccountOwner,
      if (vehiclePlate != null && vehiclePlate.isNotEmpty)
        'vehicle_plate': vehiclePlate,
      if (commissionRate != null && commissionRate.isNotEmpty)
        'commission_rate': commissionRate,
      if (isCourier) 'commission_type': commissionType,
      if (canTakeOrders != null) 'can_take_orders': canTakeOrders ? 1 : 0,
      if (hasHadiAccount != null) 'has_hadi_account': hasHadiAccount ? 1 : 0,
      if (secretNote != null && secretNote.isNotEmpty)
        'secret_note': secretNote,
      if (dealerId != null) 'dealer_id': dealerId,
    };

    if (documents != null && documents.isNotEmpty) {
      final list = <MultipartFile>[];
      for (final f in documents) {
        final fn = f.path.split(Platform.pathSeparator).last;
        list.add(await MultipartFile.fromFile(f.path, filename: fn));
      }
      fields['attachments[]'] = list;
    }

    if (residencePdf != null) {
      fields['residence_pdf'] = await MultipartFile.fromFile(
        residencePdf.path,
        filename: residencePdf.path.split(Platform.pathSeparator).last,
      );
    }
    if (driverFront != null) {
      fields['driver_front'] = await MultipartFile.fromFile(
        driverFront.path,
        filename: driverFront.path.split(Platform.pathSeparator).last,
      );
    }
    if (goodConductPdf != null) {
      fields['good_conduct'] = await MultipartFile.fromFile(
        goodConductPdf.path,
        filename: goodConductPdf.path.split(Platform.pathSeparator).last,
      );
    }

    final form = FormData.fromMap(fields);

    Response res;
    try {
      res = await _dio.post('/$endpoint', data: form);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
        res = await _dio.post('$endpoint', data: form);
      } else {
        rethrow;
      }
    }

    final data = res.data;
    int? id;
    String type = isCourier ? 'delivery_man' : 'client';

    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      final n = m['user_id'] ??
          m['id'] ??
          (m['data'] is Map ? (m['data'] as Map)['id'] : null);
      if (n is num) id = n.toInt();
      if (m['type'] is String && (m['type'] as String).isNotEmpty) {
        type = m['type'] as String;
      }
    }

    if (id == null) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        message: 'createUser: Beklenen yanıt alınamadı (ID bulunamadı)',
      );
    }

    return UserMinimal(id: id, name: name, type: type);
  }

  Future<UserMinimal> createUseraaa({
    required bool isCourier,
    required String name,
    String? email,
    required String password,
    String? username,
    String? contactNumber,
    int? countryId,
    int? dealerId,
    int? cityId,
    String? districtId,
    String? address,
    String? latitude,
    String? longitude,
    double? locationLat,
    double? locationLng,
    String? iban,
    String? bankAccountOwner,
    String? vehiclePlate,
    String? commissionRate,
    String commissionType = 'percent',
    bool? canTakeOrders,
    bool? hasHadiAccount,
    String? secretNote,
    List<File>? documents,
    File? residencePdf,
    File? driverFront,
    File? goodConductPdf,
    String? cityName, // şehir ismi
    String? district, // ilçe ismi
    String? userType, // 👈 YENİ: 'client' | 'user' | 'delivery_man'
  }) async {
    // 1) Gerçek user_type'ı belirle
    // - Kurye ise her zaman 'delivery_man'
    // - Değilse: userType verilmişse onu kullan, verilmezse 'client'
    final String resolvedType =
        isCourier ? 'delivery_man' : (userType ?? 'client');

    // 2) Endpoint'i user_type'a göre seç
    // - Kurye  -> /couriers
    // - İşletme + Müşteri -> /clients  (backend aynı endpoint üzerinden filtreliyor)
    final String endpoint =
        resolvedType == 'delivery_man' ? 'couriers' : 'clients';

    final baseFields = <String, dynamic>{
      'name': name,
      'password': password,
      'user_type': resolvedType, // 👈 artık burası client/user/delivery_man

      if (email != null && email.isNotEmpty) 'email': email,
      if (username != null && username.isNotEmpty) 'username': username,
      if (contactNumber != null && contactNumber.isNotEmpty)
        'contact_number': contactNumber,

      // City/district isimleri
      if (cityName != null && cityName.isNotEmpty) 'city': cityName,
      if (district != null && district.isNotEmpty) 'district': district,

      if (countryId != null) 'country_id': countryId,
      if (cityId != null) 'city_id': cityId,
      if (address != null && address.isNotEmpty) 'address': address,
      if (locationLat != null) 'location_lat': locationLat,
      if (locationLng != null) 'location_lng': locationLng,
      if (latitude != null && latitude.isNotEmpty && locationLat == null)
        'latitude': latitude,
      if (longitude != null && longitude.isNotEmpty && locationLng == null)
        'longitude': longitude,
      if (iban != null && iban.isNotEmpty) 'iban': iban,
      if (bankAccountOwner != null && bankAccountOwner.isNotEmpty)
        'bank_account_owner': bankAccountOwner,
      if (vehiclePlate != null && vehiclePlate.isNotEmpty)
        'vehicle_plate': vehiclePlate,
      if (commissionRate != null && commissionRate.isNotEmpty)
        'commission_rate': commissionRate,
      if (resolvedType == 'delivery_man') 'commission_type': commissionType,
      if (canTakeOrders != null) 'can_take_orders': canTakeOrders ? 1 : 0,
      if (hasHadiAccount != null) 'has_hadi_account': hasHadiAccount ? 1 : 0,
      if (secretNote != null && secretNote.isNotEmpty)
        'secret_note': secretNote,
      if (dealerId != null) 'dealer_id': dealerId,
    };

    Future<FormData> buildFormData() async {
      final map = Map<String, dynamic>.from(baseFields);

      if (documents != null && documents!.isNotEmpty) {
        final list = <MultipartFile>[];
        for (final f in documents!) {
          final fn = f.path.split(Platform.pathSeparator).last;
          list.add(await MultipartFile.fromFile(f.path, filename: fn));
        }
        map['attachments[]'] = list;
      }

      if (residencePdf != null) {
        map['residence_pdf'] = await MultipartFile.fromFile(
          residencePdf!.path,
          filename: residencePdf!.path.split(Platform.pathSeparator).last,
        );
      }
      if (driverFront != null) {
        map['driver_front'] = await MultipartFile.fromFile(
          driverFront!.path,
          filename: driverFront!.path.split(Platform.pathSeparator).last,
        );
      }
      if (goodConductPdf != null) {
        map['good_conduct'] = await MultipartFile.fromFile(
          goodConductPdf!.path,
          filename: goodConductPdf!.path.split(Platform.pathSeparator).last,
        );
      }

      return FormData.fromMap(map);
    }

    final urls = <String>['/$endpoint', '$endpoint'];

    Response res;
    DioException? lastErr;

    for (final url in urls) {
      try {
        final form = await buildFormData();
        res = await _dio.post(url, data: form);
        final data = res.data;
        int? id;
        String type = resolvedType; // 👈 default artık resolvedType

        if (data is Map) {
          final m = Map<String, dynamic>.from(data);
          final n = m['user_id'] ??
              m['id'] ??
              (m['data'] is Map ? (m['data'] as Map)['id'] : null);
          if (n is num) id = n.toInt();
          if (m['type'] is String && (m['type'] as String).isNotEmpty) {
            type = m['type'] as String;
          }
        }
        if (id == null) {
          throw DioException(
            requestOptions: res.requestOptions,
            response: res,
            message: 'createUser: ID bulunamadı',
          );
        }
        return UserMinimal(id: id, name: name, type: type);
      } on DioException catch (e) {
        lastErr = e;
        final code = e.response?.statusCode;
        if (code != 404 && code != 405) break;
      }
    }

    throw lastErr ??
        DioException(
          requestOptions: RequestOptions(path: urls.last),
          message: 'createUser: bilinmeyen hata',
        );
  }

  Future<UserMinimal> createUserorj({
    required bool isCourier,
    required String name,
    required String email,
    required String password,
    String? username,
    String? contactNumber,
    int? countryId,
    int? dealer_id,
    int? cityId,
    String? address,
    String? latitude,
    String? longitude,
    String? iban,
    String? bank_account_owner,
    String? vehicle_late,
    String? commission_rate,
    List<File>? documents,
  }) async {
    final endpoint = isCourier ? 'couriers' : 'clients';

    final Map<String, dynamic> fields = {
      'name': name,
      'email': email,
      'password': password,
      'dealer_id': currentUserId,
      if (username != null && username.isNotEmpty) 'username': username,
      if (contactNumber != null && contactNumber.isNotEmpty)
        'contact_number': contactNumber,
      if (countryId != null) 'country_id': countryId,
      if (cityId != null) 'city_id': cityId,
      if (address != null && address.isNotEmpty) 'address': address,
      if (latitude != null && latitude.isNotEmpty) 'latitude': latitude,
      if (longitude != null && longitude.isNotEmpty) 'longitude': longitude,
      if (iban != null && iban.isNotEmpty) 'iban': iban,
      if (bank_account_owner != null && bank_account_owner!.isNotEmpty)
        'bank_account_owner': bank_account_owner,
      if (vehicle_late != null && vehicle_late.isNotEmpty)
        'address': vehicle_late,
      if (commission_rate != null && commission_rate!.isNotEmpty)
        'commission_rate': commission_rate,
    };

    if (documents != null && documents.isNotEmpty) {
      fields['documents[]'] = await Future.wait(
        documents.map((f) async {
          final filename = f.path.split(Platform.pathSeparator).last;
          return await MultipartFile.fromFile(f.path, filename: filename);
        }),
      );
    }

    final form = FormData.fromMap(fields);

    Response res;
    try {
      res = await _dio.post(endpoint, data: form);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
        res = await _dio.post('$endpoint', data: form);
      } else {
        rethrow;
      }
    }

    final data = res.data;

    int? id;
    String type = isCourier ? 'delivery_man' : 'client';

    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      final n = m['user_id'] ??
          m['id'] ??
          (m['data'] is Map ? m['data']['id'] : null);
      if (n is num) id = n.toInt();
      if (m['type'] is String && (m['type'] as String).isNotEmpty) {
        type = m['type'] as String;
      }
    }

    if (id == null) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        message:
            'createUser: Beklenen yanıt alınamadı (kullanıcı ID bulunamadı)',
      );
    }

    return UserMinimal(id: id, name: name, type: type);
  }

  Future<UserMinimal> createUse3r({
    required bool isCourier,
    required String name,
    required String email,
    required String password,
    String? username,
    String? contactNumber,
    int? countryId,
    int? cityId,
    String? address,
    String? latitude,
    String? longitude,
    int? dealerId,
    String? vehiclePlate,
    String? iban,
    String? bankAccountOwner,
    double commissionRate = 0.0,
    String commissionType = 'percent',
    bool canTakeOrders = true,
    bool hasHadiAccount = false,
    String? secretNote,
    File? residencePdf,
    File? driverLicenseFront,
    File? goodConductPdf,
    List<File>? documents,
    Map<String, String>? extra,
  }) async {
    final path = isCourier ? 'couriers' : 'clients';
    final url = _u(path);

    final req = http.MultipartRequest('POST', url)
      ..headers.addAll(_jsonHeaders)
      ..fields['name'] = name
      ..fields['email'] = email
      ..fields['password'] = password
      ..fields['commission_rate'] = commissionRate.toString()
      ..fields['commission_type'] = commissionType
      ..fields['can_take_orders'] = canTakeOrders ? '1' : '0'
      ..fields['has_hadi_account'] = hasHadiAccount ? '1' : '0';

    if (username != null && username.isNotEmpty)
      req.fields['username'] = username;
    if (contactNumber != null && contactNumber.isNotEmpty) {
      req.fields['contact_number'] = contactNumber;
    }
    if (countryId != null) req.fields['country_id'] = '$countryId';
    if (cityId != null) req.fields['city_id'] = '$cityId';
    if (address != null && address.isNotEmpty) req.fields['address'] = address;
    if (latitude != null && latitude.isNotEmpty)
      req.fields['latitude'] = latitude;
    if (longitude != null && longitude.isNotEmpty) {
      req.fields['longitude'] = longitude;
    }
    if (dealerId != null) req.fields['dealer_id'] = '$dealerId';
    if (vehiclePlate != null && vehiclePlate.isNotEmpty) {
      req.fields['vehicle_plate'] = vehiclePlate;
    }
    if (iban != null && iban.isNotEmpty) req.fields['iban'] = iban;
    if (bankAccountOwner != null && bankAccountOwner.isNotEmpty) {
      req.fields['bank_account_owner'] = bankAccountOwner;
    }
    if (secretNote != null && secretNote.isNotEmpty) {
      req.fields['secret_note'] = secretNote;
    }
    if (extra != null) {
      req.fields.addAll(extra);
    }

    Future<void> _addFile(String name, File? f) async {
      if (f == null) return;
      final stream = http.ByteStream(f.openRead());
      final len = await f.length();
      final part = http.MultipartFile(name, stream, len,
          filename: f.path.split(Platform.pathSeparator).last);
      req.files.add(part);
    }

    await _addFile('residence_pdf', residencePdf);
    await _addFile('driver_license_front', driverLicenseFront);
    await _addFile('good_conduct_pdf', goodConductPdf);

    if (documents != null) {
      for (final f in documents) {
        final stream = http.ByteStream(f.openRead());
        final len = await f.length();
        final part = http.MultipartFile('documents[]', stream, len,
            filename: f.path.split(Platform.pathSeparator).last);
        req.files.add(part);
      }
    }

    final res = await req.send();
    final body = await res.stream.bytesToString();
    if (res.statusCode != 200) {
      throw Exception('Create user failed: ${res.statusCode} $body');
    }
    final Map<String, dynamic> m = jsonDecode(body);
    return UserMinimal(
        id: m['user_id'] as int,
        name: name,
        type: isCourier ? 'delivery_man' : 'client');
  }

  // ========= LIST HELPERS =========
  List<dynamic> _extractArray(dynamic payload) {
    if (payload is List) return payload;
    if (payload is Map) {
      final d = payload['data'];
      if (d is List) return d;
      if (d is Map && d['data'] is List) return d['data'] as List;
      if (payload['results'] is List) return payload['results'] as List;
    }
    return const [];
  }

  // ============================================================
  // Clients & Couriers listing / detail
  // ============================================================
  Future<Map<String, dynamic>> getClients({
    int page = 1,
    int perPage = 100,
    String? q,
    String userType = 'client',
    int? dealerIdOverride,
    String? status,
  }) async {
    final dId = dealerIdOverride ?? dealerId;

    final qp = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      'user_type': userType,
      'dealer_id': currentUserId,
      if (q?.isNotEmpty == true) 'q': q,
      if (status?.isNotEmpty == true) 'status': status,
      if (dId != null) 'dealer_id': dId,
    };

    final r = await _dio.get('clients', queryParameters: qp);
    final data = r.data;
    return (data is Map<String, dynamic>) ? data : {'data': data};
  }

  Future<Map<String, dynamic>> getUsers({
    int page = 1,
    int perPage = 100,
    String? q,
    String userType = 'user',
    int? dealerIdOverride,
    String? status,
  }) async {
    final dId = dealerIdOverride ?? dealerId;

    final qp = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      'user_type': userType, // 👈 burada zaten 'user' gidiyor
      'dealer_id': currentUserId,
      if (q?.isNotEmpty == true) 'q': q,
      if (status?.isNotEmpty == true) 'status': status,
      if (dId != null) 'dealer_id': dId,
    };

    final r = await _dio.get('clients', queryParameters: qp);
    final data = r.data;
    return (data is Map<String, dynamic>) ? data : {'data': data};
  }

  Future<Map<String, dynamic>> getUsers3({
    int page = 1,
    int perPage = 100,
    String? q,
    String userType = 'user',
    int? dealerIdOverride,
    String? status,
  }) async {
    final dId = dealerIdOverride ?? dealerId;

    final qp = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      'user_type': userType,
      'dealer_id': currentUserId,
      if (q?.isNotEmpty == true) 'q': q,
      if (status?.isNotEmpty == true) 'status': status,
      if (dId != null) 'dealer_id': dId,
    };

    final r = await _dio.get('clients', queryParameters: qp);
    final data = r.data;
    return (data is Map<String, dynamic>) ? data : {'data': data};
  }

  Future<Map<String, dynamic>> getClient(int id,
      {int? dealerIdOverride}) async {
    final dId = dealerIdOverride ?? dealerId;

    try {
      final r = await _dio.get('clients/$id', queryParameters: {
        if (dId != null) 'dealer_id': dId,
      });
      final d = r.data;
      if (d is Map<String, dynamic>) {
        if (d['data'] is Map<String, dynamic>) {
          return Map<String, dynamic>.from(d['data']);
        }
        return Map<String, dynamic>.from(d);
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code != 404 && code != 405) rethrow;
    }

    final r2 = await _dio.get('clients/$id', queryParameters: {
      if (dId != null) 'dealer_id': dId,
    });
    final d2 = r2.data;
    if (d2 is Map<String, dynamic>) {
      if (d2['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(d2['data']);
      }
      return Map<String, dynamic>.from(d2);
    }
    throw Exception('getClient: beklenmeyen yanıt');
  }

  Future<void> updateClient(
    int id, {
    required String name,
    String? contactNumber,
    bool? isOpen,
    bool? requirePickupPhoto,
    bool? requireDeliveryPhoto,
    String? commissionType,
    String? kmOpeningFee,
    String? kmPrice,
    bool? payReceiver,
    bool? paySender,
    bool? payAdmin,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      if (contactNumber != null) 'contact_number': contactNumber,
      if (isOpen != null) 'is_open': isOpen ? 1 : 0,
      if (requirePickupPhoto != null)
        'require_pickup_photo': requirePickupPhoto ? 1 : 0,
      if (requireDeliveryPhoto != null)
        'require_delivery_photo': requireDeliveryPhoto ? 1 : 0,
      if (commissionType != null && commissionType.isNotEmpty)
        'commission_type': commissionType,
      if (kmOpeningFee != null && kmOpeningFee.isNotEmpty)
        'km_opening_fee': kmOpeningFee,
      if (kmPrice != null && kmPrice.isNotEmpty) 'km_price': kmPrice,
      if (payReceiver != null) 'pay_receiver': payReceiver ? 1 : 0,
      if (paySender != null) 'pay_sender': paySender ? 1 : 0,
      if (payAdmin != null) 'pay_admin': payAdmin ? 1 : 0,
    };

    try {
      await _dio.put('clients/$id', data: body);
      return;
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code != 404 && code != 405) rethrow;
    }

    await _dio.put('clients/$id', data: body);
  }

  Future<Map<String, dynamic>> getCouriers({
    int page = 1,
    int perPage = 100,
    String? q,
    String userType = 'delivery_man',
  }) async {
    final qp = {
      'page': page,
      'per_page': perPage,
      if (q?.isNotEmpty == true) 'q': q,
      'user_type': userType,
      'dealer_id': currentUserId,
    };

    try {
      final r = await _dio.get('couriers', queryParameters: qp);
      final data = r.data;
      if (data is Map<String, dynamic>) return data;
      return {'data': data};
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        final r2 = await _dio.get('couriers', queryParameters: qp);
        final data = r2.data;
        if (data is Map<String, dynamic>) return data;
        return {'data': data};
      }
      rethrow;
    }
  }

  // -------- WALLET (ESKİ REST) ----------
  Future<Wallet> getWallet(int userId) async {
    final r = await http.get(_u('wallets/$userId'), headers: _jsonHeaders);
    if (r.statusCode != 200) throw Exception('Wallet failed (${r.statusCode})');
    return Wallet.fromJson(jsonDecode(r.body));
  }

  Future<Wallet> topUpWallet({
    required int userId,
    required num amount,
    String? note,
  }) async {
    final r = await http.post(
      _u('wallets/$userId/topup'),
      headers: {
        ..._jsonHeaders,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'amount': amount, if (note != null) 'note': note}),
    );
    if (r.statusCode != 200) {
      throw Exception('TopUp failed (${r.statusCode}) ${r.body}');
    }
    return Wallet.fromJson(jsonDecode(r.body));
  }

  // -------- Delivery Orders ----------
  Future<Map<String, dynamic>> deliveryOrders({
    int page = 1,
    int perPage = 20,
    int? clientId,
    String? status,
    String? q,
    String? dateFrom,
    String? dateTo,
  }) async {
    final res = await _dio.get(
      'delivery-orders',
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (clientId != null) 'client_id': clientId,
        if (status?.isNotEmpty == true) 'status': status,
        if (q?.isNotEmpty == true) 'q': q,
        if (dateFrom?.isNotEmpty == true) 'date_from': dateFrom,
        if (dateTo?.isNotEmpty == true) 'date_to': dateTo,
      },
    );

    final data = res.data;
    if (data is Map<String, dynamic>) {
      return data['data'] is Map<String, dynamic> ? data['data'] : data;
    }
    return {'data': data};
  }

  Future<Map<String, dynamic>> updateDeliveryOrder(
      int id, Map<String, dynamic> body) async {
    final res = await _dio.put('delivery-orders/$id', data: body);
    final data = res.data;
    return (data is Map<String, dynamic>) ? data : {'data': data};
  }

  Future<Map<String, dynamic>> couriers({
    int page = 1,
    int perPage = 100,
    String? q,
    String? status,
  }) async {
    final res = await _dio.get(
      'couriers',
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (q?.isNotEmpty == true) 'q': q,
        if (status?.isNotEmpty == true) 'status': status,
      },
    );
    final data = res.data;
    return (data is Map<String, dynamic>) ? data : {'data': data};
  }

  Future<Map<String, dynamic>> handoffToCouriers2({
    int? orderId,
    String? orderNumber,
    int? clientId,
    String? paymentCollectFrom,
    int? vehicleId,
    bool? autoAssign,
    int? country_id,
    int? city_id,
  }) async {
    if (orderId == null && (orderNumber == null || orderNumber.isEmpty)) {
      throw ArgumentError('orderId veya orderNumber vermelisin.');
    }

    final body = <String, dynamic>{
      if (orderId != null) 'order_id': orderId,
      if (orderNumber != null && orderNumber.isNotEmpty)
        'order_number': orderNumber,
      if (clientId != null) 'client_id': clientId,
      if (country_id != null) 'country_id': country_id,
      if (city_id != null) 'city_id': city_id,
      if (paymentCollectFrom != null)
        'payment_collect_from': paymentCollectFrom,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (autoAssign != null) 'auto_assign': autoAssign,
    };

    try {
      final res = await _dio.post('handoff-to-couriers', data: body);
      final data = res.data;
      return (data is Map<String, dynamic>)
          ? data
          : {'success': true, 'data': data};
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code != 404 && code != 405) rethrow;
    }

    final res2 = await _dio.post('handoff-to-couriers', data: body);
    final data2 = res2.data;
    return (data2 is Map<String, dynamic>)
        ? data2
        : {'success': true, 'data': data2};
  }

  Future<Map<String, dynamic>> handoffToCouriers({
    int? orderId,
    String? orderNumber,
    int? clientId,
    int? country_id,
    int? city_id,
    String? paymentCollectFrom,
    int? vehicleId,
    bool? autoAssign,
  }) async {
    debugPrint(country_id.toString());
    final res = await dio.post(
      'handoff-to-couriers', // routes/api.php: Route::post('handoff-to-couriers', ...)
      data: {
        if (orderId != null) 'order_id': orderId,
        if (orderNumber != null) 'order_number': orderNumber, // 🔴 ÖNEMLİ
        if (clientId != null) 'client_id': clientId,
        if (country_id != null) 'country_id': country_id,
        if (city_id != null) 'city_id': city_id,
        if (paymentCollectFrom != null)
          'payment_collect_from': paymentCollectFrom,
        if (vehicleId != null) 'vehicle_id': vehicleId,
        if (autoAssign != null) 'auto_assign': autoAssign,
      },
    );

    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> handoffByOrderNumber22(
    String orderNumber, {
    int? clientId,
    int? country_id,
    int? city_id,
    String? paymentCollectFrom,
    int? vehicleId,
    bool? autoAssign,
  }) {
    return handoffToCouriers(
      orderNumber: orderNumber,
      clientId: clientId,
      country_id: country_id,
      city_id: city_id,
      paymentCollectFrom: paymentCollectFrom,
      vehicleId: vehicleId,
      autoAssign: autoAssign,
    );
  }

  Future<Map<String, dynamic>> handoffByOrderNumber(
    String orderNumber, {
    int? clientId,
    int? country_id,
    int? city_id,
    String? paymentCollectFrom,
    int? vehicleId,
    bool? autoAssign,
  }) async {
    // Eğer dışarıdan verilmediyse partner client'tan çek
    int? resolvedCountryId = country_id;
    int? resolvedCityId = city_id;

    if (resolvedCountryId == null || resolvedCityId == null) {
      final pid = clientId; // sende hangi değişkense o
      if (pid != null) {
        final t = await partnerClientCountryCity(pid); // (countryId, cityId)
        resolvedCountryId ??= t.$1;
        resolvedCityId ??= t.$2;
      }
    }

    return handoffToCouriers(
      orderNumber: orderNumber,
      clientId: clientId,
      country_id: resolvedCountryId,
      city_id: resolvedCityId,
      paymentCollectFrom: paymentCollectFrom,
      vehicleId: vehicleId,
      autoAssign: autoAssign,
    );
  }

  Future<Map<String, dynamic>> handoffByOrderId(
    int orderId, {
    int? clientId,
    String? paymentCollectFrom,
    int? vehicleId,
    bool? autoAssign,
  }) {
    return handoffToCouriers(
      orderId: orderId,
      clientId: clientId,
      paymentCollectFrom: paymentCollectFrom,
      vehicleId: vehicleId,
      autoAssign: autoAssign,
    );
  }

  // ===================
  // Couriers (REST)
  // ===================
  Map<String, dynamic> _unwrapMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }
      return Map<String, dynamic>.from(data);
    }
    throw Exception('Beklenmeyen yanıt biçimi');
  }

  bool _needsApiPrefix(DioException e) {
    final code = e.response?.statusCode ?? 0;
    return code == 404 || code == 405;
  }

  Future<Map<String, dynamic>> courierShow(int id) async {
    try {
      final r = await _dio.get('couriers/$id');
      return _unwrapMap(r.data);
    } on DioException catch (e) {
      if (_needsApiPrefix(e)) {
        final r2 = await _dio.get('couriers/$id'); // fixed fallback
        return _unwrapMap(r2.data);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> courierUpdate(
      int id, Map<String, dynamic> body) async {
    try {
      final r = await _dio.put('couriers/$id', data: body);
      return _unwrapMap(r.data);
    } on DioException catch (e) {
      if (_needsApiPrefix(e)) {
        final r2 = await _dio.put('couriers/$id', data: body); // fixed fallback
        return _unwrapMap(r2.data);
      }
      rethrow;
    }
  }

  Future<void> courierSetActive(int id, bool active) async {
    await courierUpdate(id, {'is_active': active ? 1 : 0});
  }

  Future<void> courierChangePassword(int id, String newPassword) async {
    final payload = {
      'password': newPassword,
      'password_confirmation': newPassword,
    };
    try {
      await _dio.post('couriers/$id/change-password', data: payload);
    } on DioException catch (e) {
      if (_needsApiPrefix(e)) {
        await _dio.post('couriers/$id/change-password', data: payload);
      } else {
        rethrow;
      }
    }
  }

  // List normalizer’lar
  List<T> _parseListLike<T>(
    dynamic data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final list = (data is List)
        ? data
        : (data is Map && data['data'] is List)
            ? data['data']
            : (data is Map &&
                    data['data'] is Map &&
                    data['data']['data'] is List)
                ? data['data']['data']
                : (data is Map && data['results'] is List)
                    ? data['results']
                    : (data is Map && data['data'] is Iterable)
                        ? data['data']
                        : const [];
    return list.map<T>((e) => fromJson(Map<String, dynamic>.from(e))).toList();
  }

  List<Map<String, dynamic>> _extractList(dynamic raw) {
    if (raw == null) return const [];
    final root = (raw is Map && raw.containsKey('data')) ? raw['data'] : raw;
    if (root is List) {
      return root
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (root is Map && root['data'] is List) {
      return (root['data'] as List)
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return const [];
  }

  // =======================
  // COUNTRY / CITY
  // =======================
  Future<List<City>> fetchCitiesFromCountries(
      {String? search, int perPage = -1}) async {
    try {
      final r = await _dio.get(
        'country-list',
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          'per_page': perPage,
        },
      );
      final list = _extractList(r.data);
      return list.map((m) => City.fromJson(m)).toList();
    } on DioException catch (e) {
      final msg = e.response?.data is Map && e.response!.data['message'] != null
          ? e.response!.data['message'].toString()
          : (e.message ?? 'Şehir listesi alınamadı.');
      throw Exception('country-list hata: $msg');
    }
  }

  Future<List<District>> fetchDistrictsByCountry({
    required int countryId,
    String? search,
    int perPage = -1,
  }) async {
    try {
      final r = await _dio.get(
        'city-list',
        queryParameters: {
          'country_id': countryId,
          if (search != null && search.isNotEmpty) 'search': search,
          'per_page': perPage,
        },
      );
      final list = _extractList(r.data);
      return list.map((m) => District.fromJson(m)).toList();
    } on DioException catch (e) {
      final msg = e.response?.data is Map && e.response!.data['message'] != null
          ? e.response!.data['message'].toString()
          : (e.message ?? 'İlçe listesi alınamadı.');
      throw Exception('city-list hata: $msg');
    }
  }

  // =======================
  // CLIENT — ADRESLER
  // =======================
  Future<List<Map<String, dynamic>>> clientAddresses(int clientId) async {
    try {
      final r = await _dio.get('clients/$clientId/addresses');
      return _extractList(r.data);
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code != 404 && code != 405) rethrow;
    }
    final r2 = await _dio.get('clients/$clientId/addresses');
    return _extractList(r2.data);
  }

  Future<Map<String, dynamic>> createClientAddress(
    int clientId,
    Map<String, dynamic> body,
  ) async {
    try {
      final r = await _dio.post('clients/$clientId/addresses', data: body);
      final d = r.data;
      return (d is Map<String, dynamic>) ? d : {'data': d};
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code != 404 && code != 405) rethrow;
    }
    final r2 = await _dio.post('clients/$clientId/addresses', data: body);
    final d2 = r2.data;
    return (d2 is Map<String, dynamic>) ? d2 : {'data': d2};
  }

  Future<Map<String, dynamic>> updateClientAddress(
    int addressId,
    Map<String, dynamic> body,
  ) async {
    try {
      final r = await _dio.put('addresses/$addressId', data: body);
      final d = r.data;
      return (d is Map<String, dynamic>) ? d : {'data': d};
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code != 404 && code != 405) rethrow;
    }
    final r2 = await _dio.put('addresses/$addressId', data: body);
    final d2 = r2.data;
    return (d2 is Map<String, dynamic>) ? d2 : {'data': d2};
  }

  Future<void> deleteClientAddress(int addressId) async {
    try {
      final r = await _dio.delete('addresses/$addressId');
      if ((r.statusCode ?? 200) >= 400) {
        throw Exception('deleteClientAddress failed: ${r.statusCode}');
      }
      return;
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code != 404 && code != 405) rethrow;
    }
    final r2 = await _dio.delete('addresses/$addressId');
    if ((r2.statusCode ?? 200) >= 400) {
      throw Exception('deleteClientAddress failed: ${r2.statusCode}');
    }
  }

  // =======================
  // CLIENT — SİPARİŞLER
  // =======================
  Future<List<Map<String, dynamic>>> clientOrders(
    int clientId, {
    String? status,
    int page = 1,
    int perPage = 100,
  }) async {
    final qp = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      if (status != null && status.isNotEmpty) 'status': status,
    };

    try {
      final r = await _dio.get('clients/$clientId/orders', queryParameters: qp);
      return _extractList(r.data);
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code != 404 && code != 405) rethrow;
    }

    final r2 = await _dio.get('clients/$clientId/orders', queryParameters: qp);
    return _extractList(r2.data);
  }

  Future<List<ClientOrderLite>> listClientOrders2(int clientId) async {
    final m = await deliveryOrders(clientId: clientId);
    final List list = (() {
      final root = (m['data'] ?? m);
      if (root is List) return root;
      if (root is Map && root['data'] is List) return root['data'] as List;
      return const [];
    })();

    return list
        .map((e) => ClientOrderLite.fromAny(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ClientOrderLite>> listClientOrders(
    int clientId, {
    String? status,
    int page = 1,
    int perPage = 100,
  }) async {
    final data = await deliveryOrders(
      page: page,
      perPage: perPage,
      clientId: clientId,
      status: status,
    );

    final root = (data['data'] is List)
        ? data['data'] as List
        : (data['data'] is Map && data['data']['data'] is List)
            ? data['data']['data'] as List
            : (data is List)
                ? data
                : (data['results'] is List)
                    ? data['results'] as List
                    : [];
    final list = List<Map<String, dynamic>>.from(root as List);

    return list
        .map((e) => ClientOrderLite.fromAny(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> clientChangePassword(int id, String newPassword) async {
    final payload = {
      'password': newPassword,
      'password_confirmation': newPassword,
    };
    try {
      await _dio.put('clients/$id', data: payload);
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 404 || code == 405) {
        await _dio.put('clients/$id', data: payload);
      } else {
        rethrow;
      }
    }
  }

  Future<void> changeUserPassword({
    required int userId,
    required String newPassword,
  }) async {
    final data = {
      'password': newPassword,
      'password_confirmation': newPassword,
    };
    try {
      await _dio.post('clients/$userId/change-password', data: data);
    } on DioException catch (e) {
      final msg = e.response?.data ?? e.message;
      throw Exception('Şifre değiştirilemedi: $msg');
    }
  }

  // =======================
  // DELIVERY MAN — DOCUMENTS
  // =======================
  Future<List<Map<String, dynamic>>> deliveryManDocumentList(
      int deliveryManId) async {
    try {
      final r = await _dio.get(
        'delivery-man-document-list',
        queryParameters: {'delivery_man_id': deliveryManId},
      );
      return _extractList(r.data);
    } on DioException catch (e) {
      final msg = e.response?.data ?? e.message;
      throw Exception('deliveryManDocumentList hata: $msg');
    }
  }

  Future<(int success, int fail)> deliveryManDocumentUpload(
    int deliveryManId,
    List<File> files,
  ) async {
    int ok = 0, fail = 0;
    for (final f in files) {
      try {
        final filename = f.path.split(Platform.pathSeparator).last;
        try {
          final form = FormData.fromMap({
            'delivery_man_id': deliveryManId,
            'file': await MultipartFile.fromFile(f.path, filename: filename),
          });
          await _dio.post('delivery-man-document-save', data: form);
        } on DioException {
          final form = FormData.fromMap({
            'delivery_man_id': deliveryManId,
            'document':
                await MultipartFile.fromFile(f.path, filename: filename),
          });
          await _dio.post('delivery-man-document-save', data: form);
        }
        ok++;
      } catch (_) {
        fail++;
      }
    }
    return (ok, fail);
  }

  Future<void> deliveryManDocumentDelete(int documentId) async {
    try {
      await _dio.post('delivery-man-document-delete/$documentId');
    } on DioException catch (e) {
      final msg = e.response?.data ?? e.message;
      throw Exception('deliveryManDocumentDelete hata: $msg');
    }
  }

  Future<void> deliveryManDocumentDeleteMany(List<int> ids) async {
    if (ids.isEmpty) return;
    try {
      await _dio.post('multiple-delete-deliveryman-document', data: {
        'ids': ids,
      });
    } on DioException catch (e) {
      final msg = e.response?.data ?? e.message;
      throw Exception('deliveryManDocumentDeleteMany hata: $msg');
    }
  }

  // =======================
  // WALLET / PAYMENTS (SENİN ROTALAR)
  // =======================
  Future<List<Map<String, dynamic>>> walletList({required int userId}) async {
    dynamic data;
    try {
      final r = await _dio.get('wallet-list', queryParameters: {
        'user_id': userId,
      });
      data = r.data;
    } on DioException {
      final r = await _dio.get('wallet-list', queryParameters: {
        'delivery_man_id': userId,
      });
      data = r.data;
    }
    return _extractList(data);
  }

  Future<void> saveWallet({
    required int userId,
    required num amount,
    required String type, // 'credit' | 'debit'
    String? note,
  }) async {
    assert(type == 'credit' || type == 'debit');
    final body = {
      'user_id': userId,
      'delivery_man_id': userId,
      'amount': amount,
      'type': type,
      if (note != null && note.isNotEmpty) 'note': note,
    };
    try {
      await _dio.post('save-wallet', data: body);
    } on DioException catch (e) {
      final msg = e.response?.data ?? e.message;
      throw Exception('saveWallet hata: $msg');
    }
  }

  Future<void> walletTopUp({
    required int userId,
    required num amount,
    String? note,
  }) =>
      saveWallet(userId: userId, amount: amount, type: 'credit', note: note);

  Future<void> walletDebit({
    required int userId,
    required num amount,
    String? note,
  }) =>
      saveWallet(userId: userId, amount: amount, type: 'debit', note: note);

  Future<List<Map<String, dynamic>>> paymentList(
      {required int deliveryManId}) async {
    try {
      final r = await _dio.get('payment-list', queryParameters: {
        'delivery_man_id': deliveryManId,
      });
      return _extractList(r.data);
    } on DioException catch (e) {
      final msg = e.response?.data ?? e.message;
      throw Exception('paymentList hata: $msg');
    }
  }

  Future<void> paymentSave(Map<String, dynamic> payload) async {
    try {
      await _dio.post('payment-save', data: payload);
    } on DioException catch (e) {
      final msg = e.response?.data ?? e.message;
      throw Exception('paymentSave hata: $msg');
    }
  }

  /// UserAddressController@getList — düz dizi döndürür
  Future<List<Map<String, dynamic>>> clientAddressesByUAController(
    int clientId, {
    String? searchAddress,
    int? countryId,
    int? cityId,
    int perPage = -1, // controller: -1 -> tüm kayıtlar
  }) async {
    final qp = <String, dynamic>{
      'user_id': clientId,
      'per_page': perPage,
      if (searchAddress != null && searchAddress.isNotEmpty)
        'address': searchAddress,
      if (countryId != null) 'country_id': countryId,
      if (cityId != null) 'city_id': cityId,
    };

    // 1) /useraddresses (UA Controller rotası)
    try {
      final r = await _dio.get('useraddresses', queryParameters: qp);
      return _extractList(r.data); // {data:[...]} | {data:{data:[...]}} | [...]
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code != 404 && code != 405) rethrow;
    }

    // 2) olası alternatif (prefix/değişken rota ihtimali için tekrar denemeler)
    try {
      final r2 = await _dio.get('useraddresses', queryParameters: qp);
      return _extractList(r2.data);
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code != 404 && code != 405) rethrow;
    }

    // Son çare: yine aynı endpoint (çoğu ortamda 1. deneme yeterli oluyor)
    final r3 = await _dio.get('useraddresses', queryParameters: qp);
    return _extractList(r3.data);
  }

  /// UserAddressController@getDetail — tek kayıt
  Future<Map<String, dynamic>> userAddressDetailByUAController(int id) async {
    // 1) /useraddresses/detail?id={id}
    try {
      final r =
          await _dio.get('useraddresses/detail', queryParameters: {'id': id});
      final data = r.data;
      if (data is Map && data['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(data['data']);
      }
      if (data is Map<String, dynamic>) return data;
      return {'data': data};
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code != 404 && code != 405) rethrow;
    }

    // 2) alternatif: /useraddresses/{id}
    final r2 = await _dio.get('useraddresses/$id');
    final d2 = r2.data;
    if (d2 is Map && d2['data'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(d2['data']);
    }
    if (d2 is Map<String, dynamic>) return d2;
    return {'data': d2};
  }

  Future<Map<String, dynamic>> fetchProductDashboard() async {
    final res = await dio.get('productdashboard/products');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> fetchClientDashboard() async {
    final res = await dio.get('productdashboard/clients');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> getPartnerClients({
    int page = 1,
    int perPage = 100,
    String? q,
    String? status,
  }) async {
    final qp = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      if (q?.isNotEmpty == true) 'q': q,
      if (status?.isNotEmpty == true) 'status': status,
    };

    final uri = _uPartner('partner-clients', qp);

    final r = await Dio()
        .getUri(uri /*, options: Options(headers: _partnerHeaders())*/);
    final data = r.data;
    return (data is Map<String, dynamic>) ? data : {'data': data};
  }

  Future<List<ClientOrderLite>> listPartnerClientOrders(
    int partnerClientId, {
    int page = 1,
    int perPage = 50,
  }) async {
    // ✅ Detay endpointin: GET partner-clients/{id}
    final uri = Uri.parse(
        'https://api.haldeki.com/api/partner/v1/partner-clients/$partnerClientId/orders');

    final res = await _dio.getUri(uri);
    final body = res.data;

    // ✅ beklenen: {success:true, data:{ client:{...}, deliver_orders:{data:[...], meta:{...}}}}
    final root = (body is Map<String, dynamic>) ? body : <String, dynamic>{};

    final data = (root['data'] is Map<String, dynamic>)
        ? Map<String, dynamic>.from(root['data'])
        : <String, dynamic>{};

    final deliverOrders = (data['deliver_orders'] is Map<String, dynamic>)
        ? Map<String, dynamic>.from(data['deliver_orders'])
        : <String, dynamic>{};

    final listRaw = (deliverOrders['data'] is List)
        ? deliverOrders['data'] as List
        : const [];

    final list = List<Map<String, dynamic>>.from(
      listRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
    );

    return list.map((e) => ClientOrderLite.fromAny(e)).toList();
  }

  Future<Map<String, dynamic>> partnerDeliveryOrders({
    required int partnerClientId,
    int page = 1,
    int perPage = 100,
    String? status,
  }) async {
    final uri = Uri.parse(
        'https://api.haldeki.com/api/partner/v1/partner-clients/$partnerClientId/orders');
    //    _uPartner('/partner-clients/$partnerClientId/orders');

    final res = await _dio.getUri(uri, data: {
      'partner_client_id': partnerClientId,
      'page': page,
      'per_page': perPage,
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
    });

    final body = res.data;

    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);

    return {'data': body}; // fallback
  }

  Future<Map<String, dynamic>> updatePartnerClientAddress(
    int partnerClientId,
    Map<String, dynamic> body,
  ) async {
    final r = await _dio.post(
      'https://api.haldeki.com/api/partner/v1/partner-clients/$partnerClientId',
      data: body,
      options: Options(headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      }),
    );

    final d = r.data;
    if (d is Map<String, dynamic>) return d;
    throw Exception('Unexpected response: $d');
  }

// 🗑 Sil (opsiyonel)
  Future<void> deletePartnerClientAddress(int addressId) async {
    await _dio.delete(
      'partner-client-addresses/$addressId',
    );
  }

  Future<void> updatePartnerClient(
    int id, {
    // ---- temel ----
    required String name,
    String? email,
    String? phone,
    String? contactNumber,

    // ---- adres & konum ----
    String? address,
    int? countryId,
    int? cityId,
    String? city,
    String? district,

    /// string olarak da kabul (backend string bekleyebilir)
    String? latitude,
    String? longitude,

    /// numeric olarak da gönder (backend location_lat / lng numeric bekleyebilir)
    double? locationLat,
    double? locationLng,

    // ---- mevcut iş kuralları ----
    required bool isOpen,
    required bool requirePickupPhoto,
    required bool requireDeliveryPhoto,
    required String commissionAmount,
    required bool payReceiver,
    required bool paySender,
    required bool payAdmin,

    // ---- opsiyonel ----
    String? webhookUrl,
    Map<String, dynamic>? meta,
  }) async {
    final url = _uPartner('partner-clients/$id');

    double? _toDouble(String? s) {
      if (s == null) return null;
      final t = s.trim();
      if (t.isEmpty) return null;
      return double.tryParse(t.replaceAll(',', '.'));
    }

    final commission = double.tryParse(
          commissionAmount
              .replaceAll(' ', '')
              .replaceAll('.', '')
              .replaceAll(',', '.'),
        ) ??
        0;

    final data = <String, dynamic>{
      'id': id,

      // temel
      'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (contactNumber != null) 'contact_number': contactNumber,

      // adres & konum
      if (address != null) 'address': address,
      if (countryId != null) 'country_id': countryId,
      if (cityId != null) 'city_id': cityId,
      if (city != null) 'city': city,
      if (district != null) 'district': district,

      // bazı backend’ler string lat/lng de tutuyor
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,

      // bazı backend’ler numeric location_lat/lng istiyor
      'location_lat': locationLat ?? _toDouble(latitude),
      'location_lng': locationLng ?? _toDouble(longitude),

      // iş kuralları
      'is_open': isOpen,
      'require_pickup_photo': requirePickupPhoto,
      'require_delivery_photo': requireDeliveryPhoto,
      'commission_amount': commission,

      'pay_receiver': payReceiver,
      'pay_sender': paySender,
      'pay_admin': payAdmin,

      // opsiyonel
      if (webhookUrl != null) 'webhook_url': webhookUrl,
      if (meta != null) 'meta': meta,
    };

    await _dio.putUri(url, data: data);
  }

  // ============================================================
  // Clients & Couriers listing / detail
  // ============================================================
  Future<Map<String, dynamic>> getClients2({
    int page = 1,
    int perPage = 100,
    String? q,
    String userType = 'client',
    int? dealerIdOverride,
    String? status,
  }) async {
    final dId = dealerIdOverride ?? dealerId;

    final qp = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      'user_type': userType,
      'dealer_id': currentUserId,
      if (q?.isNotEmpty == true) 'q': q,
      if (status?.isNotEmpty == true) 'status': status,
      if (dId != null) 'dealer_id': dId,
    };

    final r = await _dio.get('clients', queryParameters: qp);
    final data = r.data;
    return (data is Map<String, dynamic>) ? data : {'data': data};
  }

  Future<Map<String, dynamic>> getPartnerClientDetail(int id) async {
    final uri = _uPartner('partner-clients/$id');

    try {
      final r = await _dio.getUri(uri);
      final d = r.data;

      if (d is Map<String, dynamic>) {
        if (d['data'] is Map<String, dynamic>) {
          return Map<String, dynamic>.from(d['data']);
        }
        return Map<String, dynamic>.from(d);
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      // aynı senin getClient mantığın gibi:
      if (code != 404 && code != 405) rethrow;
    }

    // fallback (senin pattern)
    final r2 = await _dio.getUri(uri);
    final d2 = r2.data;

    if (d2 is Map<String, dynamic>) {
      if (d2['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(d2['data']);
      }
      return Map<String, dynamic>.from(d2);
    }

    throw Exception('getPartnerClient: beklenmeyen yanıt');
  }

  Future<void> updatePartnerClient2(
    int id, {
    required String name,
    String? email,
    String? phone,
    String? contactNumber,

    // --- adres & konum ---
    String? address,
    int? countryId,
    int? cityId,
    String? city,
    String? district,
    String? latitude,
    String? longitude,
    double? locationLat,
    double? locationLng,

    // --- mevcut alanlar ---
    required bool isOpen,
    required bool requirePickupPhoto,
    required bool requireDeliveryPhoto,
    required String commissionAmount,
    required bool payReceiver,
    required bool paySender,
    required bool payAdmin,

    // --- ekstra ---
    String? webhookUrl,
    Map<String, dynamic>? meta,
  }) async {
    final url = _uPartner('partner-clients/$id');

    final Map<String, dynamic> data = {
      'id': id,
      'name': name,

      // iletişim
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (contactNumber != null) 'contact_number': contactNumber,

      // adres
      if (address != null) 'address': address,
      if (countryId != null) 'country_id': countryId,
      if (cityId != null) 'city_id': cityId,
      if (city != null) 'city': city,
      if (district != null) 'district': district,

      // konum
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationLat != null) 'location_lat': locationLat,
      if (locationLng != null) 'location_lng': locationLng,

      // sipariş & komisyon
      'is_open': isOpen,
      'require_pickup_photo': requirePickupPhoto,
      'require_delivery_photo': requireDeliveryPhoto,
      'commission_rate': double.tryParse(commissionAmount) ?? 0,

      // ödeme
      'pay_receiver': payReceiver,
      'pay_sender': paySender,
      'pay_admin': payAdmin,

      // webhook & meta
      if (webhookUrl != null) 'webhook_url': webhookUrl,
      if (meta != null) 'meta': meta,
    };

    await _dio.patchUri(url, data: data);
  }

  Future<PartnerClientMinimal> createPartnerClient({
    required String name,
    String? email,
    String? phone,
    String? contactNumber,
    String? address,
    int? countryId,
    int? cityId,
    String? city,
    String? district,
    String? latitude,
    String? longitude,
    double? locationLat,
    double? locationLng,
    String? webhookUrl,
    int? dealer_id,
    Map<String, dynamic>? meta,
  }) async {
    final data = <String, dynamic>{
      'name': name,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (contactNumber != null && contactNumber.isNotEmpty)
        'contact_number': contactNumber,
      if (address != null && address.isNotEmpty) 'address': address,
      if (countryId != null) 'country_id': countryId,
      if (cityId != null) 'city_id': cityId,
      if (dealer_id != null) 'dealer_id': dealer_id,
      if (city != null && city.isNotEmpty) 'city': city,
      if (district != null && district.isNotEmpty) 'district': district,
      if (latitude != null && latitude.isNotEmpty) 'latitude': latitude,
      if (longitude != null && longitude.isNotEmpty) 'longitude': longitude,
      if (locationLat != null) 'location_lat': locationLat,
      if (locationLng != null) 'location_lng': locationLng,
      if (webhookUrl != null && webhookUrl.isNotEmpty)
        'webhook_url': webhookUrl,
      if (meta != null) 'meta': meta,
    };

    // ✅ Burada FULL URL kullanıyoruz: apiBasePartner + path
    // AppConfig.apiBasePartner örnek: "http://localhost:8082/api/partner/v1"
    final uri =
        Uri.parse('http://localhost:8082/api/partner/v1/partner-clients');
    debugPrint(uri.toString());
    final res = await _dio.postUri(uri, data: data);

    final body = res.data;
    // response normalize
    final Map<String, dynamic> m =
        (body is Map<String, dynamic>) ? body : <String, dynamic>{'data': body};

    final row = (m['data'] is Map)
        ? Map<String, dynamic>.from(m['data'])
        : Map<String, dynamic>.from(m);

    return PartnerClientMinimal(
      id: (row['id'] as num).toInt(),
      name: (row['name'] ?? name).toString(),
      partnerKey: row['partner_key']?.toString(),
      partnerSecret: row['partner_secret']?.toString(),
    );
  }

  Future<Map<String, dynamic>> bulkMarkCollected({
    required String email,
    required List<int> orderIds,
  }) async {
    if (orderIds.isEmpty) {
      return {'success': false, 'message': 'order_ids boş olamaz'};
    }

    final body = {
      'email': email,
      'order_ids': orderIds,
    };

    try {
      final r = await _dio.post(
        'bulk-charge',
        data: body,
      );

      final d = r.data;
      return (d is Map<String, dynamic>) ? d : {'success': true, 'data': d};
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;

      // Projede bazı endpointlerde 404/405 fallback kullanıyordun.
      if (code == 404 || code == 405) {
        final r2 = await _dio.post(
          'bulk-charge',
          data: body,
        );
        final d2 = r2.data;
        return (d2 is Map<String, dynamic>)
            ? d2
            : {'success': true, 'data': d2};
      }

      final msg = e.response?.data ?? e.message;
      throw Exception('bulkMarkCollected hata: $msg');
    }
  }

  Future<Map<String, dynamic>> bulkPayCourier({
    required String email,
    required List<int> orderIds,
  }) async {
    if (orderIds.isEmpty) {
      return {'success': false, 'message': 'order_ids boş olamaz'};
    }

    final body = {
      'email': email,
      'order_ids': orderIds,
    };

    try {
      final r = await _dio.post(
        'bulk-pay-courier',
        data: body,
      );

      final d = r.data;
      return (d is Map<String, dynamic>) ? d : {'success': true, 'data': d};
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;

      if (code == 404 || code == 405) {
        final r2 = await _dio.post(
          'bulk-pay-courier',
          data: body,
        );
        final d2 = r2.data;
        return (d2 is Map<String, dynamic>)
            ? d2
            : {'success': true, 'data': d2};
      }

      final msg = e.response?.data ?? e.message;
      throw Exception('bulkPayCourier hata: $msg');
    }
  }
}

class PartnerClientMinimal {
  final int id;
  final String name;
  final String? partnerKey;
  final String? partnerSecret;

  PartnerClientMinimal(
      {required this.id,
      required this.name,
      this.partnerKey,
      this.partnerSecret});
}
