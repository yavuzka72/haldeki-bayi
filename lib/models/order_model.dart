import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'cart_model.dart';

enum OrderStatus { pending, preparing, shipped, delivered, cancelled }

String orderStatusText(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending: return "Alındı";
    
    case OrderStatus.preparing: return "Hazırlanıyor";
    case OrderStatus.shipped: return "Yolda";
    case OrderStatus.delivered: return "Teslim Edildi";
    case OrderStatus.cancelled: return "İptal";
  }
}

class Order {
  final String orderNumber;
  final DateTime createdAt;
  final double totalAmount;
  final List<CartItem> items;
  final OrderStatus status;

  const Order({
    required this.orderNumber,
    required this.createdAt,
    required this.totalAmount,
    required this.items,
    required this.status,
  });

  Order copyWith({
    String? orderNumber,
    DateTime? createdAt,
    double? totalAmount,
    List<CartItem>? items,
    OrderStatus? status,
  }) => Order(
        orderNumber: orderNumber ?? this.orderNumber,
        createdAt: createdAt ?? this.createdAt,
        totalAmount: totalAmount ?? this.totalAmount,
        items: items ?? this.items,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        "order_number": orderNumber,
        "created_at": createdAt.toIso8601String(),
        "status": orderStatusText(status),
        "currency": "TRY",
        "items": items.map((e) => e.toJson()).toList(),
        "total_amount": totalAmount,
      };
}

class OrdersModel extends ChangeNotifier {
  OrdersModel._();
  static final OrdersModel I = OrdersModel._();

  final List<Order> _orders = [];
  UnmodifiableListView<Order> get orders => UnmodifiableListView(_orders);

  // ✔️ var olan siparişi numaradan bul
  Order? findByNumber(String orderNumber) {
    try {
      return _orders.firstWhere((o) => o.orderNumber == orderNumber);
    } catch (_) {
      return null;
    }
  }

  // ✔️ siparişi iptal et (pending/preparing ise)
  bool cancelOrder(String orderNumber) {
    final idx = _orders.indexWhere((o) => o.orderNumber == orderNumber);
    if (idx == -1) return false;
    final o = _orders[idx];
    if (o.status == OrderStatus.pending || o.status == OrderStatus.preparing) {
      _orders[idx] = o.copyWith(status: OrderStatus.cancelled);
      notifyListeners();
      return true;
    }
    return false;
    }

  // ✔️ durum güncelle (demo amaçlı)
  bool updateStatus(String orderNumber, OrderStatus newStatus) {
    final idx = _orders.indexWhere((o) => o.orderNumber == orderNumber);
    if (idx == -1) return false;
    _orders[idx] = _orders[idx].copyWith(status: newStatus);
    notifyListeners();
    return true;
  }

  // ✔️ sepetten sipariş oluştur
  void placeOrderFromCart() {
    if (CartModel.I.items.isEmpty) return;
    final ts = DateTime.now();
    final orderNo = "SIP-${ts.millisecondsSinceEpoch}";
    final items = CartModel.I.items.values.toList();
    final total = CartModel.I.total;

    final newOrder = Order(
      orderNumber: orderNo,
      createdAt: ts,
      totalAmount: total,
      items: items,
      status: OrderStatus.pending,
    );
    _orders.insert(0, newOrder);
    notifyListeners();
    CartModel.I.clear();
  }

  // ✔️ yeniden sipariş (ürünleri sepete ekle)
  void reorder(String orderNumber) {
    final order = findByNumber(orderNumber);
    if (order == null) return;
    for (final it in order.items) {
      CartModel.I.add(it.product, it.variant, qty: it.qty);
    }
  }

  // JSON listesi
  List<Map<String, dynamic>> toOrdersJson() =>
      _orders.map((e) => e.toJson()).toList();
}
