// lib/models/cash_report_models.dart

// JSON -> double / int helper'ları
double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

/// API'nin döndüğü genel response
///
/// {
///   "date_from": "2025-11-01",
///   "date_to": "2025-11-16",
///   "dealer_id": "24",
///   "courier_id": null,
///   "daily": [ ... ],
///   "customers": [ ... ],
///   "suppliers": [ ... ],
///   "couriers": [ ... ],
///   "vendors": [ ... ]
/// }
class CashReportResponse {
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int? dealerId;
  final int? courierId;

  final List<DailyCashDay> dailyCash;
  final List<CustomerCollectionRow> customerCollections;
  final List<SupplierPaymentRow> supplierPayments;
  final List<CourierPaymentRow> courierPayments;
  final List<VendorCommissionRow> vendorCommissions;
  final CashSummary? summary;
  final List<SourceBreakdownRow> sourceBreakdown;

  CashReportResponse({
    required this.dateFrom,
    required this.dateTo,
    required this.dealerId,
    required this.courierId,
    required this.dailyCash,
    required this.customerCollections,
    required this.supplierPayments,
    required this.courierPayments,
    required this.vendorCommissions,
    required this.summary,
    required this.sourceBreakdown,
  });

  factory CashReportResponse.fromJson(Map<String, dynamic> json) {
    final root = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;

    List<T> _parseList<T>(
      String key,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      final raw = root[key];
      if (raw is List) {
        return raw
            .map<T>((e) => fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return <T>[];
    }

    List<T> _parseFirstList<T>(
      List<String> keys,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      for (final key in keys) {
        final list = _parseList<T>(key, fromJson);
        if (list.isNotEmpty) return list;
      }
      return <T>[];
    }

    DateTime? _parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    int? _parseIntNullable(dynamic v) {
      if (v == null) return null;
      return int.tryParse(v.toString());
    }

    CashSummary? _parseSummary() {
      final raw = root['summary'];
      if (raw is Map<String, dynamic>) return CashSummary.fromJson(raw);
      if (raw is Map) {
        return CashSummary.fromJson(Map<String, dynamic>.from(raw));
      }
      return null;
    }

    return CashReportResponse(
      dateFrom: _parseDate(root['date_from']),
      dateTo: _parseDate(root['date_to']),
      dealerId: _parseIntNullable(root['dealer_id']),
      courierId: _parseIntNullable(root['courier_id']),
      dailyCash: _parseFirstList(
        ['daily', 'daily_cash'],
        (m) => DailyCashDay.fromJson(m),
      ),
      customerCollections: _parseFirstList(
        ['customers', 'customer_collections'],
        (m) => CustomerCollectionRow.fromJson(m),
      ),
      supplierPayments: _parseFirstList(
        ['suppliers', 'supplier_payments'],
        (m) => SupplierPaymentRow.fromJson(m),
      ),
      courierPayments: _parseFirstList(
        ['couriers', 'courier_payments'],
        (m) => CourierPaymentRow.fromJson(m),
      ),
      vendorCommissions: _parseFirstList(
        ['vendors', 'vendor_commissions', 'businesses'],
        (m) => VendorCommissionRow.fromJson(m),
      ),
      summary: _parseSummary(),
      sourceBreakdown: _parseFirstList(
        ['source_breakdown', 'sourceBreakdown'],
        (m) => SourceBreakdownRow.fromJson(m),
      ),
    );
  }
}

class CashSummary {
  final double commissionRate;
  final double courierPackageFee;
  final double orderTotal;
  final double ecommerceTotal;
  final double businessTotal;
  final double commissionTotal;
  final double hakedisTotal;
  final int courierOrderCount;
  final double courierPaymentTotal;
  final double netTotal;

  CashSummary({
    required this.commissionRate,
    required this.courierPackageFee,
    required this.orderTotal,
    required this.ecommerceTotal,
    required this.businessTotal,
    required this.commissionTotal,
    required this.hakedisTotal,
    required this.courierOrderCount,
    required this.courierPaymentTotal,
    required this.netTotal,
  });

  factory CashSummary.fromJson(Map<String, dynamic> json) {
    final rawRate = _toDouble(json['commission_rate'] ?? json['komisyon_orani']);
    final normalizedRate = rawRate > 1 ? rawRate / 100 : rawRate;

    return CashSummary(
      commissionRate: normalizedRate,
      courierPackageFee:
          _toDouble(json['courier_package_fee'] ?? json['courier_fee'] ?? 0),
      orderTotal: _toDouble(
        json['order_total'] ??
            json['ciro_total'] ??
            json['customer_collections_total'],
      ),
      ecommerceTotal:
          _toDouble(json['ecommerce_total'] ?? json['ecommerce_amount']),
      businessTotal:
          _toDouble(json['business_total'] ?? json['business_amount']),
      commissionTotal: _toDouble(
        json['commission_total'] ?? json['vendor_commissions_total'],
      ),
      hakedisTotal: _toDouble(
        json['hakedis_total'] ?? json['vendor_commissions_total'],
      ),
      courierOrderCount: _toInt(json['courier_order_count']),
      courierPaymentTotal: _toDouble(
        json['courier_payment_total'] ?? json['courier_payments_total'],
      ),
      netTotal: _toDouble(json['net_total'] ?? json['net_cash_total']),
    );
  }
}

class SourceBreakdownRow {
  final String source;
  final int orderCount;
  final double total;
  final double pct;

  SourceBreakdownRow({
    required this.source,
    required this.orderCount,
    required this.total,
    required this.pct,
  });

  factory SourceBreakdownRow.fromJson(Map<String, dynamic> json) {
    return SourceBreakdownRow(
      source: json['source']?.toString() ?? '-',
      orderCount: _toInt(json['order_count'] ?? json['count']),
      total: _toDouble(json['total'] ?? json['amount']),
      pct: _toDouble(json['pct'] ?? json['percentage']),
    );
  }
}

/// Günlük kasa satırı (vw_gunluk_kasa_ozet)
///
/// JSON örnek:
/// {
///   "tarih":"2025-11-05",
///   "dealer_id":24,
///   "bayi_adi":"A BAYİ",
///   "musteri_tahsilat":0,
///   "tedarikci_odeme":"4303.00",
///   "kurye_odeme":0,
///   "bayi_komisyonu":"0.00",
///   "gunluk_net_kasa":-4303
/// }
class DailyCashDay {
  final DateTime date;
  final int? dealerId;
  final String? dealerName;
  final double musteriTahsilat;
  final double tedarikciOdeme;
  final double kuryeOdeme;
  final double bayiKomisyonu;

  DailyCashDay({
    required this.date,
    required this.dealerId,
    required this.dealerName,
    required this.musteriTahsilat,
    required this.tedarikciOdeme,
    required this.kuryeOdeme,
    required this.bayiKomisyonu,
  });

  // Ekranda kullandığımız net kasa (istersen DB'den geleni de kullanabilirdin)
  double get netKasa =>
      musteriTahsilat - (tedarikciOdeme + kuryeOdeme + bayiKomisyonu);

  factory DailyCashDay.fromJson(Map<String, dynamic> json) {
    final dateStr = json['tarih'] ?? json['date'];
    return DailyCashDay(
      date:
          dateStr != null ? DateTime.parse(dateStr.toString()) : DateTime.now(),
      dealerId: _toInt(json['dealer_id']),
      dealerName: json['bayi_adi']?.toString(),
      musteriTahsilat:
          _toDouble(json['musteri_tahsilat'] ?? json['musteriTahsilat'] ?? 0),
      tedarikciOdeme:
          _toDouble(json['tedarikci_odeme'] ?? json['tedarikciOdeme'] ?? 0),
      kuryeOdeme: _toDouble(json['kurye_odeme'] ?? json['kuryeOdeme'] ?? 0),
      bayiKomisyonu:
          _toDouble(json['bayi_komisyonu'] ?? json['bayiKomisyonu'] ?? 0),
    );
  }
}

/// Müşteri tahsilat detay satırı (vw_musteri_tahsilat_detay)
///
/// JSON örnek:
/// {
///   "islem_tarihi":"2025-11-05",
///   "dealer_id":24,
///   "bayi_adi":"A BAYİ",
///   "delivery_order_id":412,
///   "kaynak_order_id":156,
///   "musteri_adi":null,
///   "siparis_tutari":2080,
///   "tahsil_edilen_tutar":0,
///   "odeme_durumu":"pending",
///   "siparis_durumu":"create"
/// }
class CustomerCollectionRow {
  final DateTime date;
  final int dealerId;
  final String dealerName;
  final int deliveryOrderId;
  final int sourceOrderId;
  final String code; // ekranda "Teslimat Kodu" olarak kullanacağız
  final String customerName;
  final double amount;
  final double collected;
  final String paymentStatus;
  final String orderStatus;

  CustomerCollectionRow({
    required this.date,
    required this.dealerId,
    required this.dealerName,
    required this.deliveryOrderId,
    required this.sourceOrderId,
    required this.code,
    required this.customerName,
    required this.amount,
    required this.collected,
    required this.paymentStatus,
    required this.orderStatus,
  });

  factory CustomerCollectionRow.fromJson(Map<String, dynamic> json) {
    final dateStr = json['islem_tarihi'] ?? json['tarih'] ?? json['date'];

    final deliveryId = _toInt(json['delivery_order_id']);
    final sourceId = _toInt(json['kaynak_order_id']);

    // JSON'da "teslimat_kodu" yok, o yüzden delivery_order_id'yi kod gibi gösterelim
    final code =
        json['teslimat_kodu']?.toString() ?? 'DO-${deliveryId.toString()}';

    return CustomerCollectionRow(
      date:
          dateStr != null ? DateTime.parse(dateStr.toString()) : DateTime.now(),
      dealerId: _toInt(json['dealer_id']),
      dealerName: json['bayi_adi']?.toString() ?? '',
      deliveryOrderId: deliveryId,
      sourceOrderId: sourceId,
      code: code,
      customerName: json['musteri_adi']?.toString() ?? '',
      amount: _toDouble(json['siparis_tutari'] ?? json['amount'] ?? 0),
      collected:
          _toDouble(json['tahsil_edilen_tutar'] ?? json['collected'] ?? 0),
      paymentStatus: json['odeme_durumu']?.toString() ??
          json['payment_status']?.toString() ??
          'unknown',
      orderStatus: json['siparis_durumu']?.toString() ??
          json['order_status']?.toString() ??
          'unknown',
    );
  }
}

/// Tedarikçi ödeme satırı (vw_tedarikci_odeme_detay)
class SupplierPaymentRow {
  final DateTime date;
  final int dealerId;
  final String dealerName;
  final int orderId;
  final String code;
  final String supplierName;
  final double amount;
  final double payable;
  final String status;
  final String paymentStatus;

  SupplierPaymentRow({
    required this.date,
    required this.dealerId,
    required this.dealerName,
    required this.orderId,
    required this.code,
    required this.supplierName,
    required this.amount,
    required this.payable,
    required this.status,
    required this.paymentStatus,
  });

  factory SupplierPaymentRow.fromJson(Map<String, dynamic> json) {
    final dateStr = json['islem_tarihi'] ?? json['tarih'] ?? json['date'];

    return SupplierPaymentRow(
      date:
          dateStr != null ? DateTime.parse(dateStr.toString()) : DateTime.now(),
      dealerId: _toInt(json['dealer_id']),
      dealerName: json['bayi_adi']?.toString() ?? '',
      orderId: _toInt(json['order_id']),
      code: json['siparis_kodu']?.toString() ?? '',
      supplierName: json['tedarikci_adi']?.toString() ?? '',
      amount: _toDouble(json['siparis_tutari'] ?? json['amount'] ?? 0),
      payable:
          _toDouble(json['tedarikci_odeme_tutari'] ?? json['payable'] ?? 0),
      status: json['siparis_durumu']?.toString() ?? '',
      paymentStatus: json['odeme_durumu']?.toString() ??
          json['payment_status']?.toString() ??
          'unknown',
    );
  }
}

/// Kurye ödeme satırı (vw_kurye_odeme_detay)
class CourierPaymentRow {
  final DateTime date;
  final int dealerId;
  final String dealerName;
  final int deliveryOrderId;
  final int sourceOrderId;
  final String code;
  final String courierName;
  final double amount;
  final double courierPayment;
  final String status;
  final String paymentStatus;

  CourierPaymentRow({
    required this.date,
    required this.dealerId,
    required this.dealerName,
    required this.deliveryOrderId,
    required this.sourceOrderId,
    required this.code,
    required this.courierName,
    required this.amount,
    required this.courierPayment,
    required this.status,
    required this.paymentStatus,
  });

  factory CourierPaymentRow.fromJson(Map<String, dynamic> json) {
    final dateStr = json['islem_tarihi'] ?? json['tarih'] ?? json['date'];
    final deliveryId = _toInt(json['delivery_order_id']);
    final sourceId = _toInt(json['kaynak_order_id']);

    final code =
        json['teslimat_kodu']?.toString() ?? 'DO-${deliveryId.toString()}';

    return CourierPaymentRow(
      date:
          dateStr != null ? DateTime.parse(dateStr.toString()) : DateTime.now(),
      dealerId: _toInt(json['dealer_id']),
      dealerName: json['bayi_adi']?.toString() ?? '',
      deliveryOrderId: deliveryId,
      sourceOrderId: sourceId,
      code: code,
      courierName: json['kurye_adi']?.toString() ?? '',
      amount: _toDouble(json['siparis_tutari'] ?? json['amount'] ?? 0),
      courierPayment:
          _toDouble(json['kurye_odeme_tutari'] ?? json['courier_payment'] ?? 0),
      status: json['teslimat_durumu']?.toString() ??
          json['status']?.toString() ??
          '',
      paymentStatus: json['odeme_durumu']?.toString() ??
          json['payment_status']?.toString() ??
          'unknown',
    );
  }
}

/// Bayi komisyon satırı (vw_bayi_komisyon_detay)
class VendorCommissionRow {
  final DateTime date;
  final int dealerId;
  final String dealerName;
  final int orderId;
  final String code;
  final double amount;
  final double commission;
  final int? partnerClientId;
  final String businessName;
  final int orderCount;
  final double ciro;
  final double hakedis;
  final double commissionRate;
  final String status;
  final String paymentStatus;

  VendorCommissionRow({
    required this.date,
    required this.dealerId,
    required this.dealerName,
    required this.orderId,
    required this.code,
    required this.amount,
    required this.commission,
    required this.partnerClientId,
    required this.businessName,
    required this.orderCount,
    required this.ciro,
    required this.hakedis,
    required this.commissionRate,
    required this.status,
    required this.paymentStatus,
  });

  factory VendorCommissionRow.fromJson(Map<String, dynamic> json) {
    final dateStr = json['islem_tarihi'] ?? json['tarih'] ?? json['date'];

    return VendorCommissionRow(
      date:
          dateStr != null ? DateTime.parse(dateStr.toString()) : DateTime.now(),
      dealerId: _toInt(json['dealer_id']),
      dealerName: json['bayi_adi']?.toString() ?? '',
      orderId: _toInt(json['order_id']),
      code: json['siparis_kodu']?.toString() ?? '',
      amount: _toDouble(json['siparis_tutari'] ?? json['amount'] ?? 0),
      commission:
          _toDouble(json['bayi_komisyon_tutari'] ?? json['commission'] ?? 0),
      partnerClientId: json['partner_client_id'] == null
          ? null
          : _toInt(json['partner_client_id']),
      businessName: json['isletme_adi']?.toString() ??
          json['business_name']?.toString() ??
          '',
      orderCount: _toInt(json['siparis_adedi'] ?? json['order_count']),
      ciro: _toDouble(json['ciro'] ?? json['siparis_tutari'] ?? json['amount']),
      hakedis: _toDouble(
        json['hakedis'] ?? json['bayi_komisyon_tutari'] ?? json['commission'],
      ),
      commissionRate:
          _toDouble(json['komisyon_orani'] ?? json['commission_rate']),
      status: json['siparis_durumu']?.toString() ?? '',
      paymentStatus: json['odeme_durumu']?.toString() ??
          json['payment_status']?.toString() ??
          'unknown',
    );
  }
}
