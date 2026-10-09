// lib/widgets/variant_section_dynamic.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wa_blast/providers/product_provider.dart';

/// =========================
/// Design tokens
/// =========================
const Color _kBlue = Color(0xFF2563EB);
const Color _kText = Color(0xFF0F172A);
const Color _kMuted = Color(0xFF64748B);
const Color _kBorder = Color(0xFFE2E8F0);
const Color _kFill = Color(0xFFF8FAFC);
const Color _kHint = Color(0xFFA0AEC0);
const Color _kDanger = Color(0xFFDC2626);

/// =========================
/// Utils (kept public for backward compatibility)
/// =========================

/// 1500000 -> "1.500.000"
String formatIdNumber(String t) {
  final digits = t.replaceAll(RegExp(r'\D'), '');
  final n = int.tryParse(digits) ?? 0;
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// "1.500.000" -> 1500000
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

/// Digits only + live thousand separator ("12000" -> "12.000").
class _IdThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    if (digits.length > 12) digits = digits.substring(0, 12);
    final f = formatIdNumber(digits);
    return TextEditingValue(
      text: f,
      selection: TextSelection.collapsed(offset: f.length),
    );
  }
}

/// =========================
/// Controllers & models
/// =========================

/// One row: "Option Name" + "Price".
class VariantOptionController {
  VariantOptionController({String name = '', int price = 0}) : id = _nextId++ {
    nameC.text = name;
    if (price > 0) priceC.text = formatIdNumber('$price');
  }

  static int _nextId = 0;

  final int id;
  final TextEditingController nameC = TextEditingController();
  final TextEditingController priceC = TextEditingController();

  String get name => nameC.text.trim();
  int get price => parseIdInt(priceC.text);

  void dispose() {
    nameC.dispose();
    priceC.dispose();
  }
}

/// One section (e.g. "Size", "Additional") that holds many options.
class VariantGroupController {
  VariantGroupController({this.title = '', int emptyOptions = 0}) {
    for (var i = 0; i < emptyOptions; i++) {
      options.add(VariantOptionController());
    }
  }

  String title;
  final List<VariantOptionController> options = [];

  /// Options that have a name (duplicates by name are ignored).
  List<VariantOptionController> get activeOptions {
    final seen = <String>{};
    final out = <VariantOptionController>[];
    for (final o in options) {
      final n = o.name;
      if (n.isEmpty) continue;
      if (seen.add(n.toLowerCase())) out.add(o);
    }
    return out;
  }

  void dispose() {
    for (final o in options) {
      o.dispose();
    }
  }
}

/// One final SKU = one option from every active section.
class _Combo {
  _Combo(this.groups, this.options);

  final List<VariantGroupController> groups;
  final List<VariantOptionController> options;

  String get key => options.map((o) => o.id).join('-');
  String get label => options.map((o) => o.name).join(' • ');
  int get sum => options.fold<int>(0, (a, o) => a + o.price);
}

class _SkuRow {
  _SkuRow(this.code, this.price, this.attrs);
  final String code;
  final int price;
  final Map<String, String> attrs;
}

/// =========================
/// VariantsSectionDynamic
/// =========================
///
/// Simple UI:
///   Size                                   Edit
///   Option Name        Price
///   [ Small      ]     [Rp. 10.000]        (trash)
///   [ + Add Option ]
///
/// Price rule: a final variant's price = sum of the prices of the options it
/// is made of. With only one section, price = the option's own price.
class VariantsSectionDynamic extends StatefulWidget {
  const VariantsSectionDynamic({
    super.key,
    this.initialGroups, // OPTIONAL: prefill (edit)
    this.initialSkus, // OPTIONAL: prefill (edit)
  });

  /// each: {"name": "Color", "values": ["Blue", "White"]}
  final List<Map<String, dynamic>>? initialGroups;

  /// each: {"code": "SMBLUE128", "price": 11000000,
  ///        "attributes": [{"name":"Color","value":"Blue"}, ...]}
  /// or    {"attributes": {"Color":"Blue"}} is accepted as well.
  final List<Map<String, dynamic>>? initialSkus;

