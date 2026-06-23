import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/onboarding_service.dart';
import '../widgets/app_tour_overlay.dart';
import '../widgets/marketplace_product_card.dart';
import '../widgets/marketplace_filter_sheet.dart';
import '../theme/premium_theme.dart';
import '../services/cart_ui_helper.dart';
import '../services/data_service.dart';
import '../utils/api_errors.dart';
import '../utils/category_catalog.dart';
import '../utils/constants.dart';
import '../utils/listing_attributes.dart';
import '../utils/responsive.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _dataService = DataService();

  final _filters = MarketplaceFilterState();
  List<String> _categories = ['Toutes'];
  Map<String, int> _categoryIds = {};

  bool _loading = false;
  bool _imageSearchActive = false;
  String? _imageSearchMessage;
  List<Map<String, dynamic>> _searchResults = [];

  bool get _isActiveSearch =>
      _imageSearchActive ||
      _searchController.text.trim().isNotEmpty ||
      _filters.category != 'Toutes' ||
      _filters.activeCount > 0 ||
      _searchResults.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _init();
    _searchController.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppTourPresenter.maybeShow(context, AppTourPage.search);
    });
  }

  Future<void> _init() async {
    final cat = await CategoryCatalog.load(_dataService);
    if (mounted) {
      setState(() {
        _categories = cat.names;
        _categoryIds = cat.ids;
      });
    }
    await _loadListings();
  }

  void _onQueryChanged() {
    if (_searchController.text.trim().isEmpty &&
        _filters.category == 'Toutes' &&
        _filters.activeCount == 0) {
      setState(() => _searchResults = []);
    }
  }

  Future<void> _loadListings() async {
    setState(() => _loading = true);
    try {
      await _applyApiFilters();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _applyApiFilters() async {
    await _dataService.refreshListings(
      q: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      categoryId: _filters.categoryId,
      size: _filters.size,
      isOfficial: _filters.officialOnly ? true : null,
      minPrice: _filters.minPrice > 0 ? _filters.minPrice : null,
      maxPrice: _filters.maxPrice < 10000000 ? _filters.maxPrice : null,
      color: _filters.color,
      condition: _filters.condition,
      brand: _filters.brand,
      gender: _filters.gender,
      audience: _filters.audience,
      commune: _filters.commune,
      quartier: _filters.quartier,
      province: _filters.province,
      minRating: _filters.minStars,
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _displayResults {
    if (_searchResults.isNotEmpty) return _searchResults;
    return _dataService.listings;
  }

  @override
  Widget build(BuildContext context) {
    final results = _clientFilter(_displayResults);

    return Scaffold(
      backgroundColor: PremiumTheme.surface,
      body: Column(
        children: [
          _buildHeader(),
          _buildCategoryChips(),
          Expanded(child: _buildBody(results)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final filterCount = _filters.activeCount;
    return Container(
      width: double.infinity,
      decoration: PremiumTheme.heroGradient,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacementNamed(context, AppRoutes.main);
                      }
                    },
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  Expanded(
                    child: Text('Rechercher', style: PremiumTheme.display.copyWith(fontSize: 24)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: PremiumTheme.radiusLg,
                  boxShadow: PremiumTheme.softShadow,
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    const Icon(Icons.search_rounded, color: PremiumTheme.blue, size: 22),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: (_) => _performSearch(),
                        decoration: const InputDecoration(
                          hintText: 'Produit, marque, ville…',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                      ),
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          tooltip: 'Filtres',
                          onPressed: _openFilters,
                          icon: const Icon(Icons.tune_rounded, color: PremiumTheme.blue),
                        ),
                        if (filterCount > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                              child: Text(
                                '$filterCount',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Material(
                      color: PremiumTheme.navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: _searchByImage,
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.photo_camera_rounded, color: PremiumTheme.navy, size: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFilters() async {
    final result = await showMarketplaceFilterSheet(
      context,
      initial: _filters,
      categories: _categories,
      categoryIds: _categoryIds,
    );
    if (result == null) return;
    setState(() {
      _filters.category = result.category;
      _filters.categoryId = result.categoryId;
      _filters.size = result.size;
      _filters.color = result.color;
      _filters.condition = result.condition;
      _filters.brand = result.brand;
      _filters.gender = result.gender;
      _filters.audience = result.audience;
      _filters.province = result.province;
      _filters.commune = result.commune;
      _filters.quartier = result.quartier;
      _filters.minStars = result.minStars;
      _filters.officialOnly = result.officialOnly;
      _filters.minPrice = result.minPrice;
      _filters.maxPrice = result.maxPrice;
    });
    _performSearch();
  }

  Widget _buildCategoryChips() {
    final displayCats = _categories.length > 12 ? _categories.take(12).toList() : _categories;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: displayCats.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final label = displayCats[i];
            final selected = _filters.category == label;
            return FilterChip(
              label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              avatar: Icon(
                CategoryCatalog.iconFor(label),
                size: 16,
                color: selected ? Colors.white : CategoryCatalog.colorFor(label),
              ),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _filters.category = label;
                  _filters.categoryId = label == 'Toutes' ? null : _categoryIds[label];
                  _filters.size = null;
                });
                _performSearch();
              },
              selectedColor: PremiumTheme.blue,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(color: selected ? Colors.white : PremiumTheme.textDark),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> results) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: PremiumTheme.blue));
    }
    if (!_isActiveSearch) return _buildDiscover();
    if (results.isEmpty) return _buildEmptyResults();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(
            _imageSearchActive
                ? 'Résultats · photo similaire'
                : '${results.length} résultat${results.length > 1 ? 's' : ''}',
            style: PremiumTheme.h1.copyWith(fontSize: 16),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: Responsive.productGridColumns(context),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: Responsive.productGridAspectRatio(context),
            ),
            itemCount: results.length,
            itemBuilder: (_, i) {
              final listing = results[i];
              final sim = (listing['similarity'] as num?)?.toDouble();
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  MarketplaceProductCard(
                    listing: listing,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.detail, arguments: listing),
                    onFavorite: () async {
                      await _dataService.toggleFavorite(listing['id']?.toString() ?? '');
                      setState(() {});
                    },
                    onAddToCart: listing['isOwnListing'] == true
                        ? null
                        : () => CartUiHelper.addListing(context, listing),
                  ),
                  if (_imageSearchActive && sim != null && sim > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [PremiumTheme.navy, PremiumTheme.blue],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '${(sim * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDiscover() {
    final cats = _categories.where((c) => c != 'Toutes').take(8).toList();
    final listings = _dataService.listings.take(8).toList();

    return RefreshIndicator(
      color: PremiumTheme.blue,
      onRefresh: _loadListings,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text('Catégories', style: PremiumTheme.h1.copyWith(fontSize: 17)),
          const SizedBox(height: 4),
          Text(
            'Recherche visuelle SombaTeka — photo ou galerie pour trouver un produit similaire',
            style: PremiumTheme.body.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: Responsive.productGridColumns(context).clamp(2, 4),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.15,
            children: cats.map((name) {
              return Material(
                color: Colors.white,
                borderRadius: PremiumTheme.radiusMd,
                child: InkWell(
                  borderRadius: PremiumTheme.radiusMd,
                  onTap: () {
                    setState(() {
                      _filters.category = name;
                      _filters.categoryId = _categoryIds[name];
                    });
                    _performSearch();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: PremiumTheme.radiusMd,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CategoryCatalog.iconFor(name), color: CategoryCatalog.colorFor(name), size: 28),
                        const SizedBox(height: 6),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (listings.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Annonces récentes', style: PremiumTheme.h1.copyWith(fontSize: 17)),
            const SizedBox(height: 12),
            ...listings.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MarketplaceProductCard(
                    listing: l,
                    compact: true,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.detail, arguments: l),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyResults() {
    final imageEmpty = _imageSearchActive;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              imageEmpty ? Icons.image_not_supported_outlined : Icons.search_off_rounded,
              size: 72,
              color: PremiumTheme.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              imageEmpty ? 'Aucun produit similaire' : 'Aucun résultat',
              style: PremiumTheme.h1,
            ),
            const SizedBox(height: 8),
            Text(
              imageEmpty
                  ? (_imageSearchMessage ??
                      'Aucun article similaire dans les annonces SombaTeka pour cette photo.')
                  : 'Modifiez les filtres ou essayez une autre catégorie',
              style: PremiumTheme.body,
              textAlign: TextAlign.center,
            ),
            if (!imageEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _openFilters,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Ouvrir les filtres'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _clientFilter(List<Map<String, dynamic>> listings) {
    if (_imageSearchActive) {
      return _dataService.searchListings(
        query: _searchController.text,
        category: _filters.category,
        minPrice: _filters.minPrice,
        maxPrice: _filters.maxPrice,
        size: _filters.size,
        color: _filters.color,
        condition: _filters.condition,
        brand: _filters.brand,
        gender: _filters.gender,
        audience: _filters.audience,
        commune: _filters.commune,
        quartier: _filters.quartier,
        officialOnly: _filters.officialOnly,
        minSellerRating: _filters.minStars?.toDouble(),
      );
    }
    final cat = _filters.category;
    return listings.where((listing) {
      if (cat != 'Toutes') {
        final lc = listing['category']?.toString().toLowerCase() ?? '';
        if (!lc.contains(cat.toLowerCase()) && !cat.toLowerCase().contains(lc)) return false;
      }
      return ListingAttributes.matchesExtraFilters(
        listing,
        condition: _filters.condition,
        color: _filters.color,
        brand: _filters.brand,
        gender: _filters.gender,
        audience: _filters.audience,
        commune: _filters.commune,
        quartier: _filters.quartier,
        officialOnly: _filters.officialOnly,
        minSellerRating: _filters.minStars?.toDouble(),
      ) &&
          ListingAttributes.matchesSize(listing, _filters.size);
    }).toList();
  }

  Future<void> _performSearch() async {
    HapticFeedback.selectionClick();
    setState(() {
      _loading = true;
      _imageSearchActive = false;
      _imageSearchMessage = null;
    });
    try {
      await _applyApiFilters();
    } catch (_) {}
    setState(() {
      if (!_imageSearchActive) _searchResults = [];
      _loading = false;
    });
  }

  Future<void> _searchByImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recherche par photo', style: PremiumTheme.h1.copyWith(fontSize: 18)),
              const SizedBox(height: 6),
              Text(
                'Cadrez un seul produit — SombaTeka compare forme, couleurs et textures.',
                style: PremiumTheme.body.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded, color: PremiumTheme.blue),
                title: const Text('Prendre une photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: PremiumTheme.navy),
                title: const Text('Choisir dans la galerie'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (image == null) return;
      setState(() => _loading = true);
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) throw StateError('Photo illisible');
      final search = await _dataService.searchByImage(
        bytes: bytes,
        filename: image.name.isNotEmpty ? image.name : 'recherche.jpg',
      );
      setState(() {
        _searchResults = search.items;
        _imageSearchActive = true;
        _imageSearchMessage = search.message;
        _filters.reset();
        _loading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            search.items.isEmpty
                ? (search.message ?? 'Aucun produit proche trouvé')
                : '${search.items.length} produit(s) trouvé(s)',
          ),
          backgroundColor: search.items.isEmpty ? AppColors.warning : PremiumTheme.emerald,
        ),
      );
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyApiError(e, fallback: 'Recherche par photo impossible')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}
