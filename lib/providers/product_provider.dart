// lib/providers/product_provider.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/core/provider_helper.dart';
import 'package:wa_blast/models/product_models/product_model.dart';
import 'package:wa_blast/providers/sales_provider.dart';
import 'package:wa_blast/providers/store_provider.dart';
import 'package:wa_blast/services/api_service.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

part '../models/product_models/inventory_attr.dart';
part '../models/product_models/inventory_history_item.dart';
part '../models/product_models/inventory_product_sku.dart';
part '../models/product_models/inventory_store_location_lite.dart';
part '../models/product_models/new_image.dart';
part '../models/product_models/new_price.dart';
part '../models/product_models/new_sku.dart';
part '../models/product_models/new_sku_attribute.dart';
part '../models/product_models/sku_inventory_buckets.dart';

/// =========================
/// PROVIDER
/// =========================

class ProductProvider with ChangeNotifier {
  // --- Products
  final List<Product> _products = [];
  bool _loadingProducts = false;
  PageMeta? _pageProducts;

  // --- Product Detail
  Product? _productDetail;
  bool _loadingDetail = false;
  final Map<String, Product> _detailCache = {}; // cache per id

  Product? get productDetail => _productDetail;
  bool get loadingDetail => _loadingDetail;

  // --- Inventory History PER-SKU (non-pagination)
  final Map<String, SkuInventoryBuckets> _skuBuckets = {};
  final Map<String, InventoryHistoryItem?> _skuLatestCurrent = {};
  final Set<String> _skuLoading = {};
  final Map<String, Object?> _skuError = {};
  final Map<String, PageMeta?> _skuPageMeta = {}; // kalau backend kirim "page"

  bool isLoadingSkuHistory(String idProductSKU) =>
      _skuLoading.contains(idProductSKU);
  Object? skuHistoryError(String idProductSKU) => _skuError[idProductSKU];
  SkuInventoryBuckets? skuInventoryBuckets(String idProductSKU) =>
      _skuBuckets[idProductSKU];
  InventoryHistoryItem? skuLatestCurrentStock(String idProductSKU) =>
      _skuLatestCurrent[idProductSKU];
  PageMeta? skuHistoryPage(String idProductSKU) => _skuPageMeta[idProductSKU];

  // --- Brands
  final List<ProductBrand> _brands = [];
  bool _loadingBrands = false;
  PageMeta? _pageBrands;

  // --- Categories
  final List<ProductCategory> _categories = [];
  bool _loadingCategories = false;
  PageMeta? _pageCategories;

  String? _lastError;

  // NEW: error khusus produk
  String? _productError;
  String? get productError => _productError;

  List<Product> get products => List.unmodifiable(_products);
  List<ProductBrand> get brands => List.unmodifiable(_brands);
  List<ProductCategory> get categories => List.unmodifiable(_categories);

  bool get loadingProducts => _loadingProducts;
  bool get loadingBrands => _loadingBrands;
  bool get loadingCategories => _loadingCategories;

  PageMeta? get pageProducts => _pageProducts;
  PageMeta? get pageBrands => _pageBrands;
  PageMeta? get pageCategories => _pageCategories;

  bool get isEmpty =>
      _products.isEmpty && _brands.isEmpty && _categories.isEmpty;

  String? get lastError => _lastError;

  bool get reachedEnd => _reachedEnd;
  bool get isFirstPageDoneEmpty => _reachedEnd && _products.isEmpty;

  // --- Inventory History
  final List<InventoryHistoryItem> _inventoryHistory = [];
  bool _loadingInventoryHistory = false;
  PageMeta? _pageInventoryHistory;
  String? _inventoryHistoryError;

  List<InventoryHistoryItem> get inventoryHistory =>
      List.unmodifiable(_inventoryHistory);
  bool get loadingInventoryHistory => _loadingInventoryHistory;
  PageMeta? get pageInventoryHistory => _pageInventoryHistory;
  String? get inventoryHistoryError => _inventoryHistoryError;

  String _currentSearch = '';
  String? _currentStoreLocationId;
  int _currentPage = 1;
  bool _hasMoreProducts = true;

  // Getter opsional
  bool get hasMoreProducts => _hasMoreProducts;
  String get currentSearch => _currentSearch;
  String? get currentStoreLocationId => _currentStoreLocationId;

  final int _pageSize = 40;
  PagingController<int, Product>? _pagingController;
  int _lastFetchedPage = 0;

  InventoryProductSku _inventorySkuFromProduct(
    Product product,
    String idProductSKU,
  ) {
    ProductSku? src;
    for (final s in product.productSkus) {
      if (s.idProductSku == idProductSKU) {
        src = s;
        break;
      }
    }
    src ??= ProductSku(
      uuid: '',
      idProductSku: idProductSKU,
      code: '',
      price: 0,
      attributes: const [],
    );

    return InventoryProductSku(
      idProductSku: src.idProductSku,
      code: src.code,
      price: src.price,
      attributes: src.attributes
          .map((a) => InventoryAttr(name: a.name, value: a.value))
          .toList(growable: false),
    );
  }

