import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/data_service.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../utils/category_catalog.dart';
import '../utils/listing_attributes.dart';
import '../widgets/color_picker_field.dart';
import '../widgets/publish_field_styles.dart';
import '../widgets/publish_photo_grid.dart';
import '../widgets/listing_extra_params.dart';
import '../widgets/location_picker_fields.dart';
import '../utils/rdc_locations.dart';

/// Publication catalogue officielle (plusieurs tailles / variantes — style Wildberries).
class OfficialCatalogPublishScreen extends StatefulWidget {
  const OfficialCatalogPublishScreen({super.key, this.onPublished});

  final VoidCallback? onPublished;

  @override
  State<OfficialCatalogPublishScreen> createState() => _OfficialCatalogPublishScreenState();
}

class _CatalogVariant {
  String size = '';
  String price = '';
  String stock = '10';
  String? color;
}

class _OfficialCatalogPublishScreenState extends State<OfficialCatalogPublishScreen> {
  final _data = DataService();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _city = TextEditingController(text: 'Kinshasa');
  String? _province = RdcLocations.kinshasa;
  String? _commune;
  String? _quartier;
  final _avenueCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _picker = ImagePicker();
  final List<PublishPhoto> _photos = [];
  final List<_CatalogVariant> _variants = [_CatalogVariant()];

