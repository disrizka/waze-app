// lib/models/store_order_model.dart
import 'package:flutter/foundation.dart';

@immutable
class StoreOrder {
  final String idStoreOrder;

  /// seringnya backend ada int / string, kita normalisasi ke int
  final int businessId;
  final int storeLocationId;
  final int storeId;

  final String platformName;
  final String storeName;

  /// id/nomor order dari platform (kadang external_id / order_no)
  final String externalId;

  /// kadang bool, kadang 0/1
  final bool processed;

  /// status raw dari API
  final String status;

  /// total amount (rupiah)
  final int totalAmount;

  /// epoch seconds (kadang backend kirim ms)
  final int createTimeEpoch;
  final String createTimeLabel;

  /// epoch seconds (kadang backend kirim ms)
  final int updateTimeEpoch;

  final List<StoreOrderItem> items;

  const StoreOrder({
    required this.idStoreOrder,
    required this.businessId,
    required this.storeLocationId,
    required this.storeId,
    required this.platformName,
    required this.storeName,
    required this.externalId,
    required this.processed,
    required this.status,
    required this.totalAmount,
    required this.createTimeEpoch,
    required this.createTimeLabel,
    required this.updateTimeEpoch,
    required this.items,
  });

  /// ====== Convenience getters (buat UI lebih enak) ======

  /// fallback buat title di card
  String get orderNo {
    final v = externalId.trim();
    if (v.isNotEmpty) return v;
    final id = idStoreOrder.trim();
    return id.isNotEmpty ? id : '-';
  }

  /// convert epoch seconds/ms -> DateTime
  DateTime get createdAt {
    final s = _normalizeEpochToSeconds(createTimeEpoch);
    return DateTime.fromMillisecondsSinceEpoch(s * 1000);
  }

  DateTime? get updatedAt {
    if (updateTimeEpoch <= 0) return null;
    final s = _normalizeEpochToSeconds(updateTimeEpoch);
    return DateTime.fromMillisecondsSinceEpoch(s * 1000);
  }

  int get itemsCount => items.length;

  /// ====== JSON ======

  factory StoreOrder.fromJson(Map<String, dynamic> json) {
    // items bisa "items" / "Items" / "order_items" dll
    final rawItems =
        (json['items'] as List?) ??
        (json['Items'] as List?) ??
        (json['order_items'] as List?) ??
        (json['orderItems'] as List?) ??
        const [];

    final parsedItems = rawItems
        .whereType<dynamic>()
        .map((e) {
          if (e is Map<String, dynamic>) return StoreOrderItem.fromJson(e);
          if (e is Map) {
            return StoreOrderItem.fromJson(e.cast<String, dynamic>());
          }
          return null;
        })
        .whereType<StoreOrderItem>()
        .toList();

    // createTimeEpoch bisa dikirim di key berbeda + bisa string epoch
    final createEpoch = _toInt(
      json['CreateTime'] ??
          json['createTimeEpoch'] ??
          json['create_time_epoch'] ??
          json['create_time'] ??
          json['createTime'],
    );

    // updateTimeEpoch key juga bisa beda
    final updateEpoch = _toInt(
      json['UpdateTime'] ??
          json['updateTimeEpoch'] ??
          json['update_time_epoch'] ??
          json['update_time'] ??
          json['updateTime'],
    );

    return StoreOrder(
      idStoreOrder: (json['idStoreOrder'] ?? json['id'] ?? '').toString(),

      // beberapa backend pakai BusinessID / businessId / business_id
      businessId: _toInt(
        json['BusinessID'] ?? json['businessId'] ?? json['business_id'],
      ),
      storeLocationId: _toInt(
        json['StoreLocationID'] ??
            json['storeLocationId'] ??
            json['store_location_id'],
      ),
      storeId: _toInt(json['StoreID'] ?? json['storeId'] ?? json['store_id']),

      platformName: (json['platformName'] ?? json['platform_name'] ?? '')
          .toString(),
      storeName: (json['storeName'] ?? json['store_name'] ?? '').toString(),

      externalId:
          (json['externalId'] ??
                  json['external_id'] ??
                  json['orderNo'] ??
                  json['order_no'] ??
                  '')
              .toString(),

      processed: _toBool(
        json['processed'] ?? json['isProcessed'] ?? json['is_processed'],
      ),

      status: (json['status'] ?? json['order_status'] ?? '').toString(),

      totalAmount: _toInt(
        json['totalAmount'] ??
            json['total_amount'] ??
            json['total'] ??
            json['grandTotal'] ??
            json['grand_total'],
      ),

      createTimeEpoch: createEpoch,
      // label string biasanya "24-11-2025 14:10" dll
      createTimeLabel:
          (json['createTimeLabel'] ??
                  json['create_time_label'] ??
                  json['createTime'] ??
                  json['create_time'] ??
                  '')
              .toString(),

      updateTimeEpoch: updateEpoch,
      items: parsedItems,
    );
  }

  Map<String, dynamic> toJson() => {
    'idStoreOrder': idStoreOrder,
    'businessId': businessId,
    'storeLocationId': storeLocationId,
    'storeId': storeId,
    'platformName': platformName,
    'storeName': storeName,
    'externalId': externalId,
    'processed': processed,
    'status': status,
    'totalAmount': totalAmount,
    'createTimeEpoch': createTimeEpoch,
    'createTimeLabel': createTimeLabel,
    'updateTimeEpoch': updateTimeEpoch,
    'items': items.map((e) => e.toJson()).toList(),
  };
}

@immutable
class StoreOrderItem {
  final int qty;
  final int price;

  final String productName;

  final int productSkuId;
  final String sellerSku;

  final String skuImage;
  final String skuId;
  final String skuName;

  const StoreOrderItem({
    required this.qty,
    required this.price,
    required this.productName,
    required this.productSkuId,
    required this.sellerSku,
    required this.skuImage,
    required this.skuId,
    required this.skuName,
  });

  int get subtotal => qty * price;

  factory StoreOrderItem.fromJson(Map<String, dynamic> json) {
    return StoreOrderItem(
      qty: _toInt(json['qty'] ?? json['quantity']),
      price: _toInt(json['price'] ?? json['unitPrice'] ?? json['unit_price']),
      productName:
          (json['productName'] ??
                  json['product_name'] ??
                  json['sku_name'] ??
                  json['skuName'] ??
                  '')
              .toString(),

      productSkuId: _toInt(
        json['productSkuId'] ?? json['productSkuID'] ?? json['product_sku_id'],
      ),
      sellerSku: (json['sellerSku'] ?? json['seller_sku'] ?? '').toString(),

      skuImage: (json['skuImage'] ?? json['sku_image'] ?? json['image'] ?? '')
          .toString(),
      skuId: (json['sku_id'] ?? json['skuId'] ?? '').toString(),
      skuName: (json['sku_name'] ?? json['skuName'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'qty': qty,
    'price': price,
    'productName': productName,
    'productSkuId': productSkuId,
    'sellerSku': sellerSku,
    'skuImage': skuImage,
    'skuId': skuId,
    'skuName': skuName,
  };
}

/// ====== Helpers ======

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

bool _toBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().trim().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes';
}

/// kalau backend kadang kirim epoch ms, kita normalisasi ke seconds
int _normalizeEpochToSeconds(int epoch) {
  // 13 digits = ms
  if (epoch >= 1000000000000) return (epoch / 1000).floor();
  return epoch;
}
