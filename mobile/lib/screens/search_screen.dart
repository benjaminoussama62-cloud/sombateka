import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';

import '../services/onboarding_service.dart';
import '../widgets/app_tour_overlay.dart';
import '../widgets/st_network_image.dart';
import '../widgets/marketplace_product_card.dart';
import '../widgets/marketplace_filter_sheet.dart';
import '../theme/premium_theme.dart';
import '../services/cart_ui_helper.dart';
import '../services/data_service.dart';
import '../utils/api_errors.dart';
import '../utils/category_catalog.dart';
import '../utils/constants.dart';
import '../utils/image_search_helper.dart';
import '../utils/listing_attributes.dart';
import '../utils/listing_utils.dart';
import '../utils/marketplace_layout.dart';
import '../services/recently_viewed_service.dart';
import '../widgets/st_page_header.dart';
import '../widgets/st_icon.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.initialImageBytes,
    this.initialImageFilename,
  });

  /// Image déjà choisie (geste utilisateur sur l'accueil) — évite le blocage navigateur.
  final Uint8List? initialImageBytes;
  final String? initialImageFilename;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _dataService = DataService();

  final _filters = MarketplaceFilterState();
  List<String> _categories = ['Toutes'];
  Map<String, int> _categoryIds = {};

  bool _loading = false;
  bool _imageSearchActive = false;
  String? _imageSearchMessage;
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _recentlyViewed = [];

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
      final bytes = widget.initialImageBytes;
      if (bytes != null && bytes.isNotEmpty) {
        _runImageSearch(bytes, widget.initialImageFilename ?? 'recherche.jpg');
      }
    });
  }

  Future<void> _init() async {
    _recentlyViewed = await RecentlyViewedService.instance.load();
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
      minPrice: _filters.hasPriceFilter && _filters.minPrice > 0 ? _filters.minPrice.roundToDouble() : null,
      maxPrice: _filters.hasPriceFilter && _filters.maxPrice < MarketplaceFilterState.defaultMaxPrice
          ? _filters.maxPrice.roundToDouble()
          : null,
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
    // Recherche photo : ne jamais retomber sur le catalogue général
    // (sinon 0 match API = tout le feed affiché comme « similaires »).
    if (_imageSearchActive) return _searchResults;
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
          if (_imageSearchActive) _buildImageSearchBanner(),
          _buildCategoryChips(),
          Expanded(child: _buildBody(results)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final filterCount = _filters.activeCount;
    return StPageHeader(
      child: MarketplaceLayout.centered(
      Column(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rechercher', style: PremiumTheme.display.copyWith(fontSize: 24)),
                    Text(
                      'Texte, filtres ou photo similaire',
                      style: PremiumTheme.body.copyWith(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
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
                  color: PremiumTheme.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _searchByImage,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        kIsWeb ? Icons.photo_library_rounded : Icons.photo_camera_rounded,
                        color: PremiumTheme.emerald,
                        size: 22,
                      ),
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
      child: MarketplaceLayout.centered(
      SizedBox(
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
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> results) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: PremiumTheme.blue));
    }
    if (!_isActiveSearch) return _buildDiscover();
    if (results.isEmpty) return _buildEmptyResults();
    if (_imageSearchActive) {
      return _buildImageSearchResults(results);
    }
    return MarketplaceLayout.centered(
      Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(
            '${results.length} résultat${results.length > 1 ? 's' : ''}',
            style: PremiumTheme.h1.copyWith(fontSize: 16),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: MarketplaceLayout.pagePadding(context).copyWith(top: 8, bottom: 24),
            gridDelegate: MarketplaceLayout.productGridDelegate(context),
            itemCount: results.length,
            itemBuilder: (_, i) => _buildResultCard(results[i]),
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildImageSearchResults(List<Map<String, dynamic>> results) {
    final exact = results.where((l) {
      final tier = l['matchTier']?.toString();
      final sim = (l['similarity'] as num?)?.toDouble() ?? 0;
      return tier == 'exact' || sim >= 0.80;
    }).toList();
    final close = results.where((l) {
      final tier = l['matchTier']?.toString();
      final sim = (l['similarity'] as num?)?.toDouble() ?? 0;
      final id = l['id'];
      return (tier == 'close' || (sim >= 0.60 && sim < 0.80)) &&
          !exact.any((e) => e['id'] == id);
    }).toList();
    final related = results.where((l) {
      final id = l['id'];
      return !exact.any((e) => e['id'] == id) && !close.any((e) => e['id'] == id);
    }).toList();

    return MarketplaceLayout.centered(
      ListView(
      padding: MarketplaceLayout.pagePadding(context).copyWith(top: 8, bottom: 28),
      children: [
        Text('Visuellement similaire', style: PremiumTheme.h1.copyWith(fontSize: 16)),
        if (_imageSearchMessage != null && _imageSearchMessage!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(_imageSearchMessage!, style: PremiumTheme.body.copyWith(fontSize: 13)),
        ],
        if (exact.isNotEmpty) ...[
          const SizedBox(height: 14),
          _sectionLabel('Correspondance exacte', PremiumTheme.emerald),
          const SizedBox(height: 8),
          _imageResultGrid(exact),
        ],
        if (close.isNotEmpty) ...[
          const SizedBox(height: 18),
          _sectionLabel('Très similaires', PremiumTheme.blue),
          const SizedBox(height: 8),
          _imageResultGrid(close),
        ],
        if (related.isNotEmpty) ...[
          const SizedBox(height: 18),
          _sectionLabel('Même style', PremiumTheme.navy),
          const SizedBox(height: 8),
          _imageResultGrid(related),
        ],
      ],
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: PremiumTheme.h1.copyWith(fontSize: 14, color: color),
        ),
      ],
    );
  }

  Widget _imageResultGrid(List<Map<String, dynamic>> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: MarketplaceLayout.productGridDelegate(context),
      itemCount: items.length,
      itemBuilder: (_, i) => _buildResultCard(items[i], showSimilarity: true),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> listing, {bool showSimilarity = false}) {
    final sim = (listing['similarity'] as num?)?.toDouble();
    final tier = listing['matchTier']?.toString();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        MarketplaceProductCard(
          listing: listing,
          autoRotateImages: true,
          onTap: () => Navigator.pushNamed(context, AppRoutes.detail, arguments: listing),
          onFavorite: () async {
            await _dataService.toggleFavorite(listing['id']?.toString() ?? '');
            setState(() {});
          },
          onAddToCart: listing['isOwnListing'] == true
              ? null
              : () => CartUiHelper.toggleListing(context, listing),
        ),
        if (showSimilarity && sim != null && sim > 0)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: tier == 'exact' || sim >= 0.80
                      ? const [PremiumTheme.emerald, Color(0xFF34D399)]
                      : tier == 'close' || sim >= 0.60
                          ? const [PremiumTheme.blue, Color(0xFF60A5FA)]
                          : const [PremiumTheme.navy, PremiumTheme.blue],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tier == 'exact' || sim >= 0.80
                        ? Icons.verified_rounded
                        : Icons.photo_camera_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tier == 'exact' || sim >= 0.80
                        ? 'Exact ${(sim * 100).round()}%'
                        : tier == 'close' || sim >= 0.60
                            ? 'Similaire ${(sim * 100).round()}%'
                            : 'Style ${(sim * 100).round()}%',
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
  }

  Widget _buildImageSearchBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [PremiumTheme.emerald.withValues(alpha: 0.15), PremiumTheme.blue.withValues(alpha: 0.1)],
        ),
        borderRadius: PremiumTheme.radiusMd,
        border: Border.all(color: PremiumTheme.emerald.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: PremiumTheme.emerald.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              kIsWeb ? Icons.photo_library_rounded : Icons.photo_camera_rounded,
              color: PremiumTheme.emerald,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recherche par photo active',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: PremiumTheme.textDark),
                ),
                Text(
                  _imageSearchMessage ?? 'Produits similaires à votre photo',
                  style: PremiumTheme.label.copyWith(fontSize: 10),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _imageSearchActive = false;
                _imageSearchMessage = null;
                _searchResults = [];
              });
              _loadListings();
            },
            child: const Text('Effacer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentlyViewed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Consultés récemment',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ),
            TextButton(
              onPressed: () async {
                await RecentlyViewedService.instance.clear();
                if (mounted) setState(() => _recentlyViewed = []);
              },
              child: const Text('Effacer', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _recentlyViewed.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final item = _recentlyViewed[i];
              return GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.detail, arguments: item),
                child: Container(
                  width: 92,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                          child: (item['imageUrl']?.toString().isNotEmpty == true)
                              ? StNetworkImage(
                                  url: item['imageUrl'].toString(),
                                  fit: BoxFit.cover,
                                  errorIconSize: 20,
                                )
                              : const ColoredBox(
                                  color: Color(0xFFF1F5F9),
                                  child: AppIcon(Icons.image_outlined),
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          item['title']?.toString() ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
      child: MarketplaceLayout.centered(
      ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (_recentlyViewed.isNotEmpty) ...[
            _buildRecentlyViewed(),
            const SizedBox(height: 16),
          ],
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _searchByImage,
              borderRadius: PremiumTheme.radiusLg,
              child: Ink(
                decoration: StGlowDecoration(
                  borderRadius: PremiumTheme.radiusLg,
                  boxShadow: PremiumTheme.softShadow,
                ),
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        kIsWeb ? Icons.photo_library_rounded : Icons.photo_camera_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recherche par photo',
                            style: PremiumTheme.display.copyWith(fontSize: 16, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Prenez ou importez une photo — SombaTeka trouve les annonces les plus proches.',
                            style: PremiumTheme.body.copyWith(color: Colors.white70, fontSize: 11, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text('Catégories', style: PremiumTheme.h1.copyWith(fontSize: 17)),
          const SizedBox(height: 4),
          Text(
            'Parcourez par rubrique ou combinez avec les filtres avancés',
            style: PremiumTheme.body.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: MarketplaceLayout.categoryColumns(context),
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
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: MarketplaceLayout.productGridDelegate(context),
              itemCount: listings.length,
              itemBuilder: (_, i) => MarketplaceProductCard(
                listing: listings[i],
                autoRotateImages: true,
                onTap: () => Navigator.pushNamed(context, AppRoutes.detail, arguments: listings[i]),
              ),
            ),
          ],
        ],
      ),
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
    Iterable<Map<String, dynamic>> results = listings;

    if (_filters.hasPriceFilter) {
      results = results.where((l) => listingMatchesPriceRange(
            l,
            minPrice: _filters.minPrice,
            maxPrice: _filters.maxPrice,
          ));
    }

    if (_imageSearchActive) {
      // Ne pas re-filtrer aggresivement : les scores API sont la source de vérité.
      // On applique seulement la requête texte / catégorie si l'utilisateur les change.
      final q = _searchController.text.trim();
      final cat = _filters.category;
      var list = results.toList();
      if (q.isNotEmpty) {
        final lower = q.toLowerCase();
        list = list
            .where((l) =>
                l['title'].toString().toLowerCase().contains(lower) ||
                l['description'].toString().toLowerCase().contains(lower))
            .toList();
      }
      if (cat != 'Toutes') {
        final c = cat.toLowerCase();
        list = list.where((l) {
          final lc = l['category']?.toString().toLowerCase() ?? '';
          return lc.contains(c) || c.contains(lc);
        }).toList();
      }
      return list;
    }

    final cat = _filters.category;
    return results.where((listing) {
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

  Future<void> _runImageSearch(Uint8List bytes, String filename) async {
    setState(() => _loading = true);
    try {
      final search = await _dataService.searchByImage(bytes: bytes, filename: filename);
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

  Future<void> _searchByImage() async {
    try {
      final picked = await pickImageForSearch(context);
      if (picked == null) return;
      await _runImageSearch(picked.bytes, picked.filename);
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
