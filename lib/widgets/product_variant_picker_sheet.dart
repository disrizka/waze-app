import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wa_blast/models/product_models/product_model.dart';

typedef VariantUnitPriceResolver = int Function(ProductSku? matched, int qty);
typedef VariantBoolResolver = bool Function(ProductSku? matched, int qty);
typedef VariantTextResolver =
    String Function(ProductSku? matched, int qty, int unitPrice);
typedef VariantColorResolver = Color Function(ProductSku? matched, int qty);

class VariantPickerSelection {
  final ProductSku sku;
  final int qty;
  final int unitPrice;

  const VariantPickerSelection({
    required this.sku,
    required this.qty,
    required this.unitPrice,
  });
}

class ProductVariantPickerSheet extends StatefulWidget {
  final Product product;
  final String title;
  final String? caption;

  final bool showPriceInfo;
  final bool showStockInfo;
  final bool showSkuCode;
  final bool showWholesaleInfo;
  final bool enforceValidOption;
  final bool showUnitSuffix;

  final int initialQty;
  final String qtyLabel;
  final String unitSuffix;
  final Color primaryColor;
  final Color dividerColor;
  final Color secondaryTextColor;
  final EdgeInsets safeAreaMinimum;
  final NumberFormat moneyFormatter;

  final VariantUnitPriceResolver? unitPriceResolver;
  final VariantBoolResolver? canIncreaseQty;
  final VariantBoolResolver? isConfirmEnabled;
  final VariantTextResolver? confirmLabelResolver;
  final VariantTextResolver? stockTextResolver;
  final VariantColorResolver? stockColorResolver;

  ProductVariantPickerSheet({
    super.key,
    required this.product,
    this.title = 'Choose Variants',
    this.caption,
    this.showPriceInfo = false,
    this.showStockInfo = false,
    this.showSkuCode = true,
    this.showWholesaleInfo = false,
    this.enforceValidOption = false,
    this.showUnitSuffix = false,
    this.initialQty = 1,
    this.qtyLabel = 'Quantity',
    this.unitSuffix = ' / pcs',
    this.primaryColor = const Color(0xFF4069E6),
    this.dividerColor = const Color(0xFFE5E7EB),
    this.secondaryTextColor = const Color(0xFF64748B),
    this.safeAreaMinimum = const EdgeInsets.fromLTRB(16, 12, 16, 0),
    NumberFormat? moneyFormatter,
    this.unitPriceResolver,
    this.canIncreaseQty,
    this.isConfirmEnabled,
    this.confirmLabelResolver,
    this.stockTextResolver,
    this.stockColorResolver,
  }) : moneyFormatter = moneyFormatter ?? NumberFormat.decimalPattern('id_ID');

  @override
  State<ProductVariantPickerSheet> createState() =>
      _ProductVariantPickerSheetState();
}

class _ProductVariantPickerSheetState extends State<ProductVariantPickerSheet> {
  final Map<String, String> _selectedAttrs = {};
  late int _qty;

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQty < 1 ? 1 : widget.initialQty;

