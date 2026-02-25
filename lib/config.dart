// lib/config.dart
class AppConfig {
  /// Çalıştırırken override edebilirsin:
  /// flutter run -d chrome --dart-define=API_ORIGIN=https://staging.haldeki.com
  static const origin = String.fromEnvironment(
    'API_ORIGIN',
    // defaultValue: 'https://api.haldeki.com/',
    defaultValue:
        'https://api.haldeki.com/', //'https://api.haldeki.com/', localhost
  );

  static const siteBase =
      'https://api.haldeki.com/'; // 'https://api.haldeki.com/';
  static String imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final clean = path.startsWith('/') ? path.substring(1) : path;
    return '$siteBase/storage/$clean';
  }

  static const apiVersion = 'v1/';

  /// Tam taban URL (ör:https://api.haldeki.com//api/v1)
  static String get apiBase => '$origin/api/$apiVersion';
  static String get apiBasePartner => '$origin/api/partner/$apiVersion';

  // ---- Paths (BAŞINDA "/" YOK) ----
  static const String loginPath = 'login';
  static const String previousOrdersPath = 'previous-orders';

  static const String dealerOrdersPath = 'dealer-orders';
  static const String dealerOrdersPaending = 'dealer-orders-pending';
  static const dealerOrderDetailPath = 'dealer-order-detail'; // <-- eklendi

  static const String productsPath = 'products';

  static String approveOrderPath(String id) => 'orders/$id/approve';
  static String cancelOrderPath(String id) => 'orders/$id/cancel';
  static String readyOrderPath(String id) => 'orders/$id/ready';
  static String deliverOrderPath(String id) => 'orders/$id/deliver';

  // Ürün güncelleme / görsel / fiyat / varyantlar
  static String updateProductPath(String id) => 'products/$id';
  static String updateProductImagePath(String id) => 'products/$id/image';
  static const String updatePricePath = 'products/update-price';
  static String productVariantsPath(String id) => 'products/$id/variants';
  static String singleVariantPath(String variantId) => 'variants/$variantId';
  static const String createProductPath = 'products';
  static const String activeCouriersPath =
      'active-couriers'; // bunu backend'e bağla

  static const dealerOrdersDeliveryPath = 'dealer-orders-delivery';

  static const dealerOrderDetailDeliveryPath = 'dealer-order-detail-delivery';

  static const dealerOrderUpdateStatusDeliveryPath =
      'dealer-order-update-status-delivery';
}
