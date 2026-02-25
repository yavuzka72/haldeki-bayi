// lib/models/cart.dart
import 'dart:collection';
import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/variant.dart';

class CartItem {
  final Product product;
  final ProductVariant variant;

  /// Genel miktar (koli/adet/kg).
  double qtyCases;

  CartItem({
    required this.product,
    required this.variant,
    this.qtyCases = 1,
  });

  /// Birim fiyat (eski şema varsa pricePerKg, yoksa variant.price).
  double get unitPrice {
    final dyn = variant as dynamic;
    try {
      final ppk = dyn.pricePerKg;
      if (ppk is num && ppk > 0) return ppk.toDouble();
    } catch (_) {}
    return variant.price;
  }

  /// Birim etiketi
  String get unitLabel {
    final dyn = variant as dynamic;
    try {
      final ppk = dyn.pricePerKg;
      if (ppk is num && ppk > 0) return 'kg';
    } catch (_) {}
    return (variant.unit.isEmpty ? 'adet' : variant.unit);
  }

  /// Satır toplamı
  double get lineTotal {
    final dyn = variant as dynamic;
    try {
      final ppk = dyn.pricePerKg; // fiyat/kg
      if (ppk is num && ppk > 0) {
        final kgpc = dyn.approxKgPerCase; // kg/koli
        final perCase = (kgpc is num && kgpc > 0) ? kgpc.toDouble() : 1.0;
        return qtyCases * perCase * ppk.toDouble();
      }
    } catch (_) {}
    return qtyCases * variant.price;
  }
}

class Cart extends ChangeNotifier {
  // Singleton istiyorsan:
  static final Cart I = Cart._();
  Cart._();

  // Singleton istemiyorsan normal ctor da olur:
  // Cart();

  /// İç depolama: aynı ürün+varyant aynı satırda tutulur.
  final Map<String, CartItem> _map = LinkedHashMap<String, CartItem>();

  String _keyOf(Product p, ProductVariant v) => '${p.id}-${v.id}';

  /// Dışarıya salt-okunur liste ver.
  UnmodifiableListView<CartItem> get items =>
      UnmodifiableListView<CartItem>(_map.values);

  /// Satır sayısı
  int get lines => _map.length;

  /// Toplam miktar
  double get totalQty =>
      _map.values.fold(0.0, (s, it) => s + it.qtyCases);

  /// Sepet toplamı
  double get total =>
      _map.values.fold(0.0, (sum, it) => sum + it.lineTotal);

  /// Miktarı artırarak ekler (yoksa oluşturur). Negatif değer azaltır.
  void add(Product p, ProductVariant v, {double qtyCases = 1}) {
    if (qtyCases == 0) return;
    final key = _keyOf(p, v);
    final ex = _map[key];
    if (ex == null) {
      if (qtyCases > 0) {
        _map[key] = CartItem(product: p, variant: v, qtyCases: qtyCases);
      }
    } else {
      ex.qtyCases += qtyCases;
      if (ex.qtyCases <= 0) _map.remove(key);
    }
    notifyListeners();
  }

  /// Satır miktarını set eder; <=0 ise siler.
  void setQty(Product p, ProductVariant v, double qtyCases) {
    final key = _keyOf(p, v);
    if (qtyCases <= 0) {
      _map.remove(key);
    } else {
      final ex = _map[key];
      if (ex == null) {
        _map[key] = CartItem(product: p, variant: v, qtyCases: qtyCases);
      } else {
        ex.qtyCases = qtyCases;
      }
    }
    notifyListeners();
  }

  /// 1 artır
  void inc(Product p, ProductVariant v) => add(p, v, qtyCases: 1);

  /// 1 azalt (0 veya altına düşerse satırı siler)
  void dec(Product p, ProductVariant v) => add(p, v, qtyCases: -1);

  /// Satırı tamamen kaldır (mevcut adet kadar negatif ekleyerek de yapılabilir)
  void removeLine(Product p, ProductVariant v) {
    _map.remove(_keyOf(p, v));
    notifyListeners();
  }

  /// Sepeti temizle
  void clear() {
    _map.clear();
    notifyListeners();
  }
}
