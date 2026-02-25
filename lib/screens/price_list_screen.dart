// lib/screens/price_list_screen.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/variant.dart';
import '../services/api_client.dart';

class PriceListScreen extends StatefulWidget {
  const PriceListScreen({super.key});

  @override
  State<PriceListScreen> createState() => _PriceListScreenState();
}

class _RowVM {
  final Product product;
  List<ProductVariant> variants;
  int? selectedVariantId;
  final TextEditingController priceC;
  bool dirty;

  _RowVM({
    required this.product,
    required this.variants,
    required this.selectedVariantId,
    required double price,
  })  : priceC = TextEditingController(text: price.toStringAsFixed(2)),
        dirty = false;

  void dispose() => priceC.dispose();
}

class _PriceListScreenState extends State<PriceListScreen> {
  // --- Controls
  final _search = TextEditingController();
  Timer? _debounce;

  // --- Categories
  bool _loadingCats = true;
  List<Category> _cats = const [];
  int? _selectedCat;

  // --- Data
  final List<_RowVM> _rows = [];
  bool _loadingRows = true;
  bool _fetchingMore = false;
  bool _more = true;
  int _page = 1;
  String? _error;

  // --- Table
  late _PriceDataSource _dataSource;
  int _rowsPerPage = PaginatedDataTable.defaultRowsPerPage; // 10
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  Key _pdtKey = UniqueKey(); // paginator'ı resetlemek için

  final _hCtrl = ScrollController(); // yatay
  final _vCtrl = ScrollController(); // dikey

  // --- API
  Dio get _dio => context.read<ApiClient>().dio;

  // --- constants
  static const List<String> _unitOptions = [
    'ADET',
    'GR',
    'KG',
    'BAĞ',
    'DEMET',
    'KASA'
  ];
  static const String _emailForPrice = 'bayi@bayi.com'; // 'bayi@bayi.com';

  static const int _myUserIdForPricePick = 18;

  // --- Performance additions
  CancelToken? _listToken;
  final Map<int, List<ProductVariant>> _variantsCache =
      {}; // productId -> variants
  final Map<int, CancelToken> _variantTokens = {}; // productId -> cancel token

