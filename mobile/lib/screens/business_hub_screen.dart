import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../services/data_service.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../utils/listing_attributes.dart';
import '../utils/responsive.dart';
import '../widgets/st_network_image.dart';
import '../widgets/st_safe_area.dart';
import 'official_catalog_publish_screen.dart';
import 'official_single_product_screen.dart';
import 'payment_settings_screen.dart';
import '../utils/friendly_error.dart';

/// Espace Pro — tableau de bord boutique officielle (web PC, mobile, app).
class BusinessHubScreen extends StatefulWidget {
  const BusinessHubScreen({
    super.key,
    this.onPublished,
    this.onGoHome,
    this.onOpenMessages,
    this.embedded = false,
  });

  final VoidCallback? onPublished;
  final VoidCallback? onGoHome;
  final VoidCallback? onOpenMessages;

  /// true = onglet du menu principal (pas de bouton retour).
  final bool embedded;

  @override
  State<BusinessHubScreen> createState() => BusinessHubScreenState();
}

class BusinessHubScreenState extends State<BusinessHubScreen> with SingleTickerProviderStateMixin {
  final _data = DataService();
  late final TabController _tabs;
  bool _loading = true;
  Map<String, dynamic> _stats = {};
  String _businessType = '';
  List<Map<String, dynamic>> _products = [];
  String _stockFilter = 'all'; // all | low | out
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> reload() => _reload();

