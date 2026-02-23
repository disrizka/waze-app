// ====== PURCHASE DETAIL MODELS ======

class PurchaseDetail {
  final String idTransaction;
  final String number;

  /// API bisa kirim "success" untuk purchase yang selesai.
  /// UI kamu mapping 'success' → Completed sudah dihandle di widget.
  final String status;

  final String storeLocationId;
  final StoreLocationLight? storeLocation; // ← detail lokasi untuk ambil name
  final String supplierId;
  final SupplierLight? supplier;

  final String note;
  final String reference;

  /// Grand total dari API (bisa 0 jika backend tidak menyertakan).
  final int amount;

  /// Diskon level order (IDR).
  final int discount;

  /// Ongkir (IDR).
  final int shippingFee;

  /// Waktu order (epoch detik dari field order_at jika ada,
  /// atau fallback ke created_at).
  final DateTime orderAt;

  /// Timestamp dibuat.
  final DateTime createdAt;

  /// Daftar item.
  final List<PurchaseDetailItem> items;

  const PurchaseDetail({
    required this.idTransaction,
    required this.number,
    required this.status,
    required this.storeLocationId,
    required this.storeLocation,
    required this.supplierId,
    required this.supplier,
    required this.note,
    required this.reference,
    required this.amount,
    required this.discount,
    required this.shippingFee,
    required this.orderAt,
    required this.createdAt,
    required this.items,
  });

  /// Nama store location yang siap pakai di UI.
  String get storeLocationName =>
      (storeLocation?.name?.isNotEmpty == true) ? storeLocation!.name! : '—';
  String get supplierName =>
      (supplier?.name?.isNotEmpty == true) ? supplier!.name! : '—';

  /// Total kuantitas masuk (qty_in - qty_out) semua baris.
  int get totalQty => items.fold<int>(0, (s, i) => s + i.netQty);

  /// Subtotal dihitung dari item (qty_in - qty_out) * price.
  int get itemsSubtotal =>
      items.fold<int>(0, (s, i) => s + (i.netQty * i.price));

  /// Grand total praktis untuk UI:
  /// - pakai `amount` jika tersedia (>0),
  /// - selain itu hitung: `itemsSubtotal - discount + shippingFee`.
  int get grandTotal {
    final manual = (itemsSubtotal - discount + shippingFee);
    return amount > 0 ? amount : (manual < 0 ? 0 : manual);
  }

