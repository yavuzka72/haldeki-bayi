import 'package:flutter/material.dart';

import 'package:haldeki_admin_web/config.dart';
import 'package:haldeki_admin_web/models/product.dart';
import 'package:haldeki_admin_web/models/variant.dart';
import 'package:haldeki_admin_web/screens/Product/market_controller.dart';

class ProductDetailPanel extends StatelessWidget {
  final MarketController c;

  const ProductDetailPanel({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = c.selectedProduct;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: p == null
          ? const _EmptyState(
              icon: Icons.touch_app_outlined,
              title: 'Ürün seç',
              subtitle: 'Soldan bir ürün seçince detayları burada göreceksin.',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ürün Detayı',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Kapat',
                        onPressed: () {
                          c.selectedProduct = null;
                          c.notifyListeners();
                        },
                        icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: cs.outlineVariant),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _imageViewOnly(cs, p),
                        const SizedBox(height: 12),
                        Text(
                          p.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Varyantlar',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (c.isLoadingVariants(p)) ...[
                          Row(
                            children: const [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 10),
                              Text('Varyantlar yükleniyor…'),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        ...c
                            .variantsFor(p)
                            .map((v) => _variantReadOnlyRow(cs, v)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// ✅ SADECE GÖSTER: upload/choose/kaldır yok
  Widget _imageViewOnly(ColorScheme cs, Product p) {
    final img = (p.image ?? '').toString();
    final imageUrl = (img.isNotEmpty && img.startsWith('http'))
        ? img
        : AppConfig.imageUrl(img);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: cs.surfaceVariant.withOpacity(.6),
            child: Icon(
              Icons.image_not_supported_outlined,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  /// ✅ SADECE OKUNUR: fiyat düzenlenmez
  Widget _variantReadOnlyRow(ColorScheme cs, ProductVariant v) {
    final priceTxt = _formatPrice(v.price);
    final unitTxt = (v.unit ?? '').toString().trim().isEmpty ? '—' : v.unit!;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                /*     Text(
                  unitTxt,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                */
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Text(
              '₺ $priceTxt',
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double v) {
    // 12.3 -> 12,30 gibi basit TR format
    final s = v.toStringAsFixed(2);
    return s.replaceAll('.', ',');
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(18.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: cs.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
