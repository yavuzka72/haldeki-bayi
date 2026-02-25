import 'package:flutter/foundation.dart';
import 'product.dart';
import 'variant.dart';

class CartItem {
  final String key; // productId:variantId
  final Product product;
  final ProductVariant variant;
  int qty;

  CartItem({
    required this.key,
    required this.product,
    required this.variant,
    required this.qty,
  });

  double get lineTotal => (variant.price) * qty;

  /// API'ye gidecek sipariş item formatı
  Map<String, dynamic> toApiItem() => {
        'product_variant_id': variant.id,
        'quantity': qty,
        'unit_price': variant.price,
        'snapshot': {
          'product_id': product.id,
          'product_name': product.name,
          'variant_id': variant.id,
          'variant_name': variant.name,
          'unit': variant.unit,
          'image': variant.image ?? product.image,
          'category_id': product.categoryId,
        }
      };

  /// Debug/ekranda gösterim için okunaklı JSON
  Map<String, dynamic> toJson() => {
        'key': key,
        'qty': qty,
        'line_total': lineTotal,
        'product': {
          'id': product.id,
          'name': product.name,
          'image': product.image,
          'category_id': product.categoryId,
        },
        'variant': {
          'id': variant.id,
          'name': variant.name,
          'price': variant.price,
          'unit': variant.unit,
          'image': variant.image,
        },
      };
}


class CartModel extends ChangeNotifier {
  CartModel._();
  static final CartModel I = CartModel._();

  /// key = "${product.id}:${variant.id}"
  final Map<String, CartItem> _items = {};
  Map<String, CartItem> get items => _items;

  // --- Mutations ---
  void add(Product p, ProductVariant v, {int qty = 1}) {
    final pid = p.id;
    final vid = v.id;
    if (pid == 0 || vid == 0) return; // id'ler düzgün gelmeli
    final k = '$pid:$vid';

    if (_items.containsKey(k)) {
      _items[k]!.qty += qty;
    } else {
      _items[k] = CartItem(key: k, product: p, variant: v, qty: qty);
    }
    notifyListeners();
  }

  void setQtyByKey(String key, int qty) {
    if (!_items.containsKey(key)) return;
    if (qty <= 0) {
      _items.remove(key);
    } else {
      _items[key]!.qty = qty;
    }
    notifyListeners();
  }

  void removeByKey(String key) {
    _items.remove(key);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  // --- Totals ---
  double get subtotal =>
      _items.values.fold(0.0, (s, it) => s + it.lineTotal);

double get shipping => subtotal >= 2000 ? 0.0 : 200.0;

double get total => subtotal + shipping;


  // --- API payload / Debug JSON ---
  List<Map<String, dynamic>> toCartJson() {
    return _items.values.map((it) => {
      'product_variant_id': it.variant.id,
      'quantity': it.qty,
      'unit_price': it.variant.price,
      'snapshot': {
        'product_name': it.product.name,
        'variant_name': it.variant.name,
        'unit': it.variant.unit,
      }
    }).toList();
  }
}
