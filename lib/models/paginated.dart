class Paginated<T> {
final List<T> data;
final int currentPage;
final int lastPage;
final int total;


Paginated({required this.data, required this.currentPage, required this.lastPage, required this.total});


factory Paginated.fromLaravel(Map<String, dynamic> m, T Function(Map<String, dynamic>) fromJson) {
final list = (m['data'] as List).cast<Map<String, dynamic>>();
return Paginated<T>(
data: list.map(fromJson).toList(),
currentPage: (m['current_page'] as num).toInt(),
lastPage: (m['last_page'] as num).toInt(),
total: (m['total'] as num).toInt(),
);
}
}