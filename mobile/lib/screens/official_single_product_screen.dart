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

class _CatalogVariant {
  String size = '';
  String price = '';
  String stock = '10';
  String? color;
}

/// Produit officiel unique (1 annonce, variantes tailles — distinct de la collection).
class OfficialSingleProductScreen extends StatefulWidget {
  const OfficialSingleProductScreen({super.key, this.onPublished});

  final VoidCallback? onPublished;

  @override
  State<OfficialSingleProductScreen> createState() => _OfficialSingleProductScreenState();
}

class _OfficialSingleProductScreenState extends State<OfficialSingleProductScreen> {
  final _data = DataService();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _picker = ImagePicker();
  final List<PublishPhoto> _photos = [];
  final List<_CatalogVariant> _variants = [_CatalogVariant()];

  String? _province = RdcLocations.kinshasa;
  String? _commune;
  String? _quartier;
  final _avenueCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  String _category = 'Mode & Vêtements';
  Map<String, int> _categoryIds = {};
  List<String> _categories = [];
  String? _condition;
  String? _defaultColor;
  String _gender = 'Mixte';
  String _audience = 'Adulte';
  String _deliveryMethod = 'pickup_store';
  bool _loading = false;

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
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _brandCtrl.dispose();
    _avenueCtrl.dispose();
    _numeroCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.surface,
      appBar: AppBar(
        title: const Text('Produit unique Pro'),
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PublishPhotoGrid(
              photos: _photos,
              maxPhotos: 12,
              onAdd: _pickImage,
              onRemove: (i) => setState(() => _photos.removeAt(i)),
            ),
            const SizedBox(height: 16),
            _field('Titre', _title, 'Ex: Sneakers Nike Air'),
            const SizedBox(height: 12),
            _field('Description', _desc, 'Matière, entretien…', maxLines: 3),
            const SizedBox(height: 12),
            _field('Marque', _brandCtrl, 'Ex: Nike'),
            const SizedBox(height: 16),
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
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            const Text('Tailles & stock', style: TextStyle(fontWeight: FontWeight.w800)),
            ...List.generate(_variants.length, (i) => _variantRow(i)),
            TextButton.icon(
              onPressed: () => setState(() => _variants.add(_CatalogVariant())),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une taille'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _publish,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Publier le produit', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
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

  Widget _variantRow(int index) {
    final v = _variants[index];
    final sizes = ListingAttributes.sizesForCategory(_category);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              children: sizes.take(10).map((s) {
                return FilterChip(
                  label: Text(s, style: const TextStyle(fontSize: 10)),
                  selected: v.size == s,
                  onSelected: (_) => setState(() => v.size = s),
                );
              }).toList(),
            ),
            ColorPickerField(label: 'Couleur', compact: true, selectedColor: v.color, onChanged: (c) => setState(() => v.color = c)),
            Row(
              children: [
                Expanded(child: TextField(decoration: PublishFieldStyles.decoration('Prix CDF'), keyboardType: TextInputType.number, onChanged: (t) => v.price = t)),
                const SizedBox(width: 8),
                Expanded(child: TextField(decoration: PublishFieldStyles.decoration('Stock'), keyboardType: TextInputType.number, onChanged: (t) => v.stock = t)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (x == null || _photos.length >= 12) return;
    final bytes = await x.readAsBytes();
    if (mounted) setState(() => _photos.add(PublishPhoto(file: x, bytes: bytes)));
  }

  Future<void> _publish() async {
    if (_photos.isEmpty || _title.text.trim().isEmpty || _brandCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photos, titre et marque requis')));
      return;
    }
    if (_commune == null || _quartier == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Commune et quartier requis')));
      return;
    }
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajoutez au moins une taille')));
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
      widget.onPublished?.call();
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
