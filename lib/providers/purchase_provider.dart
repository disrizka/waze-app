// lib/providers/purchase_provider.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wa_blast/models/city_model.dart';

import 'package:wa_blast/models/supplier_model.dart';
import 'package:wa_blast/services/api_service.dart';

import '../core/provider_helper.dart';

/// Status order
enum PurchaseStatus { inProgress, completed, canceled }

/// Produk katalog (untuk tambah dari bottom sheet)
class Product {
  final String name;
  final int price;
  final String imageUrl;
  const Product({
    required this.name,
    required this.price,
    required this.imageUrl,
  });
}

/// Baris item di order
class OrderLine {
  final String name;
  final int qty;
  final int price; // harga per item (IDR)
  final String note;
  final String imageUrl;

  const OrderLine({
    required this.name,
    required this.qty,
    required this.price,
    this.note = 'Note here',
    this.imageUrl =
        'https://images.unsplash.com/photo-1542831371-29b0f74f9713?w=200&q=60',
  });

  int get lineTotal => qty * price;

  OrderLine copyWith({
    String? name,
    int? qty,
    int? price,
    String? note,
    String? imageUrl,
  }) {
    return OrderLine(
      name: name ?? this.name,
      qty: qty ?? this.qty,
      price: price ?? this.price,
      note: note ?? this.note,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

/// Entitas purchase/order
class PurchaseItem {
  final String code;
  final DateTime time;
  final int quantity; // total qty semua line
  final int totalAmount; // dipakai di list (legacy display)
  final PurchaseStatus status;

  // Detail
  final String servicedByName;
  final String servicedById;
  final String servicedByAvatarUrl;
  final double serviceFeePercent; // 0.02 = 2%
  final List<OrderLine> lines;

  const PurchaseItem({
    required this.code,
    required this.time,
    required this.quantity,
    required this.totalAmount,
    required this.status,
    required this.servicedByName,
    required this.servicedById,
    required this.servicedByAvatarUrl,
    required this.serviceFeePercent,
    required this.lines,
  });

  // Perhitungan live
  int get subtotal => lines.fold<int>(0, (sum, l) => sum + l.lineTotal);
  int get serviceFee => (subtotal * serviceFeePercent).round();
  int get grandTotal => subtotal + serviceFee;

  PurchaseItem copyWith({
    String? code,
    DateTime? time,
    int? quantity,
    int? totalAmount,
    PurchaseStatus? status,
    String? servicedByName,
    String? servicedById,
    String? servicedByAvatarUrl,
    double? serviceFeePercent,
    List<OrderLine>? lines,
  }) {
    return PurchaseItem(
      code: code ?? this.code,
      time: time ?? this.time,
      quantity: quantity ?? this.quantity,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      servicedByName: servicedByName ?? this.servicedByName,
      servicedById: servicedById ?? this.servicedById,
      servicedByAvatarUrl: servicedByAvatarUrl ?? this.servicedByAvatarUrl,
      serviceFeePercent: serviceFeePercent ?? this.serviceFeePercent,
      lines: lines ?? this.lines,
    );
  }
}

class PurchaseProvider extends ChangeNotifier {
  // ====== SUPPLIERS STATE ======
  final List<Supplier> _suppliers = [];
  PageMeta? _pageSuppliers;
  bool _loadingSuppliers = false;
  String? _supplierError;

  List<Supplier> get suppliers => List.unmodifiable(_suppliers);
  PageMeta? get pageSuppliers => _pageSuppliers;
  bool get loadingSuppliers => _loadingSuppliers;
  String? get supplierError => _supplierError;

  // Detail
  Supplier? _supplierDetail;
  bool _loadingSupplierDetail = false;
  String? _supplierDetailError;

  Supplier? get supplierDetail => _supplierDetail;
  bool get loadingSupplierDetail => _loadingSupplierDetail;
  String? get supplierDetailError => _supplierDetailError;

  // Delete (GET remove)
  final Set<String> _deletingSupplierIds = {};
  String? _deleteSupplierError;

  Set<String> get deletingSupplierIds => _deletingSupplierIds;
  String? get deleteSupplierError => _deleteSupplierError;

  final List<City> _cities = [];
  PageMeta? _pageCities;
  bool _loadingCities = false;
  String? _citiesError;

  List<City> get cities => List.unmodifiable(_cities);
  PageMeta? get pageCities => _pageCities;
  bool get loadingCities => _loadingCities;
  String? get citiesError => _citiesError;

  void _setCitiesError(String? msg) {
    _citiesError = msg;
    notifyListeners();
  }

  void _setLoadingCities(bool v) {
    _loadingCities = v;
    notifyListeners();
  }

  // ====== Setters (private) ======
  void _setLoading({bool? suppliers}) {
    if (suppliers != null) _loadingSuppliers = suppliers;
    notifyListeners();
  }

  void _setSupplierError(String? message) {
    _supplierError = message;
    notifyListeners();
  }

  void _setLoadingDetail(bool v) {
    _loadingSupplierDetail = v;
    notifyListeners();
  }

  void _setSupplierDetailError(String? msg) {
    _supplierDetailError = msg;
    notifyListeners();
  }

  void _setDeleting(String id, bool isDeleting) {
    if (isDeleting) {
      _deletingSupplierIds.add(id);
    } else {
      _deletingSupplierIds.remove(id);
    }
    notifyListeners();
  }

  void _setDeleteSupplierError(String? msg) {
    _deleteSupplierError = msg;
    notifyListeners();
  }

  // =========================
  // GET SUPPLIER LIST (API) - pakai FetchHelper
  // =========================
  Future<void> fetchSuppliers(BuildContext context) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _suppliers.clear();
      _pageSuppliers = null;
      _setSupplierError('Business ID is missing.');
      return;
    }

    _setSupplierError(null);
    _setLoading(suppliers: true);

    try {
      final result = await FetchHelper.fetchList<Supplier>(
        context: context,
        path: '/waveup/$bizId/supplier',
        parser: Supplier.fromJson,
      );

      if (result == null) {
        _suppliers.clear();
        _pageSuppliers = null;
        return;
      }

      _suppliers
        ..clear()
        ..addAll(result.items);
      _pageSuppliers = result.page;
    } catch (e) {
      _suppliers.clear();
      _pageSuppliers = null;
      _setSupplierError(e.toString());
    } finally {
      _setLoading(suppliers: false);
    }
  }

  // =========================
  // GET SUPPLIER DETAIL - pakai ApiJson.getMap
  // =========================
  Future<void> fetchSupplierDetail(
    BuildContext context,
    String supplierId,
  ) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _supplierDetail = null;
      _setSupplierDetailError('Business ID is missing.');
      return;
    }

