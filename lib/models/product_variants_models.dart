class ProductHeader {
  final int id;
  final String name;
  final String? imageUrl;
  final bool active;

  ProductHeader({
    required this.id,
    required this.name,
    required this.active,
    this.imageUrl,
  });

  factory ProductHeader.fromJson(Map<String, dynamic> j) {
    return ProductHeader(
      id: (j['id'] as num).toInt(),
      name: (j['name'] ?? '').toString(),
      imageUrl: j['image_url']?.toString(),
      active: j['active'] == true || j['active'] == 1,
    );
  }
}

class VariantRow {
  final int variantId;
  final String variantName;
  final double? price;

  VariantRow({required this.variantId, required this.variantName, this.price});

  factory VariantRow.fromJson(Map<String, dynamic> j) {
    double? _d(v) => v == null
        ? null
        : (v is num ? v.toDouble() : double.tryParse(v.toString()));
    return VariantRow(
      variantId: (j['variant_id'] as num).toInt(),
      variantName: (j['variant_name'] ?? '').toString(),
      price: _d(j['price']),
    );
  }
}

class ProductByProductResult {
  final ProductHeader product;
  final List<VariantRow> variants;
  final bool? assigned; // backend meta.assigned varsa gösterebilirsiniz

  ProductByProductResult({
    required this.product,
    required this.variants,
    this.assigned,
  });
}
