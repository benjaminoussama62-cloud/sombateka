import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/premium_theme.dart';
import '../utils/listing_attributes.dart';
import '../utils/listing_utils.dart';
import '../utils/rdc_locations.dart';
import 'location_picker_fields.dart';

/// Filtres avancés SombaTeka (catégorie, avis, couleur, localisation RDC…).
class MarketplaceFilterState {
  static const double defaultMaxPrice = 10000000;
  static const double sliderMaxPrice = 5000000;
  static const double sliderStep = 25000;

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
  double maxPrice = defaultMaxPrice;

  bool get hasPriceFilter => minPrice > 0 || maxPrice < defaultMaxPrice;

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
    if (hasPriceFilter) n++;
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
    maxPrice = defaultMaxPrice;
  }
}

Future<MarketplaceFilterState?> showMarketplaceFilterSheet(
  BuildContext context, {
  required MarketplaceFilterState initial,
  required List<String> categories,
  required Map<String, int> categoryIds,
}) {
  return showModalBottomSheet<MarketplaceFilterState>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _MarketplaceFilterSheet(
      initial: initial,
      categories: categories,
      categoryIds: categoryIds,
    ),
  );
}

class _MarketplaceFilterSheet extends StatefulWidget {
  const _MarketplaceFilterSheet({
    required this.initial,
    required this.categories,
    required this.categoryIds,
  });

  final MarketplaceFilterState initial;
  final List<String> categories;
  final Map<String, int> categoryIds;

  @override
  State<_MarketplaceFilterSheet> createState() => _MarketplaceFilterSheetState();
}

class _MarketplaceFilterSheetState extends State<_MarketplaceFilterSheet> {
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
  final _minPriceCtrl = TextEditingController();
  final _maxPriceCtrl = TextEditingController();

  static const _pricePresets = <({String label, double min, double max})>[
    (label: 'Tous les prix', min: 0, max: MarketplaceFilterState.defaultMaxPrice),
    (label: 'Jusqu\'à 50K', min: 0, max: 50000),
    (label: '50K – 200K', min: 50000, max: 200000),
    (label: '200K – 1M', min: 200000, max: 1000000),
    (label: '1M – 5M', min: 1000000, max: 5000000),
    (label: '5M et +', min: 5000000, max: MarketplaceFilterState.defaultMaxPrice),
  ];

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
    _syncPriceFieldsFromSlider();
  }

  void _syncPriceFieldsFromSlider() {
    _minPriceCtrl.text = _minPrice <= 0 ? '' : _minPrice.round().toString();
    if (_maxPrice >= MarketplaceFilterState.defaultMaxPrice) {
      _maxPriceCtrl.text = '';
    } else {
      _maxPriceCtrl.text = _maxPrice.round().toString();
    }
  }

  double _sliderMaxValue() =>
      _maxPrice > MarketplaceFilterState.sliderMaxPrice ? MarketplaceFilterState.sliderMaxPrice : _maxPrice;

  double _sliderMinValue() => _minPrice.clamp(0, MarketplaceFilterState.sliderMaxPrice);

  void _applyPreset(({String label, double min, double max}) preset) {
    setState(() {
      _minPrice = preset.min;
      _maxPrice = preset.max;
      _syncPriceFieldsFromSlider();
    });
  }

  void _applyManualPrices() {
    final minRaw = int.tryParse(_minPriceCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final maxRaw = int.tryParse(_maxPriceCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    setState(() {
      _minPrice = (minRaw ?? 0).toDouble().clamp(0, MarketplaceFilterState.defaultMaxPrice);
      if (maxRaw == null || maxRaw <= 0) {
        _maxPrice = MarketplaceFilterState.defaultMaxPrice;
      } else {
        _maxPrice = maxRaw.toDouble().clamp(_minPrice, MarketplaceFilterState.defaultMaxPrice);
      }
      if (_maxPrice < _minPrice) _maxPrice = _minPrice;
    });
  }

  void _resetPrices() {
    _minPrice = 0;
    _maxPrice = MarketplaceFilterState.defaultMaxPrice;
    _syncPriceFieldsFromSlider();
  }

  String? _activePresetLabel() {
    for (final p in _pricePresets) {
      if (_minPrice == p.min && _maxPrice == p.max) return p.label;
    }
    return null;
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  MarketplaceFilterState _buildResult() {
    _applyManualPrices();
    return MarketplaceFilterState()
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

  Widget _buildPriceSection() {
    final activePreset = _activePresetLabel();
    final maxLabel = _maxPrice >= MarketplaceFilterState.defaultMaxPrice
        ? 'Illimité'
        : formatFilterPriceCdf(_maxPrice);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Prix (CDF)'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PremiumTheme.surface,
            borderRadius: PremiumTheme.radiusMd,
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Minimum', style: PremiumTheme.label.copyWith(fontSize: 10)),
                        Text(
                          formatFilterPriceCdf(_minPrice),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: PremiumTheme.blue),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.swap_horiz_rounded, color: PremiumTheme.textMuted.withValues(alpha: 0.5)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Maximum', style: PremiumTheme.label.copyWith(fontSize: 10)),
                        Text(
                          maxLabel,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: PremiumTheme.blue),
                          textAlign: TextAlign.end,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                ),
                child: RangeSlider(
                  values: RangeValues(
                    _sliderMinValue(),
                    _sliderMaxValue().clamp(_sliderMinValue() + MarketplaceFilterState.sliderStep, MarketplaceFilterState.sliderMaxPrice),
                  ),
                  min: 0,
                  max: MarketplaceFilterState.sliderMaxPrice,
                  divisions: (MarketplaceFilterState.sliderMaxPrice / MarketplaceFilterState.sliderStep).round(),
                  activeColor: PremiumTheme.blue,
                  inactiveColor: PremiumTheme.blue.withValues(alpha: 0.15),
                  labels: RangeLabels(
                    formatFilterPriceCdf(_minPrice),
                    _maxPrice >= MarketplaceFilterState.defaultMaxPrice ? '5M+' : formatFilterPriceCdf(_maxPrice),
                  ),
                  onChanged: (v) => setState(() {
                    _minPrice = v.start;
                    _maxPrice = v.end >= MarketplaceFilterState.sliderMaxPrice - MarketplaceFilterState.sliderStep
                        ? MarketplaceFilterState.defaultMaxPrice
                        : v.end;
                    _syncPriceFieldsFromSlider();
                  }),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _pricePresets.map((p) {
                  final selected = activePreset == p.label;
                  return FilterChip(
                    label: Text(p.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    selected: selected,
                    onSelected: (_) => _applyPreset(p),
                    selectedColor: PremiumTheme.blue.withValues(alpha: 0.15),
                    checkmarkColor: PremiumTheme.blue,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minPriceCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Min CDF',
                        hintText: '0',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onSubmitted: (_) => setState(_applyManualPrices),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('—', style: TextStyle(fontWeight: FontWeight.w700, color: PremiumTheme.textMuted)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _maxPriceCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Max CDF',
                        hintText: 'Illimité',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onSubmitted: (_) => setState(_applyManualPrices),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
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
                Expanded(child: Text('Filtres SombaTeka', style: PremiumTheme.h1.copyWith(fontSize: 18))),
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
                    _resetPrices();
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
                _buildPriceSection(),
                const SizedBox(height: 8),
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
