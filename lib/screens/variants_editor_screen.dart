// lib/screens/variants_editor_screen.dart
import 'package:flutter/material.dart';
import 'package:wa_blast/widgets/variant_section_dynamic.dart';

class VariantsEditorResult {
  final List<Map<String, dynamic>> skusJson;
  final List<String> variantNames;
  final bool pricesUniform;
  final int? uniformBasePrice;

  VariantsEditorResult({
    required this.skusJson,
    required this.variantNames,
    required this.pricesUniform,
    required this.uniformBasePrice,
  });
}

class VariantsEditorScreen extends StatefulWidget {
  const VariantsEditorScreen({super.key, this.initialSkusJson});

  final List<Map<String, dynamic>>? initialSkusJson;

  @override
  State<VariantsEditorScreen> createState() => _VariantsEditorScreenState();
}

class _VariantsEditorScreenState extends State<VariantsEditorScreen> {
  final GlobalKey<VariantsSectionDynamicState> _variantsKey =
      GlobalKey<VariantsSectionDynamicState>();

  bool _saving = false;

  static const Color _blue = Color(0xFF2563EB);
  static const Color _text = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  List<String> _extractVariantNamesFromSkus(List<Map<String, dynamic>> skus) {
    final set = <String>{};
    for (final s in skus) {
      final attrs = (s['attributes'] as List?) ?? const [];
      for (final a in attrs) {
        final name = (a['name'] ?? '').toString().trim();
        if (name.isNotEmpty) set.add(name);
      }
    }
    return set.toList()..sort();
  }

  bool _isUniformPrice(List<Map<String, dynamic>> skus) {
    final prices = skus
        .map((e) => (e['price'] as int?) ?? 0)
        .where((p) => p > 0)
        .toList();
    if (prices.isEmpty) return false;
    final p0 = prices.first;
    for (final p in prices) {
      if (p != p0) return false;
    }
    return true;
  }

  int? _uniformBasePrice(List<Map<String, dynamic>> skus) {
    if (!_isUniformPrice(skus)) return null;
    final prices = skus
        .map((e) => (e['price'] as int?) ?? 0)
        .where((p) => p > 0)
        .toList();
    if (prices.isEmpty) return null;
    return prices.first;
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFFBBF24),
        content: Text(
          msg,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w700,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onSave() async {
    final st = _variantsKey.currentState;
    if (st == null) return;

    FocusScope.of(context).unfocus();

    if (!st.hasAtLeastOneRow) {
      _toast('Please add at least one option with a name.');
      return;
    }

    // Highlights options without a price (red) and checks every variant > 0.
    if (!st.validate()) {
      _toast('Please fill in a price for every variant.');
      return;
    }

    setState(() => _saving = true);
    try {
      final skusBuilt = st.buildSkus();
      if (skusBuilt.isEmpty) {
        _toast('Please add at least one option with a name.');
        return;
      }

      final skusJson = skusBuilt
          .map(
            (s) => {
              'code': s.code.trim().isEmpty ? null : s.code.trim(),
              'price': s.price,
              'attributes': s.attributes
                  .map((a) => {'name': a.name, 'value': a.value})
                  .toList(),
            },
          )
          .toList();

      final names = _extractVariantNamesFromSkus(skusJson);
      final uniform = _isUniformPrice(skusJson);
      final base = _uniformBasePrice(skusJson);

      Navigator.pop(
        context,
        VariantsEditorResult(
          skusJson: skusJson,
          variantNames: names,
          pricesUniform: uniform,
          uniformBasePrice: base,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _text,
        centerTitle: false,
        title: const Text(
          'Variants',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: _border),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text(
                      'Add the options customers can choose (e.g. Small, Large) '
                      'and set a price for each one.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: _muted,
                      ),
                    ),
                  ),
                  VariantsSectionDynamic(
                    key: _variantsKey,
                    initialSkus: widget.initialSkusJson,
                  ),
                ],
              ),
            ),
            if (_saving)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withOpacity(0.55),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _border)),
          ),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _blue.withOpacity(0.5),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(_saving ? 'Saving...' : 'Save'),
            ),
          ),
        ),
      ),
    );
  }
}