    final attrsList = _extractAttributes(widget.product.productSkus);
    for (final e in attrsList.entries) {
      if (e.value.length == 1) {
        _selectedAttrs[e.key] = e.value.first;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final attrsList = _extractAttributes(product.productSkus);

    ProductSku? matchedSku;
    for (final s in product.productSkus) {
      if (_isSkuMatch(s, _selectedAttrs, requiredCount: attrsList.length)) {
        matchedSku = s;
        break;
      }
    }

    final int unitPrice =
        widget.unitPriceResolver?.call(matchedSku, _qty) ??
        matchedSku?.price ??
        product.basePrice ??
        0;

    final bool canIncrease =
        widget.canIncreaseQty?.call(matchedSku, _qty) ?? true;
    final bool ctaEnabled =
        widget.isConfirmEnabled?.call(matchedSku, _qty) ??
        (matchedSku != null && _qty > 0);

    final String ctaLabel =
        widget.confirmLabelResolver?.call(matchedSku, _qty, unitPrice) ??
        ((matchedSku == null) ? 'Pilih semua varian' : 'Add to cart');

    final String stockText =
        widget.stockTextResolver?.call(matchedSku, _qty, unitPrice) ?? '';
    final Color stockColor =
        widget.stockColorResolver?.call(matchedSku, _qty) ??
        widget.secondaryTextColor;

    final int basePrice = matchedSku?.price ?? product.basePrice ?? 0;
    final List<ProductPrice> wholesaleTiers = List<ProductPrice>.from(
      product.productPrices,
    )..sort((a, b) => a.minQty.compareTo(b.minQty));

    return Container(
      color: Colors.white,
      child: SafeArea(
        minimum: widget.safeAreaMinimum,
        child: Column(
          children: [
            _VariantSheetHeader(
              title: widget.title,
              caption: widget.caption ?? product.name,
            ),
            const SizedBox(height: 4),
            _VariantSection(
              dividerColor: widget.dividerColor,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _VariantThumb(url: product.primaryImageUrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (widget.showPriceInfo) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Rp ${widget.moneyFormatter.format(unitPrice)}'
                            '${widget.showUnitSuffix ? widget.unitSuffix : ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          if (widget.showWholesaleInfo &&
                              wholesaleTiers.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Harga normal: Rp ${widget.moneyFormatter.format(basePrice)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: widget.secondaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Harga grosir:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: widget.secondaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              spacing: 6,
                              runSpacing: 2,
                              children: wholesaleTiers.map((t) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: widget.dividerColor,
                                    ),
                                  ),
                                  child: Text(
                                    '≥ ${t.minQty} : Rp ${widget.moneyFormatter.format(t.price)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                        if (widget.showSkuCode && matchedSku != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'SKU Code: ${matchedSku.code}',
                            style: TextStyle(
                              color: widget.secondaryTextColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        if (widget.showStockInfo &&
                            stockText.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 16,
                                color: widget.secondaryTextColor,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  stockText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: stockColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: attrsList.entries.map((e) {
                  final attr = e.key;
                  final values = e.value.toList()..sort();
                  final selected = _selectedAttrs[attr];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _VariantSection(
                      dividerColor: widget.dividerColor,
                      title: attr,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: values.map((val) {
                          final isSel = selected == val;
                          final enabled = widget.enforceValidOption
                              ? _isValueEnabled(
                                  attr,
                                  val,
                                  _selectedAttrs,
                                  product.productSkus,
                                )
                              : true;

                          return ChoiceChip(
                            label: Text(val),
                            selected: isSel,
                            onSelected: enabled
                                ? (_) =>
                                      setState(() => _selectedAttrs[attr] = val)
                                : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            selectedColor: widget.primaryColor.withValues(
                              alpha: .12,
                            ),
                            labelStyle: TextStyle(
                              fontWeight: isSel
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: !enabled
                                  ? const Color(0xFF9CA3AF)
                                  : (isSel
                                        ? widget.primaryColor
                                        : const Color(0xFF111827)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: widget.dividerColor)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.qtyLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Container(
                          height: 36,
                          decoration: BoxDecoration(
                            border: Border.all(color: widget.dividerColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: _qty > 1
                                    ? () => setState(() => _qty--)
                                    : null,
                                icon: const Icon(Icons.remove_rounded),
                              ),
                              Text(
                                '$_qty',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: canIncrease
                                    ? () => setState(() => _qty++)
                                    : null,
                                icon: const Icon(Icons.add_rounded),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (!ctaEnabled || matchedSku == null)
                            ? null
                            : () {
                                Navigator.pop<VariantPickerSelection>(
                                  context,
                                  VariantPickerSelection(
                                    sku: matchedSku!,
                                    qty: _qty,
                                    unitPrice: unitPrice,
                                  ),
                                );
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: widget.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          ctaLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, Set<String>> _extractAttributes(List<ProductSku> skus) {
    final result = <String, Set<String>>{};
    for (final sku in skus) {
      for (final attr in sku.attributes) {
        (result[attr.name] ??= <String>{}).add(attr.value);
      }
    }
    return result;
  }

  bool _isSkuMatch(
    ProductSku sku,
    Map<String, String> sel, {
    required int requiredCount,
  }) {
    for (final entry in sel.entries) {
      final ok = sku.attributes.any(
        (a) =>
            a.name.toLowerCase() == entry.key.toLowerCase() &&
            a.value == entry.value,
      );
      if (!ok) return false;
    }
    return sel.length == requiredCount;
  }

  bool _isValueEnabled(
    String attr,
    String val,
    Map<String, String> currentSel,
    List<ProductSku> allSkus,
  ) {
    final trial = Map<String, String>.from(currentSel)..[attr] = val;
    return allSkus.any((sku) {
      for (final e in trial.entries) {
        final ok = sku.attributes.any(
          (a) =>
              a.name.toLowerCase() == e.key.toLowerCase() && a.value == e.value,
        );
        if (!ok) return false;
      }
      return true;
    });
  }
}

class _VariantSheetHeader extends StatelessWidget {
  final String title;
  final String? caption;

  const _VariantSheetHeader({required this.title, this.caption});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    if ((caption ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        caption!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.black54),
                tooltip: 'Close',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VariantSection extends StatelessWidget {
  final String? title;
  final Widget child;
  final Color dividerColor;

  const _VariantSection({
    this.title,
    required this.child,
    required this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((title ?? '').trim().isNotEmpty) ...[
            Text(title!, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

class _VariantThumb extends StatelessWidget {
  final String? url;
  const _VariantThumb({this.url});

  @override
  Widget build(BuildContext context) {
    if ((url ?? '').trim().isEmpty) {
      return _fallback();
    }
    return Image.network(
      url!,
      width: 72,
      height: 72,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      width: 72,
      height: 72,
      color: const Color(0xFFF3F4F6),
      child: const Icon(Icons.image, color: Color(0xFFA3A3A3)),
    );
  }
}
