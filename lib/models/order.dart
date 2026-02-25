import 'package:haldeki_admin_web/utils/json_parse.dart';

class Order {
  final int id;
  final String orderNumber; // boş bile olsa '' veriyoruz
  final String status;
  final String dealer_status; // '' olabilir, UI’da _s() ile güvenle kullan
  final String paymentStatus;
  final int deliveryStatus;
  final double totalAmount;
  final String? shippingAddress; // nullable bırakılabilir
  final String? phone;
  final bool isGuestOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdByName; // JSON'da yoksa '' olur

  /// 'client' = işletme, 'user' = son kullanıcı (müşteri)
  final String userType;

  final List<OrderItem> items;

  Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.dealer_status,
    required this.paymentStatus,
    required this.deliveryStatus,
    required this.totalAmount,
    required this.shippingAddress,
    required this.phone,
    required this.isGuestOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.createdByName,
    required this.userType,
    required this.items,
  });

  // ---- created_by / user alanından isim çekme ----
  static String _pickCreatedBy(Map<String, dynamic> m) {
    final u = m['user'] ?? m['created_by'] ?? m['customer'];
    if (u == null) return '';
    if (u is Map) {
      return asString(u['name'], fallback: asString(u['email'], fallback: ''));
    }
    return asString(u); // zaten string ise
  }

  /// Backend'den gelen user_type → 'client' | 'user'
  static String _parseUserType(Map<String, dynamic> m) {
    final raw = asString(m['user_type'] ?? m['userType'] ?? m['type'])
        .toLowerCase()
        .trim();

    // Eğer backend açıkça böyle gönderiyorsa:
    if (raw == 'client') return 'client'; // işletme
    if (raw == 'user') return 'user'; // son kullanıcı

    // Muhtemel varyasyonlar:
    if (raw == 'dealer' || raw == 'restaurant' || raw == 'merchant') {
      return 'client';
    }
    if (raw == 'customer' || raw == 'buyer') {
      return 'user';
    }

    // ⚠️ ÖNEMLİ:
    // Şu an "müşteri datası 0" dediğin için, bilinmeyen / boş değerleri
    // son kullanıcı (user) sayalım ki Müşteri filtresinde de siparişler gelsin.
    if (raw.isEmpty) {
      return 'user';
    }

    // En güvenli fallback: user (müşteri)
    return 'user';
  }

  factory Order.fromJson(Map<String, dynamic> j) {
    final itemsRaw = (j['items'] ?? j['order_items'] ?? []) as List?;
    final items = (itemsRaw ?? [])
        .whereType<Map>()
        .map((m) => OrderItem.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    return Order(
      id: asInt(j['id']),
      orderNumber: asString(j['order_number'] ?? j['number'] ?? j['code']),
      status: asString(j['status']).toLowerCase(),
      dealer_status: asString(j['dealer_status']).toLowerCase(),
      deliveryStatus: asInt(j['delivery_status']),
      // 'pending','delivered','away' vb.
      paymentStatus: asString(j['payment_status']),
      totalAmount: asDouble(
        j['total_amount'] ?? j['total'] ?? j['grand_total'] ?? j['amount'],
      ),
      shippingAddress: (j['shipping_address'] ?? j['address'])?.toString(),
      phone: j['phone']?.toString(),
      isGuestOrder: asBool(j['is_guest_order']),
      createdAt: parseDate(j['created_at'] ?? j['date']),
      updatedAt: parseDate(j['updated_at']),
      createdByName: _pickCreatedBy(j),
      userType: _parseUserType(j),
      items: items,
    );
  }
}

class OrderItem {
  final int id;
  final int orderId;
  final int productVariantId;
  final int? sellerId;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String status;
  final String dealer_status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // UI için yardımcı alanlar
  final ProductVariant? productVariant;
  final Seller? seller;

  // ürün adı türetmesi (backend bazen product nested vermiyor)
  String get productTitle {
    final vName = productVariant?.name;
    // Eğer ileride productVariant.product?.name gelirse burayı genişlet
    return vName?.isNotEmpty == true ? vName! : 'Ürün';
  }

  double get qtyCases => quantity.toDouble();

  OrderItem({
    required this.id,
    required this.orderId,
    required this.productVariantId,
    required this.sellerId,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.status,
    required this.dealer_status,
    required this.createdAt,
    required this.updatedAt,
    required this.productVariant,
    required this.seller,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) {
    final pvJson = j['product_variant'] ?? j['variant'] ?? {};
    final sellerJson = j['seller'];

    return OrderItem(
      id: asInt(j['id']),
      orderId: asInt(j['order_id']),
      productVariantId: asInt(j['product_variant_id']),
      sellerId: j['seller_id'] != null ? asInt(j['seller_id']) : null,
      quantity: asInt(j['quantity'] ?? j['qty']),
      unitPrice: asDouble(j['unit_price'] ?? j['price']),
      lineTotal: asDouble(j['total_price'] ?? j['line_total'] ?? j['total']),
      status: asString(j['status']).toLowerCase(),
      dealer_status: asString(j['dealer_status']).toLowerCase(),
      createdAt: parseDate(j['created_at']),
      updatedAt: parseDate(j['updated_at']),
      productVariant: pvJson is Map
          ? ProductVariant.fromJson(Map<String, dynamic>.from(pvJson))
          : null,
      seller: (sellerJson is Map)
          ? Seller.fromJson(Map<String, dynamic>.from(sellerJson))
          : null,
    );
  }
}

class ProductVariant {
  final int id;
  final int? productId;
  final String name;
  final bool active;
  final double averagePrice;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProductVariant({
    required this.id,
    required this.productId,
    required this.name,
    required this.active,
    required this.averagePrice,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> j) {
    return ProductVariant(
      id: asInt(j['id']),
      productId: j['product_id'] != null ? asInt(j['product_id']) : null,
      name: asString(j['name']),
      active: asBool(j['active']),
      averagePrice: asDouble(j['average_price'] ?? j['price']),
      createdAt: parseDate(j['created_at']),
      updatedAt: parseDate(j['updated_at']),
    );
  }
}

class Seller {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? address;

  Seller({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.address,
  });

  factory Seller.fromJson(Map<String, dynamic> j) {
    return Seller(
      id: asInt(j['id']),
      name: asString(j['name']),
      email: asString(j['email']),
      phone: j['phone']?.toString(),
      address: j['address']?.toString(),
    );
  }
}
