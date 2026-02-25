class Courier {
  final int id;
  final String name;
  final String phone;
  final String createdAt;
  final bool isActive;
  final double balance;

  Courier({
    required this.id,
    required this.name,
    required this.phone,
    required this.createdAt,
    required this.isActive,
    required this.balance,
  });

  factory Courier.fromJson(Map<String, dynamic> j) => Courier(
        id: j['id'] as int,
        name: j['ad_soyad'] as String,
        phone: j['telefon'] as String,
        createdAt: j['kayit_tarihi'] as String,
        isActive: (j['durum'] as String).toLowerCase().contains('aktif'),
        balance: (j['bakiye'] as num?)?.toDouble() ?? 0.0,
      );
}

class CourierLite {
  final int id;
  final String name;
  final String phone;
  final double balance;
  final bool deleted;
  const CourierLite({
    required this.id,
    required this.name,
    required this.phone,
    this.balance = 0.0,
    this.deleted = false,
  });
}
