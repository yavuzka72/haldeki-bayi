import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/variant.dart'; // 👈 gerekli
import '../utils/format.dart'; // tl(...) için

class ProductCard extends StatefulWidget {
  final Product product;
  final void Function(Product product, ProductVariant variant) onAdd;

  const ProductCard({
    super.key,
    required this.product,
    required this.onAdd,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  ProductVariant? _selected;

  @override
  void initState() {
    super.initState();
    // Modelde defaultVariant varsa onu, yoksa ilk varyantı seç
    final v = widget.product.variants;
    _selected = v.isNotEmpty ? v.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final cs = Theme.of(context).colorScheme;
    final hasVariants = p.variants.isNotEmpty;

    return Card(
      elevation: .5,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Görsel alanı
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: _buildImage(p.image),
              ),
            ),

            const SizedBox(height: 8),

            // Başlık
            Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),

            const SizedBox(height: 8),

            // Varyant seçimi
            if (hasVariants && p.variants.length > 1)
              DropdownButtonFormField<ProductVariant>(
                value: _selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Varyant',
                  isDense: true,
                ),
                items: [
                  for (final v in p.variants)
                    DropdownMenuItem(
                      value: v,
                      child: Text('${v.name} • ${_priceLabel(v)}'),
                    ),
                ],
                onChanged: (v) => setState(() => _selected = v),
              )
            else if (hasVariants && p.variants.length == 1)
              // Tek varyant — bilgi çipi
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(.35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.category_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            '${p.variants.first.name} • ${_priceLabel(p.variants.first)}')),
                  ],
                ),
              )
            else
              // Varyant yok
              Text('Varyant yok', style: TextStyle(color: cs.onSurfaceVariant)),

            const SizedBox(height: 8),

            // Sepete Ekle
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_selected == null)
                    ? null
                    : () => widget.onAdd(p, _selected!),
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(
                  _selected == null
                      ? 'Stok yok'
                      : 'Sepete Ekle • ${_priceLabel(_selected!)}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Yardımcılar ---

  String _priceLabel(ProductVariant v) {
    // Örn: "₺45,00 / kg" veya "₺12,50 / adet"
    final unit = (v.unit.isEmpty) ? 'adet' : v.unit;
    return '${tl(v.price)} / $unit';
  }

  Widget _buildImage(String emojiOrUrl) {
    // URL ise görsel, değilse emoji
    // if (emojiOrUrl.startsWith('https://api.haldeki.com//storage/') || emojiOrUrl.startsWith('https://api.haldeki.com//storage/')) {
    if (emojiOrUrl.startsWith('https://api.haldeki.com/') ||
        emojiOrUrl.startsWith('https://api.haldeki.com/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child:
            Image.network(emojiOrUrl, width: 72, height: 72, fit: BoxFit.cover),
      );
    }
    return Text(
      emojiOrUrl.isEmpty ? '🛒' : emojiOrUrl,
      style: const TextStyle(fontSize: 42),
    );
  }
}