    _setSupplierDetailError(null);
    _setLoadingDetail(true);

    try {
      final path = '/waveup/$bizId/supplier/$supplierId';
      final jsonMap = await ApiJson.getMap(context, path);

      if (jsonMap == null ||
          (jsonMap['status'] as num?)?.toInt() != 200 ||
          jsonMap['data'] is! Map) {
        _supplierDetail = null;
        _setSupplierDetailError('Unexpected response format.');
        return;
      }

      _supplierDetail = Supplier.fromJson(
        jsonMap['data'] as Map<String, dynamic>,
      );
      notifyListeners();
    } catch (e) {
      _supplierDetail = null;
      _setSupplierDetailError(e.toString());
    } finally {
      _setLoadingDetail(false);
    }
  }

  /// GET CITIES: /waveup/{bizId}/city
  Future<void> fetchCities(BuildContext context) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _cities..clear();
      _pageCities = null;
      _setCitiesError('Business ID is missing.');
      return;
    }

    _setCitiesError(null);
    _setLoadingCities(true);
    try {
      final result = await FetchHelper.fetchList<City>(
        context: context,
        path: '/waveup/$bizId/city',
        parser: City.fromJson,
        // kalau FetchHelper mendukung query, bisa tambahkan row_per_page lebih besar:
        // query: {'row_per_page': 200},
      );

      if (result == null) {
        _cities.clear();
        _pageCities = null;
        return;
      }

      // optional: sort by province, then name
      result.items.sort((a, b) {
        final p = a.provinceName.compareTo(b.provinceName);
        return p != 0 ? p : a.name.compareTo(b.name);
      });

      _cities
        ..clear()
        ..addAll(result.items);
      _pageCities = result.page;
      notifyListeners();
    } catch (e) {
      _cities.clear();
      _pageCities = null;
      _setCitiesError(e.toString());
    } finally {
      _setLoadingCities(false);
    }
  }

  // =========================
  // REMOVE SUPPLIER (GET) - pakai ApiJson.getMap
  // =========================
  Future<bool> removeSupplier(BuildContext context, String supplierId) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _setDeleteSupplierError('Business ID is missing.');
      return false;
    }

    _setDeleteSupplierError(null);
    _setDeleting(supplierId, true);

    try {
      final path = '/waveup/$bizId/supplier/remove/$supplierId';
      final jsonMap = await ApiJson.getMap(context, path);

      if (jsonMap == null || (jsonMap['status'] as num?)?.toInt() != 200) {
        _setDeleteSupplierError(
          (jsonMap?['message'] as String?) ?? 'Delete failed',
        );
        return false;
      }

      // sukses -> hapus dari cache list
      _suppliers.removeWhere((s) => s.idSupplier == supplierId);

      if (_supplierDetail?.idSupplier == supplierId) {
        _supplierDetail = null;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _setDeleteSupplierError(e.toString());
      return false;
    } finally {
      _setDeleting(supplierId, false);
    }
  }

  // =========================
  // ADD / UPDATE SUPPLIER (POST) - pakai ApiJson.postMap
  // =========================

  /// Upload satu file logo supplier via ApiService.uploadFile(String path).
  /// Harapannya response:
  /// { "status": 200, "data": { "filename": "<stored-filename>" } }
  Future<String?> _uploadSupplierLogo(BuildContext context, File file) async {
    try {
      final body = await ApiService.uploadFile(file.path);
      if (body != null && body['status'] == 200) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          final filename = data['filename']?.toString();
          if (filename != null && filename.isNotEmpty) return filename;
        }
        if (data is String && data.isNotEmpty) return data;
      }
    } catch (e) {
      debugPrint("[addSupplier] upload logo error: $e");
    }
    return null;
  }

  Future<bool> addSupplier({
    required BuildContext context,
    required String name,
    File? logoFile, // optional
    String? phone,
    String? email,
    required int cityId,
    String? address,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _supplierDetailError = "Business ID is not available.";
      notifyListeners();
      return false;
    }

    String? logoFilename;
    if (logoFile != null) {
      logoFilename = await _uploadSupplierLogo(context, logoFile);
      if (logoFilename == null || logoFilename.isEmpty) {
        _supplierDetailError = "Failed to upload logo file.";
        notifyListeners();
        return false;
      }
    }

    final payload = <String, dynamic>{
      'name': name,
      'logo': logoFilename, // boleh null jika tidak upload
      'phone': phone,
      'email': email,
      'city_id': cityId,
      'address': address,
    }..removeWhere((k, v) => v == null);

    try {
      if (kDebugMode) {
        debugPrint("[addSupplier] Payload: ${jsonEncode(payload)}");
      }

      final j = await ApiJson.postMap(
        context,
        '/waveup/$bizId/supplier',
        payload,
        withAccessToken: true,
      );

      if (j == null) {
        _supplierDetailError = 'Empty response';
        notifyListeners();
        return false;
      }

      final status = (j['status'] as num?)?.toInt();
      if (status != 200) {
        _supplierDetailError =
            j['message']?.toString() ?? 'Unexpected response';
        notifyListeners();
        return false;
      }

      if (j['data'] is Map<String, dynamic>) {
        final created = Supplier.fromJson(j['data'] as Map<String, dynamic>);
        _suppliers.insert(0, created);
        _supplierDetail = created;
        notifyListeners();
      } else {
        // fallback refresh list
        await fetchSuppliers(context);
      }

      return true;
    } catch (e) {
      _supplierDetailError = '$e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSupplier({
    required BuildContext context,
    required String idSupplier,
    required String name,
    File? logoFile, // optional
    String? phone,
    String? email,
    required int cityId,
    String? address,
  }) async {
    final bizId = await BizIdCache.get();
    if (bizId == null || bizId.isEmpty) {
      _supplierDetailError = "Business ID is not available.";
      notifyListeners();
      return false;
    }

    String? logoFilename;
    if (logoFile != null) {
      logoFilename = await _uploadSupplierLogo(context, logoFile);
      if (logoFilename == null || logoFilename.isEmpty) {
        _supplierDetailError = "Failed to upload logo file.";
        notifyListeners();
        return false;
      }
    }

    final payload = <String, dynamic>{
      'name': name,
      if (logoFilename != null) 'logo': logoFilename, // hanya kirim jika ganti
      'phone': phone,
      'email': email,
      'city_id': cityId,
      'address': address,
    }..removeWhere((k, v) => v == null);

    try {
      final j = await ApiJson.postMap(
        context,
        '/waveup/$bizId/supplier/$idSupplier', // atau PUT jika backend mendukung
        payload,
        withAccessToken: true,
      );

      if (j == null) {
        _supplierDetailError = 'Empty response';
        notifyListeners();
        return false;
      }

      final status = (j['status'] as num?)?.toInt();
      if (status != 200) {
        _supplierDetailError =
            j['message']?.toString() ?? 'Unexpected response';
        notifyListeners();
        return false;
      }

      if (j['data'] is Map<String, dynamic>) {
        final updated = Supplier.fromJson(j['data'] as Map<String, dynamic>);
        final idx = _suppliers.indexWhere((e) => e.idSupplier == idSupplier);
        if (idx != -1) _suppliers[idx] = updated;
        _supplierDetail = updated;
        notifyListeners();
      } else {
        await fetchSuppliers(context);
      }

      return true;
    } catch (e) {
      _supplierDetailError = '$e';
      notifyListeners();
      return false;
    }
  }

  // Optional: flag agar UI bisa cek ketersediaan
  bool get respondsToUpdateSupplier => true;

  // ====== Dummy katalog produk ======
  final List<Product> _products = const [
    Product(
      name: 'Garlic Bread',
      price: 15000,
      imageUrl:
          'https://images.unsplash.com/photo-1542831371-29b0f74f9713?w=400&q=60',
    ),
    Product(
      name: 'Hot Cappucino',
      price: 24000,
      imageUrl:
          'https://images.unsplash.com/photo-1504754524776-8f4f37790ca0?w=400&q=60',
    ),
    Product(
      name: 'Berry Sourdough',
      price: 18000,
      imageUrl:
          'https://images.unsplash.com/photo-1550367086-456a0a0f1c1b?w=400&q=60',
    ),
    Product(
      name: 'Ice Latte',
      price: 22000,
      imageUrl:
          'https://images.unsplash.com/photo-1541167760496-1628856ab772?w=400&q=60',
    ),
    Product(
      name: 'Ice Americano',
      price: 20000,
      imageUrl:
          'https://images.unsplash.com/photo-1517705008128-361805f42e86?w=400&q=60',
    ),
  ];

  List<Product> get products => List.unmodifiable(_products);

  // ====== Dummy orders ======
  final List<PurchaseItem> _items = [
    PurchaseItem(
      code: 'ODR0003',
      time: DateTime(2025, 9, 4, 12, 0, 5),
      quantity: 3,
      totalAmount: 54000,
      status: PurchaseStatus.inProgress,
      servicedByName: 'Mirna Sari',
      servicedById: 'ID 2004882',
      servicedByAvatarUrl:
          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120&q=60',
      serviceFeePercent: 0.02,
      lines: const [
        OrderLine(
          name: 'Garlic Bread',
          qty: 2,
          price: 15000,
          imageUrl:
              'https://images.unsplash.com/photo-1542831371-29b0f74f9713?w=400&q=60',
        ),
        OrderLine(
          name: 'Hot Cappucino',
          qty: 1,
          price: 24000,
          imageUrl:
              'https://images.unsplash.com/photo-1504754524776-8f4f37790ca0?w=400&q=60',
        ),
      ],
    ),
    PurchaseItem(
      code: 'ODR0001',
      time: DateTime(2025, 9, 4, 12, 0, 5),
      quantity: 8,
      totalAmount: 108500,
      status: PurchaseStatus.completed,
      servicedByName: 'Mirna Sari',
      servicedById: 'ID 2004882',
      servicedByAvatarUrl:
          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120&q=60',
      serviceFeePercent: 0.02,
      lines: const [
        OrderLine(
          name: 'Garlic Bread',
          qty: 2,
          price: 15000,
          imageUrl:
              'https://images.unsplash.com/photo-1542831371-29b0f74f9713?w=400&q=60',
        ),
        OrderLine(
          name: 'Hot Cappucino',
          qty: 1,
          price: 74000,
          imageUrl:
              'https://images.unsplash.com/photo-1550547660-d9450f859349?w=400&q=60',
        ),
        OrderLine(
          name: 'Berry Sourdough',
          qty: 5,
          price: 2400,
          imageUrl:
              'https://images.unsplash.com/photo-1550367086-456a0a0f1c1b?w=400&q=60',
        ),
      ],
    ),
    PurchaseItem(
      code: 'ODR0002',
      time: DateTime(2025, 9, 4, 12, 0, 5),
      quantity: 2,
      totalAmount: 54000,
      status: PurchaseStatus.completed,
      servicedByName: 'Mirna Sari',
      servicedById: 'ID 2004882',
      servicedByAvatarUrl:
          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120&q=60',
      serviceFeePercent: 0.02,
      lines: const [OrderLine(name: 'Garlic Bread', qty: 2, price: 27000)],
    ),
    PurchaseItem(
      code: 'ODR0004',
      time: DateTime(2025, 9, 4, 12, 0, 5),
      quantity: 2,
      totalAmount: 54000,
      status: PurchaseStatus.canceled,
      servicedByName: 'Mirna Sari',
      servicedById: 'ID 2004882',
      servicedByAvatarUrl:
          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120&q=60',
      serviceFeePercent: 0.02,
      lines: const [OrderLine(name: 'Garlic Bread', qty: 2, price: 27000)],
    ),
  ];

  PurchaseStatus? _filter;

  // ====== Selectors ======
  List<PurchaseItem> get items => _filter == null
      ? List.unmodifiable(_items)
      : _items.where((e) => e.status == _filter).toList(growable: false);

  PurchaseStatus? get filter => _filter;

  // ====== Actions umum ======
  void setFilter(PurchaseStatus? status) {
    _filter = status;
    notifyListeners();
  }

  Future<void> refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    notifyListeners();
  }

  PurchaseItem? getByCode(String code) {
    try {
      return _items.firstWhere((e) => e.code == code);
    } catch (_) {
      return null;
    }
  }

  void updateStatus(String code, PurchaseStatus newStatus) {
    final idx = _items.indexWhere((e) => e.code == code);
    if (idx == -1) return;
    _items[idx] = _items[idx].copyWith(status: newStatus);
    notifyListeners();
  }

  // ====== Kontrol qty/baris ======
  void setLineQty(String code, int lineIndex, int qty) {
    final idx = _items.indexWhere((e) => e.code == code);
    if (idx == -1) return;

    final item = _items[idx];
    if (lineIndex < 0 || lineIndex >= item.lines.length) return;

    final newLines = List<OrderLine>.from(item.lines);
    final newQty = qty.clamp(0, 9999);

    if (newQty == 0) {
      newLines.removeAt(lineIndex);
    } else {
      newLines[lineIndex] = newLines[lineIndex].copyWith(qty: newQty);
    }

    final newTotalQty = newLines.fold<int>(0, (s, l) => s + l.qty);

    _items[idx] = item.copyWith(lines: newLines, quantity: newTotalQty);
    notifyListeners();
  }

  void incrementLineQty(String code, int lineIndex) {
    final item = getByCode(code);
    if (item == null || lineIndex < 0 || lineIndex >= item.lines.length) return;
    setLineQty(code, lineIndex, item.lines[lineIndex].qty + 1);
  }

  void decrementLineQty(String code, int lineIndex) {
    final item = getByCode(code);
    if (item == null || lineIndex < 0 || lineIndex >= item.lines.length) return;
    setLineQty(code, lineIndex, (item.lines[lineIndex].qty - 1).clamp(0, 9999));
  }

  void addProductToOrder(String code, Product product) {
    final idx = _items.indexWhere((e) => e.code == code);
    if (idx == -1) return;

    final item = _items[idx];
    final lines = List<OrderLine>.from(item.lines);

    final existIdx = lines.indexWhere((l) => l.name == product.name);
    if (existIdx >= 0) {
      final exist = lines[existIdx];
      lines[existIdx] = exist.copyWith(qty: exist.qty + 1);
    } else {
      lines.add(
        OrderLine(
          name: product.name,
          qty: 1,
          price: product.price,
          imageUrl: product.imageUrl,
        ),
      );
    }

    final newTotalQty = lines.fold<int>(0, (s, l) => s + l.qty);
    _items[idx] = item.copyWith(lines: lines, quantity: newTotalQty);
    notifyListeners();
  }

  int getQtyForProduct(String code, String productName) {
    final item = getByCode(code);
    if (item == null) return 0;
    final i = item.lines.indexWhere((l) => l.name == productName);
    return i == -1 ? 0 : item.lines[i].qty;
  }
}
