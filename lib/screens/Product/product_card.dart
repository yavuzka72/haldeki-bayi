import 'package:flutter/material.dart';

import 'package:haldeki_admin_web/config.dart';
import 'package:haldeki_admin_web/models/product.dart';
import 'package:haldeki_admin_web/screens/Product/market_controller.dart';

class ProductCard extends StatelessWidget {
  final MarketController c;
  final Product item;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.c,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final selected = c.selectedProduct?.id == item.id;
    final img = (item.image ?? '').toString();
    final imageUrl = img.startsWith('http') ? img : AppConfig.imageUrl(img);

    /// ✅ TEK KAYNAK: controller
    final info = c.cardMinPriceWithUnit(item);

    final priceText = info == null
        ? 'Fiyat girilmedi'
        : 'En düşük: ₺ ${info.price.toStringAsFixed(2)} / ${info.unit}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withOpacity(.08) : cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? cs.primary.withOpacity(.65) : cs.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 18,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
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
            ),
            const SizedBox(height: 10),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),

            // ✅ mevcut: en düşük fiyat satırı
            Row(
              children: [
                Icon(Icons.sell_outlined, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: info == null ? cs.onSurfaceVariant : cs.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            // ✅ yeni: chip'ler
            const SizedBox(height: 10),
            _buildVariantChips(context, selected: selected),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantChips(BuildContext context, {required bool selected}) {
    final cs = Theme.of(context).colorScheme;

    final variants = c.variantsFor(item).where((v) => v.price > 0).toList();
    if (variants.isEmpty) return const SizedBox.shrink();

    variants.sort((a, b) => a.price.compareTo(b.price));

    const maxShow = 4;
    final extraCount =
        variants.length > maxShow ? (variants.length - maxShow) : 0;
    final show = variants.take(maxShow).toList();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...show.map((v) {
          final unitRaw = v.name.trim().isEmpty ? 'ADET' : v.name.trim();
          final unit = _prettyUnit(unitRaw);
          final icon = _unitIcon(unitRaw);

          return _HoverChip(
            active: selected, // card seçiliyse chip daha “aktif”
            child: _VariantChip(
              icon: icon,
              unit: unit,
              price: v.price,
            ),
          );
        }),
        if (extraCount > 0)
          _HoverChip(
            active: selected,
            child: _MoreChip(count: extraCount),
          ),
      ],
    );
  }

  /// Kart içinde: küçük chip'ler (KG ₺75 gibi)
  Widget _buildVariantChips23(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final variants = c.variantsFor(item).where((v) => v.price > 0).toList();
    if (variants.isEmpty) return const SizedBox.shrink();

    // En ucuzdan pahalıya
    variants.sort((a, b) => a.price.compareTo(b.price));

    // En fazla 4 tane
    final show = variants.take(4).toList();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: show.map((v) {
        final unit = v.name.trim().isEmpty ? 'ADET' : v.name.trim();

        return Container(
          width: 68, // 🔽 küçüldü
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: cs.primary.withOpacity(.55),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                unit,
                style: TextStyle(
                  fontSize: 11, // 🔽 küçüldü
                  fontWeight: FontWeight.w900,
                  color: cs.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                '₺${v.price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 10, // 🔽 küçüldü
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Kart içinde: "1 KG / ₺ 75.00" gibi chip kutuları
  Widget _buildVariantChips2(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final variants = c.variantsFor(item).where((v) => v.price > 0).toList();
    if (variants.isEmpty) return const SizedBox.shrink();

    // En ucuzdan pahalıya
    variants.sort((a, b) => a.price.compareTo(b.price));

    // Çok kalabalık olmasın diye ilk 4 tanesini göster (istersen 6 yap)
    final show = variants.take(4).toList();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: show.map((v) {
        final unit = v.unit.trim().isEmpty ? 'ADET' : v.unit.trim();

        return Container(
          width: 92,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.primary.withOpacity(.60),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                unit,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: cs.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '₺ ${v.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

IconData _unitIcon(String unit) {
  final u = unit.trim().toUpperCase();

  // ağırlık
  if (u.contains('KG') || u.contains('GR') || u.contains('GRAM')) {
    return Icons.scale_outlined; // ⚖️
  }

  // koli / kasa / paket
  if (u.contains('KASA') ||
      u.contains('KOLI') ||
      u.contains('KOLİ') ||
      u.contains('PAKET')) {
    return Icons.inventory_2_outlined; // 📦
  }

  // demet / bağ
  if (u.contains('DEMET') || u.contains('BAĞ') || u.contains('BAG')) {
    return Icons.local_florist_outlined; // 🧺/🌿 hissi
  }

  // adet vs
  return Icons.tag_outlined; // 🔢/etiket
}

String _prettyUnit(String unit) {
  final u = unit.trim().toUpperCase();
  // istersen burada “Kasa (15 KG)” gibi isimler de gelebilir; aynen bırakıyoruz.
  return u;
}

/// CHIP görünümü (küçük, iki satırlı)
class _VariantChip extends StatelessWidget {
  final IconData icon;
  final String unit;
  final double price;

  const _VariantChip({
    required this.icon,
    required this.unit,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 86,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withOpacity(.45), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(height: 2),
          Text(
            unit,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: cs.primary,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            '₺${price.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: cs.onSurfaceVariant,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// +3 chip’i
class _MoreChip extends StatelessWidget {
  final int count;
  const _MoreChip({required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 70,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Center(
        child: Text(
          '+$count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: cs.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Hover + Active efekti (web’de hover, her yerde active)
class _HoverChip extends StatefulWidget {
  final Widget child;
  final bool active;

  const _HoverChip({required this.child, required this.active});

  @override
  State<_HoverChip> createState() => _HoverChipState();
}

class _HoverChipState extends State<_HoverChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final on = widget.active || _hover;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: on
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(.06),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  )
                ]
              : const [],
        ),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: on ? 1.02 : 1.0,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              on ? cs.primary.withOpacity(.03) : Colors.transparent,
              BlendMode.srcATop,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
