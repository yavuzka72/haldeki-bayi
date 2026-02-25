class Category {
  final int id;
  final String name;
  final String image;
  const Category({required this.id, required this.name, required this.image});

  factory Category.fromJson(Map<String, dynamic> j) =>
      Category(id: j["id"], name: j["name"], image: j["image"] ?? "🛒");

  Map<String, dynamic> toJson() => {"id": id, "name": name, "image": image};
}
class CategoryCreate {
final String name;
final int? supplierId;
final String? image;
CategoryCreate({required this.name, this.supplierId, this.image});
Map<String, dynamic> toJson() => {
'name': name,
if (supplierId != null) 'supplier_id': supplierId,
if (image != null) 'image': image,
};
}


class CategoryUpdate {
final String? name;
final String? image;
CategoryUpdate({this.name, this.image});
Map<String, dynamic> toJson() => {
if (name != null) 'name': name,
if (image != null) 'image': image,
};
}