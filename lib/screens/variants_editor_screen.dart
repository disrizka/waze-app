// lib/screens/variants_editor_screen.dart
import 'dart:async';

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

  // ✅ show hint only after table likely appears (after user inputs variant values)
  bool _showScrollHint = false;
  Timer? _hintTimer;

  // Theme tokens (blue & white)
  static const Color _blue = Color(0xFF2563EB); // blue-600
  static const Color _blueDark = Color(0xFF1D4ED8); // blue-700
  static const Color _bg = Color(0xFFF8FAFF); // very light blue
  static const Color _text = Color(0xFF0F172A); // slate-900
  static const Color _muted = Color(0xFF64748B); // slate-500
  static const Color _border = Color(0xFFE2E8F0); // slate-200

  // ✅ Prefill buffers for VariantsSectionDynamic
  List<Map<String, dynamic>>? _initialGroups;
  List<Map<String, dynamic>>? _initialSkus;

  @override
  void initState() {
    super.initState();

    // ✅ Build initialGroups from initialSkusJson (edit mode / reopen)
    final initSkus = widget.initialSkusJson;
    if (initSkus != null && initSkus.isNotEmpty) {
      _initialSkus = initSkus;

      final Map<String, Set<String>> map = {};
      for (final s in initSkus) {
        final attrs = (s['attributes'] as List?) ?? const [];
        for (final a in attrs) {
          final name = (a['name'] ?? '').toString().trim();
          final value = (a['value'] ?? '').toString().trim();
          if (name.isEmpty || value.isEmpty) continue;
          map.putIfAbsent(name, () => <String>{}).add(value);
        }
      }

      _initialGroups = map.entries
          .map((e) => {'name': e.key, 'values': e.value.toList()..sort()})
          .toList();
    }

    // ✅ Poll state VariantsSectionDynamic tanpa mengubah file widget tsb.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hintTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
        final shouldShow = _shouldShowHorizontalHint();
        if (!mounted) return;
        if (shouldShow != _showScrollHint) {
          setState(() => _showScrollHint = shouldShow);
        }
      });
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _hintTimer = null;
    super.dispose();
  }

  bool _shouldShowHorizontalHint() {
    final st = _variantsKey.currentState;
    if (st == null) return false;
    if (!st.hasAtLeastOneRow) return false;

    final skus = st.buildSkus();
    if (skus.isEmpty) return false;

    for (final s in skus) {
      if (s.attributes.isNotEmpty) return true;
      if (s.attributes.any((a) => (a.value).trim().isNotEmpty)) return true;
    }
    return false;
  }

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFFBBF24), // yellow-400
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

    if (!st.hasAtLeastOneRow) {
      _toast('Please add at least one variant row.');
      return;
    }

    setState(() => _saving = true);
    try {
      final skusBuilt = st.buildSkus();

      if (skusBuilt.isEmpty) {
        _toast('Please add at least one variant row.');
        return;
      }

      // ✅ FIX: price is mandatory for every SKU downstream (Add/Edit Product
      // screen blocks submit if any variant has no price), so we must catch
      // this here instead of silently saving price as null and leaving the
      // user stuck on a permanently greyed-out "Add new product" button.
      final missingPrice = skusBuilt.any((s) => s.price <= 0);
      if (missingPrice) {
        _toast('Please fill in a price for every variant.');
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

  Widget _topInfo() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_blue, _blueDark],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: _TopCopy()),
        ],
      ),
    );
  }

  Widget _horizontalScrollHint() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // blue-50
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)), // blue-200
      ),
      child: Row(
        children: const [
          Icon(Icons.swipe_rounded, color: _blue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tip: SKU Code is optional, but Price is required for every variant.',
              style: TextStyle(
                color: _muted,
                height: 1.25,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(width: 6),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _blue),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overlay = _saving;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _text,
        title: const Text(
          'Variants',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _PrimaryPillButton(
              label: _saving ? 'Saving...' : 'Save',
              loading: _saving,
              onTap: _saving ? null : _onSave,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _topInfo(),
                  const SizedBox(height: 12),
                  if (_showScrollHint) ...[
                    _horizontalScrollHint(),
                    const SizedBox(height: 10),
                  ],
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: VariantsSectionDynamic(
                      key: _variantsKey,
                      initialGroups: _initialGroups,
                      initialSkus: _initialSkus,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF), // blue-50
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.info_outline_rounded, color: _blue),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tip: SKU Code is optional, but Price is required for every variant before saving.',
                            style: TextStyle(
                              color: _muted,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (overlay)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withOpacity(0.55),
                  child: const Center(child: _SavingIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopCopy extends StatelessWidget {
  const _TopCopy();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Build your variants',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        SizedBox(height: 3),
        Text(
          'Add variant options (e.g. Color, Size). SKU code is optional, but Price is required for every variant.',
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PrimaryPillButton extends StatelessWidget {
  const _PrimaryPillButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final VoidCallback? onTap;

  static const Color _blue = Color(0xFF2563EB);
  static const Color _blueDark = Color(0xFF1D4ED8);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [_blue, _blueDark],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 14,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
              ] else ...[
                const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavingIndicator extends StatelessWidget {
  const _SavingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          SizedBox(width: 12),
          Text(
            'Saving…',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
