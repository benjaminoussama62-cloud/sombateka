import 'package:flutter/material.dart';

import '../theme/premium_theme.dart';
import '../utils/listing_attributes.dart';
import '../utils/rdc_locations.dart';
import 'location_picker_fields.dart';

/// Filtres style Wildberries (catégorie, avis, couleur, genre, enfant, marque, localisation…).
class WildberriesFilterState {
  String category = 'Toutes';
  int? categoryId;
  String? size;
  String? color;
  String? condition;
  String? brand;
  String? gender;
  String? audience;
  String? province;
  String? commune;
  String? quartier;
  int? minStars;
  bool officialOnly = false;
  double minPrice = 0;
  double maxPrice = 10000000;

  int get activeCount {
    var n = 0;
    if (category != 'Toutes') n++;
    if (size != null) n++;
    if (color != null) n++;
    if (condition != null) n++;
    if (brand != null && brand!.isNotEmpty) n++;
    if (gender != null) n++;
    if (audience != null) n++;
    if (commune != null) n++;
    if (quartier != null) n++;
    if (province != null) n++;
    if (minStars != null) n++;
    if (officialOnly) n++;
    if (minPrice > 0 || maxPrice < 10000000) n++;
    return n;
  }

  void reset() {
    category = 'Toutes';
    categoryId = null;
    size = null;
    color = null;
    condition = null;
    brand = null;
    gender = null;
    audience = null;
    commune = null;
    quartier = null;
    province = null;
    minStars = null;
    officialOnly = false;
    minPrice = 0;
    maxPrice = 10000000;
  }
}

Future<WildberriesFilterState?> showWildberriesFilterSheet(
  BuildContext context, {
  required WildberriesFilterState initial,
  required List<String> categories,
  required Map<String, int> categoryIds,
}) {
  return showModalBottomSheet<WildberriesFilterState>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _WildberriesFilterSheet(
      initial: initial,
      categories: categories,
      categoryIds: categoryIds,
    ),
  );
}

class _WildberriesFilterSheet extends StatefulWidget {
  const _WildberriesFilterSheet({
    required this.initial,
    required this.categories,
    required this.categoryIds,
  });

  final WildberriesFilterState initial;
  final List<String> categories;
  final Map<String, int> categoryIds;

  @override
  State<_WildberriesFilterSheet> createState() => _WildberriesFilterSheetState();
}

