class Supplier {
final String? logoPath;

  var id;
  
  var name;
  
  var email;
  
  var phone;
  
  var address;
Supplier({required this.id, required this.name, this.email, this.phone, this.address, this.logoPath});
factory Supplier.fromJson(Map<String, dynamic> m) => Supplier(
id: (m['id'] as num).toInt(),
name: (m['name'] ?? '') as String,
email: m['email'] as String?,
phone: m['phone'] as String?,
address: m['address'] as String?,
logoPath: m['logo_path'] as String?,
);
}


class SupplierCreate {
final String name;
final String? email, phone, address, logo;
SupplierCreate({required this.name, this.email, this.phone, this.address, this.logo});
Map<String, dynamic> toJson() => {
'name': name,
if (email != null) 'email': email,
if (phone != null) 'phone': phone,
if (address != null) 'address': address,
if (logo != null) 'logo': logo,
};
}


class SupplierUpdate extends SupplierCreate {
SupplierUpdate({String? name, String? email, String? phone, String? address, String? logo})
: super(name: name ?? '', email: email, phone: phone, address: address, logo: logo);
@override
Map<String, dynamic> toJson() {
final m = <String, dynamic>{};
if (name.isNotEmpty) m['name'] = name;
if (email != null) m['email'] = email;
if (phone != null) m['phone'] = phone;
if (address != null) m['address'] = address;
if (logo != null) m['logo'] = logo;
return m;
}
}