  @override
  void initState() {
    super.initState();

    _dataSource = _PriceDataSource(
      getRows: () => _rows,
      onSaveRow: _saveRow,
      onAddVariant: _addVariantForRow,
      onChanged: () => setState(() {}),
    );

    // debounce search
    _search.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), () => _onSearch());
    });

    _loadAll();
  }

  @override
  void dispose() {
    // aktif istekleri iptal et
    _listToken?.cancel('dispose');
    for (final t in _variantTokens.values) {
      t.cancel('dispose');
    }
    _variantTokens.clear();

    _hCtrl.dispose();
    _vCtrl.dispose();
    _debounce?.cancel();
    _search.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadCategories(), _fetchRows(reset: true)]);
  }

  Future<void> _onSearch() => _fetchRows(reset: true);

  // ----------------- CATEGORIES -----------------
  Future<void> _loadCategories() async {
    setState(() => _loadingCats = true);

    try {
      final res = await _dio.get('categories');
      final data = res.data;
      List list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['data'] is List) {
        list = data['data'];
      } else if (data is Map && data['results'] is List) {
        list = data['results'];
      } else {
        list = [];
      }
      _cats = list
          .whereType<Map>()
          .map((j) => Category.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } finally {
      if (mounted) setState(() => _loadingCats = false);
    }
  }

  // ----------------- PRODUCTS + VARIANTS -----------------
  Future<void> _fetchRows({bool reset = false}) async {
    final api = context.read<ApiClient>();
    final dio = api.dio;
    String email = api.currentEmail.toString();
    if (reset) {
      // önceki products isteklerini iptal et
      _listToken?.cancel('reset');
      _listToken = CancelToken();

      // variant isteklerini de iptal et
      for (final t in _variantTokens.values) {
        t.cancel('reset');
      }
      _variantTokens.clear();

      for (final r in _rows) r.dispose();
      _rows.clear();
      _page = 1;
      _more = true;
      _error = null;
      _dataSource.notifyListeners();
      _pdtKey = UniqueKey(); // paginator'ı başa al
      setState(() {});
    }
    if (!_more || _fetchingMore) return;

    _fetchingMore = true;
    if (reset) setState(() => _loadingRows = true);

    try {
      final params = <String, dynamic>{
        'page': _page,
        'per_page': 50, // ilk boyama hızlansın
        if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
        if (_selectedCat != null) ...{
          'category_id': _selectedCat,
          'filters[category_id]': _selectedCat,
        },
      };

      final res = await _dio.get(
        'products',
        queryParameters: params,
        cancelToken: _listToken,
      );
      final products = _parseProductsPayload(res.data);

      // 1) OPTİMİSTİK DOLDURMA: ürünleri hemen göster (ilk varyant veya placeholder)
      for (final p in products) {
        final baseVariant = p.variants.isNotEmpty
            ? p.variants.first
            : ProductVariant(
                id: p.id * 1000,
                name: 'Standart',
                price: 0.0,
                unit: 'ADET',
                image: p.image,
              );

        _rows.add(_RowVM(
          product: p,
          variants: [baseVariant],
          selectedVariantId: baseVariant.id,
          price: baseVariant.price ?? 0.0,
        ));
      }
      _dataSource.notifyListeners();
      if (mounted) setState(() {});

      // 2) VARYANTLARI LAZY + CACHED ÇEK
      const int concurrency = 4;
      for (var i = 0; i < products.length; i += concurrency) {
        final group =
            products.sublist(i, (i + concurrency).clamp(0, products.length));
        await Future.wait(group.map((p) async {
          // cache'de varsa direkt uygula
          if (_variantsCache.containsKey(p.id)) {
            final cached = _variantsCache[p.id]!;
            final idx = _rows.indexWhere((r) => r.product.id == p.id);
            if (idx >= 0) {
              final row = _rows[idx];
              row.variants = cached;
              // mevcut seçim yoksa ilkini ata
              final sel = cached.firstWhere(
                (v) => v.id == row.selectedVariantId,
                orElse: () => cached.first,
              );
              row.selectedVariantId = sel.id;
              row.priceC.text = (sel.price ?? 0.0).toStringAsFixed(2);
            }
            return;
          }

          // aynı ürün için eski bir variant isteği varsa iptal et
          _variantTokens[p.id]?.cancel('newer variants request');
          final token = CancelToken();
          _variantTokens[p.id] = token;

          List<ProductVariant> vs = const [];
          try {
            final r = await _dio.get(
              'products/${p.id}/variantsuser',
              queryParameters: {'email': email},
              cancelToken: token,
            );

            dynamic data = r.data;
            if (data is Map && data['data'] is List) data = data['data'];
            if (data is Map && data['variants'] is List)
              data = data['variants'];
            final list = (data is List) ? data : <dynamic>[];

            vs = list.whereType<Map>().map((vv) {
              final v = Map<String, dynamic>.from(vv);
              return ProductVariant(
                id: _asInt(v['id']),
                name: (v['name'] ?? 'Varyant').toString(),
                price: _latestPriceOfMine(v, _myUserIdForPricePick) ??
                    _asDouble(
                        v['user_price'] ?? v['price'] ?? v['average_price']),
                unit: (v['unit'] ?? 'adet').toString(),
                sku: v['sku']?.toString(),
                image: v['image']?.toString(),
              );
            }).toList();
          } on DioException catch (e) {
            if (CancelToken.isCancel(e)) {
              vs = const [];
            } else {
              vs = const [];
            }
          } catch (_) {
            vs = const [];
          } finally {
            if (_variantTokens[p.id] == token) {
              _variantTokens.remove(p.id);
            }
          }

          if (vs.isNotEmpty) {
            _variantsCache[p.id] = vs;
            final idx = _rows.indexWhere((r) => r.product.id == p.id);
            if (idx >= 0) {
              final row = _rows[idx];
              row.variants = vs;
              final sel = vs.firstWhere(
                (v) => v.id == row.selectedVariantId,
                orElse: () => vs.first,
              );
              row.selectedVariantId = sel.id;
              row.priceC.text = (sel.price ?? 0.0).toStringAsFixed(2);
            }
          }
        }));

        _dataSource.notifyListeners();
        if (mounted) setState(() {});
      }

      // sayfalama
      int? currentPage, lastPage;
      final root = res.data;
      if (root is Map) {
        if (root['data'] is Map) {
          final d = root['data'] as Map;
          if (d['current_page'] is num)
            currentPage = (d['current_page'] as num).toInt();
          if (d['last_page'] is num) lastPage = (d['last_page'] as num).toInt();
        }
        if (root['current_page'] is num)
          currentPage = (root['current_page'] as num).toInt();
        if (root['last_page'] is num)
          lastPage = (root['last_page'] as num).toInt();
      }
      if (currentPage != null && lastPage != null) {
        _more = currentPage < lastPage;
        if (_more) _page = currentPage + 1;
      } else {
        _more = products.isNotEmpty;
        if (_more) _page += 1;
      }
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e)) _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      _fetchingMore = false;
      if (mounted) {
        _loadingRows = false;
        _dataSource.notifyListeners();
        _pdtKey = UniqueKey(); // tabloyu zorla yeniden kur
        setState(() {});
      }
    }
  }

  // ----------------- SAVE OPS -----------------
  Future<void> _saveRow(_RowVM row) async {
    final variantId = row.selectedVariantId;
    final price = double.tryParse(row.priceC.text.replaceAll(',', '.'));
    if (variantId == null || price == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Geçersiz fiyat')));
      return;
    }

    try {
      await _dio.post('user-product-prices/upsert', data: {
        'email': _emailForPrice,
        'product_variant_id': variantId,
        'price': price,
        'active': true,
      });
      row.dirty = false;
      _dataSource.notifyListeners();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Kaydedildi: ${row.product.name}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _saveAll() async {
    final list = _rows.where((e) => e.dirty).toList();
    for (final r in list) {
      await _saveRow(r);
    }
  }

  // ----------------- VARIANT ADD -----------------
  Future<({String name, String unit, double? price})?> _askVariant(
      BuildContext ctx) async {
    final formKey = GlobalKey<FormState>();
    final nameC = TextEditingController();
    final priceC = TextEditingController();
    String selectedUnit = _unitOptions.first;
    bool saving = false;

    final result =
        await showDialog<({String name, String unit, double? price})>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setS) => AlertDialog(
          title: const Text('Varyant Ekle'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameC,
                    decoration:
                        const InputDecoration(labelText: 'Varyant adı *'),
                    autofocus: true,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Varyant adı zorunlu'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedUnit,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Birim'),
                    items: _unitOptions
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) =>
                        setS(() => selectedUnit = v ?? selectedUnit),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: priceC,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Başlangıç fiyatı (₺) — opsiyonel'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed:
                    saving ? null : () => Navigator.of(dialogCtx).pop(null),
                child: const Text('Vazgeç')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      final raw = priceC.text.trim();
                      final parsed = raw.isEmpty
                          ? null
                          : double.tryParse(raw.replaceAll(',', '.'));
                      setS(() => saving = true);
                      Navigator.of(dialogCtx).pop((
                        name: nameC.text.trim(),
                        unit: selectedUnit,
                        price: parsed
                      ));
                    },
              child: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Ekle'),
            ),
          ],
        ),
      ),
    );

    nameC.dispose();
    priceC.dispose();
    return result;
  }

  Future<void> _addVariantForRow(_RowVM row) async {
    final input = await _askVariant(context);
    if (input == null) return;

    try {
      final create =
          await _dio.post('products/${row.product.id}/variants', data: {
        'name': input.name,
        'unit': input.unit,
        'active': true,
      });
      final newId = _asInt(
        (create.data is Map && create.data['variant'] != null)
            ? (create.data['variant']['id'])
            : (create.data is Map && create.data['id'] != null)
                ? create.data['id']
                : 0,
      );

      if (input.price != null) {
        await _dio.post('user-product-prices/upsert', data: {
          'email': _emailForPrice,
          'product_variant_id': newId,
          'price': input.price,
          'active': true,
        });
      }

      final pv = ProductVariant(
        id: newId,
        name: input.name,
        price: input.price ?? 0.0,
        unit: input.unit,
        sku: null,
        image: null,
      );
      row.variants = [...row.variants, pv];
      row.selectedVariantId = newId;
      row.priceC.text = (pv.price ?? 0.0).toStringAsFixed(2);
      row.dirty = input.price != null ? false : true;

      _dataSource.notifyListeners();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Varyant eklendi')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  // ----------------- PRODUCT ADD (sheet + single POST) -----------------
  Future<void> _addProduct() async {
    final form = await showAddProductSheet(
      context,
      cats: _cats,
      preselectedCatId: _selectedCat,
      unitOptions: _unitOptions,
    );
    if (form == null) return;
    await _submitProductForm(form);
  }

  Future<void> _submitProductForm(
      ({
        String name,
        String? description,
        int? categoryId,
        Uint8List? imageBytes,
        String? imageName,
        String? variantName,
        double? variantPrice,
      }) form) async {
    try {
      final dio = _dio;

      // upload (ops.)
      String? imagePath;
      if (form.imageBytes != null && form.imageName != null) {
        final fd = FormData.fromMap({
          'image': MultipartFile.fromBytes(form.imageBytes!,
              filename: form.imageName!),
        });
        final up = await dio.post('upload', data: fd);
        if (up.data is Map && up.data['path'] is String) {
          imagePath = up.data['path'] as String;
        } else if (up.data is Map &&
            up.data['data'] is Map &&
            up.data['data']['path'] is String) {
          imagePath = up.data['data']['path'] as String;
        }
      }

      // tek POST
      final payload = <String, dynamic>{
        'name': form.name,
        if (form.description != null) 'description': form.description,
        if (imagePath != null) 'image': imagePath,
        'active': true,
        if (form.categoryId != null) 'category_ids': [form.categoryId],
        'email': _emailForPrice,
        if (form.variantName != null || form.variantPrice != null)
          'variants': [
            {
              'name': form.variantName ?? 'Standart',
              'unit': form.variantName ?? 'ADET',
              'active': true,
              if (form.variantPrice != null) 'price': form.variantPrice,
            }
          ],
      };

      final created = await dio.post('productsfull', data: payload);
      final productId = _asInt(
        (created.data is Map &&
                created.data['product'] is Map &&
                created.data['product']['id'] != null)
            ? created.data['product']['id']
            : 0,
      );
      if (productId <= 0) throw Exception('Product ID alınamadı.');

      await _fetchRows(reset: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ürün eklendi')));
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      final body = e.response?.data;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Hata ($status): ${body is String ? body : body.toString()}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  // ----------------- HELPERS -----------------
  List<Product> _parseProductsPayload(dynamic payload) {
    List items;
    if (payload is Map &&
        payload['data'] is Map &&
        (payload['data'] as Map)['data'] is List) {
      items = ((payload['data'] as Map)['data'] as List);
    } else if (payload is Map && payload['data'] is List) {
      items = (payload['data'] as List);
    } else if (payload is List) {
      items = payload;
    } else if (payload is Map && payload['results'] is List) {
      items = payload['results'] as List;
    } else {
      items = const [];
    }

    return items.whereType<Map>().map((raw) {
      final j = Map<String, dynamic>.from(raw);

      int _asIntLocal(dynamic v) {
        if (v is int) return v;
        if (v is String) return int.tryParse(v) ?? 0;
        if (v is num) return v.toInt();
        return 0;
      }

      double _asDoubleLocal(dynamic v) {
        if (v is double) return v;
        if (v is int) return v.toDouble();
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
        return 0.0;
      }

      final id = _asIntLocal(j['id']);
      final name = (j['name'] ?? j['title'] ?? '').toString();
      final catId = _asIntLocal(j['category_id'] ?? j['categoryId']);

      final imagePath = j['image']?.toString() ?? '';
      final imageUrl = AppConfig.imageUrl(imagePath);

      List<ProductVariant> variants = [];
      if (j['variants'] is List) {
        variants = (j['variants'] as List).whereType<Map>().map((vv) {
          final v = Map<String, dynamic>.from(vv);
          return ProductVariant(
            id: _asIntLocal(v['id']),
            name: (v['name'] ?? 'Standart').toString(),
            price: _asDoubleLocal(v['price'] ?? v['average_price']),
            unit: (v['unit'] ?? 'adet').toString(),
            sku: v['sku']?.toString(),
            image: v['image']?.toString(),
          );
        }).toList();
      } else {
        variants = [
          ProductVariant(
            id: id,
            name: (j['variant_name'] ?? 'Standart').toString(),
            price: _asDoubleLocal(j['price']),
            unit: (j['unit'] ?? 'adet').toString(),
            sku: j['sku']?.toString(),
            image: j['variant_image']?.toString(),
          ),
        ];
      }

      return Product(
        id: id,
        categoryId: catId,
        name: name,
        image: imageUrl,
        variants: variants,
      );
    }).toList();
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is num) return v.toInt();
    return 0;
  }

  double _asDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
    return 0.0;
  }

  double? _latestPriceOfMine(Map<String, dynamic> v, int? myId) {
    if (myId == null) return null;
    final list = v['prices'];
    if (list is! List) return null;

    final mine = list.whereType<Map>().where((p) {
      final uid = _asInt(p['user_id']);
      return uid == myId;
    }).toList();

    if (mine.isEmpty) return null;

    mine.sort((a, b) {
      final ai = _asInt(a['id']);
      final bi = _asInt(b['id']);
      return bi.compareTo(ai);
    });

    return _asDouble(mine.first['price']);
  }

  // ----------------- UI -----------------
  @override
  Widget build(BuildContext context) {
    final dirtyCount = _rows.where((e) => e.dirty).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiyat Listesi (Tablo)'),
        actions: [
          IconButton(
            tooltip: 'Ürün Ekle',
            onPressed: _addProduct,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Hepsini Kaydet',
            onPressed: dirtyCount > 0 ? _saveAll : null,
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: Column(
        children: [
          // arama & kategori
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: 'Ürün veya varyant ara…',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _onSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                _loadingCats
                    ? const SizedBox(
                        width: 140,
                        child: LinearProgressIndicator(minHeight: 2))
                    : DropdownButton<int?>(
                        value: _selectedCat,
                        hint: const Text('Kategori'),
                        onChanged: (v) {
                          setState(() => _selectedCat = v);
                          _fetchRows(reset: true);
                        },
                        items: [
                          const DropdownMenuItem<int?>(
                              value: null, child: Text('Tümü')),
                          ..._cats.map((c) => DropdownMenuItem<int?>(
                              value: c.id, child: Text(c.name))),
                        ],
                      ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_error!,
                          maxLines: 2, overflow: TextOverflow.ellipsis)),
                  TextButton.icon(
                    onPressed: () => _fetchRows(reset: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            ),
          if (!_loadingRows && _rows.isEmpty && _error == null)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Kayıt bulunamadı',
                    style: TextStyle(fontStyle: FontStyle.italic)),
              ),
            ),
          Expanded(
            child: _loadingRows && _rows.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildPaginatedTable(),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  if (_fetchingMore)
                    const Expanded(child: LinearProgressIndicator(minHeight: 2))
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: dirtyCount > 0 ? _saveAll : null,
                    icon: const Icon(Icons.save),
                    label: Text(dirtyCount > 0
                        ? 'Hepsini Kaydet ($dirtyCount)'
                        : 'Hepsini Kaydet'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginatedTable() {
    const double kMinTableWidth = 920; // dar ekran için minimum tablo genişliği

    final columns = <DataColumn>[
      DataColumn(
        label: const Text('Ürün'),
        onSort: (i, asc) {
          setState(() {
            _sortColumnIndex = i;
            _sortAscending = asc;
            _rows.sort((a, b) => asc
                ? a.product.name
                    .toLowerCase()
                    .compareTo(b.product.name.toLowerCase())
                : b.product.name
                    .toLowerCase()
                    .compareTo(a.product.name.toLowerCase()));
            _dataSource.notifyListeners();
          });
        },
      ),
      const DataColumn(label: Text('Varyant')),
      const DataColumn(label: Text('Varyant Ekle')),
      const DataColumn(label: Text('Fiyat (₺)')),
      const DataColumn(label: Text('İşlem')),
    ];

    // rowsPerPage seçenekleri (mevcut değer dışarıdaysa ilkine çek)
    final availableRpp = const [5, 8, 10, 20];
    if (!availableRpp.contains(_rowsPerPage)) {
      _rowsPerPage = availableRpp.first;
    }

    final pdt = PaginatedDataTable(
      key: _pdtKey,
      header: null, // boş başlık satırını kaldır
      columns: columns,
      source: _dataSource,
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      rowsPerPage: _rowsPerPage,
      availableRowsPerPage: availableRpp,
      onRowsPerPageChanged: (v) {
        if (v == null) return;
        setState(() {
          _rowsPerPage = v;
          _pdtKey = UniqueKey(); // paginator yeniden kurulsun
        });
      },
      onPageChanged: (rowStart) async {
        // tablo sonuna yaklaşınca bir sonraki sayfayı çek
        final needMore = rowStart + _rowsPerPage >= _rows.length - 2;
        if (needMore && _more && !_fetchingMore) {
          await _fetchRows(); // reset=false
        }
      },
      headingRowHeight: 40,
      dataRowMinHeight: 48,
      dataRowMaxHeight: 56,
      columnSpacing: 18,
      horizontalMargin: 12,
      showCheckboxColumn: false,
      showFirstLastButtons: true,
    );

    // *** SADECE YATAY SCROLL ***
    // Çocuğun genişliğini SONLU yapıyoruz (en az kMinTableWidth, en az viewport kadar).
    return LayoutBuilder(
      builder: (context, constraints) {
        final double tableWidth = (constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : kMinTableWidth);
        final double width =
            tableWidth < kMinTableWidth ? kMinTableWidth : tableWidth;

        return Scrollbar(
          controller: _hCtrl,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _hCtrl,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width, // SONLU genişlik (kritik)
              child: pdt,
            ),
          ),
        );
      },
    );
  }
}

// ================== DataTableSource ==================
class _PriceDataSource extends DataTableSource {
  final List<_RowVM> Function() getRows;
  final Future<void> Function(_RowVM) onSaveRow;
  final Future<void> Function(_RowVM) onAddVariant;
  final VoidCallback? onChanged;

  _PriceDataSource({
    required this.getRows,
    required this.onSaveRow,
    required this.onAddVariant,
    this.onChanged,
  });

  void _tick() {
    notifyListeners();
    onChanged?.call();
  }

  @override
  DataRow? getRow(int index) {
    final rows = getRows();
    if (index < 0 || index >= rows.length) return null;
    final row = rows[index];

    final selected = row.variants.isNotEmpty
        ? row.variants.firstWhere(
            (v) => v.id == row.selectedVariantId,
            orElse: () => row.variants.first,
          )
        : null;

    return DataRow.byIndex(
      index: index,
      cells: [
        // Ürün (görsel + ad)
        DataCell(Row(
          children: [
            if ((row.product.image).toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    row.product.image.startsWith('http')
                        ? row.product.image
                        : AppConfig.imageUrl(row.product.image),
                    width: 36,
                    height: 36,
                    cacheWidth: 72, // küçük thumb için decode maliyeti düşer
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.image_not_supported, size: 20),
                  ),
                ),
              ),
            Flexible(
              child: Text(
                row.product.name,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        )),

        // Varyant dropdown
        DataCell(SizedBox(
          width: 240,
          child: DropdownButton<int>(
            isExpanded: true,
            value: row.selectedVariantId ?? selected?.id,
            items: row.variants
                .map(
                  (v) => DropdownMenuItem<int>(
                    value: v.id,
                    child: Text(
                      v.name ?? 'Varyant ${v.id}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val == null) return;
              final nv = row.variants.firstWhere(
                (e) => e.id == val,
                orElse: () => row.variants.first,
              );
              row.selectedVariantId = val;
              row.priceC.text = (nv.price ?? 0.0).toStringAsFixed(2);
              row.dirty = true;
              _tick();
            },
          ),
        )),

        // Varyant ekle
        DataCell(
          OutlinedButton.icon(
            onPressed: () async {
              await onAddVariant(row);
              _tick();
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Varyant'),
          ),
        ),

        // Fiyat input
        DataCell(
          SizedBox(
            width: 160,
            child: TextField(
              controller: row.priceC,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: const OutlineInputBorder(),
                filled: row.dirty,
                fillColor: row.dirty ? Colors.green.withOpacity(.08) : null,
              ),
              onChanged: (_) {
                row.dirty = true;
                _tick();
              },
              onSubmitted: (_) async {
                await onSaveRow(row);
                _tick();
              },
            ),
          ),
        ),

        // Kaydet
        DataCell(
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: row.dirty
                  ? () async {
                      await onSaveRow(row);
                      _tick();
                    }
                  : null,
              icon: const Icon(Icons.check),
              label: const Text('Kaydet'),
            ),
          ),
        ),
      ],
    );
  }

  @override
  int get rowCount => getRows().length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}

// ================== Modern Bottom Sheet: Add Product ==================
typedef AddProductForm = ({
  String name,
  String? description,
  int? categoryId,
  Uint8List? imageBytes,
  String? imageName,
  String? variantName,
  double? variantPrice,
});

Future<AddProductForm?> showAddProductSheet(
  BuildContext context, {
  required List<Category> cats,
  int? preselectedCatId,
  List<String> unitOptions = const ['ADET', 'GR', 'KG', 'BAĞ', 'DEMET', 'KASA'],
}) {
  final nameC = TextEditingController();
  final descC = TextEditingController();
  final vPriceC = TextEditingController();

  Uint8List? imgBytes;
  String? imgName;

  int? selCatId = preselectedCatId;
  String selUnit = unitOptions.first;

  return showModalBottomSheet<AddProductForm>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      final mq = MediaQuery.of(ctx);
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: mq.viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setS) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text('Ürün Ekle',
                            style: Theme.of(ctx).textTheme.titleLarge)),
                    IconButton(
                      tooltip: 'Kapat',
                      onPressed: () => Navigator.of(ctx).pop(null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameC,
                  decoration: const InputDecoration(
                    labelText: 'Ürün adı *',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: selCatId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Kategori (opsiyonel)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                        value: null, child: Text('— Yok —')),
                    ...cats.map((c) => DropdownMenuItem<int>(
                        value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (v) => setS(() => selCatId = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descC,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final picked = await FilePicker.platform
                              .pickFiles(type: FileType.image, withData: true);
                          if (picked != null && picked.files.isNotEmpty) {
                            final f = picked.files.first;
                            if (f.bytes != null) {
                              setS(() {
                                imgBytes = f.bytes;
                                imgName = f.name;
                              });
                            }
                          }
                        } catch (_) {}
                      },
                      icon: const Icon(Icons.image),
                      label: const Text('Resim Seç'),
                    ),
                    const SizedBox(width: 12),
                    if (imgName != null)
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(imgName!,
                                    overflow: TextOverflow.ellipsis)),
                            IconButton(
                              tooltip: 'Kaldır',
                              onPressed: () => setS(() {
                                imgBytes = null;
                                imgName = null;
                              }),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (imgBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child:
                        Image.memory(imgBytes!, height: 150, fit: BoxFit.cover),
                  ),
                const Divider(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('İlk Varyant (opsiyonel)',
                      style: Theme.of(ctx).textTheme.titleSmall),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: selUnit,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Birim',
                          border: OutlineInputBorder(),
                        ),
                        items: unitOptions
                            .map((u) =>
                                DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) => setS(() => selUnit = v ?? selUnit),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: vPriceC,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Başlangıç fiyatı (₺)',
                          hintText: 'opsiyonel',
                          border: OutlineInputBorder(),
                          suffixText: '₺',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(null),
                      child: const Text('Vazgeç'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () {
                        final name = nameC.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text('Ürün adı zorunludur')),
                          );
                          return;
                        }
                        final priceRaw = vPriceC.text.trim();
                        final vPrice = priceRaw.isEmpty
                            ? null
                            : double.tryParse(priceRaw.replaceAll(',', '.'));
                        Navigator.of(ctx).pop((
                          name: name,
                          description: descC.text.trim().isEmpty
                              ? null
                              : descC.text.trim(),
                          categoryId: selCatId,
                          imageBytes: imgBytes,
                          imageName: imgName,
                          variantName: selUnit,
                          variantPrice: vPrice,
                        ));
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Kaydet'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    },
  ).then((value) {
    nameC.dispose();
    descC.dispose();
    vPriceC.dispose();
    return value;
  });
}
