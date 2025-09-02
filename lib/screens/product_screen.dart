import 'dart:io';
import 'package:intl/intl.dart';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wa_blast/constants/app_colors.dart';
import 'package:wa_blast/providers/product_provider.dart';

class ProductScreen extends StatelessWidget {
  const ProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorPrimary = _resolvePrimary(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        foregroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Product List',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pushReplacementNamed(context, '/splash'),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<ProductProvider>().refresh(),
          child: Consumer<ProductProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.isEmpty) {
                return _EmptyState(colorPrimary: colorPrimary);
              }

              // TODO: List product when not empty
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24 + 56),
                itemCount: provider.items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) =>
                    ListTile(title: Text(provider.items[i].name)),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 30),
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blueButton,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () async {
              // TODO: navigate to Add Product page
              await showAddProductSheet(context);
              // context.read<ProductProvider>().addDummy();
            },
            child: const Text(
              'Add new product',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  Color _resolvePrimary(BuildContext context) {
    // Pakai theme jika sudah diset, fallback ke biru yang “cantik & soft”
    final themePrimary = Theme.of(context).colorScheme.primary;
    if (themePrimary != const Color(0xff6200ee)) return themePrimary;
    return const Color(0xFF4C6EF5);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colorPrimary});
  final Color colorPrimary;

  @override
  Widget build(BuildContext context) {
    return Column(
      // supaya RefreshIndicator bisa bekerja
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Gambar di tengah
        Center(
          child: Image.asset(
            'assets/empty_box.png',
            width: 180,
            height: 180,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text(
            'No Product',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Please to create and add your product\nto the application',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.4, color: Color(0xFF6B7280)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

Future<void> showAddProductSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _AddProductSheet(),
  );
}

class _AddProductSheet extends StatefulWidget {
  const _AddProductSheet();

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _priceC = TextEditingController();
  final _stockC = TextEditingController();
  bool _available = true;

  File? _pickedFile; // TODO: hubungkan ke image picker kalau sudah siap

  @override
  void dispose() {
    _nameC.dispose();
    _priceC.dispose();
    _stockC.dispose();
    super.dispose();
  }

  bool get _isValid =>
      (_formKey.currentState?.validate() ?? false) &&
      _priceC.text.trim().isNotEmpty &&
      _stockC.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final primary = _resolvePrimary(context);
    final padBottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: padBottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) {
          return Column(
            mainAxisSize: MainAxisSize.min,
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
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Form(
                    key: _formKey,
                    onChanged: () => setState(() {}),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'New Product',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Product Photo
                        const Text(
                          'Product Photo',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            // TODO: buka image picker di sini
                            // final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                            // if (picked != null) setState(() => _pickedFile = File(picked.path));
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: DottedBorder(
                            options: RoundedRectDottedBorderOptions(
                              color: const Color(0xFF4C6EF5), // warna garis
                              strokeWidth: 2, // tebal garis
                              dashPattern: const <double>[
                                8,
                                6,
                              ], // panjang garis, jarak
                              radius: const Radius.circular(12), // radius sudut
                              padding: const EdgeInsets.all(
                                0,
                              ), // padding dalam border
                            ),
                            child: Container(
                              height: 120,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'Upload file',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Product Name
                        const Text(
                          'Product Name',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _Field(
                          controller: _nameC,
                          hintText: 'E.g Chicken',
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),

                        const SizedBox(height: 16),

                        // Price
                        const Text(
                          'Price',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _Field(
                          controller: _priceC,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          prefix: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Rp.',
                              style: TextStyle(color: Color(0xFF6B7280)),
                            ),
                          ),
                          hintText: 'E.g Chicken',
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                          onChanged: (t) {
                            // optional: format rupiah ringan
                            if (t.isEmpty) return;
                            final sel = _priceC.selection;
                            final digits = t.replaceAll('.', '');
                            final f = NumberFormat.decimalPattern('id');
                            final newText = f.format(int.tryParse(digits) ?? 0);
                            _priceC
                              ..text = newText
                              ..selection = sel.copyWith(
                                baseOffset: newText.length,
                                extentOffset: newText.length,
                              );
                          },
                        ),

                        const SizedBox(height: 16),

                        // Stock
                        const Text(
                          'Stock',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _Field(
                          controller: _stockC,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          hintText: 'E.g Chicken',
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),

                        const SizedBox(height: 16),

                        // Available
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Available Product',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Switch button to active the product',
                                  style: TextStyle(color: Color(0xFF6B7280)),
                                ),
                              ],
                            ),
                            Switch(
                              value: _available,
                              activeColor: Colors.white,
                              activeTrackColor: primary,
                              onChanged: (v) => setState(() => _available = v),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),

              // Footer button (sticky)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                child: SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isValid
                          ? primary
                          : const Color(0xFFE5E7EB),
                      foregroundColor: _isValid
                          ? Colors.white
                          : const Color(0xFF9CA3AF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: !_isValid
                        ? null
                        : () {
                            if (!_formKey.currentState!.validate()) return;
                            final provider = context.read<ProductProvider>();
                            provider.addDummy(); // ganti dengan add sebenarnya
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Product added successfully'),
                              ),
                            );
                          },
                    child: const Text(
                      'Add new product',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _resolvePrimary(BuildContext context) {
    final themePrimary = Theme.of(context).colorScheme.primary;
    if (themePrimary != const Color(0xff6200ee)) return themePrimary;
    return const Color(0xFF4C6EF5);
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.prefix,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        isDense: true,
        hintText: hintText,
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        prefixIcon: prefix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
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
    );
  }
}
