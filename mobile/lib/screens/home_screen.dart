// lib/screens/home_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';
import '../utils/app_theme.dart';
import '../widgets/smart_home_header.dart';
import '../widgets/st_icon.dart';
import '../widgets/marketplace_product_card.dart';
import 'detail_screen.dart';
import '../components/shimmer_effect.dart';
import '../services/cart_ui_helper.dart';
import '../services/data_service.dart';
import '../services/app_services.dart';
import '../theme/premium_theme.dart';
import '../utils/responsive.dart';
import '../utils/image_search_helper.dart';
import '../utils/marketplace_layout.dart';
import '../services/onboarding_service.dart';
import '../widgets/app_tour_overlay.dart';
import '../widgets/st_network_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenCart});

  final VoidCallback? onOpenCart;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Future<void> reloadListings() async {
    setState(() => _isLoading = true);
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
  
  final DataService _dataService = DataService();
  bool _isLoading = true;
  int _notifCount = 0;
  bool _headerCollapsed = false;
  final ScrollController _scrollController = ScrollController();

  void _updateHeaderCollapsed() {
    // Scroll externe > 0 : la barre de recherche peut atteindre le haut
    // (innerBoxIsScrolled ne suffit pas quand le feed interne est trop court).
    final collapsed = _scrollController.hasClients && _scrollController.offset > 0.5;
    if (collapsed != _headerCollapsed) {
      setState(() => _headerCollapsed = collapsed);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_updateHeaderCollapsed);
    // Stale-first synchrone : 1er frame avec cache, pas de shimmer bleu vide.
    _dataService.hydrateListingsFromCache();
    _isLoading = _dataService.getHomeFeedListings().isEmpty;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Feed réseau tout de suite — session en parallèle (ne bloque pas l'UI).
      final sessionFuture = AppServices.instance.auth.hasSession();
      final feedFuture = _dataService.refreshHomeFeeds();
      final session = await sessionFuture;
      final jobs = <Future<void>>[feedFuture];
      if (session) {
        jobs.add(_dataService.refreshUser());
      }
      await Future.wait(jobs);
      if (session) {
        unawaited(Future.wait([
          _dataService.loadFavorites(),
          _dataService.loadCart(),
          _dataService.loadNotifications(),
        ]).then((_) {
          if (mounted) setState(() => _notifCount = _dataService.unreadNotificationCount);
        }));
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppTourPresenter.maybeShow(context, AppTourPage.home);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return Scaffold(
      backgroundColor: PremiumTheme.surface,
      body: NestedScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          ...HomeCollapsingHeader.slivers(
            context: context,
            innerBoxIsScrolled: innerBoxIsScrolled || _headerCollapsed,
            topInset: topInset,
            notificationCount: _notifCount,
            onNotificationTap: () async {
              await Navigator.pushNamed(context, AppRoutes.notifications);
              await _dataService.loadNotifications();
              if (mounted) setState(() => _notifCount = _dataService.unreadNotificationCount);
            },
            onSearchTap: () => Navigator.pushNamed(context, AppRoutes.search),
            onImageSearchTap: () => _startImageSearch(context),
          ),
          MarketplaceLayout.centeredSliver(
            SliverToBoxAdapter(
            child: Container(
              margin: MarketplaceLayout.pagePadding(context).copyWith(top: 16, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                border: Border.all(color: PremiumTheme.navy.withValues(alpha: 0.06)),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: PremiumTheme.blue,
                unselectedLabelColor: PremiumTheme.textMuted,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  color: PremiumTheme.blue.withValues(alpha: 0.1),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(
                    icon: AppIcon(Icons.person_outline),
                    text: 'Particuliers',
                  ),
                  Tab(
                    icon: AppIcon(Icons.store_outlined),
                    text: 'Professionnels',
                  ),
                ],
              ),
            ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildParticularScroll(),
            _buildProfessionalScroll(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateHeaderCollapsed);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _homeListings() => _dataService.getHomeFeedListings();

  Future<void> _startImageSearch(BuildContext context) async {
    final picked = await pickImageForSearch(context);
    if (picked == null || !mounted) return;
    await Navigator.pushNamed(
      context,
      AppRoutes.search,
      arguments: {
        'imageSearchBytes': picked.bytes,
        'imageSearchFilename': picked.filename,
      },
    );
  }

  Widget _buildParticularScroll() {
    if (_isLoading) {
      return _buildShimmerScroll();
    }

    final listings = _homeListings();

    if (listings.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyCatalog(
              icon: Icons.storefront_outlined,
              title: 'Aucune annonce pour le moment',
              subtitle: 'Soyez le premier à publier une annonce',
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        MarketplaceLayout.centeredSliver(
        SliverPadding(
          padding: MarketplaceLayout.pagePadding(context).copyWith(top: 16, bottom: 24),
          sliver: SliverGrid(
            gridDelegate: MarketplaceLayout.productGridDelegate(context),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
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
                          await CartUiHelper.toggleListing(
                            context,
                            listing,
                            onViewCart: widget.onOpenCart,
                          );
                          if (mounted) setState(() {});
                        },
                );
              },
              childCount: listings.length,
            ),
          ),
        ),
        ),
      ],
    );
  }

  Widget _buildProfessionalScroll() {
    if (_isLoading) {
      return _buildShimmerScroll();
    }

    final publications = _dataService.getOfficialPublications();
    final professionals = _dataService.getProfessionalStores();

    if (publications.isEmpty && professionals.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyCatalog(
              icon: Icons.verified_outlined,
              title: 'Aucune boutique officielle',
              subtitle: 'Les publications des comptes certifiés SombaTeka apparaîtront ici',
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        MarketplaceLayout.centeredSliver(
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(18),
            decoration: StGlowDecoration(
              borderRadius: PremiumTheme.radiusLg,
              boxShadow: PremiumTheme.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIcon(Icons.verified_rounded, size: 14, color: PremiumTheme.gold),
                          SizedBox(width: 4),
                          Text('SombaTeka Pro', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${publications.length} publication${publications.length > 1 ? 's' : ''} officielle${publications.length > 1 ? 's' : ''}',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                ),
                Text(
                  'Collections multi-produits des boutiques certifiées',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        ),
        if (professionals.isNotEmpty)
          MarketplaceLayout.centeredSliver(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: professionals.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _buildProfessionalStoreChip(professionals[i]),
                ),
              ),
            ),
          ),
          ),
        MarketplaceLayout.centeredSliver(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (i == publications.length) {
                  return _buildOfficialProductsGrid();
                }
                return _buildOfficialPublicationCard(publications[i]);
              },
              childCount: publications.length + 1,
            ),
          ),
        ),
        ),
      ],
    );
  }

  Widget _buildOfficialProductsGrid() {
    final products = _dataService.getOfficialProductListings();
    if (products.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Text('Tous les produits officiels', style: PremiumTheme.h1.copyWith(fontSize: 16)),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: MarketplaceLayout.productGridDelegate(context),
          itemCount: products.length,
          itemBuilder: (_, index) {
            final listing = products[index];
            return MarketplaceProductCard(
              listing: {...listing, 'promoted': true},
              autoRotateImages: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DetailScreen(listing: listing)),
                );
              },
              onFavorite: () async {
                await _dataService.toggleFavorite(listing['id']?.toString() ?? '');
                if (mounted) setState(() {});
              },
              onAddToCart: listing['isOwnListing'] == true
                  ? null
                  : () async {
                      await CartUiHelper.toggleListing(context, listing, onViewCart: widget.onOpenCart);
                      if (mounted) setState(() {});
                    },
            );
          },
        ),
      ],
    );
  }

  Widget _buildOfficialPublicationCard(Map<String, dynamic> pub) {
    final products = (pub['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final title = pub['title']?.toString() ?? 'Publication';
    final seller = pub['sellerName']?.toString() ?? 'Boutique officielle';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: PremiumTheme.radiusMd,
        border: Border.all(color: const Color(0xFFE8ECF4)),
        boxShadow: PremiumTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: PremiumTheme.h1.copyWith(fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const AppIcon(Icons.storefront_rounded, size: 12, color: PremiumTheme.blue),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              seller,
                              style: PremiumTheme.label.copyWith(fontSize: 11, color: PremiumTheme.blue),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const AppIcon(Icons.verified_rounded, size: 14, color: PremiumTheme.gold),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: PremiumTheme.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${products.length} prod.',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: PremiumTheme.blue),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, j) {
                final listing = products[j];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DetailScreen(listing: listing)),
                    );
                  },
                  child: SizedBox(
                    width: 96,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: (listing['imageUrl']?.toString().isNotEmpty == true)
                                ? StNetworkImage(
                                    url: listing['imageUrl'].toString(),
                                    fit: BoxFit.cover,
                                    errorIconSize: 28,
                                  )
                                : const ColoredBox(
                                    color: Color(0xFFF1F5F9),
                                    child: AppIcon(Icons.image_outlined, size: 28),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          listing['title']?.toString() ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          listing['price']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: PremiumTheme.blue),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalStoreChip(Map<String, dynamic> store) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon(Icons.storefront_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  store['name']?.toString() ?? 'Boutique',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '${store['totalListings'] ?? 0} article(s)',
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary.withValues(alpha: 0.9)),
          ),
        ],
      ),
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
                ? AppIcon(Icons.store, size: 35, color: AppColors.primary)
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
                    const AppIcon(Icons.verified, size: 16, color: AppColors.gold),
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
                    AppIcon(Icons.star, size: 14, color: AppColors.gold),
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
                    AppIcon(Icons.location_on, size: 12, color: AppColors.textSecondary),
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
            AppIcon(icon, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerScroll() {
    return CustomScrollView(
      slivers: [
        MarketplaceLayout.centeredSliver(
        SliverPadding(
          padding: MarketplaceLayout.pagePadding(context),
          sliver: SliverGrid(
            gridDelegate: MarketplaceLayout.productGridDelegate(context),
            delegate: SliverChildBuilderDelegate(
              (_, __) => const ShimmerProductCard(),
              childCount: 6,
            ),
          ),
        ),
        ),
      ],
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
          BottomNavigationBarItem(icon: AppIcon(Icons.home_rounded), label: 'Accueil'),
          BottomNavigationBarItem(icon: AppIcon(Icons.search_rounded), label: 'Explorer'),
          BottomNavigationBarItem(icon: AppIcon(Icons.add_circle_rounded), label: 'Vendre'),
          BottomNavigationBarItem(icon: AppIcon(Icons.message_rounded), label: 'Messages'),
          BottomNavigationBarItem(icon: AppIcon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}