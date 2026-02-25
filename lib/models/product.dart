import 'variant.dart';

class Product {
  final int id;
  final int categoryId;
  final String name;
  final String image; // ürün ana görseli/emoji
  final List<ProductVariant> variants;

  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.image,
    required this.variants,
  });

  ProductVariant get defaultVariant => variants.first;

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'],
        categoryId: j['category_id'],
        name: j['name'],
        image: j['image'] ?? '🛒',
        variants: (j['variants'] as List<dynamic>?)
                ?.map((e) => ProductVariant.fromJson(e))
                .toList() ??
            // geriye dönük uyumluluk: eski price/unit'ten tek varyant üret
            [
              ProductVariant(
                id: j['id'] * 1000, // sentetik id
                name: 'Standart',
                price: (j['price'] as num).toDouble(),
                unit: j['unit'],
                image: j['image'],
              )
            ],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category_id': categoryId,
        'name': name,
        'image': image,
        'variants': variants.map((v) => v.toJson()).toList(),
      };
}



class ProductCreate {
final String name;
final String? description;
final String? image;
final int? supplierId;
final int? categoryId;
ProductCreate({required this.name, this.description, this.image, this.supplierId, this.categoryId});
Map<String, dynamic> toJson() => {
'name': name,
if (description != null) 'description': description,
if (image != null) 'image': image,
if (supplierId != null) 'supplier_id': supplierId,
if (categoryId != null) 'category_id': categoryId,
};
}


class ProductUpdate {
final String? name;
final String? description;
final String? image;
ProductUpdate({this.name, this.description, this.image});
Map<String, dynamic> toJson() => {
if (name != null) 'name': name,
if (description != null) 'description': description,
if (image != null) 'image': image,
};
}