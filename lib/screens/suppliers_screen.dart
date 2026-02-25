// lib/screens/suppliers_screen.dart
import 'package:flutter/material.dart';
import 'package:haldeki_admin_web/models/paginated.dart';
import '../services/api_client.dart';
import '../models/supplier.dart';

class SuppliersScreen extends StatefulWidget {
  final ApiClient api;
  const SuppliersScreen({super.key, required this.api});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _search = TextEditingController();
  int _page = 1;
  bool _loading = false;
  Paginated<Supplier>? _p;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<String?> _askText(
    BuildContext ctx, {
    required String title,
    required String label,
    String? initial,
  }) async {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirm(BuildContext ctx, String msg) {
    return showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Onay'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hayır'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet'),
          ),
        ],
      ),
    );
  }

  Future<void> _load({int page = 1}) async {
    setState(() => _loading = true);
    try {
      final q = _search.text.trim();
      final p = await widget.api.suppliers(
        q: q.isEmpty ? null : q,
        page: page,
      );
      setState(() {
        _page = page;
        _p = p;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Liste alınamadı: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _newSupplier() async {
    final name = await _askText(context, title: 'Yeni Bayi', label: 'Ad');
    if (name == null || name.trim().isEmpty) return;
    try {
      await widget.api.createSupplier(SupplierCreate(name: name.trim()));
      await _load(page: 1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaydetme hatası: $e')),
        );
      }
    }
  }

  Future<void> _editSupplier(Supplier s) async {
    final name =
        await _askText(context, title: 'Bayi Düzenle', label: 'Ad', initial: s.name);
    if (name == null || name.trim().isEmpty) return;
    try {
      await widget.api.updateSupplier(s.id, SupplierUpdate(name: name.trim()));
      await _load(page: _page);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Güncelleme hatası: $e')),
        );
      }
    }
  }

  Future<void> _deleteSupplier(Supplier s) async {
    final ok = await _confirm(context, '“${s.name}” silinsin mi?');
    if (ok != true) return;
    try {
      await widget.api.deleteSupplier(s.id);
      await _load(page: 1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Silme hatası: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _p?.data ?? [];

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Ara...',
                  ),
                  onSubmitted: (_) => _load(page: 1),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _newSupplier,
                icon: const Icon(Icons.add),
                label: const Text('Yeni'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _load(page: _page),
                    child: rows.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(child: Text('Kayıt bulunamadı')),
                            ],
                          )
                        : ListView.separated(
                            itemCount: rows.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final s = rows[i];
                              return ListTile(
                                title: Text(s.name),
                                subtitle: Text(
                                  [s.email, s.phone]
                                      .where((e) => (e ?? '').isNotEmpty)
                                      .join(' · '),
                                ),
                                trailing: Wrap(
                                  spacing: 8,
                                  children: [
                                    IconButton(
                                      onPressed: () => _editSupplier(s),
                                      icon: const Icon(Icons.edit),
                                      tooltip: 'Düzenle',
                                    ),
                                    IconButton(
                                      onPressed: () => _deleteSupplier(s),
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: 'Sil',
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
          ),
          if (_p != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _page > 1 ? () => _load(page: _page - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${_p!.currentPage}/${_p!.lastPage}'),
                IconButton(
                  onPressed: _page < _p!.lastPage ? () => _load(page: _page + 1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