  DateTime _parseTxDate(dynamic raw) {
    if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (raw is DateTime) return raw;
    if (raw is num) {
      final v = raw.toInt();
      final ms = v > 1000000000000 ? v : v * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    final s = raw.toString().trim();
    if (s.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    try {
      return DateTime.parse(s);
    } catch (_) {}
    final m = RegExp(r'^(\d{2})-(\d{2})-(\d{4})$').firstMatch(s);
    if (m != null) {
      final d = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final y = int.parse(m.group(3)!);
      return DateTime(y, mo, d);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _txTypeLabel(String type) {
    final t = type.toLowerCase();
    if (t == 'sale') return 'Sales transaction';
    if (t == 'purchase') return 'Purchase transaction';
    if (t == 'manual_adjustment') return 'Manual adjustment';
    if (t.isEmpty) return 'Transaction';
    return t.replaceAll('_', ' ');
  }

  List<InventoryHistoryItem> _mapTransactionsToHistory(
    List raw,
    Product product,
    InventoryProductSku invSku,
  ) {
    final items = <InventoryHistoryItem>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final tx = Map<String, dynamic>.from(e.cast<String, dynamic>());
      final trx = (tx['transaction'] as Map?)?.cast<String, dynamic>();

      final createdAt = _parseTxDate(
        trx?['created_at'] ?? trx?['order_at'] ?? tx['date'],
      );
      final updatedAt = _parseTxDate(
        trx?['updated_at'] ?? trx?['created_at'] ?? tx['date'],
      );
      final type = tx['type']?.toString() ?? '';
      final number =
          tx['number']?.toString() ?? trx?['number']?.toString() ?? '';

      var note = tx['note']?.toString() ?? '';
      if (note.isEmpty) {
        final label = _txTypeLabel(type);
        note = number.isNotEmpty ? '$label: $number' : label;
      }

      items.add(
        InventoryHistoryItem(
          createdAt: createdAt,
          updatedAt: updatedAt,
          note: note,
          qty: (tx['qty'] is num)
              ? (tx['qty'] as num).toInt()
              : int.tryParse('${tx['qty']}') ?? 0,
          balance: (tx['balance'] is num)
              ? (tx['balance'] as num).toInt()
              : int.tryParse('${tx['balance']}') ?? 0,
          referenceId:
              tx['id']?.toString() ?? trx?['idTransaction']?.toString() ?? '',
          referenceType: tx['referenceType']?.toString() ?? '',
          source: tx['referenceType']?.toString() ?? 'transaction',
          type: type,
          number: number,
          product: product,
          productSku: invSku,
          storeLocation: InventoryStoreLocationLite(
            idStoreLocation: trx?['store_location_id']?.toString() ?? '',
            name: '',
          ),
        ),
      );
    }

    items.sort((a, b) {
      final aDt = a.createdAt.isAfter(a.updatedAt) ? a.createdAt : a.updatedAt;
      final bDt = b.createdAt.isAfter(b.updatedAt) ? b.createdAt : b.updatedAt;
      return bDt.compareTo(aDt);
    });
    return items;
  }

  int _lastBatchCount = 0;
  bool _reachedEnd = false;

  PagingController<int, Product>? get pagingController => _pagingController;

  void _syncHasNextPage(bool value) {
    final pc = _pagingController;
    if (pc == null) return;
    if (pc.value.hasNextPage == value) return;
    pc.value = pc.value.copyWith(hasNextPage: value);
  }

  void _setLoading({
    bool? products,
    bool? brands,
    bool? categories,
    bool? detail,
    bool notify = true,
  }) {
    if (products != null) _loadingProducts = products;
    if (brands != null) _loadingBrands = brands;
    if (categories != null) _loadingCategories = categories;
    if (detail != null) _loadingDetail = detail;
    if (notify) notifyListeners();
  }

  void initInfinitePaging(
    BuildContext context, {
    String? initialSearch,
    bool autoFetchFirstPage = false, // ✅ baru
  }) {
    _pagingController?.dispose();
    _pagingController = null;

    _currentSearch = initialSearch ?? '';
    _lastFetchedPage = 0;
    _lastBatchCount = 0;
    _pageProducts = null;
    _productError = null;
    _reachedEnd = false; // reset end flag

    _pagingController = PagingController<int, Product>(
      getNextPageKey: (state) {
        // 1) Utamakan meta dari backend
        final current = _pageProducts?.currentPage;
        final total = _pageProducts?.totalPages;

        if (current != null && total != null) {
          return (current >= total) ? null : (current + 1);
        }

        // 2) Fallback
        if (_lastFetchedPage == 0) return 1;
        if (_lastBatchCount < _pageSize) return null;
        return _lastFetchedPage + 1;
      },

      fetchPage: (pageKey) async {
        try {
          final rawSearch = _currentSearch;
          String? expectedStore = _currentStoreLocationId;

          // Pastikan ada store default jika belum
          if (expectedStore == null || expectedStore.isEmpty) {
            try {
              expectedStore = await ensureDefaultStoreLocation(context);
            } catch (_) {}
          }

          final filters = _composeFiltersFromSearchString(
            rawSearch: rawSearch,
            storeId: expectedStore,
          );

          final res = await FetchHelper.fetchListByFilter<Product>(
            context: context,
            basePath: '/waveup/{{idBusiness}}/product',
            parser: Product.fromJson,
            filters: filters,
            page: pageKey,
            limit: _pageSize,
            injectBizId: true,
            dataKey: 'data',
          );

          if (res == null) {
            _lastFetchedPage = pageKey;
            _lastBatchCount = 0;
            _pageProducts = null;
            // ❗ batch 0 = akhir
            _reachedEnd = true;
            _syncHasNextPage(false);
            notifyListeners();
            return const <Product>[];
          }

          final items = res.items;

          _pageProducts = res.page;
          _lastFetchedPage = pageKey;
          _lastBatchCount = items.length;

          // ✅ set end-flag dari meta atau dari ukuran batch
          final hasMeta =
              _pageProducts?.currentPage != null &&
              _pageProducts?.totalPages != null;
          if (hasMeta) {
            _reachedEnd =
                _pageProducts!.currentPage! >= _pageProducts!.totalPages!;
          } else {
            _reachedEnd = items.length < _pageSize;
          }
          _syncHasNextPage(!_reachedEnd);

          if (pageKey == 1) {
            _products
              ..clear()
              ..addAll(items);
          } else {
            _products.addAll(items);
          }

          _currentSearch = rawSearch;
          _currentStoreLocationId = expectedStore;

          notifyListeners();
          return items;
        } catch (e) {
          _pageProducts = null;
          _productError = e.toString();
          _reachedEnd = true; // anggap stop agar UI tidak nyoba terus
          _syncHasNextPage(false);
          notifyListeners();
          rethrow;
        }
      },
    );

    // ✅ auto-trigger page pertama bila diminta
    if (autoFetchFirstPage) {
      // Kosongkan meta dulu supaya getNextPageKey balik ke 1
      _pageProducts = null;
      _lastFetchedPage = 0;
      _lastBatchCount = 0;
      _reachedEnd = false;
      _pagingController!.refresh();
    }
  }

  // ===== Infinite Paging: setter store (filter) =====

  /// Set filter store untuk mekanisme infinite paging.
  /// - Hanya menyetel ID lalu `.refresh()` supaya mulai dari page 1.
  /// - Boleh kirim `null` untuk menghapus filter (fallback ke ensureDefaultStoreLocation saat fetch).
  Future<void> setInfiniteStore(BuildContext context, String? storeId) async {
    _currentStoreLocationId = (storeId == null || storeId.isEmpty)
        ? null
        : storeId;
    // reset meta & end-flag supaya aman
    _lastFetchedPage = 0;
    _lastBatchCount = 0;
    _pageProducts = null;
    _productError = null;
    _reachedEnd = false;
    _pagingController?.refresh();
  }

  /// Alias ringan bila kamu ingin memanggil via tear-off (seperti yang disebut di UI)
  void Function(BuildContext, String?)? get setStoreLocationForPaging =>
      (BuildContext ctx, String? id) {
        _currentStoreLocationId = (id == null || id.isEmpty) ? null : id;
      };

  // === PATCH: ProductProvider ===
  // Tambahkan di dalam class ProductProvider

  /// Dipanggil saat sheet product dibuka.
  /// - Inisialisasi paging (reset meta, dll)
  /// - Set store (jika tersedia dari SalesProvider)
  /// - Trigger refresh supaya page 1 langsung di-load.
  Future<void> ensureProductsForPickerOnOpen(
    BuildContext context, {
    String? initialSearch,
  }) async {
    // 1) Inisialisasi paging
    initInfinitePaging(context, initialSearch: initialSearch);

    // 2) Usahakan set store lebih spesifik dari SalesProvider (kalau ada)
    try {
      final sales = context.read<SalesProvider>();
      final useStoreId = sales.storeLocationId;
      if (useStoreId != null && useStoreId.isNotEmpty) {
        await setInfiniteStore(context, useStoreId);
      } else {
        // kalau belum ada, ensure default (ambil dari StoreProvider)
        await ensureDefaultStoreLocation(context);
      }
    } catch (_) {
      // ignore; fallback di fetchPage juga handle ensure default
    }

    // 3) Trigger fetch page-1
    await refreshInfinite(context);
  }

  /// Kombinasi: set store lalu refresh langsung (praktis untuk first open sheet)
  Future<void> setInfiniteStoreAndRefresh(
    BuildContext context,
    String? storeId,
  ) async {
    await setInfiniteStore(context, storeId);
    await refreshInfinite(context);
  }

  Future<void> setInfiniteSearch(BuildContext context, String search) async {
    _currentSearch = search.trim();
    _lastFetchedPage = 0;
    _lastBatchCount = 0;
    _pageProducts = null; // penting: reset meta
    _productError = null;
    _reachedEnd = false;

    // 🔧 Pastikan store ada (backend kamu biasa butuh store_location_id)
    if (_currentStoreLocationId == null || _currentStoreLocationId!.isEmpty) {
      try {
        await ensureDefaultStoreLocation(
          context,
        ).timeout(const Duration(seconds: 6));
      } catch (_) {
        // biarkan kosong kalau gagal; fetchPage akan handle juga
      }
    }

    _pagingController?.refresh();
  }

  /// Set keduanya sekaligus untuk infinite paging (tanpa fetch otomatis).
  Future<void> setInfiniteFilters(
    BuildContext context, {
    String? search,
    String? storeId,
    bool andRefresh = true,
  }) async {
    if (search != null) _currentSearch = search;
    _currentStoreLocationId = (storeId == null || storeId.isEmpty)
        ? null
        : storeId;

    // reset meta
    _lastFetchedPage = 0;
    _lastBatchCount = 0;
    _pageProducts = null;
    _productError = null;
    _reachedEnd = false;

    if (andRefresh) {
      _pagingController?.refresh();
    }
  }

  // ==== sentuh sedikit untuk akurasi empty-state ====
  Future<void> refreshInfinite(BuildContext context) async {
    debugPrint(
      '[ProductProvider] refreshInfinite() called '
      '(search="$_currentSearch", store="$_currentStoreLocationId")',
    );

    _pageProducts = null;
    _lastFetchedPage = 0;
    _lastBatchCount = 0;
    _reachedEnd = false; // ✅ reset end-flag
    _productError = null;

    notifyListeners();
    _pagingController?.refresh();
  }

  // Provider
  void disposeInfinitePaging({bool notify = false}) {
    _pagingController?.dispose();
    _pagingController = null;

    _lastFetchedPage = 0;
    _lastBatchCount = 0;
    _reachedEnd = false;
    _pageProducts = null;
    _productError = null;
    _currentPage = 1;

    if (notify) {
      // aman: jadwalkan setelah frame unlock
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) notifyListeners();
      });
    }
  }