  Future<void> _reload() async {
    setState(() => _loading = true);
    await _data.refreshUser();
    await _data.refreshMyListings();
    await _data.refreshListings(mixPromoted: true);
    String type = '';
    try {
      final kyc = await _data.fetchKycStatus();
      type = (kyc?['category'] ?? kyc?['business_type'] ?? '').toString().trim();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _stats = _data.getBusinessDashboardStats();
      _businessType = type;
      _products = _data.myListings
          .where((l) => l['status']?.toString() != 'deleted')
          .map((l) => Map<String, dynamic>.from(l))
          .toList();
      _loading = false;
    });
  }

  String get _shopName {
    final u = _data.currentUser;
    final official = u?['official_name']?.toString().trim();
    if (official != null && official.isNotEmpty) return official;
    return u?['display_name']?.toString() ?? 'Ma boutique';
  }

  double get _contentMaxWidth {
    final w = MediaQuery.sizeOf(context).width;
    if (Responsive.isDesktopWeb(context)) return 1200;
    if (w >= 900) return 960;
    return double.infinity;
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _products.where((l) {
      final status = l['status']?.toString() ?? 'active';
      if (status == 'sold') return _stockFilter == 'all' && q.isEmpty ? true : (q.isNotEmpty);
      final stock = ListingAttributes.catalogTotalStock(l['attributes']);
      if (_stockFilter == 'low' && (stock > 3 || stock <= 0)) return false;
      if (_stockFilter == 'out' && stock > 0) return false;
      if (q.isEmpty) return true;
      final title = l['title']?.toString().toLowerCase() ?? '';
      return title.contains(q);
    }).toList();
  }

  int get _lowStockCount => _products.where((l) {
        if (l['status']?.toString() != 'active') return false;
        final s = ListingAttributes.catalogTotalStock(l['attributes']);
        return s > 0 && s <= 3;
      }).length;

  int get _outOfStockCount => _products.where((l) {
        if (l['status']?.toString() != 'active') return false;
        return ListingAttributes.catalogTotalStock(l['attributes']) <= 0;
      }).length;

  @override
  Widget build(BuildContext context) {
    final desktop = Responsive.isDesktopWeb(context) || MediaQuery.sizeOf(context).width >= 768;
    final pad = Responsive.screenPadding(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Column(
        children: [
          _topBar(desktop),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator(color: PremiumTheme.blue)),
            )
          else
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: _contentMaxWidth),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(pad.left, 8, pad.right, 0),
                        child: _tabBar(desktop),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabs,
                          children: [
                            _overviewTab(desktop, pad),
                            _stockTab(desktop, pad),
                            _manageTab(desktop, pad),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topBar(bool desktop) {
    return Container(
      width: double.infinity,
      decoration: const StGlowDecoration(),
      child: StSafeTop(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _contentMaxWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                desktop ? 24 : 12,
                widget.embedded ? 14 : 8,
                desktop ? 24 : 12,
                16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!widget.embedded)
                        IconButton(
                          tooltip: 'Retour',
                          onPressed: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              widget.onGoHome?.call();
                            }
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.18),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.arrow_back_rounded, size: 22),
                        ),
                      if (!widget.embedded) const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, color: PremiumTheme.gold, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Espace Pro',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Actualiser',
                        onPressed: _reload,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.14),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _shopName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: desktop ? 26 : 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _businessType.isEmpty
                        ? 'Tableau de bord boutique — stock, publications & clients'
                        : 'Activité $_businessType · gestion boutique',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _heroPill(Icons.verified_rounded, 'KYC validé'),
                      if (_businessType.isNotEmpty) _heroPill(Icons.category_rounded, _businessType),
                      _heroPill(Icons.inventory_2_outlined, '${_stats['totalStock'] ?? 0} en stock'),
                      if (_lowStockCount > 0) _heroPill(Icons.warning_amber_rounded, '$_lowStockCount stock bas'),
                      if (_outOfStockCount > 0) _heroPill(Icons.remove_shopping_cart_outlined, '$_outOfStockCount rupture'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: PremiumTheme.gold, size: 14),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _tabBar(bool desktop) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF4)),
      ),
      child: TabBar(
        controller: _tabs,
        labelColor: PremiumTheme.navy,
        unselectedLabelColor: const Color(0xFF64748B),
        indicator: BoxDecoration(
          color: PremiumTheme.blue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: desktop ? 13 : 12),
        tabs: const [
          Tab(text: 'Vue d\'ensemble'),
          Tab(text: 'Stock'),
          Tab(text: 'Gérer'),
        ],
      ),
    );
  }

  Widget _overviewTab(bool desktop, EdgeInsets pad) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad.left, 16, pad.right, 100),
        children: [
          _statsGrid(desktop),
          const SizedBox(height: 20),
          _sectionTitle('Publier rapidement', Icons.add_business_rounded),
          const SizedBox(height: 10),
          _publishActions(desktop),
          const SizedBox(height: 20),
          _sectionTitle('Alertes stock', Icons.notifications_active_outlined),
          const SizedBox(height: 10),
          _stockAlerts(),
          const SizedBox(height: 20),
          _sectionTitle('Faire grandir ma boutique', Icons.trending_up_rounded),
          const SizedBox(height: 10),
          _growthTools(desktop),
          const SizedBox(height: 20),
          _sectionTitle(
            _businessType.isEmpty ? 'Conseils Pro' : 'Conseils pour $_businessType',
            Icons.lightbulb_outline_rounded,
          ),
          const SizedBox(height: 10),
          _tips(),
        ],
      ),
    );
  }

  Widget _statsGrid(bool desktop) {
    final items = <(String, String, IconData, Color)>[
      ('${_stats['productCount'] ?? 0}', 'Produits', Icons.inventory_2_outlined, PremiumTheme.blue),
      ('${_stats['publicationCount'] ?? 0}', 'Publications', Icons.collections_bookmark_outlined, const Color(0xFF7C3AED)),
      ('${_stats['totalStock'] ?? 0}', 'Stock total', Icons.layers_outlined, const Color(0xFF0891B2)),
      ('${_stats['soldCount'] ?? 0}', 'Vendus', Icons.sell_outlined, const Color(0xFF059669)),
      ('${_stats['activeCount'] ?? 0}', 'Actifs', Icons.check_circle_outline, PremiumTheme.emerald),
      (
        AppConfig.paymentsEnabled ? _formatRevenue(_stats['revenueCdf']) : '${_stats['promotedOnHome'] ?? 0}',
        AppConfig.paymentsEnabled ? 'CA (CDF)' : 'Promus',
        AppConfig.paymentsEnabled ? Icons.payments_outlined : Icons.campaign_outlined,
        PremiumTheme.gold,
      ),
    ];

    final cross = desktop ? 3 : (MediaQuery.sizeOf(context).width >= 420 ? 3 : 2);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: desktop ? 1.55 : 1.35,
      ),
      itemBuilder: (_, i) {
        final it = items[i];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8ECF4)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(it.$3, size: 22, color: it.$4),
              const SizedBox(height: 6),
              Text(it.$1, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              Text(it.$2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
            ],
          ),
        );
      },
    );
  }

  String _formatRevenue(dynamic v) {
    final n = (v as num?)?.toInt() ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k';
    return '$n';
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: PremiumTheme.blue),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
      ],
    );
  }

  Widget _stockAlerts() {
    if (_lowStockCount == 0 && _outOfStockCount == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PremiumTheme.emerald.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PremiumTheme.emerald.withValues(alpha: 0.25)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: PremiumTheme.emerald),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Aucun stock critique — vos produits actifs sont bien fournis.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        if (_outOfStockCount > 0)
          _alertCard(
            color: const Color(0xFFDC2626),
            icon: Icons.remove_shopping_cart_rounded,
            title: '$_outOfStockCount produit(s) en rupture',
            subtitle: 'Mettez à jour le stock ou mettez en pause la vitrine.',
            onTap: () {
              setState(() => _stockFilter = 'out');
              _tabs.animateTo(1);
            },
          ),
        if (_outOfStockCount > 0 && _lowStockCount > 0) const SizedBox(height: 8),
        if (_lowStockCount > 0)
          _alertCard(
            color: const Color(0xFFD97706),
            icon: Icons.warning_amber_rounded,
            title: '$_lowStockCount produit(s) en stock bas (≤ 3)',
            subtitle: 'Réapprovisionnez avant la rupture.',
            onTap: () {
              setState(() => _stockFilter = 'low');
              _tabs.animateTo(1);
            },
          ),
      ],
    );
  }

  Widget _alertCard({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stockTab(bool desktop, EdgeInsets pad) {
    final list = _filteredProducts;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad.left, 14, pad.right, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Rechercher un produit…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('Tous', 'all'),
                    const SizedBox(width: 8),
                    _filterChip('Stock bas', 'low'),
                    const SizedBox(width: 8),
                    _filterChip('Rupture', 'out'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: list.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 60),
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          'Aucun produit à afficher',
                          style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => _tabs.animateTo(0),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Publier un produit'),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(pad.left, 4, pad.right, 100),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _inventoryCard(list[i], desktop),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _stockFilter == value;
    return FilterChip(
      selected: selected,
      label: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: selected ? Colors.white : PremiumTheme.navy)),
      selectedColor: PremiumTheme.blue,
      backgroundColor: Colors.white,
      checkmarkColor: Colors.white,
      side: BorderSide(color: selected ? PremiumTheme.blue : const Color(0xFFE8ECF4)),
      onSelected: (_) => setState(() => _stockFilter = value),
    );
  }

  Widget _inventoryCard(Map<String, dynamic> listing, bool desktop) {
    final title = listing['title']?.toString() ?? 'Produit';
    final status = listing['status']?.toString() ?? 'active';
    final image = listing['imageUrl']?.toString() ??
        listing['image']?.toString() ??
        listing['primary_image_url']?.toString();
    final variants = ListingAttributes.catalogVariants(listing['attributes']);
    final totalStock = ListingAttributes.catalogTotalStock(listing['attributes']);
    final paused = status == 'hidden';
    final sold = status == 'sold';
    final low = !sold && totalStock > 0 && totalStock <= 3;
    final out = !sold && totalStock <= 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: out
              ? const Color(0xFFFECACA)
              : low
                  ? const Color(0xFFFDE68A)
                  : const Color(0xFFE8ECF4),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: image != null && image.isNotEmpty
                        ? StNetworkImage(url: image, fit: BoxFit.cover)
                        : Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(Icons.image_outlined, color: Color(0xFF94A3B8)),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _statusBadge(
                            sold
                                ? 'Vendu'
                                : paused
                                    ? 'En pause'
                                    : out
                                        ? 'Rupture'
                                        : low
                                            ? 'Stock bas'
                                            : 'Actif',
                            sold
                                ? const Color(0xFF64748B)
                                : paused
                                    ? const Color(0xFF7C3AED)
                                    : out
                                        ? const Color(0xFFDC2626)
                                        : low
                                            ? const Color(0xFFD97706)
                                            : PremiumTheme.emerald,
                          ),
                          _statusBadge('$totalStock u.', PremiumTheme.blue),
                          if (variants.isNotEmpty) _statusBadge('${variants.length} variante(s)', const Color(0xFF64748B)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!sold)
                  PopupMenuButton<String>(
                    onSelected: (v) => _onProductAction(listing, v),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'toggle', child: Text(paused ? 'Remettre en vitrine' : 'Mettre en pause')),
                      const PopupMenuItem(value: 'detail', child: Text('Voir la fiche')),
                      const PopupMenuItem(value: 'sold', child: Text('Marquer vendu')),
                    ],
                  ),
              ],
            ),
          ),
          if (!sold && variants.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  for (var i = 0; i < variants.length; i++) ...[
                    if (i > 0) const Divider(height: 12),
                    _variantStockRow(listing, i, variants[i], desktop),
                  ],
                ],
              ),
            )
          else if (!sold)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  const Text('Stock (unité)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const Spacer(),
                  _stockStepper(
                    value: totalStock,
                    onChanged: (v) => _setSimpleStock(listing, v),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _variantStockRow(Map<String, dynamic> listing, int index, Map<String, dynamic> variant, bool desktop) {
    final size = variant['size']?.toString() ?? '—';
    final color = variant['color']?.toString();
    final stock = (variant['stock'] as num?)?.toInt() ?? 0;
    final label = (color != null && color.isNotEmpty) ? '$size · $color' : size;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
        ),
        _stockStepper(
          value: stock,
          onChanged: (v) => _setVariantStock(listing, index, v),
        ),
      ],
    );
  }

  Widget _stockStepper({required int value, required ValueChanged<int> onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value <= 0 ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove_rounded, size: 18),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
          IconButton(
            tooltip: 'Saisir',
            visualDensity: VisualDensity.compact,
            onPressed: () => _promptStock(value, onChanged),
            icon: const Icon(Icons.edit_outlined, size: 16),
          ),
        ],
      ),
    );
  }

  Future<void> _promptStock(int current, ValueChanged<int> onChanged) async {
    final ctrl = TextEditingController(text: '$current');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le stock'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Quantité'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim()) ?? current),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result != null) onChanged(result);
  }

  Future<void> _setVariantStock(Map<String, dynamic> listing, int index, int stock) async {
    HapticFeedback.selectionClick();
    final prev = List<Map<String, dynamic>>.from(_products);
    setState(() {
      final variants = ListingAttributes.catalogVariants(listing['attributes']);
      if (index < variants.length) {
        variants[index]['stock'] = stock;
        final attrs = ListingAttributes.decodeMap(listing['attributes']) ?? {};
        attrs['variants'] = variants;
        listing['attributes'] = attrs;
        final i = _products.indexWhere((p) => p['id']?.toString() == listing['id']?.toString());
        if (i >= 0) _products[i] = listing;
        _stats = _data.getBusinessDashboardStats();
      }
    });
    try {
      await _data.updateVariantStock(listing, variantIndex: index, stock: stock);
      if (mounted) await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _products = prev);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, fallback: 'Échec de la mise à jour du stock.'))),
      );
    }
  }

  Future<void> _setSimpleStock(Map<String, dynamic> listing, int stock) async {
    final attrs = ListingAttributes.decodeMap(listing['attributes']) ?? {'catalog': true};
    var variants = ListingAttributes.catalogVariants(listing['attributes']);
    if (variants.isEmpty) {
      variants = [
        {
          'size': ListingAttributes.parseSize(listing['attributes']) ?? 'U',
          'stock': stock,
          'price_cdf': listing['price_cdf'] ?? listing['price'],
        },
      ];
    } else {
      variants[0]['stock'] = stock;
    }
    attrs['variants'] = variants;
    attrs['catalog'] = true;
    final id = int.tryParse(listing['id']?.toString() ?? '') ?? 0;
    if (id <= 0) return;
    try {
      await _data.updateListingInventory(id, attributesJson: ListingAttributes.encodeMap(attrs));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, fallback: 'Échec de la mise à jour du stock.'))),
      );
    }
  }

  Future<void> _onProductAction(Map<String, dynamic> listing, String action) async {
    final id = int.tryParse(listing['id']?.toString() ?? '') ?? 0;
    if (id <= 0) return;
    try {
      if (action == 'toggle') {
        final paused = listing['status']?.toString() == 'hidden';
        await _data.updateListingInventory(id, status: paused ? 'active' : 'hidden');
        await _reload();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(paused ? 'Produit remis en vitrine' : 'Produit en pause')),
        );
      } else if (action == 'detail') {
        Navigator.pushNamed(context, AppRoutes.detail, arguments: listing);
      } else if (action == 'sold') {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Marquer comme vendu ?'),
            content: const Text('Le produit disparaîtra de la vitrine active.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmer')),
            ],
          ),
        );
        if (ok == true) {
          await _data.markListingSold(id);
          await _reload();
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: 'Action impossible. Réessayez.'))));
    }
  }

  Widget _manageTab(bool desktop, EdgeInsets pad) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad.left, 16, pad.right, 100),
        children: [
          _sectionTitle('Actions boutique', Icons.storefront_rounded),
          const SizedBox(height: 10),
          _manageTile(
            Icons.grid_view_rounded,
            'Publier une collection',
            'Plusieurs produits en une publication',
            const Color(0xFF2563EB),
            () => _openCatalog(),
          ),
          const SizedBox(height: 8),
          _manageTile(
            Icons.shopping_bag_rounded,
            'Publier un produit unique',
            'Tailles, stock, jusqu\'à 12 photos',
            const Color(0xFF059669),
            () => _openSingle(),
          ),
          const SizedBox(height: 8),
          _manageTile(
            Icons.chat_rounded,
            'Messages clients',
            'Répondre aux demandes liées à vos produits',
            PremiumTheme.blue,
            () {
              if (widget.onOpenMessages != null) {
                widget.onOpenMessages!();
              } else {
                Navigator.pushNamed(context, AppRoutes.messages);
              }
            },
          ),
          if (AppConfig.paymentsEnabled) ...[
            const SizedBox(height: 8),
            _manageTile(
              Icons.payments_rounded,
              'Paiements Mobile Money',
              'Configurer vos comptes de réception',
              PremiumTheme.gold,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentSettingsScreen())),
            ),
          ],
          const SizedBox(height: 8),
          _manageTile(
            Icons.analytics_outlined,
            'Statistiques détaillées',
            'Vue rapide des publications et stocks',
            const Color(0xFF7C3AED),
            _showStatsSheet,
          ),
          const SizedBox(height: 20),
          _sectionTitle('Privilèges compte officiel', Icons.workspace_premium_rounded),
          const SizedBox(height: 10),
          _privileges(),
        ],
      ),
    );
  }

  Widget _manageTile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8ECF4)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _privileges() {
    const items = [
      (Icons.verified_rounded, 'Badge « Officiel »', 'Visible sur chaque fiche produit et votre profil public.'),
      (Icons.collections_bookmark_rounded, 'Catalogues illimités', 'Collections avec tailles, couleurs et stock.'),
      (Icons.inventory_2_rounded, 'Gestion de stock', 'Ajustez les quantités à tout moment depuis Stock.'),
      (Icons.campaign_rounded, 'Mise en avant accueil', 'Rotation prioritaire dans le bandeau boutiques.'),
      (Icons.chat_rounded, 'Messagerie boutique', 'Échanges clients liés à chaque produit.'),
      (Icons.shield_rounded, 'Priorité modération', 'Litiges traités en priorité pour les comptes KYC.'),
    ];
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8ECF4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: PremiumTheme.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(items[i].$1, color: PremiumTheme.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(items[i].$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      const SizedBox(height: 3),
                      Text(items[i].$3, style: const TextStyle(fontSize: 11.5, height: 1.35, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _publishActions(bool desktop) {
    final children = [
      _actionCard(
        gradient: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
        icon: Icons.grid_view_rounded,
        title: 'Collection catalogue',
        subtitle: '1 publication · plusieurs produits · chaque article sur l\'accueil',
        onTap: _openCatalog,
      ),
      _actionCard(
        gradient: const [Color(0xFF059669), Color(0xFF047857)],
        icon: Icons.shopping_bag_rounded,
        title: 'Produit unique',
        subtitle: 'Un article avec tailles, stock et jusqu\'à 12 photos',
        onTap: _openSingle,
      ),
    ];
    if (desktop) {
      return Row(
        children: [
          Expanded(child: children[0]),
          const SizedBox(width: 12),
          Expanded(child: children[1]),
        ],
      );
    }
    return Column(
      children: [
        children[0],
        const SizedBox(height: 10),
        children[1],
      ],
    );
  }

  Future<void> _openCatalog() async {
    HapticFeedback.mediumImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfficialCatalogPublishScreen(
          onPublished: () {
            widget.onPublished?.call();
            _reload();
          },
        ),
      ),
    );
    _reload();
  }

  Future<void> _openSingle() async {
    HapticFeedback.mediumImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfficialSingleProductScreen(
          onPublished: () {
            widget.onPublished?.call();
            _reload();
          },
        ),
      ),
    );
    _reload();
  }

  Widget _actionCard({
    required List<Color> gradient,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _growthTools(bool desktop) {
    final tools = <(IconData, String, VoidCallback)>[
      if (AppConfig.paymentsEnabled)
        (
          Icons.payments_rounded,
          'Paiements Mobile Money',
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentSettingsScreen())),
        ),
      (
        Icons.inventory_2_rounded,
        'Gérer le stock',
        () => _tabs.animateTo(1),
      ),
      (
        Icons.visibility_rounded,
        'Visibilité accueil',
        () => _showInfo(
          'Visibilité accueil',
          'Vos produits officiels sont promus automatiquement sur l\'accueil '
          '(bandeau + rotation équitable entre boutiques). Publiez régulièrement pour rester visible.',
        ),
      ),
      (
        Icons.chat_rounded,
        'Messages clients',
        () {
          if (widget.onOpenMessages != null) {
            widget.onOpenMessages!();
          } else {
            Navigator.pushNamed(context, AppRoutes.messages);
          }
        },
      ),
      (
        Icons.analytics_outlined,
        'Mes statistiques',
        _showStatsSheet,
      ),
      (
        Icons.reply_all_rounded,
        'Répondre vite',
        () => _showInfo(
          'Réactivité = ventes',
          'Répondez sous quelques heures : les acheteurs préfèrent les boutiques réactives.',
        ),
      ),
    ];

    final width = MediaQuery.sizeOf(context).width;
    final tileW = desktop
        ? ((_contentMaxWidth.isFinite ? _contentMaxWidth : width) - 48) / 3 - 8
        : (width - 42) / 2;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tools
          .map(
            (t) => Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  t.$3();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: tileW.clamp(140, 360),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8ECF4)),
                  ),
                  child: Row(
                    children: [
                      Icon(t.$1, size: 20, color: PremiumTheme.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.$2,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _tips() {
    final tips = _tipsForBusinessType(_businessType);
    return Column(
      children: tips
          .map(
            (t) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8ECF4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, color: PremiumTheme.emerald, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.$1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(t.$2, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  List<(String, String)> _tipsForBusinessType(String raw) {
    const base = <(String, String)>[
      ('Publiez en collection', 'Regroupez 5–20 produits par publication : chaque article a sa carte sur l\'accueil.'),
      ('Stock à jour', 'Ajustez le stock dans l\'onglet Stock pour éviter les ruptures et garder la confiance.'),
      ('Répondez rapidement', 'Un message sous 2 h augmente fortement vos chances de conclure.'),
      ('Pause vitrine', 'Mettez un produit en pause plutôt que de le supprimer s\'il est temporairement indisponible.'),
    ];
    final t = raw.toLowerCase().trim();
    final specific = <(String, String)>[];
    if (t.contains('mode') || t.contains('vêt') || t.contains('fashion')) {
      specific.addAll(const [
        ('Photos mannequin + détail', 'Montrez face, dos, étiquette et texture — la mode se vend d\'abord en image.'),
        ('Tailles complètes', 'Listez toutes les tailles avec stock réel.'),
      ]);
    } else if (t.contains('électron') || t.contains('tech') || t.contains('phone')) {
      specific.addAll(const [
        ('État & accessoires', 'Précisez neuf / occasion, boîte, chargeur, garantie.'),
        ('Prix transparent', 'Affichez le prix final pour gagner en crédibilité boutique.'),
      ]);
    } else {
      specific.addAll(const [
        ('Marque visible', 'Renseignez toujours la marque pour la recherche.'),
        ('Titre précis', 'Produit + marque + état dans le titre.'),
      ]);
    }
    return [...specific, ...base];
  }

  void _showInfo(String title, String body) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(body, style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF475569))),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Compris')),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatsSheet() {
    final pubs = (_stats['publications'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        minChildSize: 0.35,
        builder: (_, scroll) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: ListView(
            controller: scroll,
            children: [
              const Text('Statistiques boutique', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              _sheetStat('Produits actifs', '${_stats['productCount'] ?? 0}'),
              _sheetStat('Publications', '${_stats['publicationCount'] ?? 0}'),
              _sheetStat('Stock total (unités)', '${_stats['totalStock'] ?? 0}'),
              _sheetStat('Stock bas', '$_lowStockCount'),
              _sheetStat('Ruptures', '$_outOfStockCount'),
              _sheetStat('Promus sur l\'accueil', '${_stats['promotedOnHome'] ?? 0}'),
              if (pubs.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Dernières publications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                ...pubs.take(5).map(
                  (p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_special_outlined, color: PremiumTheme.blue),
                    title: Text(p['title']?.toString() ?? 'Publication', style: const TextStyle(fontSize: 13)),
                    subtitle: Text('${p['productCount']} produit(s)', style: const TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF64748B)))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
  }
}