  @override
  State<VariantsSectionDynamic> createState() => VariantsSectionDynamicState();
}

class VariantsSectionDynamicState extends State<VariantsSectionDynamic> {
  static const int _maxGroups = 5;

  final List<VariantGroupController> _groups = [];
  final Map<String, TextEditingController> _codeCtrls = {};

  /// Prices that were saved per-combination before and do not match the
  /// "sum of options" rule. Kept until the user edits any price, so opening
  /// and saving an existing product never silently changes its prices.
  final Map<String, int> _legacyPrices = {};
  bool _legacyActive = false;

  bool _submitted = false;
  int _pendingFocusId = -1;

  @override
  void initState() {
    super.initState();
    final hasInit =
        (widget.initialGroups?.isNotEmpty ?? false) ||
        (widget.initialSkus?.isNotEmpty ?? false);
    if (hasInit) {
      _applyHydration(
        widget.initialGroups ?? const [],
        widget.initialSkus ?? const [],
      );
    }
    if (_groups.isEmpty) {
      _groups.add(VariantGroupController(title: 'Size', emptyOptions: 2));
    }
  }

  @override
  void dispose() {
    for (final g in _groups) {
      g.dispose();
    }
    for (final c in _codeCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// ========= PUBLIC API =========

  bool get hasAtLeastOneRow => _computeCombos().isNotEmpty;

  /// Call before saving: highlights options that still miss a price.
  /// Returns true when every final variant has a price > 0.
  bool validate() {
    final combos = _computeCombos();
    setState(() => _submitted = true);
    if (combos.isEmpty) return false;
    return combos.every((c) => _priceOf(c) > 0);
  }

  List<NewSku> buildSkus() {
    return _computeCombos().map((c) {
      final attrs = <NewSkuAttribute>[
        for (var i = 0; i < c.options.length; i++)
          NewSkuAttribute(
            name: c.groups[i].title.trim(),
            value: c.options[i].name,
          ),
      ];
      return NewSku(
        code: (_codeCtrls[c.key]?.text ?? '').trim(),
        price: _priceOf(c),
        attributes: attrs,
      );
    }).toList();
  }

  void hydrateFromServer({
    required List<Map<String, dynamic>> groups,
    required List<Map<String, dynamic>> skus,
  }) {
    setState(() => _applyHydration(groups, skus));
  }

  /// ========= INTERNAL: combos & price =========

  List<_Combo> _computeCombos() {
    final active = _groups
        .where((g) => g.title.trim().isNotEmpty && g.activeOptions.isNotEmpty)
        .toList();
    if (active.isEmpty) return <_Combo>[];

    var acc = <List<VariantOptionController>>[<VariantOptionController>[]];
    for (final g in active) {
      final next = <List<VariantOptionController>>[];
      for (final partial in acc) {
        for (final o in g.activeOptions) {
          next.add([...partial, o]);
        }
      }
      acc = next;
    }
    return acc.map((opts) => _Combo(active, opts)).toList();
  }

  int _priceOf(_Combo c) {
    if (_legacyActive && _legacyPrices.containsKey(c.key)) {
      return _legacyPrices[c.key]!;
    }
    return c.sum;
  }

  TextEditingController _codeCtrl(String key) =>
      _codeCtrls.putIfAbsent(key, () => TextEditingController());

  void _afterFrame(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) => fn());
  }

  /// ========= INTERNAL: hydrate (edit mode) =========

