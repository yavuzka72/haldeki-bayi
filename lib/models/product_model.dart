// lib/models/product_model.dart
import 'dart:convert';

class ProductModel {
  final String id;
  final String name;
  final double price;
  final String? unit;
  final String? imageUrl;

  /// Sunucudan gelen ham veri (gerekirse başka alanlara erişebilmek için)
  final Map<String, dynamic> raw;

  const ProductModel({
    required this.id,
    required this.name,
    required this.price,
    this.unit,
    this.imageUrl,
    this.raw = const {},
  });

  /// Esnek parse: id/name/price/image alanları farklı anahtarlarla da gelebilir.
  factory ProductModel.fromJson(Map<String, dynamic> json0) {
    // Eğer {key, value:{...}} şeklinde geldiyse "value" içini asıl kaynak yap.
    Map<String, dynamic> json = json0;
    if (json0.containsKey('value') && json0['value'] is Map) {
      json = Map<String, dynamic>.from(json0['value'] as Map);
      // value içinde id yoksa dıştaki key'i id olarak kullan
      if (!json.containsKey('id') && json0['key'] != null) {
        json['id'] = json0['key'];
      }
    }

    String _s(dynamic v) => v == null ? '' : '$v';
    double _d(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      final s = '$v'.replaceAll(',', '.');
      return double.tryParse(s) ?? 0.0;
    }

    // ID adayları
    final id =
        _s(json['id'] ?? json['uuid'] ?? json['product_id'] ?? json['_id'] ?? json['key']);

    // İsim adayları
    final name = _s(json['name'] ?? json['title'] ?? json['product_name'] ?? '—');

    // Fiyat adayları
    final price = _d(json['price'] ?? json['unit_price'] ?? json['sale_price'] ?? json['amount']);

    // Birim
    final unit = (json['unit'] ?? json['unit_name'] ?? json['unitType'])?.toString();

    // Görsel URL adayları
    String? imageUrl;
    final img = json['image'] ?? json['image_url'] ?? json['photo'] ?? json['thumbnail'] ?? json['thumb'] ?? json['cover'];
    if (img != null && img is String && img.trim().isNotEmpty) {
      imageUrl = img;
    } else if (json['images'] is List && (json['images'] as List).isNotEmpty) {
      final first = (json['images'] as List).first;
      if (first is String) {
        imageUrl = first;
      } else if (first is Map) {
        // {url: ...} gibi
        imageUrl = first['url']?.toString();
      }
    }

    return ProductModel(
      id: id,
      name: name,
      price: price,
      unit: unit,
      imageUrl: imageUrl,
      raw: Map<String, dynamic>.from(json0),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        if (unit != null) 'unit': unit,
        if (imageUrl != null) 'image_url': imageUrl,
      };

  ProductModel copyWith({
    String? id,
    String? name,
    double? price,
    String? unit,
    String? imageUrl,
    Map<String, dynamic>? raw,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      imageUrl: imageUrl ?? this.imageUrl,
      raw: raw ?? this.raw,
    );
  }

  @override
  String toString() => jsonEncode(toJson());

  /// List parse helper
  static List<ProductModel> listFromDynamic(dynamic v) {
    if (v is List) {
      return v
          .where((e) => e is Map)
          .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    if (v is Map) {
      // Tek obje geldiyse
      return [ProductModel.fromJson(Map<String, dynamic>.from(v))];
    }
    return const [];
  }
}