  String _category = 'Mode & Vêtements';
  Map<String, int> _categoryIds = {};
  List<String> _categories = [];
  String? _condition;
  String? _defaultColor;
  String _gender = 'Mixte';
  String _audience = 'Adulte';
  String _deliveryMethod = 'pickup_store';
  bool _loading = false;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cat = await CategoryCatalog.load(_data);
    if (mounted) {
      setState(() {
        _categories = cat.names.where((c) => c != 'Toutes').toList();
        _categoryIds = cat.ids;
        if (_categories.isNotEmpty && !_categories.contains(_category)) {
          _category = _categories.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _city.dispose();
    _brandCtrl.dispose();
    _avenueCtrl.dispose();
    _numeroCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _stepBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _step == 0
                    ? _photosStep()
                    : _step == 1
                        ? _infoStep()
                        : _variantsStep(),
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 16),
      decoration: PremiumTheme.heroGradient,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Catalogue officiel', style: PremiumTheme.display.copyWith(fontSize: 20, color: Colors.white)),
                Text(
                  'Plusieurs tailles dans une publication (Wildberries)',
                  style: PremiumTheme.body.copyWith(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          const Icon(Icons.storefront_rounded, color: PremiumTheme.gold, size: 28),
        ],
      ),
    );
  }

  Widget _stepBar() {
    const labels = ['Photos', 'Produit', 'Variantes'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: List.generate(3, (i) {
          final active = _step >= i;
          return Expanded(
            child: Column(
              children: [
                Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: active ? PremiumTheme.blue : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(labels[i], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? PremiumTheme.blue : PremiumTheme.textMuted)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _photosStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photos du produit', style: PublishFieldStyles.label.copyWith(fontSize: 16)),
        const SizedBox(height: 12),
        PublishPhotoGrid(
          photos: _photos,
          onAdd: _pickImage,
          onRemove: (i) => setState(() => _photos.removeAt(i)),
        ),
      ],
    );
  }

  Widget _infoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field('Titre du produit', _title, 'Ex: Robe été coton'),
        const SizedBox(height: 12),
        _field('Description', _desc, 'Composition, entretien…', maxLines: 4),
        const SizedBox(height: 12),
        LocationPickerFields(
          province: _province,
          commune: _commune,
          quartier: _quartier,
          avenueController: _avenueCtrl,
          numeroController: _numeroCtrl,
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
        const SizedBox(height: 16),
        Text('Mode de remise (obligatoire)', style: PublishFieldStyles.label),
        const SizedBox(height: 8),
        RadioListTile<String>(
          title: const Text('Récupération en boutique / sur place', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
          subtitle: const Text('Permet aussi le paiement sur place', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          value: 'pickup_store',
          groupValue: _deliveryMethod,
          onChanged: (v) => setState(() => _deliveryMethod = v!),
        ),
        RadioListTile<String>(
          title: const Text('J\'ai mon propre livreur', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
          value: 'own_courier',
          groupValue: _deliveryMethod,
          onChanged: (v) => setState(() => _deliveryMethod = v!),
        ),
        const SizedBox(height: 12),
        Text('Catégorie', style: PublishFieldStyles.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((c) {
            final sel = _category == c;
            return FilterChip(
              label: Text(c, style: sel ? PublishFieldStyles.chipLabelSelected : PublishFieldStyles.chipLabel),
              selected: sel,
              onSelected: (_) => setState(() => _category = c),
              selectedColor: PremiumTheme.blue.withValues(alpha: 0.18),
              checkmarkColor: PremiumTheme.blue,
              backgroundColor: Colors.white,
              side: BorderSide(color: sel ? PremiumTheme.blue : const Color(0xFFCBD5E1)),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _field('Marque', _brandCtrl, 'Ex: Zara, Nike…'),
        const SizedBox(height: 16),
        Text('Genre', style: PublishFieldStyles.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ListingAttributes.genders.map((g) {
            return FilterChip(
              label: Text(g, style: PublishFieldStyles.chipLabel),
              selected: _gender == g,
              onSelected: (_) => setState(() => _gender = g),
              selectedColor: PremiumTheme.blue.withValues(alpha: 0.18),
              checkmarkColor: PremiumTheme.blue,
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Text('Public', style: PublishFieldStyles.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ListingAttributes.audiences.map((a) {
            return FilterChip(
              label: Text(a, style: const TextStyle(fontSize: 11)),
              selected: _audience == a,
              onSelected: (_) => setState(() => _audience = a),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        ListingExtraParams(
          category: _category,
          selectedSize: null,
          onSizeChanged: (_) {},
          sizeRequired: false,
          condition: _condition,
          onConditionChanged: (c) => setState(() => _condition = c),
          selectedColor: _defaultColor,
          onColorChanged: (c) => setState(() => _defaultColor = c),
        ),
      ],
    );
  }

  Widget _variantsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tailles & prix', style: PublishFieldStyles.label.copyWith(fontSize: 16)),
        const SizedBox(height: 6),
        Text(
          'Ajoutez une ligne par taille (prix, stock, couleur).',
          style: PublishFieldStyles.input.copyWith(fontSize: 12, color: PremiumTheme.textMuted),
        ),
        const SizedBox(height: 16),
        ...List.generate(_variants.length, (i) => _variantCard(i)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => setState(() => _variants.add(_CatalogVariant())),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Ajouter une taille'),
        ),
      ],
    );
  }

  Widget _variantCard(int index) {
    final v = _variants[index];
    final sizes = ListingAttributes.sizesForCategory(_category);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Variante ${index + 1}', style: PremiumTheme.h1.copyWith(fontSize: 14)),
                const Spacer(),
                if (_variants.length > 1)
                  IconButton(
                    onPressed: () => setState(() => _variants.removeAt(index)),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Taille', style: PublishFieldStyles.label),
            Wrap(
              spacing: 6,
              children: sizes.take(14).map((s) {
                return FilterChip(
                  label: Text(s, style: PublishFieldStyles.chipLabel),
                  selected: v.size == s,
                  onSelected: (_) => setState(() => v.size = s),
                  selectedColor: PremiumTheme.blue.withValues(alpha: 0.18),
                  checkmarkColor: PremiumTheme.blue,
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            ColorPickerField(
              label: 'Couleur de la variante',
              compact: true,
              selectedColor: v.color,
              onChanged: (c) => setState(() => v.color = c),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    style: PublishFieldStyles.input,
                    decoration: PublishFieldStyles.decoration('Prix CDF'),
                    keyboardType: TextInputType.number,
                    onChanged: (t) => v.price = t,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    style: PublishFieldStyles.input,
                    decoration: PublishFieldStyles.decoration('Stock'),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: v.stock),
                    onChanged: (t) => v.stock = t,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: PublishFieldStyles.label),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          maxLines: maxLines,
          style: PublishFieldStyles.input,
          decoration: PublishFieldStyles.decoration(hint),
        ),
      ],
    );
  }

  Widget _bottomBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          if (_step > 0)
            TextButton(onPressed: () => setState(() => _step--), child: const Text('Retour')),
          Expanded(
            child: ElevatedButton(
              onPressed: _loading ? null : _onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: PremiumTheme.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_step < 2 ? 'Continuer' : 'Publier le catalogue', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  void _onNext() {
    if (_step == 0) {
      if (_photos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajoutez au moins une photo')));
        return;
      }
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      if (_title.text.trim().isEmpty || _brandCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Titre et marque requis')));
        return;
      }
      if (_commune == null || _quartier == null || _quartier!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sélectionnez la commune et le quartier'), backgroundColor: AppColors.danger),
        );
        return;
      }
      setState(() => _step = 2);
      return;
    }
    _publish();
  }

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null || _photos.length >= 8) return;
    final bytes = await x.readAsBytes();
    if (mounted) setState(() => _photos.add(PublishPhoto(file: x, bytes: bytes)));
  }

  Future<void> _publish() async {
    final variantMaps = <Map<String, dynamic>>[];
    for (final v in _variants) {
      final price = int.tryParse(v.price.replaceAll(RegExp(r'[^0-9]'), ''));
      if (v.size.isEmpty || price == null || price <= 0) continue;
      variantMaps.add({
        'size': v.size,
        'price_cdf': price,
        'stock': int.tryParse(v.stock) ?? 0,
        if (v.color != null) 'color': v.color,
      });
    }
    if (variantMaps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins une taille avec prix'), backgroundColor: AppColors.danger),
      );
      return;
    }
    if (_commune == null || _quartier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez commune et quartier'), backgroundColor: AppColors.danger),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await _data.createOfficialCatalog(
        title: _title.text.trim(),
        description: _desc.text.trim(),
        location: RdcLocations.listingCity(province: _province ?? RdcLocations.kinshasa, cityOrCommune: _commune ?? ''),
        province: _province,
        commune: _commune,
        quartier: _quartier,
        avenue: _avenueCtrl.text.trim().isEmpty ? null : _avenueCtrl.text.trim(),
        numero: _numeroCtrl.text.trim().isEmpty ? null : _numeroCtrl.text.trim(),
        category: _category,
        categoryId: _categoryIds[_category],
        brand: _brandCtrl.text.trim(),
        gender: _gender,
        audience: _audience,
        condition: _condition,
        defaultColor: _defaultColor,
        variants: variantMaps,
        deliveryMethod: _deliveryMethod,
        imageFiles: _photos.map((p) => p.file).toList(),
        imageBytesList: _photos.map((p) => p.bytes).toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Catalogue publié avec succès'), backgroundColor: PremiumTheme.emerald),
      );
      widget.onPublished?.call();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
