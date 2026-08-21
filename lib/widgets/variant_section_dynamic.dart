import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:wa_blast/providers/product_provider.dart';

/// =========================
/// Controllers, Models & Utils
/// =========================

class VariantGroupController {
  final TextEditingController nameC = TextEditingController();
  final TextEditingController valuesC = TextEditingController();

  List<String> get values {
    final raw = valuesC.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final seen = <String>{};
    final out = <String>[];
    for (final v in raw) {
      if (seen.add(v)) out.add(v);
    }
    return out;
  }

  void dispose() {
    nameC.dispose();
    valuesC.dispose();
  }
}

class VariantCombo {
  final Map<String, String> attrs;
  final TextEditingController skuName = TextEditingController(); // no spaces
  final TextEditingController price = TextEditingController(); // IDR number

  VariantCombo(this.attrs);

  void dispose() {
    skuName.dispose();
    price.dispose();
  }
}

String formatIdNumber(String t) {
  final digits = t.replaceAll('.', '');
  final n = int.tryParse(digits) ?? 0;
  final f = NumberFormat.decimalPattern('id'); // thousands with dots
  return f.format(n);
}

int parseIdInt(String s) {
  final digits = s.replaceAll('.', '').replaceAll(',', '').trim();
  return int.tryParse(digits) ?? 0;
}

final TextInputFormatter skuNoSpaceFormatter = TextInputFormatter.withFunction((
  oldValue,
  newValue,
) {
  final replaced = newValue.text.replaceAll(RegExp(r'\s+'), '');
  return newValue.copyWith(
    text: replaced,
    selection: TextSelection.collapsed(offset: replaced.length),
  );
});

String? skuNoSpaceValidator(String? v) {
  final s = (v ?? '').trim();
  if (RegExp(r'\s').hasMatch(s)) return 'No spaces allowed';
  return null;
}

/// =========================
/// N-level Cartesian builder (Main + up to 4 subs)
/// =========================
/// Only the first group (main) is required to have values. Sub groups are used
/// only if BOTH name and values are provided.
List<VariantCombo> buildVariantCombosN({
  required VariantGroupController main,
  List<VariantGroupController> subs = const [],
}) {
  final mainName = main.nameC.text.trim().isEmpty
      ? 'Main Variant'
      : main.nameC.text.trim();
  final mainVals = main.values;
  if (mainVals.isEmpty) return <VariantCombo>[];

  // Collect active dimensions: [(name, values)]
  final dims = <MapEntry<String, List<String>>>[MapEntry(mainName, mainVals)];

  for (final s in subs) {
    final n = s.nameC.text.trim();
    final v = s.values;
    if (n.isNotEmpty && v.isNotEmpty) {
      dims.add(MapEntry(n, v));
    }
  }

  // Cartesian product across dims
  List<Map<String, String>> acc = [<String, String>{}];
  for (final d in dims) {
    final next = <Map<String, String>>[];
    for (final partial in acc) {
      for (final val in d.value) {
        final m = Map<String, String>.from(partial);
        m[d.key] = val;
        next.add(m);
      }
    }
    acc = next;
  }

  return acc.map((attrs) => VariantCombo(attrs)).toList();
}

/// =========================
/// VariantsSectionDynamic (Unified rows UI, 4 subs)
/// =========================
class VariantsSectionDynamic extends StatefulWidget {
  const VariantsSectionDynamic({
    super.key,
    this.initialGroups, // OPTIONAL: untuk prefill dari server (edit)
    this.initialSkus, // OPTIONAL: untuk prefill dari server (edit)
  });

  /// initialGroups: List<Map<String, dynamic>>
  ///   each: {"name": "Color", "values": ["Blue", "White"]}
  final List<Map<String, dynamic>>? initialGroups;

  /// initialSkus: List<Map<String, dynamic>>
  ///   each: {"code": "SMBLUE128", "price": 11000000,
  ///          "attributes": [{"name":"Color","value":"Blue"},{"name":"Storage","value":"128GB"}]}
  ///   atau  {"attributes": {"Color":"Blue","Storage":"128GB"}} juga diterima.
  final List<Map<String, dynamic>>? initialSkus;

  @override
  State<VariantsSectionDynamic> createState() => VariantsSectionDynamicState();
}

class VariantsSectionDynamicState extends State<VariantsSectionDynamic> {
  /// Row 0 = Main; Rows 1..4 = Sub Variants (max 4)
  static const int _maxRows = 5; // 1 main + 4 subs
  final List<VariantGroupController> _groups = [VariantGroupController()];

