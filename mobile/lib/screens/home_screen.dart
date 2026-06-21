// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';
import '../utils/app_theme.dart';
import '../widgets/smart_home_header.dart';
import '../widgets/marketplace_product_card.dart';
import 'detail_screen.dart';
import '../components/category_chip.dart';
import '../components/shimmer_effect.dart';
import '../services/cart_ui_helper.dart';
import '../services/data_service.dart';
import '../services/app_services.dart';
import '../theme/premium_theme.dart';
import '../utils/rdc_locations.dart';
import '../utils/responsive.dart';
import '../services/recently_viewed_service.dart';
import '../services/preferred_province_service.dart';
import '../widgets/province_picker_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenCart});

  final VoidCallback? onOpenCart;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Future<void> reloadListings() async {
    setState(() => _isLoading = true);
    _recentlyViewed = await RecentlyViewedService.instance.load();
    await _loadData();
  }

  Future<void> refreshCartBadge() async {
    try {
      if (await AppServices.instance.auth.hasSession()) {
        await _dataService.loadCart();
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }
  late TabController _tabController;
  late AnimationController _headerController;
  late Animation<double> _headerAnimation;
  
  final DataService _dataService = DataService();
  String _selectedCategory = 'Toutes';
  String? _selectedProvince;
  List<Map<String, dynamic>> _recentlyViewed = [];
  bool _isLoading = true;
  int _notifCount = 0;
  final ScrollController _scrollController = ScrollController();
  bool _isHeaderVisible = true;
  double _lastScrollPosition = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _headerAnimation = Tween<double>(begin: 1, end: 0).animate(_headerController);
    
    _scrollController.addListener(_onScroll);
    _initProvinceAndLoad();
  }

  Future<void> _initProvinceAndLoad() async {
    final saved = await PreferredProvinceService.instance.load();
    if (saved != null && mounted) {
      setState(() => _selectedProvince = saved);
    }
    await _loadData();
  }

  Future<void> _selectProvince(String? province) async {
    setState(() {
      _selectedProvince = province;
      _isLoading = true;
    });
    await PreferredProvinceService.instance.save(province);
    await _dataService.refreshListings(province: _selectedProvince);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _openAllProvincesPicker() async {
    final picked = await showProvincePickerSheet(
      context,
      selected: _selectedProvince,
      includeAllOption: true,
    );
    if (!mounted || picked == null) return;
    await _selectProvince(picked.isEmpty ? null : picked);
  }

  void _onScroll() {
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll > _lastScrollPosition && currentScroll > 100 && _isHeaderVisible) {
      setState(() => _isHeaderVisible = false);
      _headerController.forward();
    } else if (currentScroll < _lastScrollPosition && !_isHeaderVisible) {
      setState(() => _isHeaderVisible = true);
      _headerController.reverse();
    }
    _lastScrollPosition = currentScroll;
  }

  Future<void> _loadData() async {
    try {
      await _dataService.refreshListings(province: _selectedProvince);
      _recentlyViewed = await RecentlyViewedService.instance.load();
      if (await AppServices.instance.auth.hasSession()) {
        await _dataService.loadFavorites();
        await _dataService.loadCart();
        await _dataService.loadNotifications();
        _notifCount = _dataService.unreadNotificationCount;
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _headerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: SmartHomeHeader(
              expanded: _isHeaderVisible,
              cartCount: _dataService.cartItems.length,
              notificationCount: _notifCount,
              onCartTap: widget.onOpenCart,
              onSearchTap: () => Navigator.pushNamed(context, AppRoutes.search),
              onNotificationTap: () async {
                await Navigator.pushNamed(context, AppRoutes.notifications);
                await _dataService.loadNotifications();
                if (mounted) setState(() => _notifCount = _dataService.unreadNotificationCount);
              },
            ),
          ),
          
          // Barre d'onglets (Particulier / Professionnel)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  color: AppColors.primary.withOpacity(0.1),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.person_outline),
                    text: 'Particuliers',
                  ),
                  Tab(
                    icon: Icon(Icons.store_outlined),
                    text: 'Professionnels',
                  ),
                ],
              ),
            ),
          ),
          
          // Contenu selon l'onglet
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildParticularView(),
                _buildProfessionalView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filteredParticularListings() {
    var items = _dataService.getParticularListings();
    if (_selectedCategory != 'Toutes') {
      items = items.where((l) => (l['category']?.toString() ?? '') == _selectedCategory).toList();
    }
    if (_selectedProvince != null && _selectedProvince!.isNotEmpty) {
      items = items.where((l) {
        final p = l['province']?.toString() ?? RdcLocations.guessProvince(l);
        return p == _selectedProvince;
      }).toList();
    }
    return items;
  }

  static const _quickProvinces = [
    'Toutes',
    'Kinshasa',
    'Haut-Katanga',
    'Nord-Kivu',
    'Sud-Kivu',
    'Lualaba',
    'Kongo Central',
    'Kasaï-Oriental',
    'Équateur',
  ];

  Widget _buildProvinceBar() {
    final extraSelected = _selectedProvince != null &&
        _selectedProvince!.isNotEmpty &&
        !_quickProvinces.contains(_selectedProvince);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Par province',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ),
              if (_selectedProvince != null)
                TextButton(
                  onPressed: () => _selectProvince(null),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Réinitialiser', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _quickProvinces.length + 1 + (extraSelected ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              if (extraSelected && i == _quickProvinces.length) {
                final p = _selectedProvince!;
                return FilterChip(
                  label: Text(p, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  selected: true,
                  onSelected: (_) => _openAllProvincesPicker(),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                );
              }
              if (i == _quickProvinces.length + (extraSelected ? 1 : 0)) {
                return ActionChip(
                  avatar: const Icon(Icons.map_outlined, size: 16, color: AppColors.primary),
                  label: const Text('26 provinces', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  onPressed: _openAllProvincesPicker,
                  backgroundColor: const Color(0xFFF1F5F9),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                );
              }
              final p = _quickProvinces[i];
              final sel = (p == 'Toutes' && _selectedProvince == null) || _selectedProvince == p;
              return FilterChip(
                label: Text(p, style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.w800 : FontWeight.w600, color: const Color(0xFF0F172A))),
                selected: sel,
                onSelected: (_) => _selectProvince(p == 'Toutes' ? null : p),
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                checkmarkColor: AppColors.primary,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildRecentlyViewed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Consultés récemment',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await RecentlyViewedService.instance.clear();
                  if (mounted) setState(() => _recentlyViewed = []);
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Effacer', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _recentlyViewed.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final item = _recentlyViewed[i];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DetailScreen(listing: item)),
                  );
                },
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
                              ? Image.network(item['imageUrl'].toString(), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined))
                              : const ColoredBox(color: Color(0xFFF1F5F9), child: Icon(Icons.image_outlined)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          item['title']?.toString() ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
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

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryLight,
            AppColors.secondary.withOpacity(0.3),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              // Texte de bienvenue
              Text(
                'Bonjour 👋',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Découvrez la marketplace congolaise',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.gold.withOpacity(0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 14, color: AppColors.gold),
                        SizedBox(width: 4),
                        Text(
                          '100% RDC',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.gold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      const Icon(Icons.people, size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        '+124k vendeurs',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Barre de recherche
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.search),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: AppColors.textSecondary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Rechercher un produit, une boutique...',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '🔍',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticularView() {
    if (_isLoading) {
      return _buildShimmerGrid();
    }
    
    final listings = _filteredParticularListings();

    if (listings.isEmpty) {
      return _buildEmptyCatalog(
        icon: Icons.storefront_outlined,
        title: _selectedProvince != null ? 'Aucune annonce dans cette province' : 'Aucune annonce pour le moment',
        subtitle: _selectedProvince != null
            ? 'Essayez une autre province ou publiez la première annonce'
            : 'Soyez le premier à publier une annonce réelle',
      );
    }

    return Column(
      children: [
        _buildProvinceBar(),
        if (_recentlyViewed.isNotEmpty) ...[
          _buildRecentlyViewed(),
          const SizedBox(height: 8),
        ],
        // Catégories horizontales
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: AppStrings.categories.length,
            itemBuilder: (context, index) {
              final category = AppStrings.categories[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CategoryChip(
                  name: category,
                  icon: Icons.category,
                  color: AppColors.primary,
                  isSelected: _selectedCategory == category,
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                ),
              );
            },
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Grille des produits
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: Responsive.productGridColumns(context),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: Responsive.productGridAspectRatio(context),
            ),
            itemCount: listings.length,
            itemBuilder: (context, index) {
              final listing = listings[index];
              return MarketplaceProductCard(
                listing: listing,
                autoRotateImages: true,
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => DetailScreen(listing: listing),
                      transitionsBuilder: (_, anim, __, child) =>
                          FadeTransition(opacity: anim, child: child),
                      transitionDuration: const Duration(milliseconds: 280),
                    ),
                  );
                },
                onFavorite: () async {
                  await _dataService.toggleFavorite(listing['id']?.toString() ?? '');
                  if (mounted) setState(() {});
                },
                onAddToCart: listing['isOwnListing'] == true
                    ? null
                    : () async {
                        await CartUiHelper.addListing(
                          context,
                          listing,
                          onViewCart: widget.onOpenCart,
                        );
                        if (mounted) setState(() {});
                      },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfessionalView() {
    if (_isLoading) {
      return _buildShimmerGrid();
    }
    
    final professionals = _dataService.getProfessionalStores();

    if (professionals.isEmpty) {
      return _buildEmptyCatalog(
        icon: Icons.verified_outlined,
        title: 'Aucune boutique professionnelle',
        subtitle: 'Les vendeurs certifiés (KYC approuvé) apparaîtront ici',
      );
    }

    return Column(
      children: [
        // Bannière premium
        Container(
          margin: const EdgeInsets.all(16),
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            gradient: const LinearGradient(
              colors: [Color(0xFF6B21A5), Color(0xFFD946EF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 20,
                top: 20,
                child: Icon(
                  Icons.storefront_rounded,
                  size: 80,
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Boutiques officielles',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Marques certifiées',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Livraison garantie | Paiement sécurisé',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Liste des boutiques professionnelles
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: professionals.length,
            itemBuilder: (context, index) {
              final store = professionals[index];
              return _buildProfessionalStoreCard(store);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfessionalStoreCard(Map<String, dynamic> store) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo boutique
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              image: store['imageUrl'] != null
                  ? DecorationImage(image: NetworkImage(store['imageUrl']), fit: BoxFit.cover)
                  : null,
            ),
            child: store['imageUrl'] == null
                ? Icon(Icons.store, size: 35, color: AppColors.primary)
                : null,
          ),
          const SizedBox(width: 12),
          // Infos boutique
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        store['name']?.toString() ?? 'Boutique',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.verified, size: 16, color: AppColors.gold),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        store['sellerType'] ?? 'Pro',
                        style: TextStyle(fontSize: 10, color: AppColors.success),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, size: 14, color: AppColors.gold),
                    const SizedBox(width: 2),
                    Text(store['rating'].toString(), style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    Text('${store['sales']} ventes', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    Text('${store['products']} produits', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 2),
                    Text(
                      store['location'] ?? 'RDC',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Voir la boutique', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCatalog({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.productGridColumns(context),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: Responsive.productGridAspectRatio(context),
      ),
      itemCount: 6,
      itemBuilder: (context, index) => const ShimmerProductCard(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Explorer'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_rounded), label: 'Vendre'),
          BottomNavigationBarItem(icon: Icon(Icons.message_rounded), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}