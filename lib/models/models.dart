import 'dart:convert';

class ProductDto {
  final int id;
  final String name;
  final bool active;

  ProductDto({required this.id, required this.name, required this.active});

  factory ProductDto.fromJson(Map<String, dynamic> j) => ProductDto(
        id: j['id'] as int,
        name: j['name'] as String? ?? '-',
        active: (j['active'] == true || j['active'] == 1),
      );
}

class VariantDto {
  final int id;
  final String name;
  final bool active;

  VariantDto({required this.id, required this.name, required this.active});

  factory VariantDto.fromJson(Map<String, dynamic> j) => VariantDto(
        id: j['id'] as int,
        name: j['name'] as String? ?? '-',
        active: (j['active'] == true || j['active'] == 1),
      );
}

class PriceDto {
  final int id;
  final double price;
  final bool active;

  PriceDto({required this.id, required this.price, required this.active});

  factory PriceDto.fromJson(Map<String, dynamic> j) => PriceDto(
        id: j['id'] as int,
        price: (j['price'] is num)
            ? (j['price'] as num).toDouble()
            : double.tryParse(j['price'].toString()) ?? 0,
        active: (j['active'] == true || j['active'] == 1),
      );
}

class Country {
  final int id;
  final String name;
  Country({required this.id, required this.name});
  factory Country.fromJson(Map<String, dynamic> j) =>
      Country(id: j['id'] as int, name: j['name'] as String);
}

// models/city.dart  -> "şehir" = country-list'ten geliyor
class City {
  final int id;
  final String name;

  City({required this.id, required this.name});

  factory City.fromJson(Map<String, dynamic> j) => City(
        id: _asInt(j['id']),
        name: (j['name'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

// models/district.dart -> "ilçe" = city-list'ten geliyor
class District {
  final int id;
  final String name;
  final int countryId; // bağlı olduğu şehir id'si
  final String? countryName; // opsiyonel: İZMİR, ANKARA vs.

  District({
    required this.id,
    required this.name,
    required this.countryId,
    this.countryName,
  });

  factory District.fromJson(Map<String, dynamic> j) => District(
        id: _asInt(j['id']),
        name: (j['name'] ?? '').toString(),
        countryId: _asInt(j['country_id']),
        countryName: j['country_name']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'country_id': countryId,
        if (countryName != null) 'country_name': countryName,
      };
}

// küçük yardımcı
int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

class UserMinimal {
  final int id;
  final String name;
  final String type; // delivery_man | client
  UserMinimal({required this.id, required this.name, required this.type});
  factory UserMinimal.fromJson(Map<String, dynamic> j) => UserMinimal(
        id: (j['id'] ?? j['user_id']) as int,
        name: (j['name'] ?? '') as String,
        type: (j['user_type'] ?? '') as String,
      );
}

class Wallet {
  final int userId;
  final num balance;
  Wallet({required this.userId, required this.balance});
  factory Wallet.fromJson(Map<String, dynamic> j) =>
      Wallet(userId: j['user_id'] as int, balance: (j['balance'] ?? 0) as num);
}

/// Küçük yardımcı
T decode<T>(String src, T Function(Map<String, dynamic>) f) {
  final m = jsonDecode(src) as Map<String, dynamic>;
  return f(m);
}
