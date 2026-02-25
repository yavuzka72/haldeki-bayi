// lib/screens/market/market_screen.dart
import 'package:flutter/material.dart';
import 'package:haldeki_admin_web/screens/Product/market_controller.dart';
import 'package:haldeki_admin_web/screens/Product/product_detail_panel.dart';
import 'package:haldeki_admin_web/screens/Product/product_grid.dart';
import 'package:provider/provider.dart';

import 'package:haldeki_admin_web/screens/haldeki_ui.dart';
import 'package:haldeki_admin_web/services/api_client.dart';

class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ Primary'yi (0xFF062F22) garanti etmek için kendi scheme'imiz
    final cs = HaldekiUI.lightScheme(context);

    final themed = HaldekiUI.withRectButtons(context, cs).copyWith(
      scaffoldBackgroundColor: const Color(0xFFF6F7FB),

      // ✅ Net input (beyaz)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE6E8EF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE6E8EF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 1.8),
        ),
      ),

      // ✅ Kartlar net beyaz, temiz border
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(
              color: Colors.white, width: 1), // Fine white border
        ),
      ),

      // ✅ ChoiceChip / Chip sadeleşsin
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: cs.primary.withOpacity(.10),
        side: const BorderSide(color: Color(0xFFE6E8EF)),
        labelStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w800,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w900,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    return Theme(
      data: themed,
      child: ChangeNotifierProvider(
        create: (_) => MarketController(context.read<ApiClient>())..init(),
        child: const _MarketBody(),
      ),
    );
  }
}

class _MarketBody extends StatelessWidget {
  const _MarketBody();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<MarketController>();

    return LayoutBuilder(
      builder: (context, box) {
        final showRightDetail = box.maxWidth >= 900;

        void openDetailSheetIfNeeded() {
          final w = MediaQuery.of(context).size.width;
          if (w >= 900) return;
          if (c.selectedProduct == null) return;

          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: const Color(0xFFF6F7FB),
            builder: (_) {
              return SizedBox(
                height: MediaQuery.of(context).size.height * .88,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ProductDetailPanel(c: c),
                ),
              );
            },
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _topBar(context),
                    const SizedBox(height: 12),
                    c.loadingCats
                        ? const _MiniLoader()
                        : _categoriesBar(context),
                    const SizedBox(height: 12),
                    Expanded(
                      child: c.loadingProds
                          ? const Center(child: CircularProgressIndicator())
                          : c.products.isEmpty
                              ? const _EmptyState(
                                  icon: Icons.inventory_2_outlined,
                                  title: 'Ürün bulunamadı',
                                  subtitle:
                                      'Aramayı değiştir veya kategori seç.',
                                )
                              : ProductGrid(
                                  c: c,
                                  items: c.products,
                                  onLoadMore: () {
                                    if (!c.loadingMore && c.more) {
                                      c.fetchProducts(reset: false);
                                    }
                                  },
                                  onOpenDetailSheetIfNeeded:
                                      openDetailSheetIfNeeded,
                                ),
                    ),
                    if (c.loadingMore) ...[
                      const SizedBox(height: 10),
                      const _MiniLoader(),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
              if (showRightDetail) const SizedBox(width: 16),
              if (showRightDetail)
                SizedBox(width: 380, child: ProductDetailPanel(c: c)),
            ],
          ),
        );
      },
    );
  }

  Widget _topBar(BuildContext context) {
    final c = context.read<MarketController>();
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: const BorderSide(color: Color(0xFFE6E8EF)).toBorder(),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: c.search,
              decoration: const InputDecoration(
                hintText: 'Ürün ara…',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => c.fetchProducts(reset: true),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: () => c.fetchProducts(reset: true),
            icon: const Icon(Icons.search),
            label: const Text('Ara'),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Temizle',
            onPressed: () {
              c.search.clear();
              c.fetchProducts(reset: true);
            },
            icon:
                const Icon(Icons.backspace_outlined, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _categoriesBar(BuildContext context) {
    final c = context.watch<MarketController>();
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: const BorderSide(color: Color(0xFFE6E8EF)).toBorder(),
      ),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: c.cats.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              final selected = c.selectedCat == null;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Tümü'),
                  selected: selected,
                  selectedColor: cs.primary.withOpacity(.10),
                  side: const BorderSide(color: Color(0xFFE6E8EF)),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: selected ? cs.primary : const Color(0xFF64748B),
                  ),
                  onSelected: (_) {
                    c.selectedCat = null;
                    c.fetchProducts(reset: true);
                    c.notifyListeners();
                  },
                ),
              );
            }

            final cat = c.cats[i - 1];
            final selected = c.selectedCat == cat.id;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(cat.name),
                selected: selected,
                selectedColor: cs.primary.withOpacity(.10),
                side: const BorderSide(color: Color(0xFFE6E8EF)),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: selected ? cs.primary : const Color(0xFF64748B),
                ),
                onSelected: (_) {
                  c.selectedCat = selected ? null : cat.id;
                  c.fetchProducts(reset: true);
                  c.notifyListeners();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MiniLoader extends StatelessWidget {
  const _MiniLoader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 42,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
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
            Icon(icon, size: 46, color: const Color(0xFF64748B)),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// küçük yardımcı: BorderSide -> Border
extension _BorderSideX on BorderSide {
  Border toBorder() => Border.all(color: color, width: width);
}