  // === Helper: normalisasi field detail produk dari camelCase → snake_case ===

  // === Helper: normalisasi field detail produk dari camelCase → snake_case ===
  Map<String, dynamic> _normalizeProductDetail(Map<String, dynamic> src) {
    // Peta nama key yang perlu diubah agar cocok dengan model Product.fromJson
    const keyMap = {
      // root
      'idProduct': 'id_product',
      'productBrand': 'product_brand',
      'productCategory': 'product_category',
      'storeLocation': 'store_location',
      'productImages': 'product_images',
      'productSkus': 'product_skus',
      'prices': 'product_prices',

      // nested store_location
      'idStoreLocation': 'id_store_location',

      // images
      'idProductImage': 'id_product_image',
      'imagePath': 'image_path',

      // skus
      'idProductSku': 'id_product_sku',

      // prices
      'idProductPrice': 'id_product_price',
      'minQty': 'min_qty',
    };

    // Satu fungsi rekursif untuk Map/List/primitive (tanpa mutual recursion)
    dynamic normalizeAny(dynamic value) {
      if (value is Map) {
        final m = Map<String, dynamic>.from(value.cast<String, dynamic>());
        final out = <String, dynamic>{};
        m.forEach((rawKey, v) {
          final newKey = keyMap[rawKey] ?? rawKey;
          out[newKey] = normalizeAny(v);
        });
        return out;
      } else if (value is List) {
        return value.map(normalizeAny).toList();
      }
      return value;
    }

    final normalized = normalizeAny(src);
    return Map<String, dynamic>.from(normalized as Map);
  }

  /// =========================
  /// FETCH FUNCTIONS (pakai helper)
  /// =========================