  factory PurchaseDetail.fromJson(Map<String, dynamic> j) {
    // items[]
    final items = ((j['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PurchaseDetailItem.fromJson)
        .toList(growable: false);

    // store_location (opsional tapi sering ada)
    StoreLocationLight? storeLoc;
    final sl = j['store_location'];
    if (sl is Map<String, dynamic>) {
      storeLoc = StoreLocationLight.fromJson(sl);
    }

    SupplierLight? supp;
    final supplierRaw = j['supplier'];
    if (supplierRaw is Map<String, dynamic>) {
      supp = SupplierLight.fromJson(supplierRaw);
    }

    return PurchaseDetail(
      idTransaction: (j['idTransaction'] ?? '').toString(),
      number: (j['number'] ?? '').toString(),
      status: (j['status'] ?? '').toString(), // "success" | "pending" | ...
      storeLocationId: (j['store_location_id'] ?? '').toString(),
      storeLocation: storeLoc,
      supplierId: (j['supplier_id'] ?? '').toString(),
      supplier: supp,
      note: (j['note'] ?? '').toString(),
      reference: (j['reference'] ?? '').toString(),
      amount: _asInt(j['amount']),
      discount: _asInt(j['discount']),
      shippingFee: _asInt(j['shipping_fee']),
      orderAt: _parseTime(j['order_at'], j['created_at']),
      createdAt: _parseTime(0, j['created_at']),
      items: items,
    );
  }
}

class SupplierLight {
  final String idSupplier;
  final String? name;
  final String? phone;
  final String? email;
  final String? address;

  const SupplierLight({
    required this.idSupplier,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
  });

  factory SupplierLight.fromJson(Map<String, dynamic> j) => SupplierLight(
    idSupplier: (j['idSupplier'] ?? '').toString(),
    name: j['name']?.toString(),
    phone: j['phone']?.toString(),
    email: j['email']?.toString(),
    address: j['address']?.toString(),
  );
}

class PurchaseDetailItem {
  final String productId;
  final String productSkuId;

  /// Kuantitas masuk/keluar dari API.
  final int qtyIn;
  final int qtyOut;

  /// Harga unit (IDR).
  final int price;

  /// Informasi kaya untuk UI:
  final String productName; // dari data.product.name
  final String skuCode; // dari data.product_sku.code
  final String? imageUrl; // dari product.productImages[0].imagePath

  /// Atribut SKU (opsional) → contoh: { "Size": "X", "Color": "White" }
  final Map<String, String> attributes;

  /// Kuantitas efektif = max(qtyIn - qtyOut, 0).
  int get netQty => (qtyIn - qtyOut).clamp(0, 1 << 31);

  const PurchaseDetailItem({
    required this.productId,
    required this.productSkuId,
    required this.qtyIn,
    required this.qtyOut,
    required this.price,
    required this.productName,
    required this.skuCode,
    required this.imageUrl,
    required this.attributes,
  });

  factory PurchaseDetailItem.fromJson(Map<String, dynamic> j) {
    // product & product_sku nodes (optional)
    final prod = j['product'] as Map<String, dynamic>?;
    final sku = j['product_sku'] as Map<String, dynamic>?;

    // product name
    final productName = (prod?['name'] ?? '').toString();

    // sku code
    final skuCode = (sku?['code'] ?? '').toString();

    // imagePath dari gambar pertama (kalau ada)
    String? imagePath;
    final imgs = prod?['productImages'];
    if (imgs is List && imgs.isNotEmpty) {
      final first = imgs.first;
      if (first is Map<String, dynamic>) {
        imagePath = first['imagePath']?.toString();
      }
    }

    // attributes → Map<String, String>
    final attrs = <String, String>{};
    final rawAttrs = sku?['attributes'];
    if (rawAttrs is List) {
      for (final a in rawAttrs) {
        if (a is Map<String, dynamic>) {
          final k = (a['name'] ?? '').toString();
          final v = (a['value'] ?? '').toString();
          if (k.isNotEmpty && v.isNotEmpty) {
            attrs[k] = v;
          }
        }
      }
    }

    return PurchaseDetailItem(
      productId: (j['product_id'] ?? '').toString(),
      productSkuId: (j['product_sku_id'] ?? '').toString(),
      qtyIn: _asInt(j['qty_in']),
      qtyOut: _asInt(j['qty_out']),
      price: _asInt(j['price']),
      productName: productName,
      skuCode: skuCode,
      imageUrl: imagePath,
      attributes: attrs,
    );
  }
}

/// Ringkasan store location yang cukup untuk UI.
class StoreLocationLight {
  final String idStoreLocation;
  final String? name;
  final BusinessLight? business;
  final CityLight? city;

  const StoreLocationLight({
    required this.idStoreLocation,
    required this.name,
    required this.business,
    required this.city,
  });

  factory StoreLocationLight.fromJson(Map<String, dynamic> j) {
    BusinessLight? biz;
    final b = j['business'];
    if (b is Map<String, dynamic>) {
      biz = BusinessLight.fromJson(b);
    }

    CityLight? c;
    final city = j['city'];
    if (city is Map<String, dynamic>) {
      c = CityLight.fromJson(city);
    }

    return StoreLocationLight(
      idStoreLocation: (j['idStoreLocation'] ?? '').toString(),
      name: j['name']?.toString(),
      business: biz,
      city: c,
    );
  }
}

class BusinessLight {
  final String idBusiness;
  final String name;
  final String? logoPath;

  const BusinessLight({
    required this.idBusiness,
    required this.name,
    required this.logoPath,
  });

  factory BusinessLight.fromJson(Map<String, dynamic> j) => BusinessLight(
    idBusiness: (j['idBusiness'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    logoPath: j['logoPath']?.toString(),
  );
}

class CityLight {
  final String id;
  final String name;
  final ProvinceLight? province;
  const CityLight({
    required this.id,
    required this.name,
    required this.province,
  });

  factory CityLight.fromJson(Map<String, dynamic> j) => CityLight(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    province: (j['province'] is Map<String, dynamic>)
        ? ProvinceLight.fromJson(j['province'] as Map<String, dynamic>)
        : null,
  );
}

class ProvinceLight {
  final String id;
  final String name;
  const ProvinceLight({required this.id, required this.name});

  factory ProvinceLight.fromJson(Map<String, dynamic> j) => ProvinceLight(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
  );
}

// ====== HELPERS (tetap seperti semula) ======

DateTime _parseTime(dynamic orderAt, dynamic createdAtStr) {
  // order_at: epoch detik
  final sec = _asInt(orderAt);
  if (sec > 0) return DateTime.fromMillisecondsSinceEpoch(sec * 1000);
  if (createdAtStr is String && createdAtStr.isNotEmpty) {
    try {
      return DateTime.parse(createdAtStr);
    } catch (_) {}
  }
  return DateTime.now();
}

int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
