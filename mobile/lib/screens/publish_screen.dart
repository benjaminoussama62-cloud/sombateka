import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/data_service.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../widgets/publish_photo_grid.dart';
import '../widgets/listing_extra_params.dart';
import '../widgets/location_picker_fields.dart';
import '../utils/listing_attributes.dart';
import '../utils/rdc_locations.dart';
import '../widgets/publish_field_styles.dart';
import '../utils/moderation.dart';

/// Publication d'annonce — Web-safe (build 2026-05-20-v3).
class PublishScreen extends StatefulWidget {
  const PublishScreen({super.key, this.onPublished, this.onGoHome});

  /// Après publication réussie (onglet principal).
  final VoidCallback? onPublished;

  /// Retour vers l’accueil sans quitter l’app (évite [Navigator.pop] → splash).
  final VoidCallback? onGoHome;

  @override
  State<PublishScreen> createState() => PublishScreenState();
}

class PublishScreenState extends State<PublishScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _city = TextEditingController(text: 'Kinshasa');
  String? _province = RdcLocations.kinshasa;
  String? _commune;
  String? _quartier;
  final _avenueCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _data = DataService();

  String _category = 'Électronique';
  String? _selectedSize;
  String? _condition;
  String? _selectedColor;
  final _brandCtrl = TextEditingController();
  String _listingType = ListingType.contact;
  final List<PublishPhoto> _photos = [];
  List<String> _categories = [];
  final Map<String, int> _categoryIds = {};
  bool _loading = false;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _data.fetchCategories();
      if (cats.isNotEmpty && mounted) {
        final names = <String>{};
        for (final c in cats) {
          final name = c['name'] as String;
          _categoryIds[name] = c['id'] as int;
          names.add(name);
        }
        names.addAll(ListingAttributes.fashionCategoryNames);
        setState(() {
          _categories = names.toList()..sort();
          if (!_categories.contains(_category)) _category = _categories.first;
        });
      }
    } catch (_) {
      _categories = [...AppStrings.categories, ...ListingAttributes.fashionCategoryNames];
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
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
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            _stepIndicator(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _step == 0 ? _buildPhotosStep() : _buildDetailsStep(),
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: PremiumTheme.heroGradient,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
          child: Row(
            children: [
              IconButton(
                onPressed: _handleBack,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vendre — particulier', style: PremiumTheme.display.copyWith(fontSize: 22)),
                    Text(
                      _step == 0 ? 'Photos claires = plus de contacts' : 'Décrivez bien votre article',
                      style: PremiumTheme.body.copyWith(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _stepDot(0, 'Photos'),
          Expanded(child: Container(height: 2, color: _step >= 1 ? PremiumTheme.blue : AppColors.border)),
          _stepDot(1, 'Détails'),
        ],
      ),
    );
  }

  Widget _stepDot(int i, String label) {
    final active = _step >= i;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: active ? const LinearGradient(colors: [PremiumTheme.blue, PremiumTheme.blueGlow]) : null,
            color: active ? null : AppColors.border,
          ),
          child: Center(
            child: Text(
              '${i + 1}',
              style: TextStyle(
                color: active ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: PremiumTheme.label.copyWith(
            fontSize: 10,
            color: active ? PremiumTheme.blue : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotosStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PublishPhotoGrid(
          photos: _photos,
          onAdd: _pickImage,
          onRemove: (i) => setState(() => _photos.removeAt(i)),
        ),
        const SizedBox(height: 16),
        _particularTips(),
        const SizedBox(height: 16),
        _typeSelector(),
      ],
    );
  }

  Widget _particularTips() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PremiumTheme.blue.withValues(alpha: 0.08),
        borderRadius: PremiumTheme.radiusMd,
        border: Border.all(color: PremiumTheme.blue.withValues(alpha: 0.2)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates_outlined, color: PremiumTheme.blue, size: 18),
              SizedBox(width: 8),
              Text('Conseil vendeur', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ],
          ),
          SizedBox(height: 6),
          Text(
            '• 3 à 5 photos sous différents angles\n'
            '• Prix honnête et description exacte\n'
            '• Commune + quartier pour être trouvé',
            style: TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _typeSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: PremiumTheme.radiusMd,
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: const Row(
        children: [
          Icon(Icons.chat_bubble_outline_rounded, color: PremiumTheme.emerald, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vente entre particuliers', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                Text(
                  'Les acheteurs vous contactent par message. Pas de paiement in-app.',
                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _field('Titre', _title, 'Ex: iPhone 15 Pro Max 256Go'),
        const SizedBox(height: 14),
        _field('Description', _desc, 'État, garantie, livraison...', maxLines: 4),
        const SizedBox(height: 14),
        _field('Prix (CDF)', _price, '1250000', keyboard: TextInputType.number),
        const SizedBox(height: 14),
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
        const SizedBox(height: 14),
        Text('Catégorie', style: PublishFieldStyles.label),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (_categories.isEmpty
                      ? [...AppStrings.categories, ...ListingAttributes.fashionCategoryNames]
                      : _categories)
                  .map((c) {
                final sel = _category == c;
                return FilterChip(
                  label: Text(
                    c,
                    style: sel ? PublishFieldStyles.chipLabelSelected : PublishFieldStyles.chipLabel,
                  ),
                  selected: sel,
                  onSelected: (_) => setState(() {
                    _category = c;
                    _selectedSize = null;
                    _condition = null;
                    _selectedColor = null;
                  }),
                  selectedColor: PremiumTheme.blue.withValues(alpha: 0.15),
                  checkmarkColor: PremiumTheme.blue,
                );
              }).toList(),
            ),
          ),
        ),
        if (ListingAttributes.categorySupportsExtraParams(_category)) ...[
          const SizedBox(height: 18),
          ListingExtraParams(
            category: _category,
            selectedSize: _selectedSize,
            onSizeChanged: (s) => setState(() => _selectedSize = s),
            condition: _condition,
            onConditionChanged: (c) => setState(() => _condition = c),
            brandController: _brandCtrl,
            selectedColor: _selectedColor,
            onColorChanged: (c) => setState(() => _selectedColor = c),
          ),
        ],
      ],
    );
  }

  Widget _field(String label, TextEditingController c, String hint, {int maxLines = 1, TextInputType? keyboard}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: PublishFieldStyles.label),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          maxLines: maxLines,
          keyboardType: keyboard,
          style: PublishFieldStyles.input,
          decoration: PublishFieldStyles.decoration(hint),
        ),
      ],
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          if (_step > 0)
            TextButton(
              onPressed: () => setState(() => _step--),
              child: const Text('Retour'),
            ),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : (_step == 0 ? _nextStep : _publish),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PremiumTheme.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: PremiumTheme.radiusLg),
                  elevation: 4,
                ),
                child: _loading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_step == 0 ? 'Continuer' : 'Publier maintenant', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _embeddedInMain => widget.onGoHome != null || widget.onPublished != null;

  void _handleBack() {
    if (_embeddedInMain) {
      widget.onGoHome?.call();
      return;
    }
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  /// Réinitialise le formulaire après publication réussie.
  void resetForm() {
    setState(() {
      _photos.clear();
      _step = 0;
      _title.clear();
      _desc.clear();
      _price.clear();
      _listingType = ListingType.contact;
      _selectedSize = null;
      _condition = null;
      _selectedColor = null;
      _brandCtrl.clear();
      _commune = null;
      _quartier = null;
      _province = RdcLocations.kinshasa;
      _avenueCtrl.clear();
      _numeroCtrl.clear();
    });
  }

  void _nextStep() {
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajoutez au moins une photo')));
      return;
    }
    setState(() => _step = 1);
  }

  Future<void> _pickImage() async {
    try {
      final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (x == null || _photos.length >= 5) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() => _photos.add(PublishPhoto(file: x, bytes: bytes)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de charger la photo: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _publish() async {
    if (_title.text.trim().isEmpty || _price.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Titre et prix requis')));
      return;
    }
    if (ListingAttributes.categoryNeedsSize(_category) && (_selectedSize == null || _selectedSize!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez une taille / pointure'), backgroundColor: AppColors.danger),
      );
      return;
    }
    if (_commune == null || _commune!.isEmpty || _quartier == null || _quartier!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez la commune et le quartier'), backgroundColor: AppColors.danger),
      );
      return;
    }
    final modErr = validateListingText(title: _title.text.trim(), description: _desc.text.trim());
    if (modErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(modErr), backgroundColor: AppColors.danger, duration: const Duration(seconds: 6)),
      );
      return;
    }
    if (!await _data.hasApiSession()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connectez-vous pour publier une annonce'),
          backgroundColor: AppColors.danger,
        ),
      );
      Navigator.pushNamed(context, AppRoutes.auth);
      return;
    }
    final user = _data.currentUser;
    if (user == null) {
      await _data.refreshUser();
    }
    final userId = _data.currentUser?['id']?.toString();
    if (userId == null || userId.isEmpty) {
      if (!mounted) return;
      Navigator.pushNamed(context, AppRoutes.auth);
      return;
    }
    setState(() => _loading = true);
    try {
      await _data.createListing(
        userId: userId,
        title: _title.text.trim(),
        description: _desc.text.trim(),
        price: _price.text.trim(),
        category: _category,
        categoryId: _categoryIds[_category],
        location: RdcLocations.listingCity(province: _province ?? RdcLocations.kinshasa, cityOrCommune: _commune ?? ''),
        province: _province,
        commune: _commune,
        quartier: _quartier,
        avenue: _avenueCtrl.text.trim().isEmpty ? null : _avenueCtrl.text.trim(),
        numero: _numeroCtrl.text.trim().isEmpty ? null : _numeroCtrl.text.trim(),
        listingType: _listingType,
        images: const [],
        imageFiles: _photos.map((p) => p.file).toList(),
        imageBytesList: _photos.map((p) => p.bytes).toList(),
        size: _selectedSize,
        condition: _condition,
        brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
        color: _selectedColor,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _photos.isEmpty
                ? 'Annonce publiée'
                : 'Annonce publiée avec ${_photos.length} photo(s)',
          ),
          backgroundColor: PremiumTheme.emerald,
        ),
      );
      if (widget.onPublished != null) {
        widget.onPublished!();
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('SESSION_REQUIRED') || e.toString().contains('401')
          ? 'Session expirée — reconnectez-vous'
          : 'Erreur: $e';
      if (msg.contains('reconnectez')) {
        Navigator.pushNamed(context, AppRoutes.auth);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