class _WildberriesFilterSheetState extends State<_WildberriesFilterSheet> {
  late String _category;
  late int? _categoryId;
  String? _size;
  String? _color;
  String? _condition;
  String? _gender;
  String? _audience;
  String? _province = RdcLocations.kinshasa;
  String? _commune;
  String? _quartier;
  int? _minStars;
  bool _officialOnly = false;
  late double _minPrice;
  late double _maxPrice;
  final _brandCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _category = widget.initial.category;
    _categoryId = widget.initial.categoryId;
    _size = widget.initial.size;
    _color = widget.initial.color;
    _condition = widget.initial.condition;
    _gender = widget.initial.gender;
    _audience = widget.initial.audience;
    _province = widget.initial.province ?? RdcLocations.kinshasa;
    _commune = widget.initial.commune;
    _quartier = widget.initial.quartier;
    _minStars = widget.initial.minStars;
    _officialOnly = widget.initial.officialOnly;
    _minPrice = widget.initial.minPrice;
    _maxPrice = widget.initial.maxPrice;
    _brandCtrl.text = widget.initial.brand ?? '';
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    super.dispose();
  }

  WildberriesFilterState _buildResult() {
    return WildberriesFilterState()
      ..category = _category
      ..categoryId = _categoryId
      ..size = _size
      ..color = _color
      ..condition = _condition
      ..brand = _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim()
      ..gender = _gender
      ..audience = _audience
      ..province = _province == RdcLocations.kinshasa ? null : _province
      ..commune = _commune
      ..quartier = _quartier
      ..minStars = _minStars
      ..officialOnly = _officialOnly
      ..minPrice = _minPrice
      ..maxPrice = _maxPrice;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      margin: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
            child: Row(
              children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                Expanded(child: Text('Filtres', style: PremiumTheme.h1.copyWith(fontSize: 18))),
                TextButton(
                  onPressed: () => setState(() {
                    _category = 'Toutes';
                    _categoryId = null;
                    _size = null;
                    _color = null;
                    _condition = null;
                    _brandCtrl.clear();
                    _gender = null;
                    _audience = null;
                    _commune = null;
                    _quartier = null;
                    _minStars = null;
                    _officialOnly = false;
                    _minPrice = 0;
                    _maxPrice = 10000000;
                  }),
                  child: const Text('Effacer'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _sectionTitle('Catégorie'),
                _chipWrap(widget.categories, _category, (v) => setState(() {
                      _category = v;
                      _categoryId = v == 'Toutes' ? null : widget.categoryIds[v];
                      _size = null;
                    })),
                _sectionTitle('Localisation — RDC'),
                LocationPickerFields(
                  compact: true,
                  province: _province,
                  commune: _commune,
                  quartier: _quartier,
                  onProvinceChanged: (p) => setState(() {
                    _province = p;
                    _commune = null;
                    _quartier = null;
                  }),
                  onCommuneChanged: (c) => setState(() {
                    _commune = c;
                    _quartier = null;
                  }),
                  onQuartierChanged: (q) => setState(() => _quartier = q.isEmpty ? null : q),
                ),
                _sectionTitle('Avis vendeur (étoiles)'),
                _chipWrap(
                  ['Tous', '5★', '4★+', '3★+'],
                  _minStars == null
                      ? 'Tous'
                      : _minStars == 5
                          ? '5★'
                          : _minStars == 4
                              ? '4★+'
                              : '3★+',
                  (v) => setState(() {
                    _minStars = switch (v) {
                      '5★' => 5,
                      '4★+' => 4,
                      '3★+' => 3,
                      _ => null,
                    };
                  }),
                ),
                _sectionTitle('Genre'),
                _chipWrap(['Tous', ...ListingAttributes.genders], _gender ?? 'Tous',
                    (v) => setState(() => _gender = v == 'Tous' ? null : v)),
                _sectionTitle('Public'),
                _chipWrap(['Tous', ...ListingAttributes.audiences], _audience ?? 'Tous',
                    (v) => setState(() => _audience = v == 'Tous' ? null : v)),
                _sectionTitle('Couleur'),
                _chipWrap(['Toutes', ...ListingAttributes.colors], _color ?? 'Toutes',
                    (v) => setState(() => _color = v == 'Toutes' ? null : v)),
                if (ListingAttributes.categoryNeedsSize(_category)) ...[
                  _sectionTitle(ListingAttributes.sizeLabelForCategory(_category)),
                  _chipWrap(ListingAttributes.sizesForCategory(_category), _size ?? '', (v) {
                    setState(() => _size = v.isEmpty || _size == v ? null : v);
                  }, toggle: true),
                ],
                _sectionTitle('État'),
                _chipWrap(['Tous', ...ListingAttributes.conditions], _condition ?? 'Tous',
                    (v) => setState(() => _condition = v == 'Tous' ? null : v)),
                _sectionTitle('Marque'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ListingAttributes.popularBrands.map((b) {
                    final sel = _brandCtrl.text.toLowerCase() == b.toLowerCase();
                    return FilterChip(
                      label: Text(b, style: const TextStyle(fontSize: 11)),
                      selected: sel,
                      onSelected: (_) => setState(() => _brandCtrl.text = sel ? '' : b),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _brandCtrl,
                  decoration: InputDecoration(
                    hintText: 'Autre marque…',
                    filled: true,
                    fillColor: PremiumTheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                _sectionTitle('Prix (CDF)'),
                RangeSlider(
                  values: RangeValues(_minPrice, _maxPrice.clamp(_minPrice + 1, 10000000)),
                  min: 0,
                  max: 10000000,
                  divisions: 20,
                  activeColor: PremiumTheme.blue,
                  onChanged: (v) => setState(() {
                    _minPrice = v.start;
                    _maxPrice = v.end;
                  }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Boutiques officielles uniquement',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  value: _officialOnly,
                  activeThumbColor: PremiumTheme.blue,
                  onChanged: (v) => setState(() => _officialOnly = v),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _buildResult()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumTheme.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Afficher les résultats', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(t, style: PremiumTheme.h1.copyWith(fontSize: 15)),
      );

  Widget _chipWrap(List<String> options, String selected, ValueChanged<String> onTap, {bool toggle = false}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final sel = selected == o;
        return FilterChip(
          label: Text(o, style: const TextStyle(fontSize: 11)),
          selected: sel,
          onSelected: (_) {
            if (toggle && sel) {
              onTap('');
            } else {
              onTap(o);
            }
          },
          selectedColor: PremiumTheme.blue.withValues(alpha: 0.15),
          checkmarkColor: PremiumTheme.blue,
        );
      }).toList(),
    );
  }
}