  void _applyHydration(
    List<Map<String, dynamic>> groups,
    List<Map<String, dynamic>> skus,
  ) {
    // Clear current state (dispose after the frame: widgets may still be mounted)
    final oldGroups = List<VariantGroupController>.from(_groups);
    final oldCodes = List<TextEditingController>.from(_codeCtrls.values);
    _afterFrame(() {
      for (final g in oldGroups) {
        g.dispose();
      }
      for (final c in oldCodes) {
        c.dispose();
      }
    });
    _groups.clear();
    _codeCtrls.clear();
    _legacyPrices.clear();
    _legacyActive = false;

    // 1) Normalize SKUs
    final rows = <_SkuRow>[];
    for (final s in skus) {
      final code = (s['code'] ?? '').toString();
      final price = (s['price'] is num)
          ? (s['price'] as num).toInt()
          : int.tryParse('${s['price'] ?? ''}') ?? 0;

      final attrs = <String, String>{};
      final any = s['attributes'];
      if (any is Map) {
        any.forEach((k, v) => attrs['$k'.trim()] = '$v'.trim());
      } else if (any is List) {
        for (final e in any) {
          if (e is Map) {
            final n = (e['name'] ?? '').toString().trim();
            final v = (e['value'] ?? '').toString().trim();
            if (n.isNotEmpty && v.isNotEmpty) attrs[n] = v;
          }
        }
      }
      rows.add(_SkuRow(code, price, attrs));
    }

    // 2) Build sections (from groups, or derived from SKUs)
    final defs = <MapEntry<String, List<String>>>[];
    for (final g in groups) {
      final name = (g['name'] ?? '').toString().trim();
      final raw = g['values'];
      final values = (raw is List)
          ? raw.map((e) => e.toString().trim()).toList()
          : (raw is String)
          ? raw.split(',').map((e) => e.trim()).toList()
          : <String>[];
      if (name.isEmpty) continue;
      defs.add(MapEntry(name, values.where((v) => v.isNotEmpty).toList()));
    }
    if (defs.isEmpty) {
      final map = <String, List<String>>{};
      for (final r in rows) {
        r.attrs.forEach((k, v) {
          final list = map.putIfAbsent(k, () => <String>[]);
          if (!list.contains(v)) list.add(v);
        });
      }
      map.forEach((k, v) => defs.add(MapEntry(k, v)));
    }

    for (final d in defs) {
      final g = VariantGroupController(title: d.key);
      final seen = <String>{};
      for (final v in d.value) {
        if (seen.add(v.toLowerCase())) {
          g.options.add(VariantOptionController(name: v));
        }
      }
      if (g.options.isEmpty) g.options.add(VariantOptionController());
      _groups.add(g);
    }
    if (_groups.isEmpty) {
      _groups.add(VariantGroupController(title: 'Size', emptyOptions: 2));
      return;
    }

    // 3) Decode option prices from SKU prices (exact for "sum" pricing)
    if (rows.isNotEmpty) {
      for (var gi = 0; gi < _groups.length; gi++) {
        final g = _groups[gi];
        for (final o in g.options) {
          int? best;
          for (final r in rows) {
            if (r.attrs[g.title] != o.name) continue;
            var rest = r.price;
            for (var k = 0; k < gi; k++) {
              final gk = _groups[k];
              final match = gk.options.where(
                (x) => x.name == r.attrs[gk.title],
              );
              if (match.isNotEmpty) rest -= match.first.price;
            }
            if (rest < 0) rest = 0;
            if (best == null || rest < best) best = rest;
          }
          if (best != null && best > 0) {
            o.priceC.text = formatIdNumber('$best');
          }
        }
      }

      // 4) Restore SKU codes and detect prices that are not "sum" based
      var mismatch = false;
      for (final c in _computeCombos()) {
        final want = <String, String>{
          for (var i = 0; i < c.options.length; i++)
            c.groups[i].title.trim(): c.options[i].name,
        };
        _SkuRow? hit;
        for (final r in rows) {
          if (r.attrs.length != want.length) continue;
          var same = true;
          for (final e in want.entries) {
            if (r.attrs[e.key] != e.value) {
              same = false;
              break;
            }
          }
          if (same) {
            hit = r;
            break;
          }
        }
        if (hit == null) continue;
        if (hit.code.isNotEmpty) _codeCtrl(c.key).text = hit.code;
        if (hit.price > 0) {
          _legacyPrices[c.key] = hit.price;
          if (hit.price != c.sum) mismatch = true;
        }
      }
      _legacyActive = mismatch;
      if (!mismatch) _legacyPrices.clear();
    }
  }

