// lib/widgets/reusable_pickers.dart
// Reusable bottom-sheet pickers: City, Product, Supplier
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/models/city_model.dart';
import 'package:wa_blast/models/supplier_model.dart';
import 'package:wa_blast/providers/purchase_provider.dart' hide Product;
import 'package:wa_blast/providers/product_provider.dart';
import 'package:wa_blast/models/product_model.dart';
import 'package:wa_blast/providers/store_provider.dart' hide City;

/// ------------------------------------------------------------------
/// GENERIC CORE
/// ------------------------------------------------------------------

/// Hasil picker yang reusable (bisa bawa payload aslinya di [data])
class PickerResult<T> {
  final String id;
  final String label;
  final String? subtitle;
  final T? data;
  const PickerResult({
    required this.id,
    required this.label,
    this.subtitle,
    this.data,
  });
}

typedef LoadItems<T> = Future<List<PickerResult<T>>> Function();

/// Tampilkan bottom sheet generic untuk memilih item
// tambahkan 2 argumen opsional: selectedId & isSelected
Future<PickerResult<T>?> showPickerSheet<T>(
  BuildContext context, {
  required String title,
  required LoadItems<T> loadItems,
  String searchHint = 'Search…',
  String emptyMessage = 'No data found',
  String? refreshTooltip = 'Refresh',

  // NEW:
  String? selectedId,
  bool Function(PickerResult<T> item)? isSelected,
}) {
  return showModalBottomSheet<PickerResult<T>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _GenericPickerSheet<T>(
      title: title,
      loadItems: loadItems,
      searchHint: searchHint,
      emptyMessage: emptyMessage,
      refreshTooltip: refreshTooltip,

      // NEW:
      selectedId: selectedId,
      isSelected: isSelected,
    ),
  );
}

class _GenericPickerSheet<T> extends StatefulWidget {
  const _GenericPickerSheet({
    required this.title,
    required this.loadItems,
    required this.searchHint,
    required this.emptyMessage,
    this.refreshTooltip,

    // NEW:
    this.selectedId,
    this.isSelected,
  });

  final String title;
  final LoadItems<T> loadItems;
  final String searchHint;
  final String emptyMessage;
  final String? refreshTooltip;

  // NEW:
  final String? selectedId;
  final bool Function(PickerResult<T> item)? isSelected;

  @override
  State<_GenericPickerSheet<T>> createState() => _GenericPickerSheetState<T>();
}

class _GenericPickerSheetState<T> extends State<_GenericPickerSheet<T>> {
  final _searchC = TextEditingController();
  List<PickerResult<T>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.loadItems();
      setState(() => _items = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchC.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _items
        : _items
              .where(
                (o) =>
                    o.label.toLowerCase().contains(q) ||
                    (o.subtitle ?? '').toLowerCase().contains(q),
              )
              .toList(growable: false);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (ctx, controller) {
        return Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: widget.refreshTooltip,
                    onPressed: _loading ? null : _fetch,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchC,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _fetch,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.emptyMessage,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 6), // compact
                  itemBuilder: (_, i) {
                    final item = filtered[i]; // <-- definisikan dulu

                    final selected =
                        widget.isSelected?.call(item) ??
                        (widget.selectedId != null &&
                            item.id == widget.selectedId);

                    return ListTile(
                      onTap: () => Navigator.pop(context, item),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: selected
                            ? const BorderSide(
                                color: Color(0xFF4C6EF5),
                                width: 1.5,
                              )
                            : BorderSide.none,
                      ),
                      selected: selected,
                      selectedTileColor: const Color(0xFFEFF4FF),
                      tileColor: Colors.white,
                      leading: Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: selected
                            ? const Color(0xFF4C6EF5)
                            : const Color(0xFF6B7280),
                      ),
                      title: Text(
                        item.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      subtitle: (item.subtitle?.isNotEmpty == true)
                          ? Text(
                              item.subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: selected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: Color(0xFF4C6EF5),
                            )
                          : const Icon(Icons.chevron_right_rounded, size: 20),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

/// ------------------------------------------------------------------
/// PUBLIC WIDGETS (field yang bisa dipakai di form)
/// ------------------------------------------------------------------

class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.placeholder,
    required this.onTap,
    this.value,
  });

