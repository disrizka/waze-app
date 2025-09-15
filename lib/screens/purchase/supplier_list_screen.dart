import 'package:flutter/material.dart';

class SupplierListScreen extends StatelessWidget {
  const SupplierListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pushReplacementNamed(context, '/splash'),
        ),
        title: const Text('Purchase'),
      ),
      body: const _PurchaseList(),
    );
  }
}

class _PurchaseList extends StatelessWidget {
  const _PurchaseList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(),
    );
  }
}
