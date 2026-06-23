import 'dart:typed_data';

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

/// Publication catalogue officielle SombaTeka — 1 publication, plusieurs produits.
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

class _CatalogProduct {
  _CatalogProduct();

  final title = TextEditingController();
  final desc = TextEditingController();
  final List<PublishPhoto> photos = [];
  final List<_CatalogVariant> variants = [_CatalogVariant()];
  String? condition;
  String? defaultColor;
  bool expanded = true;

  void dispose() {
    title.dispose();
    desc.dispose();
  }
}

class _OfficialCatalogPublishScreenState extends State<OfficialCatalogPublishScreen> {
  final _data = DataService();
  final _publicationTitle = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _picker = ImagePicker();
  String? _province = RdcLocations.kinshasa;
  String? _commune;
  String? _quartier;
  final _avenueCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final List<_CatalogProduct> _products = [_CatalogProduct()];

  String _category = 'Mode & Vêtements';
  Map<String, int> _categoryIds = {};
  List<String> _categories = [];
  String _gender = 'Mixte';
  String _audience = 'Adulte';
  String _deliveryMethod = 'pickup_store';
  bool _loading = false;
  int _step = 0;

  static const _maxPhotosPerProduct = 12;

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
    _publicationTitle.dispose();
    _brandCtrl.dispose();
    _avenueCtrl.dispose();
    _numeroCtrl.dispose();
    for (final p in _products) {
      p.dispose();
    }
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
                child: _step == 0 ? _boutiqueStep() : _productsStep(),
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
                  '1 publication · plusieurs produits · chaque article sur l\'accueil',
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
    const labels = ['Boutique', 'Produits'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: List.generate(2, (i) {
          final active = _step >= i;
          return Expanded(
            child: Column(
              children: [
                Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < 1 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: active ? PremiumTheme.blue : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: active ? PremiumTheme.blue : PremiumTheme.textMuted,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _boutiqueStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field('Titre de la publication', _publicationTitle, 'Ex: Collection été 2026 Zara'),
        const SizedBox(height: 12),
        _field('Marque / boutique', _brandCtrl, 'Ex: Zara, Nike…'),
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
        const SizedBox(height: 16),
        Text('Mode de remise (obligatoire)', style: PublishFieldStyles.label),
        RadioListTile<String>(
          title: const Text('Récupération en boutique / sur place'),
          value: 'pickup_store',
          groupValue: _deliveryMethod,
          onChanged: (v) => setState(() => _deliveryMethod = v!),
        ),
        RadioListTile<String>(
          title: const Text('J\'ai mon propre livreur'),
          value: 'own_courier',
          groupValue: _deliveryMethod,
          onChanged: (v) => setState(() => _deliveryMethod = v!),
        ),
        const SizedBox(height: 12),
        Text('Catégorie par défaut', style: PublishFieldStyles.label),
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
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: ListingAttributes.genders.map((g) {
            return FilterChip(
              label: Text(g),
              selected: _gender == g,
              onSelected: (_) => setState(() => _gender = g),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _productsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Produits (${_products.length})',
          style: PublishFieldStyles.label.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 6),
        Text(
          'Chaque produit = une carte sur l\'accueil, avec ses propres photos et tailles.',
          style: PublishFieldStyles.input.copyWith(fontSize: 12, color: PremiumTheme.textMuted),
        ),
        const SizedBox(height: 16),
        ...List.generate(_products.length, (i) => _productCard(i)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => setState(() => _products.add(_CatalogProduct())),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Ajouter un produit'),
        ),
      ],
    );
  }

  Widget _productCard(int index) {
    final product = _products[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          ListTile(
            title: Text('Produit ${index + 1}', style: PremiumTheme.h1.copyWith(fontSize: 14)),
            subtitle: product.title.text.trim().isEmpty
                ? const Text('Sans titre')
                : Text(product.title.text.trim(), maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_products.length > 1)
                  IconButton(
                    onPressed: () => setState(() {
                      product.dispose();
                      _products.removeAt(index);
                    }),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  ),
                IconButton(
                  onPressed: () => setState(() => product.expanded = !product.expanded),
                  icon: Icon(product.expanded ? Icons.expand_less : Icons.expand_more),
                ),
              ],
            ),
          ),
          if (product.expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field('Titre du produit', product.title, 'Ex: Robe lin beige'),
                  const SizedBox(height: 10),
                  _field('Description (optionnel)', product.desc, 'Matière, entretien…', maxLines: 3),
                  const SizedBox(height: 12),
                  PublishPhotoGrid(
                    photos: product.photos,
                    maxPhotos: _maxPhotosPerProduct,
                    onAdd: () => _pickImage(product),
                    onRemove: (i) => setState(() => product.photos.removeAt(i)),
                  ),
                  const SizedBox(height: 12),
                  ListingExtraParams(
                    category: _category,
                    selectedSize: null,
                    onSizeChanged: (_) {},
                    sizeRequired: false,
                    condition: product.condition,
                    onConditionChanged: (c) => setState(() => product.condition = c),
                    selectedColor: product.defaultColor,
                    onColorChanged: (c) => setState(() => product.defaultColor = c),
                  ),
                  const SizedBox(height: 12),
                  Text('Tailles & prix', style: PublishFieldStyles.label),
                  ...List.generate(product.variants.length, (vi) => _variantRow(product, vi)),
                  TextButton.icon(
                    onPressed: () => setState(() => product.variants.add(_CatalogVariant())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Ajouter une taille'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _variantRow(_CatalogProduct product, int index) {
    final v = product.variants[index];
    final sizes = ListingAttributes.sizesForCategory(_category);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Taille ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              const Spacer(),
              if (product.variants.length > 1)
                IconButton(
                  onPressed: () => setState(() => product.variants.removeAt(index)),
                  icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
                ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: sizes.map((s) {
              return FilterChip(
                label: Text(s, style: const TextStyle(fontSize: 10)),
                selected: v.size == s,
                onSelected: (_) => setState(() => v.size = s),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          TextField(
            decoration: PublishFieldStyles.decoration('Ou saisir une taille (ONE SIZE, 54-58…)'),
            onChanged: (t) => v.size = t.trim(),
          ),
          const SizedBox(height: 6),
          ColorPickerField(
            label: 'Couleur',
            compact: true,
            selectedColor: v.color,
            onChanged: (c) => setState(() => v.color = c),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: PublishFieldStyles.decoration('Prix CDF'),
                  keyboardType: TextInputType.number,
                  onChanged: (t) => v.price = t,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  decoration: PublishFieldStyles.decoration('Stock'),
                  keyboardType: TextInputType.number,
                  onChanged: (t) => v.stock = t,
                ),
              ),
            ],
          ),
        ],
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
                  : Text(
                      _step < 1 ? 'Continuer' : 'Publier ${_products.length} produit(s)',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _onNext() {
    if (_step == 0) {
      if (_publicationTitle.text.trim().isEmpty || _brandCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Titre publication et marque requis')));
        return;
      }
      if (_commune == null || _quartier == null || _quartier!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sélectionnez commune et quartier'), backgroundColor: AppColors.danger),
        );
        return;
      }
      setState(() => _step = 1);
      return;
    }
    _publish();
  }

  Future<void> _pickImage(_CatalogProduct product) async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (x == null || product.photos.length >= _maxPhotosPerProduct) return;
    final bytes = await x.readAsBytes();
    if (mounted) setState(() => product.photos.add(PublishPhoto(file: x, bytes: bytes)));
  }

  Future<void> _publish() async {
    final payloads = <({
      String title,
      String? description,
      String? condition,
      String? defaultColor,
      List<Map<String, dynamic>> variants,
      List<XFile> imageFiles,
      List<Uint8List> imageBytesList,
    })>[];

    for (final product in _products) {
      if (product.photos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chaque produit doit avoir au moins une photo'), backgroundColor: AppColors.danger),
        );
        return;
      }
      if (product.title.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Donnez un titre à chaque produit'), backgroundColor: AppColors.danger),
        );
        return;
      }
      final variantMaps = <Map<String, dynamic>>[];
      for (final v in product.variants) {
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
          SnackBar(content: Text('« ${product.title.text.trim()} » : ajoutez au moins une taille'), backgroundColor: AppColors.danger),
        );
        return;
      }
      payloads.add((
        title: product.title.text.trim(),
        description: product.desc.text.trim().isEmpty ? null : product.desc.text.trim(),
        condition: product.condition,
        defaultColor: product.defaultColor,
        variants: variantMaps,
        imageFiles: product.photos.map((p) => p.file).toList(),
        imageBytesList: product.photos.map((p) => p.bytes).toList(),
      ));
    }

    setState(() => _loading = true);
    try {
      final result = await _data.createOfficialCollection(
        publicationTitle: _publicationTitle.text.trim(),
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
        deliveryMethod: _deliveryMethod,
        products: payloads,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result['productCount']} produit(s) publié(s) — visibles sur l\'accueil'),
          backgroundColor: PremiumTheme.emerald,
        ),
      );
      widget.onPublished?.call();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
