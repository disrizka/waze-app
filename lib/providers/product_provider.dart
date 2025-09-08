import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wa_blast/services/api_service.dart'; // ApiService

class Product {
  final String id;
  final String name;

  Product({required this.id, required this.name});
}

class ProductBrand {
  final String idProductBrand;
  final String name;

  ProductBrand({required this.idProductBrand, required this.name});
}

class ProductProvider with ChangeNotifier {
  final List<Product> _items = [];
  final List<ProductBrand> _brands = [];
  bool _isLoading = false;

  List<Product> get items => List.unmodifiable(_items);
  List<ProductBrand> get brands => List.unmodifiable(_brands);
  bool get isLoading => _isLoading;
  bool get isEmpty => _items.isEmpty;

  // Fungsi untuk mengambil ID bisnis dari SharedPreferences
  Future<String?> _getBusinessId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('activeBizId');
  }

  // Fungsi untuk fetch kategori produk
  Future<void> fetchProductCategories(BuildContext context) async {
    final idBusiness = await _getBusinessId();

    if (idBusiness == null || idBusiness.isEmpty) {
      return; // Handle jika ID kosong
    }

    _isLoading = true;
    notifyListeners();

    try {
      final res = await ApiService.get(
        context,
        '/waveup/$idBusiness/product-category',
        withAccessToken: true,
      );

      if (res != null && res.body.isNotEmpty) {
        final responseBody = json.decode(res.body); // Decode JSON response
        if (responseBody['data'] != null) {
          final List<Product> fetchedProducts = [];
          for (var productData in responseBody['data']) {
            fetchedProducts.add(
              Product(id: productData['id'], name: productData['name']),
            );
          }

          _items.clear();
          _items.addAll(fetchedProducts);
        }
      }
    } catch (error) {
      print("Error fetching products: $error");
    }

    _isLoading = false;
    notifyListeners();
  }

  // Fungsi untuk fetch merek produk
  Future<void> fetchProductBrands(BuildContext context) async {
    final idBusiness = await _getBusinessId();

    if (idBusiness == null || idBusiness.isEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      final res = await ApiService.get(
        context,
        '/waveup/$idBusiness/product-brand',
        withAccessToken: true,
      );

      if (res != null && res.body.isNotEmpty) {
        final responseBody = json.decode(res.body); // Decode JSON response

        if (responseBody['data'] is List) {
          final List<dynamic> brandDataList = responseBody['data'];

          final List<ProductBrand> fetchedBrands = [];
          for (var brandData in brandDataList) {
            if (brandData != null) {
              fetchedBrands.add(
                ProductBrand(
                  idProductBrand: brandData['idProductBrand'] ?? '',
                  name: brandData['name'] ?? '',
                ),
              );
            }
          }

          _brands.clear();
          _brands.addAll(fetchedBrands);
        } else {
          print("Invalid data format: 'data' is not a List");
        }
      }
    } catch (error) {
      print("Error fetching product brands: $error");
    }

    _isLoading = false;
    notifyListeners();
  }

  // Fungsi untuk menambah brand produk
  Future<void> addProductBrand(BuildContext context, String name) async {
    final idBusiness = await _getBusinessId();
    if (idBusiness == null || idBusiness.isEmpty) {
      print("Business ID is not available.");
      return; // Tidak bisa menambah brand jika idBusiness tidak ada
    }

    final Map<String, dynamic> payload = {'name': name};

    try {
      final response = await ApiService.post(
        context,
        '/waveup/$idBusiness/product-brand', // Gantilah {idBusiness} dengan idBusiness yang sesuai
        payload,
      );

      if (response != null && response.statusCode == 200) {
        // Berhasil menambahkan brand
        print('Brand added successfully: ${response.body}');
        // Refresh daftar brands setelah berhasil
        await fetchProductBrands(context);
      } else {
        print('Failed to add brand');
      }
    } catch (error) {
      print('Error occurred: $error');
    }
  }

  // Fungsi untuk refresh data produk dan merek
  Future<void> refresh(BuildContext context) async {
    await fetchProductCategories(context); // Fetch product categories
    await fetchProductBrands(context); // Fetch product brands
  }

  // Fungsi untuk menambah produk dummy
  void addDummy() {
    _items.add(Product(id: DateTime.now().toIso8601String(), name: 'Sample'));
    notifyListeners();
  }
}