  /// ========= INTERNAL: actions =========

  void _addOption(VariantGroupController g) {
    final o = VariantOptionController();
    setState(() {
      g.options.add(o);
      _pendingFocusId = o.id;
    });
  }

  void _removeOption(VariantGroupController g, VariantOptionController o) {
    setState(() {
      if (g.options.length <= 1) {
        o.nameC.clear();
        o.priceC.clear();
      } else {
        g.options.remove(o);
        _afterFrame(o.dispose);
      }
    });
  }

  void _addGroup() {
    if (_groups.length >= _maxGroups) return;
    final taken = _groups.map((g) => g.title.trim().toLowerCase()).toSet();
    var title = _groups.length == 1
        ? 'Additional'
        : 'Variant ${_groups.length + 1}';
    var n = _groups.length + 1;
    while (taken.contains(title.toLowerCase())) {
      n++;
      title = 'Variant $n';
    }
    final g = VariantGroupController(title: title, emptyOptions: 2);
    setState(() {
      _groups.add(g);
      _pendingFocusId = g.options.first.id;
    });
  }

  Future<void> _editGroup(int index) async {
    final g = _groups[index];
    final taken = <String>{
      for (var i = 0; i < _groups.length; i++)
        if (i != index) _groups[i].title.trim().toLowerCase(),
    };
    final res = await showDialog<_GroupEditResult>(
      context: context,
      builder: (_) => _EditGroupDialog(
        initialTitle: g.title,
        canDelete: _groups.length > 1,
        takenTitles: taken,
      ),
    );
    if (res == null || !mounted) return;
    setState(() {
      if (res.delete) {
        _groups.remove(g);
        _afterFrame(g.dispose);
      } else if (res.title != null) {
        g.title = res.title!;
      }
    });
  }

  /// ========= UI =========

  String _nameHintFor(int groupIndex) {
    switch (groupIndex) {
      case 0:
        return 'E.g Small';
      case 1:
        return 'E.g Extra Cheese';
      default:
        return 'E.g Option';
    }
  }

