import 'package:flutter/material.dart';

class ProductPickerSheet extends StatelessWidget {
  final String title;
  final TextEditingController searchController;
  final String searchHintText;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final Future<void> Function()? onClearSearch;
  final Future<void> Function()? onFilterPressed;
  final String? filterSummary;
  final Widget body;
  final String footerText;
  final Future<void> Function() onUseSelected;
  final String useSelectedLabel;
  final Color primaryColor;
  final EdgeInsets minimumSafeArea;
  final double heightFactor;
  final double maxWidth;

  const ProductPickerSheet({
    super.key,
    required this.title,
    required this.searchController,
    required this.searchHintText,
    required this.body,
    required this.footerText,
    required this.onUseSelected,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.onClearSearch,
    this.onFilterPressed,
    this.filterSummary,
    this.useSelectedLabel = 'Use selected',
    this.primaryColor = const Color(0xFF4069E6),
    this.minimumSafeArea = const EdgeInsets.fromLTRB(16, 12, 16, 16),
    this.heightFactor = 0.9,
    this.maxWidth = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: minimumSafeArea,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * heightFactor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PickerSheetHeader(title: title),
                Row(
                  children: [
                    Expanded(
                      child: Material(
                        elevation: 0,
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        child: TextField(
                          controller: searchController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: onSearchSubmitted,
                          onChanged: onSearchChanged,
                          decoration: InputDecoration(
                            hintText: searchHintText,
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                            ),
                            suffixIcon: (searchController.text.trim().isEmpty)
                                ? null
                                : IconButton(
                                    onPressed: () => onClearSearch?.call(),
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 20,
                                    ),
                                    splashRadius: 18,
                                  ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (onFilterPressed != null) ...[
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () => onFilterPressed?.call(),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Icon(Icons.tune_rounded, size: 20),
                        ),
                      ),
                    ],
                  ],
                ),
                if ((filterSummary ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      filterSummary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Expanded(child: body),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                        child: Text(
                          footerText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: () => onUseSelected(),
                          icon: const Icon(Icons.check_rounded, size: 24),
                          label: Text(useSelectedLabel),
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: .2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProductPickerListCard extends StatelessWidget {
  final String title;
  final String? priceText;
  final String? stockText;
  final Color stockColor;
  final String? imageUrl;
  final int selectedQty;
  final VoidCallback onChoose;
  final bool disabled;
  final bool showOutOfStockOverlay;
  final String chooseLabel;
  final String unavailableLabel;
  final Color primaryColor;

  const ProductPickerListCard({
    super.key,
    required this.title,
    this.priceText,
    required this.onChoose,
    this.stockText,
    this.stockColor = const Color(0xFF475569),
    this.imageUrl,
    this.selectedQty = 0,
    this.disabled = false,
    this.showOutOfStockOverlay = false,
    this.chooseLabel = 'Choose',
    this.unavailableLabel = 'Unavailable',
    this.primaryColor = const Color(0xFF4069E6),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 62,
                    height: 62,
                    child: _ProductThumb(imageUrl: imageUrl),
                  ),
                ),
                if (showOutOfStockOverlay)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.block_rounded, color: Colors.red),
                      ),
                    ),
                  ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: _CountBadge(count: selectedQty),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                  if ((priceText ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      priceText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                  ],
                  if ((stockText ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      stockText!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: stockColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 96,
              height: 34,
              child: ElevatedButton(
                onPressed: disabled ? null : onChoose,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: disabled ? Colors.grey[300] : primaryColor,
                  foregroundColor: disabled ? Colors.grey[600] : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    disabled ? unavailableLabel : chooseLabel,
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String formatThousands(int value) {
  final negative = value < 0;
  String s = value.abs().toString();
  if (s.length <= 3) return negative ? '-$s' : s;
  final buffer = StringBuffer();
  int count = 0;
  for (int i = s.length - 1; i >= 0; i--) {
    buffer.write(s[i]);
    count++;
    if (count == 3 && i != 0) {
      buffer.write('.');
      count = 0;
    }
  }
  final result = buffer.toString().split('').reversed.join();
  return negative ? '-$result' : result;
}

class _PickerSheetHeader extends StatelessWidget {
  final String title;
  const _PickerSheetHeader({required this.title});

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
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
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

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Semantics(
      label: 'Selected $count',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF4069E6),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  final String? imageUrl;
  const _ProductThumb({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if ((imageUrl ?? '').trim().isEmpty) {
      return const _FallbackThumb();
    }
    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const _FallbackThumb(),
    );
  }
}

class _FallbackThumb extends StatelessWidget {
  const _FallbackThumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Color(0xFFA3A3A3),
        ),
      ),
    );
  }
}