  List<VariantCombo> _combos = [];

  @override
  void initState() {
    super.initState();
    _rebuildCombos();

    // Prefill dari server bila ada (EDIT SHEET)
    if ((widget.initialGroups?.isNotEmpty ?? false) ||
        (widget.initialSkus?.isNotEmpty ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        hydrateFromServer(
          groups: widget.initialGroups ?? const [],
          skus: widget.initialSkus ?? const [],
        );
      });
    }
  }

  @override
  void dispose() {
    for (final g in _groups) {
      g.dispose();
    }
    for (final c in _combos) {
      c.dispose();
    }
    super.dispose();
  }

  void _rebuildCombos() {
    for (final c in _combos) {
      c.dispose();
    }
    final main = _groups.first;
    final subs = _groups.length > 1
        ? _groups.sublist(1)
        : const <VariantGroupController>[];
    final combos = buildVariantCombosN(main: main, subs: subs);
    setState(() => _combos = combos);
  }

  void _addRow() {
    if (_groups.length >= _maxRows) return;
    setState(() => _groups.add(VariantGroupController()));
    _rebuildCombos();
  }

  void _removeRow(int index) {
    if (index == 0) return; // can't remove Main
    if (index < 0 || index >= _groups.length) return;
    setState(() {
      final removed = _groups.removeAt(index);
      removed.dispose();
    });
    _rebuildCombos();
  }

  /// ========= PUBLIC API =========
  /// Bisa dipanggil dari Edit Sheet via variantsKey.currentState?.hydrateFromServer(...)
  void hydrateFromServer({
    required List<Map<String, dynamic>> groups,
    required List<Map<String, dynamic>> skus,
  }) {
    // 1) Tulis Variant Name & Variant Values ke controllers
    if (groups.isNotEmpty) {
      _ensureGroupRowCount(groups.length);

      for (int i = 0; i < groups.length; i++) {
        final g = groups[i];
        final name = (g['name'] ?? '').toString().trim();
        final valsAny = g['values'];

        final List<String> values = (valsAny is List)
            ? valsAny.map((e) => e.toString()).toList()
            : (valsAny is String)
            ? valsAny.split(',').map((e) => e.trim()).toList()
            : const <String>[];

        _groups[i].nameC.text = name;
        _groups[i].valuesC.text = values.join(',');
      }
    }

    // 2) Bangun grid kombinasi kartesius
    _rebuildCombos();

    // 3) Isi SKU code & price berdasarkan atribut yang cocok
    if (skus.isNotEmpty && _combos.isNotEmpty) {
      // Normalisasi skus -> list of {code, price, attrs: Map<String,String>}
      final normalized = <Map<String, dynamic>>[];
      for (final s in skus) {
        final code = (s['code'] ?? '').toString();
        final price = (s['price'] is num)
            ? (s['price'] as num).toInt()
            : int.tryParse('${s['price'] ?? ''}') ?? 0;

        Map<String, String> attrsMap = {};
        final attrsAny = s['attributes'];

        if (attrsAny is Map) {
          // { "Color":"Blue", "Storage":"128GB" }
          attrsMap = attrsAny.map((k, v) => MapEntry('$k', '$v'));
        } else if (attrsAny is List) {
          // [ {"name":"Color","value":"Blue"}, ... ]
          for (final e in attrsAny) {
            if (e is Map) {
              final n = (e['name'] ?? '').toString();
              final v = (e['value'] ?? '').toString();
              if (n.isNotEmpty && v.isNotEmpty) {
                attrsMap[n] = v;
              }
            }
          }
        }

        normalized.add({'code': code, 'price': price, 'attrs': attrsMap});
      }

      // Cocokkan ke setiap combo
      for (final combo in _combos) {
        final target = normalized.firstWhere(
          (n) => _attrsEqual(combo.attrs, (n['attrs'] as Map<String, String>)),
          orElse: () => const {'code': '', 'price': 0, 'attrs': {}},
        );

        final code = (target['code'] ?? '').toString();
        final price = (target['price'] is num)
            ? (target['price'] as num).toInt()
            : 0;

        if (code.isNotEmpty) combo.skuName.text = code;
        if (price > 0)
          combo.price.text = NumberFormat.decimalPattern('id').format(price);
      }
      setState(() {}); // refresh UI
    }
  }

  bool _attrsEqual(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k)) return false;
      if (a[k] != b[k]) return false;
    }
    return true;
  }

  void _ensureGroupRowCount(int count) {
    while (_groups.length < count && _groups.length < _maxRows) {
      _groups.add(VariantGroupController());
    }
    while (_groups.length > count && _groups.length > 1) {
      final removed = _groups.removeLast();
      removed.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFE5E7EB);
    const panel = Color(0xFFF9FAFB);
    const textMain = Color(0xFF111827);
    const textSub = Color(0xFF6B7280);

    Widget _input({
      required TextEditingController controller,
      String? hint,
      TextInputType? keyboardType,
      List<TextInputFormatter>? inputFormatters,
      FormFieldValidator<String>? validator,
      ValueChanged<String>? onChanged,
    }) {
      return TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        onChanged: onChanged,
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border),
          ),
        ),
      );
    }

    Widget header() {
      return Row(
        children: const [
          Expanded(
            flex: 4,
            child: Text(
              'Variant Name',
              style: TextStyle(fontWeight: FontWeight.w600, color: textSub),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              'Variant Values',
              style: TextStyle(fontWeight: FontWeight.w600, color: textSub),
            ),
          ),
          SizedBox(width: 44),
        ],
      );
    }

    String _nameHintFor(int index) {
      switch (index) {
        case 0:
          return 'e.g., Size';
        case 1:
          return 'e.g., Color';
        case 2:
          return 'e.g., Material';
        case 3:
          return 'e.g., Style';
        case 4:
          return 'e.g., Pattern';
        default:
          return 'Variant';
      }
    }

    String _valuesHintFor(int index) {
      switch (index) {
        case 0:
          return 'Type a value, e.g., S';
        case 1:
          return 'Type a value, e.g., Blue';
        case 2:
          return 'Type a value, e.g., Cotton';
        case 3:
          return 'Type a value, e.g., Slim';
        case 4:
          return 'Type a value, e.g., Plain';
        default:
          return 'Type a value';
      }
    }

    Widget row({
      required int index,
      required VariantGroupController ctrl,
      required bool isLast,
    }) {
      return Row(
        children: [
          Expanded(
            flex: 4,
            child: _input(
              controller: ctrl.nameC,
              hint: _nameHintFor(index),
              onChanged: (_) => _rebuildCombos(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: _ChipsValueField(
              controller: ctrl,
              hintText: _valuesHintFor(index),
              onChanged: _rebuildCombos,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Column(
              children: [
                if (isLast && _groups.length < _maxRows)
                  IconButton(
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'Add row',
                    onPressed: _addRow,
                  ),
                if (index > 0)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: 'Remove row',
                    onPressed: () => _removeRow(index),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    Widget variantsMatrixCard() {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: panel,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Variants',
              style: TextStyle(fontWeight: FontWeight.w700, color: textMain),
            ),
            const SizedBox(height: 8),
            header(),
            const SizedBox(height: 6),
            ..._groups.asMap().entries.map((e) {
              final i = e.key;
              final c = e.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: i == _groups.length - 1 ? 0 : 8,
                ),
                child: row(index: i, ctrl: c, isLast: i == _groups.length - 1),
              );
            }),
          ],
        ),
      );
    }

    Widget chipsPreview() {
      final chips = <Widget>[];
      for (var i = 0; i < _groups.length; i++) {
        final g = _groups[i];
        final name = g.nameC.text.trim().isEmpty
            ? (i == 0 ? 'Main Variant' : 'Sub Variant ${i}')
            : g.nameC.text.trim();
        chips.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              'Variant: $name',
              style: const TextStyle(
                color: textMain,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    }

    Widget skuTable() {
      const border = Color(0xFFE5E7EB);
      const textSub = Color(0xFF6B7280);
      const textMain = Color(0xFF111827);

      if (_combos.isEmpty) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            border: Border.all(color: const Color(0xFFFDE68A)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Enter at least one value in the first row to show the SKU table.',
            style: TextStyle(color: Color(0xFF7C6A00)),
          ),
        );
      }

      return Container(
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 44,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 72,
              columns: const [
                DataColumn(
                  label: Text(
                    'Attributes',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textSub,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'SKU & Price',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textSub,
                    ),
                  ),
                ),
              ],
              rows: _combos.map((c) {
                final title = c.attrs.values.join(' • ');
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        title,
                        style: const TextStyle(
                          color: textMain,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DataCell(
                      _SkuPriceCell(
                        skuController: c.skuName,
                        priceController: c.price,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        variantsMatrixCard(),
        const SizedBox(height: 16),
        chipsPreview(),
        const SizedBox(height: 8),
        skuTable(),
      ],
    );
  }

  /// Expose SKUs untuk payload
  List<NewSku> buildSkus() {
    return _combos.map((c) {
      final attrs = c.attrs.entries
          .map((e) => NewSkuAttribute(name: e.key, value: e.value))
          .toList();
      return NewSku(
        code: c.skuName.text,
        price: parseIdInt(c.price.text),
        attributes: attrs,
      );
    }).toList();
  }

  bool get hasAtLeastOneRow => _combos.isNotEmpty;
}

/// =========================
/// Chip-based Variant Values Input
/// =========================
/// Replaces the old "comma-separated" text field with a friendlier UI:
/// user types ONE value at a time, presses Enter (or taps +), and it turns
/// into a removable chip. Under the hood it still writes a comma-joined
/// string into VariantGroupController.valuesC, so the existing cartesian
/// product logic (`values` getter, hydrateFromServer, etc.) keeps working
/// without any other change.
class _ChipsValueField extends StatefulWidget {
  const _ChipsValueField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final VariantGroupController controller;
  final String hintText;
  final VoidCallback onChanged;

  @override
  State<_ChipsValueField> createState() => _ChipsValueFieldState();
}

class _ChipsValueFieldState extends State<_ChipsValueField> {
  final TextEditingController _inputC = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _chips = [];

  static const Color _border = Color(0xFFE5E7EB);
  static const Color _chipBg = Color(0xFFEFF6FF); // blue-50
  static const Color _chipBorder = Color(0xFFBFDBFE); // blue-200
  static const Color _chipText = Color(0xFF1D4ED8); // blue-700
  static const Color _textMain = Color(0xFF111827);
  static const Color _textSub = Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    // Prefill from controller (covers hydrateFromServer setting valuesC.text
    // before this widget mounts, and edit-mode reopen).
    _chips = widget.controller.values;
    widget.controller.valuesC.addListener(_syncFromController);
  }

  @override
  void dispose() {
    widget.controller.valuesC.removeListener(_syncFromController);
    _inputC.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // Keeps chips in sync if valuesC.text is changed from outside this widget
  // (e.g. hydrateFromServer).
  void _syncFromController() {
    final external = widget.controller.values;
    if (!_sameList(external, _chips)) {
      setState(() => _chips = external);
    }
  }

  void _pushToController() {
    widget.controller.valuesC.text = _chips.join(',');
    widget.onChanged();
  }

  void _commitInput() {
    final text = _inputC.text.trim();
    _inputC.clear();
    if (text.isEmpty) return;
    if (_chips.contains(text)) return; // avoid duplicate values
    setState(() => _chips.add(text));
    _pushToController();
  }

  void _removeChip(String value) {
    setState(() => _chips.remove(value));
    _pushToController();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_chips.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _chips
                  .map(
                    (v) => Container(
                      padding: const EdgeInsets.only(
                        left: 10,
                        right: 4,
                        top: 4,
                        bottom: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _chipBg,
                        border: Border.all(color: _chipBorder),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            v,
                            style: const TextStyle(
                              color: _chipText,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 2),
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => _removeChip(v),
                            child: const Padding(
                              padding: EdgeInsets.all(3),
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: _chipText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputC,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(color: _textMain, fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: widget.hintText,
                    hintStyle: const TextStyle(color: _textSub, fontSize: 13),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  onSubmitted: (_) {
                    _commitInput();
                    // Keep focus so the user can keep adding values quickly.
                    _focusNode.requestFocus();
                  },
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _commitInput,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.add_circle_rounded,
                    size: 22,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkuPriceCell extends StatelessWidget {
  const _SkuPriceCell({
    required this.skuController,
    required this.priceController,
  });

  final TextEditingController skuController;
  final TextEditingController priceController;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 380,
      ), // ruang cukup untuk 2 field
      child: Row(
        children: [
          // SKU Code
          Expanded(
            flex: 6,
            child: TextFormField(
              controller: skuController,
              inputFormatters: [skuNoSpaceFormatter],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'SKU Code (no spaces)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Price (right next to SKU)
          Expanded(
            flex: 4,
            child: TextFormField(
              controller: priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (t) {
                if (t.isEmpty) return;
                final sel = priceController.selection;
                final newText = formatIdNumber(t);
                priceController
                  ..text = newText
                  ..selection = sel.copyWith(
                    baseOffset: newText.length,
                    extentOffset: newText.length,
                  );
              },
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Price',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              validator: (v) =>
                  (parseIdInt(v ?? '') > 0) ? null : 'Must be > 0',
            ),
          ),
        ],
      ),
    );
  }
}