import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:haldeki_admin_web/utils/message_screen.dart';
import 'package:provider/provider.dart'; // <-- Önemli: Provider

import '../models/cart.dart';
import '../widgets/qty_stepper.dart';
import '../utils/format.dart';
import '../services/order_api.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});
  static const double minimumOrder = 2000.0;

  // --- API'ye gönder (örnek sabit restoran bilgileriyle)
  Future<void> _sendOrderRestaurant(BuildContext context, Cart cart) async {
    if (cart.items.isEmpty) return;

    if (cart.total < CartScreen.minimumOrder) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MessageScreen(
            title: 'Uyarı',
            message: 'Minimum sipariş tutarı ${tl(CartScreen.minimumOrder)}.',
          ),
        ),
      );
      return;
    }

    // Sabit bilgiler (form yoksa)
    const String _name = 'Deneme Restoran';
    const String _email = 'bayi@bayi.com';
    const String _phone = '+905551112233';
    const String _address = 'Pendik / İstanbul';

    // payload
    final payloadItems = cart.items.map<Map<String, dynamic>>((it) {
      final double unit = it.unitPrice;
      final int qty =
          (it.qtyCases is int) ? it.qtyCases as int : (it.qtyCases).round();
      final double total = it.lineTotal;

      return {
        'product_variant_id': it.variant.id,
        'quantity': qty,
        'unit_price': double.parse(unit.toStringAsFixed(2)),
        'total_price': double.parse(total.toStringAsFixed(2)),
      };
    }).toList();

    try {
      // basit loading göstermek için SnackBar kullanıyoruz
      final loading = ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sipariş gönderiliyor…')),
      );

      final data = await OrderApiDio.I.createOrderRestaurant(
        name: _name,
        email: _email,
        phone: _phone,
        address: _address,
        items: payloadItems,
        totalAmount: double.parse(cart.total.toStringAsFixed(2)),
        note: 'işletme web / sepet',
      );

      loading.close();

      final orderNo =
          (data['order_number'] ?? data['number'] ?? data['code'] ?? '')
              .toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(orderNo.isEmpty
                ? 'Sipariş oluşturuldu'
                : 'Sipariş oluşturuldu: $orderNo')),
      );

      // İstersen başarı sonrası sepeti boşalt / yönlendir
      // cart.clear();
      // if (orderNo.isNotEmpty) context.go('/orders/$orderNo');
    } catch (e) {
      final msg = kIsWeb
          ? 'İstek başarısız. (Muhtemel CORS) — sunucuda Access-Control-Allow-Origin gerekli.\nHata: $e'
          : 'Hata: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>(); // <-- Cart değişince rebuild
    final items =
        cart.items.toList(); // UnmodifiableListView ise toList() opsiyonel
    final isEmpty = items.isEmpty;
    final total = cart.total;
    final belowMin = total < CartScreen.minimumOrder;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Üst bar
          Row(
            children: [
              Expanded(
                child: Text(
                  isEmpty
                      ? 'Sepet boş'
                      : 'Sepet (${items.length} kalem) • Toplam: ${tl(total)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (!isEmpty)
                TextButton.icon(
                  onPressed: () {
                    cart.clear(); // notifyListeners tetikler
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sepet temizlendi')),
                    );
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Sepeti Temizle'),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // İçerik
          if (isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shopping_cart_outlined, size: 64),
                    const SizedBox(height: 8),
                    const Text('Sepetiniz boş. Marketten ürün ekleyin.'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/market'),
                      icon: const Icon(Icons.store_mall_directory_outlined),
                      label: const Text('Markete Git'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final it = items[i];
                  final p = it.product;
                  final v = it.variant;

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    title: Text(p.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(_variantSubtitle(it)),
                    leading: IconButton(
                      tooltip: 'Kaldır',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        cart.removeLine(p,
                            v); // Cart sınıfında var (yoksa cart.remove(...) kullan)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('${p.name} • ${v.name} kaldırıldı')),
                        );
                      },
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tl(it.lineTotal)),
                        const SizedBox(width: 16),
                        QtyStepper(
                          value: it.qtyCases,
                          onChanged: (val) {
                            if (val <= 0) {
                              cart.removeLine(p, v);
                            } else {
                              cart.setQty(p, v, val);
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          const Divider(),

          if (!isEmpty && belowMin)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Minimum sipariş tutarı: ${tl(CartScreen.minimumOrder)}. '
                'Devam etmek için ${tl(CartScreen.minimumOrder - total)} daha ekleyin.',
              ),
            ),

          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Toplam: ${tl(total)}'),
                ),
              ),
              FilledButton.icon(
                onPressed: (!isEmpty && !belowMin)
                    ? () => _sendOrderRestaurant(context, cart)
                    : null,
                icon: const Icon(Icons.check),
                label: const Text('Sepeti Kaydet (API)'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _variantSubtitle(CartItem it) {
    final v = it.variant;
    final base = '${v.name} • ${tl(it.unitPrice)} / ${it.unitLabel}';
    try {
      final dyn = v as dynamic;
      final kgpc = dyn.approxKgPerCase;
      if (kgpc is num && kgpc > 0) {
        return '$base • ~${kgpc.toStringAsFixed(0)} kg/koli';
      }
    } catch (_) {}
    return base;
  }
}