  Future<void> fetchProducts(BuildContext context) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _products.clear();
      _pageProducts = null;
      _productError = "Business ID is not available.";
      notifyListeners();
      return;
    }

    _productError = null; // NEW: clear error
    _setLoading(products: true);
    try {
      final result = await FetchHelper.fetchList<Product>(
        context: context,
        path: '/waveup/$bizId/product/search',
        parser: Product.fromJson,
      );

      if (result == null) {
        _products.clear();
        _pageProducts = null;
        _productError = 'Failed to load products.'; // NEW
        notifyListeners(); // NEW
        return;
      }

      _products
        ..clear()
        ..addAll(result.items);
      _pageProducts = result.page;
      _productError = null; // success
      notifyListeners(); // reflect new data
    } catch (e) {
      _products.clear();
      _pageProducts = null;
      _productError = e.toString(); // NEW
      notifyListeners(); // NEW
    } finally {
      _setLoading(products: false);
    }
  }

  Future<void> fetchProductsPagination(
    BuildContext context, {
    int page = 1,
    String? search, // bebas diisi, kosong = "search="
    String? storeLocationId, // bebas diisi/nullable → tidak dikirim jika null
    int limit = 40, // default sesuai permintaan
    bool append = false, // true bila mau load halaman berikutnya & di-append
  }) async {
    _productError = null;
    _setLoading(products: true);

    try {
      final effectiveSearch = search ?? _currentSearch;
      var effectiveStore = storeLocationId ?? _currentStoreLocationId;
      if (effectiveStore == null || effectiveStore.isEmpty) {
        effectiveStore = await ensureDefaultStoreLocation(context);
      }

      // 💡 gunakan parser token yang sama
      final filters = _composeFiltersFromSearchString(
        rawSearch: effectiveSearch,
        storeId: effectiveStore,
      );

      final result = await FetchHelper.fetchListByFilter<Product>(
        context: context,
        basePath: '/waveup/{{idBusiness}}/product',
        parser: Product.fromJson,
        filters: filters,
        page: page,
        limit: limit, // 40 by default
        injectBizId: true,
        dataKey: 'data',
      );

      if (result == null) {
        if (!append) _products.clear();
        _pageProducts = null;
        _currentPage = page;
        _hasMoreProducts = false;
        _productError = 'Failed to load products.';
        notifyListeners();
        return;
      }

      // update filter & meta aktif
      _currentSearch = effectiveSearch;
      _currentStoreLocationId = effectiveStore;
      _pageProducts = result.page;
      _currentPage = page;

      if (append) {
        _products.addAll(result.items);
      } else {
        _products
          ..clear()
          ..addAll(result.items);
      }

      // tentukan apakah masih ada halaman berikutnya
      final totalPages = result.page?.totalPages ?? page;
      _hasMoreProducts = page < totalPages;

      _productError = null;
      notifyListeners();
    } catch (e) {
      if (!append) _products.clear();
      _pageProducts = null;
      _hasMoreProducts = false;
      _productError = e.toString();
      notifyListeners();
    } finally {
      _setLoading(products: false);
    }
  }

  // ====== Fungsi helper: cari (reset ke page 1, tidak append) ======
  Future<void> searchProducts(
    BuildContext context,
    String search, {
    String? storeLocationId, // boleh sekalian ganti lokasi toko
    int limit = 40,
  }) async {
    // reset ke page 1 dengan kata kunci baru
    await fetchProductsPagination(
      context,
      page: 1,
      search: search,
      storeLocationId: storeLocationId,
      limit: limit,
      append: false,
    );
  }

  /// --- Tambahan: parser search-string dari UI (_ProductFilters.toSearchString)
  /// Mengubah "q:abc brand:ID cat:ID min:1000 max:5000 date_from:2025-10-01 date_to:2025-10-15"
  /// menjadi map filter untuk backend.
  Map<String, String> _composeFiltersFromSearchString({
    required String rawSearch,
    String? storeId,
  }) {
    String searchOnly = '';
    String? idBrand;
    String? idCategory;
    String? dateFrom;
    String? dateTo;
    String? min;
    String? max;

    // pecah by spasi
    final parts = rawSearch.trim().split(RegExp(r'\s+'));
    for (final token in parts) {
      final t = token.trim();
      if (t.isEmpty) continue;

      // pasangan k:v
      final colon = t.indexOf(':');
      if (colon > 0) {
        final key = t.substring(0, colon).toLowerCase();
        final val = t.substring(colon + 1);
        switch (key) {
          case 'q':
            searchOnly = val;
            break;
          case 'brand':
            idBrand = val;
            break;
          case 'cat':
            idCategory = val;
            break;
          case 'date_from':
            dateFrom = val;
            break;
          case 'date_to':
            dateTo = val;
            break;
          case 'min':
            min = val;
            break;
          case 'max':
            max = val;
            break;
          default:
            // abaikan token tidak dikenal
            break;
        }
      } else {
        // jika tidak ada "k:v", treat sebagai free-text query
        // (tapi kita pakai 'q:' di UI, jadi case ini jarang dipakai)
        if (searchOnly.isEmpty) {
          searchOnly = t;
        } else {
          searchOnly = ('$searchOnly $t').trim();
        }
      }
    }

    final map = <String, String>{
      if (searchOnly.isNotEmpty) 'search': searchOnly,
      if ((storeId ?? '').isNotEmpty) 'store_location_id': storeId!,
      if ((idBrand ?? '').isNotEmpty) 'id_brand': idBrand!,
      if ((idCategory ?? '').isNotEmpty) 'id_category': idCategory!,
      if ((dateFrom ?? '').isNotEmpty) 'date_from': dateFrom!,
      if ((dateTo ?? '').isNotEmpty) 'date_to': dateTo!,
      if ((min ?? '').isNotEmpty) 'min': min!,
      if ((max ?? '').isNotEmpty) 'max': max!,
    };

    return map;
  }

  Future<void> initPaginated(
    BuildContext context, {
    String? initialSearch,
    int initialLimit = 40,
  }) async {
    _currentSearch = initialSearch ?? '';
    _currentPage = 1;
    _hasMoreProducts = true;
    _productError = null;

    final ok = await ensureDefaultStoreLocation(context);
    if (ok == null) return; // tidak ada store → biarkan error tampil
    await fetchProductsPagination(
      context,
      page: 1,
      search: _currentSearch,
      storeLocationId: _currentStoreLocationId,
      limit: initialLimit,
      append: false,
    );
  }

  /// Pastikan ada store location terpilih.
  /// - Ambil dari StoreProvider (fetch jika kosong)
  /// - Set ke store pertama jika _currentStoreLocationId masih null
  /// - Return id yang aktif, atau null jika tidak ada store sama sekali
  Future<String?> ensureDefaultStoreLocation(BuildContext context) async {
    try {
      final sp = context.read<StoreProvider>();
      if (sp.stores.isEmpty && !sp.loadingList) {
        await sp.fetchStoreLocations(context);
      }
      if (_currentStoreLocationId == null) {
        if (sp.stores.isNotEmpty) {
          _currentStoreLocationId = sp.stores.first.idStoreLocation;
          debugPrint(
            '[ProductProvider] default store set -> $_currentStoreLocationId',
          );
          notifyListeners();
        } else {
          _productError = 'No store location available.';
          debugPrint('[ProductProvider] ⚠️ No store location available');
          notifyListeners();
          return null;
        }
      }
      return _currentStoreLocationId;
    } catch (e) {
      _productError = e.toString();
      debugPrint('[ProductProvider] ensureDefaultStoreLocation error: $e');
      notifyListeners();
      return null;
    }
  }

  Future<void> refreshProducts(BuildContext context) async {
    await fetchProductsPagination(
      context,
      page: 1,
      search: _currentSearch,
      storeLocationId: _currentStoreLocationId,
      limit: 40,
      append: false,
    );
  }

  // ✅ Ganti store + refresh page 1
  Future<void> setStoreLocationAndRefresh(
    BuildContext context,
    String storeId, {
    int limit = 40,
  }) async {
    _currentStoreLocationId = storeId;
    _currentPage = 1;
    _productError = null;
    await fetchProductsPagination(
      context,
      page: 1,
      search: _currentSearch,
      storeLocationId: _currentStoreLocationId,
      limit: limit,
      append: false,
    );
  }

  // ✅ Ganti search + refresh page 1
  Future<void> setSearchAndRefresh(
    BuildContext context,
    String search, {
    int limit = 40,
  }) async {
    _currentSearch = search;
    _currentPage = 1;
    _productError = null;
    await fetchProductsPagination(
      context,
      page: 1,
      search: _currentSearch,
      storeLocationId: _currentStoreLocationId,
      limit: limit,
      append: false,
    );
  }

  Future<void> goToPage(
    BuildContext context,
    int page, {
    int limit = 40,
  }) async {
    if (page < 1) page = 1;
    final total = _pageProducts?.totalPages;
    if (total != null && page > total) page = total;
    await fetchProductsPagination(
      context,
      page: page,
      search: _currentSearch,
      storeLocationId: _currentStoreLocationId,
      limit: limit,
      append: false,
    );
  }

  Future<void> nextPage(BuildContext context, {int limit = 40}) async {
    final total = _pageProducts?.totalPages ?? _currentPage;
    if (_currentPage < total) {
      await goToPage(context, _currentPage + 1, limit: limit);
    }
  }

  Future<void> prevPage(BuildContext context, {int limit = 40}) async {
    if (_currentPage > 1) {
      await goToPage(context, _currentPage - 1, limit: limit);
    }
  }

  Future<void> fetchProductBrands(BuildContext context) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _brands.clear();
      notifyListeners();
      return;
    }

    _setLoading(brands: true);
    try {
      final result = await FetchHelper.fetchList<ProductBrand>(
        context: context,
        path: '/waveup/$bizId/product-brand',
        parser: ProductBrand.fromJson,
      );

      if (result == null) {
        _brands.clear();
        _pageBrands = null;
        return;
      }

      _brands
        ..clear()
        ..addAll(result.items);
      _pageBrands = result.page;
    } finally {
      _setLoading(brands: false);
    }
  }

  Future<void> fetchProductCategories(BuildContext context) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _categories.clear();
      notifyListeners();
      return;
    }

    _setLoading(categories: true);
    try {
      final result = await FetchHelper.fetchList<ProductCategory>(
        context: context,
        path: '/waveup/$bizId/product-category',
        parser: ProductCategory.fromJson,
      );

      if (result == null) {
        _categories.clear();
        _pageCategories = null;
        return;
      }

      _categories
        ..clear()
        ..addAll(result.items);
      _pageCategories = result.page;
    } finally {
      _setLoading(categories: false);
    }
  }

  /// Fetch riwayat inventory untuk SATU SKU (tanpa pagination di UI).
  /// Endpoint: /waveup/{{idBusiness}}/product/history/inventory-transaction/{{idProductSKU}}
  Future<void> fetchSkuInventoryHistory({
    required BuildContext context,
    required String idProductSKU,
    int? page,
    int? limit,
    String? idStoreLocation,
    String? typeFilter,
    String? sortBy,
    String? dateFrom,
    String? dateTo,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _skuBuckets.remove(idProductSKU);
      _skuLatestCurrent[idProductSKU] = null;
      _skuPageMeta[idProductSKU] = null;
      _skuError[idProductSKU] = "Business ID is not available.";
      notifyListeners();
      return;
    }

    // set loading
    _skuError.remove(idProductSKU);
    _skuLoading.add(idProductSKU);
    notifyListeners();

    try {
      final basePath =
          '/waveup/$bizId/product/history/inventory-transaction/$idProductSKU';
      final query = <String, String>{};
      if (page != null) query['page'] = page.toString();
      if (limit != null) query['limit'] = limit.toString();
      if (idStoreLocation != null) {
        query['id_store_location'] = idStoreLocation;
      }
      if (typeFilter != null) query['type'] = typeFilter;
      if (sortBy != null) query['sort'] = sortBy;
      if ((dateFrom ?? '').trim().isNotEmpty) {
        query['date_from'] = dateFrom!.trim();
      }
      if ((dateTo ?? '').trim().isNotEmpty) {
        query['date_to'] = dateTo!.trim();
      }
      final path = query.isEmpty
          ? basePath
          : '$basePath?${Uri(queryParameters: query).query}';
      // Pakai helper JSON yang sudah ada di project-mu
      final jsonMap = await ApiJson.getMap(context, path);

      if (jsonMap == null) {
        _skuBuckets.remove(idProductSKU);
        _skuLatestCurrent[idProductSKU] = null;
        _skuPageMeta[idProductSKU] = null;
        _skuError[idProductSKU] = 'Empty response';
        notifyListeners();
        return;
      }

      // Struktur respons yang diharapkan:
      // {
      //   "status": 200,
      //   "page": { "current_page": 1, "row_per_page": 40, "total_pages": 1, "total_rows": 4 },
      //   "data": {
      //     "current_stock": [...],
      //     "purchases": [...],
      //     "sales": [...]
      //   }
      // }
      final status = (jsonMap['status'] as num?)?.toInt() ?? 200;
      if (status < 200 || status >= 300) {
        _skuBuckets.remove(idProductSKU);
        _skuLatestCurrent[idProductSKU] = null;
        _skuPageMeta[idProductSKU] = null;
        _skuError[idProductSKU] =
            jsonMap['message']?.toString() ?? 'Failed to fetch sku history';
        notifyListeners();
        return;
      }

      final pageJ = (jsonMap['page'] as Map?)?.cast<String, dynamic>();
      if (pageJ != null) {
        // PageMeta sudah dipakai di provider ini, asumsikan ada di project.
        _skuPageMeta[idProductSKU] = PageMeta.fromJson(pageJ);
      } else {
        _skuPageMeta[idProductSKU] = null;
      }

      final dataJ =
          (jsonMap['data'] as Map?)?.cast<String, dynamic>() ?? const {};

      // Support schema baru: { data: { product, transactions: [] } }
      if (dataJ['transactions'] is List) {
        final productJ = (dataJ['product'] as Map?)?.cast<String, dynamic>();
        final product = Product.fromJson(productJ ?? const {});
        final invSku = _inventorySkuFromProduct(product, idProductSKU);
        final txItems = _mapTransactionsToHistory(
          dataJ['transactions'] as List,
          product,
          invSku,
        );

        final sales = txItems
            .where(
              (it) =>
                  it.type.toLowerCase() == 'sale' ||
                  (it.qty < 0 && it.type.isNotEmpty),
            )
            .toList(growable: false);
        final purchases = txItems
            .where(
              (it) =>
                  it.type.toLowerCase() != 'sale' &&
                  !(it.qty < 0 && it.type.isNotEmpty),
            )
            .toList(growable: false);

        final buckets = SkuInventoryBuckets(
          currentStock: const [],
          purchases: purchases,
          sales: sales,
          transactions: txItems,
        );

        _skuBuckets[idProductSKU] = buckets;
        _skuLatestCurrent[idProductSKU] = null;
        _skuError.remove(idProductSKU);
        notifyListeners();
        return;
      }

      // Schema lama: current_stock / purchases / sales
      final buckets = SkuInventoryBuckets.fromJson(dataJ);

      _skuBuckets[idProductSKU] = buckets;

      // latest current stock untuk dashboard
      final latest = buckets.currentStock.isNotEmpty
          ? buckets.currentStock.first
          : null;
      _skuLatestCurrent[idProductSKU] = latest;

      _skuError.remove(idProductSKU);
      notifyListeners();
    } catch (e, st) {
      _skuBuckets.remove(idProductSKU);
      _skuLatestCurrent[idProductSKU] = null;
      _skuPageMeta[idProductSKU] = null;
      _skuError[idProductSKU] = e.toString();
      debugPrint('[fetchSkuInventoryHistory] Exception: $e');
      debugPrint('$st');
      notifyListeners();
    } finally {
      _skuLoading.remove(idProductSKU);
      notifyListeners();
    }
  }

  // === Aliases biar cocok dengan UI picker ===
  Future<void> loadProducts(BuildContext context) => fetchProducts(context);

  Future<void> loadProductsIfEmpty(BuildContext context) async {
    if (!_loadingProducts && _products.isEmpty) {
      await fetchProducts(context);
    }
  }

  // ====== Tambahkan method di class ProductProvider (bagian FETCH FUNCTIONS) ======

  Future<void> fetchInventoryHistory(BuildContext context) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _inventoryHistory..clear();
      _pageInventoryHistory = null;
      _inventoryHistoryError = "Business ID is not available.";
      notifyListeners();
      return;
    }

    _inventoryHistoryError = null;
    _loadingInventoryHistory = true;
    notifyListeners();

    try {
      final result = await FetchHelper.fetchList<InventoryHistoryItem>(
        context: context,
        path: '/waveup/$bizId/product/history/inventory-transaction/all',
        parser: InventoryHistoryItem.fromJson,
      );

      if (result == null) {
        _inventoryHistory..clear();
        _pageInventoryHistory = null;
        _inventoryHistoryError = 'Failed to load inventory history.';
        notifyListeners();
        return;
      }

      _inventoryHistory
        ..clear()
        ..addAll(result.items);
      _pageInventoryHistory = result.page;
      _inventoryHistoryError = null;
      notifyListeners();
    } catch (e, st) {
      _inventoryHistory..clear();
      _pageInventoryHistory = null;
      _inventoryHistoryError = e.toString();
      debugPrint('[fetchInventoryHistory] Exception: $e');
      debugPrint('$st');
      notifyListeners();
    } finally {
      _loadingInventoryHistory = false;
      notifyListeners();
    }
  }

  /// Optional helper kalau mau lazy load
  Future<void> loadInventoryHistoryIfEmpty(BuildContext context) async {
    if (!_loadingInventoryHistory && _inventoryHistory.isEmpty) {
      await fetchInventoryHistory(context);
    }
  }

  Future<Product?> fetchProductDetail(
    BuildContext context,
    String idProduct, {
    bool preferCache = true,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      debugPrint("[fetchProductDetail] ❌ Business ID null/empty");
      return null;
    }

    try {
      if (preferCache && _detailCache.containsKey(idProduct)) {
        _productDetail = _detailCache[idProduct];
        debugPrint("[fetchProductDetail] ✅ Cache hit for id=$idProduct");
        notifyListeners();
      } else {
        debugPrint("[fetchProductDetail] 🔍 Cache miss for id=$idProduct");
      }

      final path = '/waveup/$bizId/product/$idProduct';
      debugPrint("[fetchProductDetail] 🌐 GET $path");

      _setLoading(detail: true);
      final jsonMap = await ApiJson.getMap(context, path);

      if (jsonMap == null) {
        _lastError = 'Null JSON response';
        debugPrint("[fetchProductDetail] ❌ Response is null");
        return _productDetail;
      }

      if (jsonMap['status'] != 200 ||
          jsonMap['data'] is! Map<String, dynamic>) {
        _lastError = 'Failed to get product detail';
        debugPrint(
          "[fetchProductDetail] ❌ Invalid status/data (status=${jsonMap['status']})",
        );
        return _productDetail;
      }

      final rawData = jsonMap['data'] as Map<String, dynamic>;
      debugPrint("[fetchProductDetail] 📦 Full data: ${jsonEncode(rawData)}");

      final fresh = Product.fromJson(rawData);
      debugPrint(
        "[fetchProductDetail] ✅ Parsed product: ${fresh.idProduct} - ${fresh.name}",
      );

      _productDetail = fresh;
      _detailCache[idProduct] = fresh;
      notifyListeners();
      return fresh;
    } catch (e, st) {
      _lastError = '$e';
      debugPrint("[fetchProductDetail] ❌ Exception: $e");
      debugPrint("$st");
      return _productDetail;
    } finally {
      _setLoading(detail: false);
      debugPrint("[fetchProductDetail] 🔄 Done (loading=false)");
    }
  }

  /// =========================
  /// UPLOAD & CREATE
  /// =========================

  Future<String?> uploadProductImage(BuildContext context, File file) async {
    final body = await ApiService.uploadFile(file.path);

    if (body != null &&
        body['status'] == 200 &&
        body['data'] is Map<String, dynamic>) {
      final data = body['data'] as Map<String, dynamic>;
      return data['filename']?.toString();
    }
    return null;
  }

  Future<bool> addProduct({
    required BuildContext context,
    required String name,
    required String description,
    required String productBrandId,
    required String productCategoryId,
    required List<NewImage> images,
    required List<NewSku> skus,
    required List<NewPrice> prices,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    final payload = {
      'name': name,
      'description': description,
      'product_brand_id': productBrandId,
      'product_category_id': productCategoryId,
      'images': images.map((e) => e.toJson()).toList(),
      'skus': skus.map((e) => e.toJson()).toList(),
      'prices': prices.map((e) => e.toJson()).toList(),
    };

    try {
      debugPrint("[addProduct] Payload: ${jsonEncode(payload)}");

      final res = await ApiService.post(
        context,
        '/waveup/$bizId/product',
        payload,
        withAccessToken: true,
      );

      if (res != null) {
        debugPrint("[addProduct] Response Code: ${res.statusCode}");
        debugPrint("[addProduct] Response Body: ${res.body}");
      } else {
        debugPrint("[addProduct] Response is null");
      }

      final ok = res != null && res.statusCode >= 200 && res.statusCode < 300;
      if (!ok) {
        _lastError = 'Failed to add product: ${res?.statusCode} ${res?.body}';
      } else {
        await fetchProducts(context);
      }
      return ok;
    } catch (e) {
      _lastError = '$e';
      debugPrint("[addProduct] Exception: $e");
      return false;
    }
  }

  Future<bool> addProductBrand(BuildContext context, String name) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    try {
      final payload = {'name': name};
      final j = await ApiJson.postMap(
        context,
        '/waveup/$bizId/product-brand',
        payload,
        withAccessToken: true,
      );

      final ok = j != null && (j['status'] as int?) == 200;
      if (ok) {
        await fetchProductBrands(context);
        return true;
      } else {
        _lastError = 'Failed to add brand: ${j?['message'] ?? '-'}';
      }
    } catch (e) {
      _lastError = "$e";
    }
    return false;
  }

  Future<bool> addProductCategory(BuildContext context, String name) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    try {
      final payload = {'name': name};
      final j = await ApiJson.postMap(
        context,
        '/waveup/$bizId/product-category',
        payload,
        withAccessToken: true,
      );

      final ok = j != null && (j['status'] as int?) == 200;
      if (ok) {
        await fetchProductCategories(context);
        return true;
      } else {
        _lastError = 'Failed to add category: ${j?['message'] ?? '-'}';
      }
    } catch (e) {
      _lastError = "$e";
      debugPrint("[addProductCategory] Exception: $e");
    }
    return false;
  }

  // === CREATE (no fetch) ===

  Future<ProductBrand?> createBrandNoFetch(
    BuildContext context,
    String name, {
    bool insertIntoProvider = true,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return null;
    }

    try {
      final j = await ApiJson.postMap(context, '/waveup/$bizId/product-brand', {
        'name': name,
      }, withAccessToken: true);
      if (j == null || (j['status'] as int?) != 200) {
        _lastError = 'Failed to add brand: ${j?['message'] ?? '-'}';
        return null;
      }
      final data = j['data'] as Map<String, dynamic>?;
      if (data == null) return null;

      final created = ProductBrand.fromJson(data);

      if (insertIntoProvider) {
        _brands.add(created);
        notifyListeners();
      }
      return created;
    } catch (e) {
      _lastError = '$e';
      return null;
    }
  }

  Future<ProductCategory?> createCategoryNoFetch(
    BuildContext context,
    String name, {
    bool insertIntoProvider = true,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return null;
    }

    try {
      final j = await ApiJson.postMap(
        context,
        '/waveup/$bizId/product-category',
        {'name': name},
        withAccessToken: true,
      );
      if (j == null || (j['status'] as int?) != 200) {
        _lastError = 'Failed to add category: ${j?['message'] ?? '-'}';
        return null;
      }
      final data = j['data'] as Map<String, dynamic>?;
      if (data == null) return null;

      final created = ProductCategory.fromJson(data);

      if (insertIntoProvider) {
        _categories.add(created);
        notifyListeners();
      }
      return created;
    } catch (e) {
      _lastError = '$e';
      return null;
    }
  }

  /// =========================
  /// EDIT / UPDATE
  /// =========================

  Future<bool> updateProductBrand(
    BuildContext context,
    String brandId,
    String name,
  ) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    try {
      final j = await ApiJson.postMap(
        context,
        '/waveup/$bizId/product-brand/$brandId',
        {'name': name},
        withAccessToken: true,
      );

      final ok = j != null && (j['status'] as int?) == 200;
      if (ok) {
        await fetchProductBrands(context);
        return true;
      } else {
        _lastError = 'Failed to update brand: ${j?['message'] ?? '-'}';
      }
    } catch (e) {
      _lastError = "$e";
      debugPrint("[updateProductBrand] Exception: $e");
    }
    return false;
  }

  Future<bool> updateProductCategory(
    BuildContext context,
    String categoryId,
    String name,
  ) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    try {
      final j = await ApiJson.postMap(
        context,
        '/waveup/$bizId/product-category/$categoryId',
        {'name': name},
        withAccessToken: true,
      );

      final ok = j != null && (j['status'] as int?) == 200;
      if (ok) {
        await fetchProductCategories(context);
        return true;
      } else {
        _lastError = 'Failed to update category: ${j?['message'] ?? '-'}';
      }
    } catch (e) {
      _lastError = "$e";
      debugPrint("[updateProductCategory] Exception: $e");
    }
    return false;
  }

  /// =========================
  /// UPDATE PAYLOAD EXACT (biar sama kaya addProductExactPayload)
  /// =========================
  Future<bool> updateProductExactPayload({
    required BuildContext context,
    required String idProduct,
    required String name,
    // boleh null
    required String? description,
    // boleh null
    required String? productBrandId,
    // boleh null
    required String? productCategoryId,
    required List<Map<String, dynamic>>?
    images, // [{"image":"...","position":1}]
    required List<Map<String, dynamic>> skus, // same shape as add
    required List<Map<String, dynamic>>? prices, // null jika multi price off
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    final payload = <String, dynamic>{
      'name': name,
      'description': description, // boleh null
      'product_brand_id': productBrandId, // boleh null
      'product_category_id': productCategoryId, // boleh null
      'images': images,
      'skus': skus,
      'prices': prices, // boleh null
    };

    try {
      if (kDebugMode) {
        debugPrint(
          "[updateProductExactPayload] Payload: ${jsonEncode(payload)}",
        );
      }

      final res = await ApiService.post(
        context,
        '/waveup/$bizId/product/$idProduct',
        payload,
        withAccessToken: true,
      );

      final ok = res != null && res.statusCode >= 200 && res.statusCode < 300;

      if (kDebugMode) {
        debugPrint("[updateProductExactPayload] Code: ${res?.statusCode}");
        debugPrint("[updateProductExactPayload] Body: ${res?.body}");
      }

      if (ok) {
        await fetchProducts(context);
        // refresh detail cache
        if (_productDetail?.idProduct == idProduct) {
          await fetchProductDetail(context, idProduct, preferCache: false);
        } else {
          _detailCache.remove(idProduct);
        }
        return true;
      } else {
        _lastError = res?.body ?? 'Failed to update product';
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) debugPrint("[updateProductExactPayload] Error: $e");
      return false;
    }
  }

  /// =========================
  /// DELETE FUNCTIONS
  /// =========================

  Future<bool> deleteProduct(BuildContext context, String idProduct) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    try {
      final path = '/waveup/$bizId/product/remove/$idProduct';
      debugPrint("[deleteProduct] GET $path");

      final jsonMap = await ApiJson.getMap(context, path);

      if (jsonMap == null) {
        _lastError = 'Empty response';
        return false;
      }

      final apiStatus = (jsonMap['status'] is num)
          ? (jsonMap['status'] as num).toInt()
          : -1;
      final message = jsonMap['message']?.toString();

      debugPrint("[deleteProduct] body: $jsonMap");

      if (apiStatus == 200) {
        await fetchProducts(context);

        _detailCache.remove(idProduct);
        if (_productDetail?.idProduct == idProduct) {
          _productDetail = null;
          notifyListeners();
        }
        return true;
      } else {
        _lastError = message ?? 'Failed to delete product';
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint("[deleteProduct] Exception: $e");
      return false;
    }
  }

  Future<bool> deleteProductBrand(BuildContext context, String brandId) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    try {
      final path = '/waveup/$bizId/product-brand/remove/$brandId';
      debugPrint("[deleteProductBrand] GET $path");

      final jsonMap = await ApiJson.getMap(context, path);

      if (jsonMap == null) {
        _lastError = 'Empty response';
        return false;
      }

      final apiStatus = (jsonMap['status'] is num)
          ? (jsonMap['status'] as num).toInt()
          : -1;
      final message = jsonMap['message']?.toString();
      debugPrint("[deleteProductBrand] body: $jsonMap");

      if (apiStatus == 200) {
        _brands.removeWhere((b) => b.id == brandId);
        notifyListeners();

        await fetchProductBrands(context);
        return true;
      } else {
        _lastError = message ?? 'Failed to delete brand';
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint("[deleteProductBrand] Exception: $e");
      return false;
    }
  }

  Future<bool> deleteProductCategory(
    BuildContext context,
    String categoryId,
  ) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    try {
      final path = '/waveup/$bizId/product-category/remove/$categoryId';
      debugPrint("[deleteProductCategory] GET $path");

      final jsonMap = await ApiJson.getMap(context, path);

      if (jsonMap == null) {
        _lastError = 'Empty response';
        return false;
      }

      final apiStatus = (jsonMap['status'] is num)
          ? (jsonMap['status'] as num).toInt()
          : -1;
      final message = jsonMap['message']?.toString();
      debugPrint("[deleteProductCategory] body: $jsonMap");

      if (apiStatus == 200) {
        _categories.removeWhere((c) => c.id == categoryId);
        notifyListeners();

        await fetchProductCategories(context);
        return true;
      } else {
        _lastError = message ?? 'Failed to delete category';
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint("[deleteProductCategory] Exception: $e");
      return false;
    }
  }

  /// =========================
  /// PAYLOAD EXACT (untuk case khusus)
  /// =========================

  Future<bool> addProductExactPayload({
    required BuildContext context,
    required String name,
    // boleh null
    required String? description,
    // boleh null
    required String? productBrandId,
    // boleh null
    required String? productCategoryId,
    required List<Map<String, dynamic>>
    images, // [{"image": "...", "position": 1}]
    required List<Map<String, dynamic>> skus,
    required List<Map<String, dynamic>>? prices, // null jika multi price off
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _lastError = "Business ID is not available.";
      return false;
    }

    final payload = <String, dynamic>{
      'name': name,
      // langsung kirim apa adanya (bisa null)
      'description': description,
      'product_brand_id': productBrandId,
      'product_category_id': productCategoryId,
      'images': images,
      'skus': skus,
      'prices': prices, // boleh null
    };

    try {
      debugPrint("[addProductExactPayload] Payload: ${jsonEncode(payload)}");

      final res = await ApiService.post(
        context,
        '/waveup/$bizId/product',
        payload,
        withAccessToken: true,
      );

      if (res != null) {
        debugPrint("[addProductExactPayload] Code: ${res.statusCode}");
        debugPrint("[addProductExactPayload] Body: ${res.body}");
      } else {
        debugPrint("[addProductExactPayload] Response is null");
      }

      final ok = res != null && res.statusCode >= 200 && res.statusCode < 300;
      if (ok) {
        await fetchProducts(context);
        return true;
      } else {
        _lastError = 'Failed to add product: ${res?.statusCode} ${res?.body}';
        return false;
      }
    } catch (e) {
      _lastError = '$e';
      debugPrint("[addProductExactPayload] Exception: $e");
      return false;
    }
  }

  /// =========================
  /// MISC
  /// =========================

  Future<void> refresh(
    BuildContext context, {
    bool products = true,
    bool brands = true,
    bool categories = true,
    bool inventoryHistory = false,
  }) async {
    final futures = <Future<void>>[];
    if (products) futures.add(fetchProducts(context));
    if (brands) futures.add(fetchProductBrands(context));
    if (categories) futures.add(fetchProductCategories(context));
    if (inventoryHistory) futures.add(fetchInventoryHistory(context));
    await Future.wait(futures);
  }

  void clearProductDetail({String? id}) {
    if (id != null) _detailCache.remove(id);
    _productDetail = null;
    notifyListeners();
  }
}