  final String placeholder;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showValue = (value != null && value!.isNotEmpty);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F9FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                showValue ? value! : placeholder,
                style: TextStyle(
                  color: showValue
                      ? const Color(0xFF111827)
                      : const Color(0xFF9CA3AF),
                  fontWeight: showValue ? FontWeight.w600 : null,
                ),
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

/// Versi berlabel + validasi sederhana (mirip _SelectTile milikmu)
class SelectFieldTile extends StatelessWidget {
  const SelectFieldTile({
    super.key,
    required this.label,
    required this.valueText,
    required this.onTap,
    this.emptyHint = 'Select…',
    this.errorText,
  });

  final String label;
  final String? valueText;
  final String emptyHint;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasError = (errorText ?? '').isNotEmpty;
    final showValue = valueText != null && valueText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasError ? Colors.redAccent : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    showValue ? valueText! : emptyHint,
                    style: TextStyle(
                      color: showValue
                          ? const Color(0xFF111827)
                          : const Color(0xFF9CA3AF),
                      fontWeight: showValue ? FontWeight.w500 : null,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(errorText!, style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }
}

/// ------------------------------------------------------------------
/// CONVENIENCE WRAPPERS: CITY / SUPPLIER / PRODUCT
/// ------------------------------------------------------------------

/// City
Future<PickerResult<City>?> showCityPickerSheet(
  BuildContext context, {
  String? selectedId, // highlight city terpilih
}) async {
  final prov = context.read<PurchaseProvider>();
  if (prov.cities.isEmpty && !prov.loadingCities) {
    await prov.fetchCities(context);
  }

  return showPickerSheet<City>(
    context,
    title: 'Select City',
    searchHint: 'Search city or province…',
    emptyMessage: 'City list is empty',
    selectedId: selectedId,
    loadItems: () async {
      final list = context.read<PurchaseProvider>().cities;
      return list
          .map(
            (c) => PickerResult<City>(
              id: c.id, // <- String (bukan int)
              label: c.name,
              subtitle: (c.province.name.isNotEmpty)
                  ? c
                        .province
                        .name // <- ambil dari province.name
                  : null,
              data: c,
            ),
          )
          .toList(growable: false);
    },
  );
}

/// Supplier
Future<PickerResult<Supplier>?> showSupplierPickerSheet(
  BuildContext context, {
  String? selectedId, // NEW
}) async {
  final prov = context.read<PurchaseProvider>();
  if (prov.suppliers.isEmpty && !prov.loadingSuppliers) {
    await prov.fetchSuppliers(context);
  }

  return showPickerSheet<Supplier>(
    context,
    title: 'Select Supplier',
    searchHint: 'Search supplier…',
    emptyMessage: 'Supplier list is empty',
    selectedId: selectedId, // NEW
    loadItems: () async {
      final list = context.read<PurchaseProvider>().suppliers;
      return list
          .map(
            (s) => PickerResult<Supplier>(
              id: s.idSupplier,
              label: s.name,
              subtitle: [
                if ((s.city?.name ?? '').isNotEmpty) s.city!.name,
                if ((s.phone ?? '').isNotEmpty) s.phone!,
                if ((s.email ?? '').isNotEmpty) s.email!,
              ].join(' • ').replaceAll(RegExp(r'(^\s*•\s*|\s*•\s*$)'), ''),
              data: s,
            ),
          )
          .toList(growable: false);
    },
  );
}

/// Product
Future<PickerResult<Product>?> showProductPickerSheet(
  BuildContext context, {
  String? selectedId, // NEW
}) async {
  final p = context.read<ProductProvider>();
  if (p.products.isEmpty && !p.loadingProducts) {
    await p.fetchProducts(context);
  }

  String _subtitle(Product e) {
    final parts = <String>[];
    if ((e.productBrand?.name ?? '').isNotEmpty)
      parts.add(e.productBrand!.name);
    if ((e.productCategory?.name ?? '').isNotEmpty)
      parts.add(e.productCategory!.name);
    if (e.productSkus.isNotEmpty && e.productSkus.first.code.isNotEmpty) {
      parts.add('SKU: ${e.productSkus.first.code}');
    }
    return parts.join(' • ');
  }

  return showPickerSheet<Product>(
    context,
    title: 'Select Product',
    searchHint: 'Search product…',
    emptyMessage: 'Product list is empty',
    selectedId: selectedId, // NEW
    loadItems: () async {
      final list = context.read<ProductProvider>().products;
      return list
          .map(
            (e) => PickerResult<Product>(
              id: e.idProduct,
              label: e.name,
              subtitle: _subtitle(e),
              data: e,
            ),
          )
          .toList(growable: false);
    },
  );
}

//SKU
Future<PickerResult<ProductSku>?> showSkuPickerSheet(
  BuildContext context, {
  String? selectedId, // highlight sku terpilih
}) async {
  final p = context.read<ProductProvider>();
  if (p.products.isEmpty && !p.loadingProducts) {
    await p.fetchProducts(context);
  }

  String _primaryVariant(ProductSku sku) {
    if (sku.attributes.isNotEmpty) {
      final a = sku.attributes.first;
      final name = (a.name).trim();
      final val = (a.value).trim();
      if (name.isNotEmpty && val.isNotEmpty) return '$name: $val';
      if (val.isNotEmpty) return val;
      if (name.isNotEmpty) return name;
    }
    return ''; // kalau tak ada atribut
  }

  // flatten semua SKU dari semua product
  final items = <PickerResult<ProductSku>>[];
  for (final prod in p.products) {
    for (final sku in prod.productSkus) {
      final primaryVar = _primaryVariant(sku);
      items.add(
        PickerResult<ProductSku>(
          id: sku.idProductSku, // ← yang dipilih: skuId
          label: (sku.code.isNotEmpty
              ? sku.code
              : // judul baris
                primaryVar.isNotEmpty
              ? primaryVar
              : 'SKU'),
          subtitle: [
            prod.name, // Nama produk
            if (primaryVar.isNotEmpty) primaryVar, // 1 variant utama
          ].join(' • '),
          data: sku, // payload SKU
          // kalau ingin akses Product saat onTap, bisa taruh di .meta, tapi
          // untuk sederhana: cukup label/subtitle di atas sudah memuat nama product
        ),
      );
    }
  }

  // kalau tidak ada SKU sama sekali
  if (items.isEmpty) {
    return showPickerSheet<ProductSku>(
      context,
      title: 'Select SKU',
      searchHint: 'Search SKU or product…',
      emptyMessage: 'No SKU available.\nMake sure products & SKUs are loaded.',
      selectedId: selectedId,
      loadItems: () async => items,
    );
  }

  return showPickerSheet<ProductSku>(
    context,
    title: 'Select SKU',
    searchHint: 'Search SKU or product…',
    emptyMessage: 'No SKU found',
    selectedId: selectedId, // highlight
    // pencarian & render dilakukan oleh _GenericPickerSheet dari reusable picker
    loadItems: () async => items,
  );
}

/// Store Location
Future<PickerResult<StoreLocation>?> showStorePickerSheet(
  BuildContext context, {
  String? selectedId, // highlight store terpilih
}) async {
  final sp = context.read<StoreProvider>();

  // Pastikan list store sudah ter-fetch
  if (sp.stores.isEmpty && !sp.loadingList) {
    await sp.fetchStoreLocations(context);
  }

  String _subtitle(StoreLocation s) {
    final parts = <String>[];
    if ((s.business?.name ?? '').isNotEmpty) parts.add(s.business!.name);
    if ((s.city?.name ?? '').isNotEmpty) {
      // Jika ada province di modelmu: tampilkan "City, Province"
      final prov = s.city?.province?.name;
      parts.add(
        prov != null && prov.isNotEmpty
            ? '${s.city!.name}, $prov'
            : s.city!.name,
      );
    }
    return parts.join(' • ');
  }

  return showPickerSheet<StoreLocation>(
    context,
    title: 'Select Store Location',
    searchHint: 'Search store…',
    emptyMessage: 'Store list is empty',
    selectedId: selectedId,
    loadItems: () async {
      final list = context.read<StoreProvider>().stores;
      return list
          .map(
            (s) => PickerResult<StoreLocation>(
              id: s.idStoreLocation,
              label: s.name,
              subtitle: _subtitle(s),
              data: s,
            ),
          )
          .toList(growable: false);
    },
  );
}

/// NOTE:
/// - Ganti `ProductModel` dengan tipe produk milikmu (mis. `Product`), lalu adjust import di atas.
/// - Jika `idProduct` nullable, pastikan tidak ada yang kosong (atau handle di caller).

/// ------------------------------------------------------------------
/// SMALL UTILS (opsional)
/// ------------------------------------------------------------------

/// Resolve logo CDN (bila perlu dipakai di list tile leading nantinya)
String? resolveLogoUrl(String? logoPath) {
  if (logoPath == null || logoPath.isEmpty) return null;
  if (logoPath.startsWith('http')) return logoPath;
  const baseCdn = 'https://wave-cdn.eon.id'; // sesuaikan dengan punyamu
  return '$baseCdn${logoPath.startsWith('/') ? '' : '/'}$logoPath';
}
