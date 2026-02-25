class ProductVariant {
  final int id;
  final String name;
  final double price;
  final String unit;
  final String? sku;
  final String? image; // opsiyonel, ürün varyanta özel görsel

  const ProductVariant({
    required this.id,
    required this.name,
    required this.price,
    required this.unit,
    this.sku,
    this.image,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> j) => ProductVariant(
        id: j['id'],
        name: j['name'],
        price: (j['price'] as num).toDouble(),
        unit: j['unit'],
        sku: j['sku'],
        image: j['image'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'unit': unit,
        if (sku != null) 'sku': sku,
        if (image != null) 'image': image,
      };
}



class Variant {
final int id;
final String name;
final String? unit;
final String? imagePath;
Variant({required this.id, required this.name, this.unit, this.imagePath});
factory Variant.fromJson(Map<String, dynamic> m) => Variant(
id: (m['id'] as num).toInt(),
name: (m['name'] ?? '') as String,
unit: m['unit'] as String?,
imagePath: m['image_path'] as String?,
);
}


class VariantCreate {
final String name;
final String? unit;
final String? image;
VariantCreate({required this.name, this.unit, this.image});
Map<String, dynamic> toJson() => {
'name': name,
if (unit != null) 'unit': unit,
if (image != null) 'image': image,
};
}


class VariantSetPrice {
final int supplierId;
final num price;
final String? currency;
VariantSetPrice({required this.supplierId, required this.price, this.currency});
Map<String, dynamic> toJson() => {
'supplier_id': supplierId,
'price': price,
if (currency != null) 'currency': currency,
};
}