  OutlineInputBorder _outline(Color c, {double w = 1}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: c, width: w),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
    bool danger = false,
    bool autofocus = false,
    Widget? prefix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    TextInputAction? action,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      textInputAction: action ?? TextInputAction.next,
      onChanged: onChanged,
      style: const TextStyle(
        color: _kText,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: _kFill,
        hintText: hint,
        hintStyle: const TextStyle(
          color: _kHint,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        prefixIcon: prefix,
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        border: _outline(_kBorder),
        enabledBorder: _outline(danger ? _kDanger : _kBorder),
        focusedBorder: _outline(danger ? _kDanger : _kBlue, w: 1.5),
      ),
    );
  }

  Widget _label(String text, {bool danger = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: danger ? _kDanger : _kText,
      ),
    ),
  );

  Widget _optionRow({
    required VariantGroupController g,
    required VariantOptionController o,
    required int groupIndex,
    required bool duplicate,
    required bool priceMissing,
  }) {
    return Padding(
      key: ValueKey('opt-${o.id}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(
                  duplicate ? 'Option Name (already used)' : 'Option Name',
                  danger: duplicate,
                ),
                _field(
                  controller: o.nameC,
                  hint: _nameHintFor(groupIndex),
                  danger: duplicate,
                  autofocus: o.id == _pendingFocusId,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Price', danger: priceMissing),
                _field(
                  controller: o.priceC,
                  hint: '0',
                  danger: priceMissing,
                  keyboardType: TextInputType.number,
                  formatters: [_IdThousandsFormatter()],
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 12, right: 4),
                    child: Text(
                      'Rp.',
                      style: TextStyle(
                        color: _kText,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() => _legacyActive = false),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 21, left: 2),
            child: IconButton(
              tooltip: 'Remove option',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 42),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: _kDanger,
                size: 22,
              ),
              onPressed: () => _removeOption(g, o),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupSection(int gi, List<_Combo> combos) {
    final g = _groups[gi];
    final seen = <String>{};

    final rows = <Widget>[];
    for (final o in g.options) {
      final n = o.name.toLowerCase();
      final duplicate = n.isNotEmpty && !seen.add(n);

      var priceMissing = false;
      if (_submitted && n.isNotEmpty && !duplicate) {
        final mine = combos.where((c) => c.options.contains(o)).toList();
        priceMissing = mine.isNotEmpty && mine.every((c) => _priceOf(c) <= 0);
      }

      rows.add(
        _optionRow(
          g: g,
          o: o,
          groupIndex: gi,
          duplicate: duplicate,
          priceMissing: priceMissing,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  g.title.trim().isEmpty ? 'Variant' : g.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => _editGroup(gi),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _kBlue,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...rows,
          OutlinedButton.icon(
            onPressed: () => _addOption(g),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add Option'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kBlue,
              backgroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
              side: const BorderSide(color: _kBlue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(List<_Combo> combos) {
    final multi = combos.isNotEmpty && combos.first.options.length > 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Variants to be saved (${combos.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _kText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            multi
                ? 'Price of each variant = sum of its option prices. SKU code is optional.'
                : 'SKU code is optional.',
            style: const TextStyle(fontSize: 12, color: _kMuted, height: 1.3),
          ),
          if (_legacyActive) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Text(
                'This product has custom prices per variant. They are kept as-is. '
                'Change any option price to recalculate all prices automatically.',
                style: TextStyle(fontSize: 12, color: _kMuted, height: 1.3),
              ),
            ),
          ],
          const SizedBox(height: 6),
          for (final c in combos)
            Padding(
              key: ValueKey('combo-${c.key}'),
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _kText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Rp ${formatIdNumber('${_priceOf(c)}')}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _priceOf(c) > 0 ? _kBlue : _kDanger,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 132,
                    child: _field(
                      controller: _codeCtrl(c.key),
                      hint: 'SKU (optional)',
                      formatters: [skuNoSpaceFormatter],
                      onChanged: (_) {},
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final combos = _computeCombos();

    if (_pendingFocusId != -1) {
      _afterFrame(() => _pendingFocusId = -1);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _groups.length; i++) _groupSection(i, combos),
        if (_groups.length < _maxGroups)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addGroup,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              label: const Text('Add Variant Group'),
              style: TextButton.styleFrom(
                foregroundColor: _kBlue,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (combos.isNotEmpty) ...[
          const SizedBox(height: 12),
          _summaryCard(combos),
        ],
      ],
    );
  }
}

/// =========================
/// Edit group dialog (rename / delete)
/// =========================
class _GroupEditResult {
  const _GroupEditResult.rename(this.title) : delete = false;
  const _GroupEditResult.remove() : title = null, delete = true;

  final String? title;
  final bool delete;
}

class _EditGroupDialog extends StatefulWidget {
  const _EditGroupDialog({
    required this.initialTitle,
    required this.canDelete,
    required this.takenTitles,
  });

  final String initialTitle;
  final bool canDelete;
  final Set<String> takenTitles;

  @override
  State<_EditGroupDialog> createState() => _EditGroupDialogState();
}

class _EditGroupDialogState extends State<_EditGroupDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initialTitle,
  );
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    final t = _c.text.trim();
    if (t.isEmpty) {
      setState(() => _error = 'Name cannot be empty');
      return;
    }
    if (widget.takenTitles.contains(t.toLowerCase())) {
      setState(() => _error = 'This name is already used');
      return;
    }
    Navigator.pop(context, _GroupEditResult.rename(t));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text(
        'Edit group name',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      content: TextField(
        controller: _c,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        decoration: InputDecoration(
          isDense: true,
          hintText: 'E.g Size, Color, Additional',
          errorText: _error,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      actions: [
        if (widget.canDelete)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _kDanger),
            onPressed: () =>
                Navigator.pop(context, const _GroupEditResult.remove()),
            child: const Text('Delete group'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _kBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
