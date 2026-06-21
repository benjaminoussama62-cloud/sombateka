import 'package:flutter/material.dart';
import '../widgets/marketplace_product_card.dart';
import '../widgets/cart_item_tile.dart';
import '../utils/listing_utils.dart';
import '../services/app_services.dart';
import '../services/cart_ui_helper.dart';
import '../services/data_service.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';

/// Favoris + panier (style Wildberries).
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<FavoritesScreen> createState() => FavoritesScreenState();
}

class FavoritesScreenState extends State<FavoritesScreen> with SingleTickerProviderStateMixin {
  final _data = DataService();
  late TabController _tabs;
  bool _loading = true;
  List<Map<String, dynamic>> _cartItems = [];

  void showCartTab() {
    if (_tabs.index != 1) _tabs.animateTo(1);
    reload();
  }

  Future<void> reload() => _reload();

  @override
  void initState() {
    super.initState();
    final tab = widget.initialTab.clamp(0, 1);
    _tabs = TabController(length: 2, vsync: this, initialIndex: tab);
    _reload();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await _data.loadFavorites();
      await _data.loadCart();
      _cartItems = List<Map<String, dynamic>>.from(_data.cartItems);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _patchCartQty(int listingId, int quantity) {
    final idx = _cartItems.indexWhere((e) {
      final id = e['listing_id'] as int? ?? int.tryParse(e['listing_id']?.toString() ?? '');
      return id == listingId;
    });
    if (idx < 0) return;
    if (quantity <= 0) {
      _cartItems.removeAt(idx);
    } else {
      _cartItems[idx] = Map<String, dynamic>.from(_cartItems[idx])..['quantity'] = quantity;
    }
    AppServices.instance.cartItems = List<Map<String, dynamic>>.from(_cartItems);
  }

  Future<void> _changeQty(int listingId, int quantity) async {
    _patchCartQty(listingId, quantity);
    if (mounted) setState(() {});
    try {
      if (quantity <= 0) {
        await _data.removeFromCart(listingId);
      } else {
        Map<String, dynamic>? row;
        for (final e in _cartItems) {
          final id = e['listing_id'] as int? ?? int.tryParse(e['listing_id']?.toString() ?? '');
          if (id == listingId) {
            row = e;
            break;
          }
        }
        await _data.updateCartQty(
          listingId,
          quantity,
          maxQuantity: row?['max_quantity'] as int?,
        );
      }
      if (!mounted) return;
      _cartItems = List<Map<String, dynamic>>.from(_data.cartItems);
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      await _data.loadCart();
      if (!mounted) return;
      _cartItems = List<Map<String, dynamic>>.from(_data.cartItems);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur panier: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  int get _cartTotal => _cartItems.fold<int>(0, (s, i) => s + ((i['quantity'] as int?) ?? 1));

  @override
  Widget build(BuildContext context) {
    final favs = _data.getFavoriteListings();

    return Scaffold(
      backgroundColor: PremiumTheme.surface,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: PremiumTheme.heroGradient,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mes sélections', style: PremiumTheme.display.copyWith(fontSize: 24)),
                    Text(
                      '${favs.length} favoris · $_cartTotal dans le panier',
                      style: PremiumTheme.body.copyWith(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TabBar(
                      controller: _tabs,
                      indicatorColor: PremiumTheme.gold,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white60,
                      tabs: [
                        Tab(text: 'Favoris (${favs.length})'),
                        Tab(text: 'Panier ($_cartTotal)'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: PremiumTheme.blue))
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _favoritesGrid(favs),
                      _cartList(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _favoritesGrid(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return _empty('Aucun favori', 'Enregistrez les articles qui vous plaisent.', Icons.favorite_border_rounded);
    return RefreshIndicator(
      color: PremiumTheme.blue,
      onRefresh: _reload,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: Responsive.productGridColumns(context),
          childAspectRatio: Responsive.productGridAspectRatio(context),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final l = normalizeListing(items[i], favoriteIds: AppServices.instance.favoriteIds);
          return MarketplaceProductCard(
            listing: l,
            onTap: () => Navigator.pushNamed(context, AppRoutes.detail, arguments: l),
            onFavorite: () async {
              await _data.toggleFavorite(l['id']?.toString() ?? '');
              if (mounted) await _reload();
            },
            onAddToCart: l['isOwnListing'] == true
                ? null
                : () => CartUiHelper.addListing(context, l, onViewCart: showCartTab),
          );
        },
      ),
    );
  }

  Widget _cartList() {
    if (_cartItems.isEmpty) {
      return _empty('Panier vide', 'Ajoutez des articles pour commander.', Icons.shopping_bag_outlined);
    }
    return RefreshIndicator(
      color: PremiumTheme.blue,
      onRefresh: _reload,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFEFF6FF), Colors.white]),
              borderRadius: PremiumTheme.radiusMd,
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_bag_rounded, color: PremiumTheme.blue),
                const SizedBox(width: 10),
                Text('$_cartTotal article${_cartTotal > 1 ? 's' : ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _cartItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final item = _cartItems[i];
                final lid = item['listing_id'] as int? ?? int.tryParse(item['listing_id']?.toString() ?? '');
                return CartItemTile(
                  key: ValueKey('cart-$lid-${item['quantity']}'),
                  item: item,
                  onQtyChanged: (q) async {
                    if (lid == null) return;
                    await _changeQty(lid, q);
                  },
                  onRemove: () async {
                    if (lid == null) return;
                    await _changeQty(lid, 0);
                  },
                  onTap: lid != null
                      ? () => Navigator.pushNamed(context, AppRoutes.detail, arguments: {'id': lid.toString()})
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(String title, String subtitle, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(title, style: PremiumTheme.h1),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
