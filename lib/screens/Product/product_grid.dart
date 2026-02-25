import 'package:flutter/material.dart';

import 'package:haldeki_admin_web/models/product.dart';
import 'package:haldeki_admin_web/screens/Product/market_controller.dart';

import 'product_card.dart';

class ProductGrid extends StatelessWidget {
  final MarketController c;
  final List<Product> items;
  final VoidCallback onLoadMore;
  final VoidCallback onOpenDetailSheetIfNeeded;

  const ProductGrid({
    super.key,
    required this.c,
    required this.items,
    required this.onLoadMore,
    required this.onOpenDetailSheetIfNeeded,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;

        int crossAxisCount = 2;
        if (w >= 1200)
          crossAxisCount = 4;
        else if (w >= 900) crossAxisCount = 3;

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels >= n.metrics.maxScrollExtent - 500) {
              onLoadMore();
            }
            return false;
          },
          child: GridView.builder(
            padding: const EdgeInsets.only(bottom: 8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final p = items[i];
              return ProductCard(
                c: c,
                item: p,
                onTap: () {
                  c.selectProduct(p);
                  onOpenDetailSheetIfNeeded();
                },
              );
            },
          ),
        );
      },
    );
  }
}
