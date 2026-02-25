import 'package:flutter/material.dart';

/// ...build() içinde uygun yere koyabilirsiniz:
Widget buildFilterBar({
  required String? status,
  required ValueChanged<String?> onStatusChanged,
  required bool loading,
  required String? errorText,
  required int? selectedBusinessId,
  required ValueChanged<int?> onBusinessChanged,
  required List<Map<String, dynamic>> businesses,
}) {
  final statusField = ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
    child: DropdownButtonFormField<String?>(
      value: status,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Durum',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: const <DropdownMenuItem<String?>>[
        DropdownMenuItem<String?>(value: null, child: Text('Tümü')),
        DropdownMenuItem<String?>(value: 'pending', child: Text('pending')),
        DropdownMenuItem<String?>(value: 'completed', child: Text('completed')),
        DropdownMenuItem<String?>(value: 'delivered', child: Text('delivered')),
        DropdownMenuItem<String?>(value: 'cancelled', child: Text('cancelled')),
      ],
      onChanged: onStatusChanged,
    ),
  );

  final businessField = ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 240, maxWidth: 360),
    child: loading
        ? const _ShimmerBox(height: 44)
        : (errorText != null)
            ? Text(
                'İşletmeler yüklenemedi: $errorText',
                style: const TextStyle(color: Colors.red),
              )
            : DropdownButtonFormField<int?>(
                value: selectedBusinessId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'İşletme (opsiyonel)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<int?>(
                      value: null, child: Text('Tümü')),
                  ...businesses.map((b) {
                    final id = (b['id'] as num?)?.toInt();
                    final name = (b['name'] ?? '—').toString();
                    return DropdownMenuItem<int?>(value: id, child: Text(name));
                  }),
                ],
                onChanged: onBusinessChanged,
              ),
  );

  return Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
    child: Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        statusField,
        SizedBox(width: 280, child: businessField),
      ],
    ),
  );
}

/// Tarih label helper (istersen aynı dosyada kullan)
String labelForRange(DateTimeRange? r) {
  if (r == null) return 'Tarih Aralığı';
  String f(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  return '${f(r.start)} – ${f(r.end)}';
}

/// Basit shimmer kutu (placeholder)
class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({this.height = 16, this.width = double.infinity});
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEEF3),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
