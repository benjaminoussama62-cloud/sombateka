import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/data_service.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../utils/listing_attributes.dart';
import 'official_catalog_publish_screen.dart';
import 'official_single_product_screen.dart';
import 'payment_settings_screen.dart';

/// Espace Pro — vendeurs officiels (totalement distinct du particulier).
class BusinessHubScreen extends StatefulWidget {
  const BusinessHubScreen({super.key, this.onPublished, this.onGoHome});

  final VoidCallback? onPublished;
  final VoidCallback? onGoHome;

  @override
  State<BusinessHubScreen> createState() => BusinessHubScreenState();
}

class BusinessHubScreenState extends State<BusinessHubScreen> {
  final _data = DataService();
  bool _loading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> reload() => _reload();

  Future<void> _reload() async {
    setState(() => _loading = true);
    await _data.refreshUser();
    await _data.refreshMyListings();
    await _data.refreshListings(mixPromoted: true);
    if (mounted) {
      setState(() {
        _stats = _data.getBusinessDashboardStats();
        _loading = false;
      });
    }
  }

  String get _shopName {
    final u = _data.currentUser;
    final official = u?['official_name']?.toString().trim();
    if (official != null && official.isNotEmpty) return official;
    return u?['display_name']?.toString() ?? 'Ma boutique';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _hero()),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: PremiumTheme.blue)),
                )
              else ...[
                SliverToBoxAdapter(child: _statsRow()),
                SliverToBoxAdapter(child: _sectionTitle('Publier', Icons.add_business_rounded)),
                SliverToBoxAdapter(child: _publishActions()),
                SliverToBoxAdapter(child: _sectionTitle('Faire grandir ma boutique', Icons.trending_up_rounded)),
                SliverToBoxAdapter(child: _growthTools()),
                SliverToBoxAdapter(child: _sectionTitle('Conseils Pro', Icons.lightbulb_outline_rounded)),
                SliverToBoxAdapter(child: _tips()),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [PremiumTheme.navy, Color(0xFF1E3A8A), PremiumTheme.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, color: PremiumTheme.gold, size: 16),
                    SizedBox(width: 4),
                    Text('Compte officiel', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.storefront_rounded, color: Colors.white70, size: 28),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _shopName,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Espace Pro — publication, stock, visibilité & paiements',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _statsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              _statTile('${_stats['productCount'] ?? 0}', 'Produits', Icons.inventory_2_outlined),
              const SizedBox(width: 10),
              _statTile('${_stats['publicationCount'] ?? 0}', 'Publications', Icons.collections_bookmark_outlined),
              const SizedBox(width: 10),
              _statTile('${_stats['totalStock'] ?? 0}', 'Stock total', Icons.layers_outlined),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statTile('${_stats['soldCount'] ?? 0}', 'Vendus', Icons.sell_outlined),
              const SizedBox(width: 10),
              _statTile('${_stats['activeCount'] ?? 0}', 'Actifs', Icons.check_circle_outline),
              const SizedBox(width: 10),
              _statTile(_formatRevenue(_stats['revenueCdf']), 'CA (CDF)', Icons.payments_outlined),
            ],
          ),
        ],
      ),
    );
  }

  String _formatRevenue(dynamic v) {
    final n = (v as num?)?.toInt() ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k';
    return '$n';
  }

  Widget _statTile(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8ECF4)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: PremiumTheme.blue),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
            Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: PremiumTheme.blue),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _publishActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _actionCard(
            gradient: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
            icon: Icons.grid_view_rounded,
            title: 'Collection catalogue',
            subtitle: '1 publication · plusieurs produits · chaque article sur l\'accueil',
            onTap: () async {
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
            },
          ),
          const SizedBox(height: 10),
          _actionCard(
            gradient: const [Color(0xFF059669), Color(0xFF047857)],
            icon: Icons.shopping_bag_rounded,
            title: 'Produit unique',
            subtitle: 'Un article avec tailles, stock et jusqu\'à 12 photos',
            onTap: () async {
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
            },
          ),
        ],
      ),
    );
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

  Widget _growthTools() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _toolChip(
            Icons.payments_rounded,
            'Paiements Mobile Money',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentSettingsScreen())),
          ),
          _toolChip(
            Icons.visibility_rounded,
            'Visibilité accueil',
            () => _showInfo(
              'Visibilité accueil',
              'Vos produits officiels sont promus automatiquement sur l\'accueil '
              '(bandeau + rotation équitable entre boutiques). Publiez régulièrement pour rester visible.',
            ),
          ),
          _toolChip(
            Icons.photo_library_rounded,
            'Photos pro',
            () => _showInfo(
              'Photos professionnelles',
              'Utilisez 5 à 12 photos par produit : face, dos, détail, étiquette. '
              'Les annonces avec plusieurs photos vendent mieux et ressortent dans la recherche par photo.',
            ),
          ),
          _toolChip(
            Icons.map_rounded,
            '26 provinces',
            () => _showInfo(
              'Couverture nationale',
              'Renseignez province, commune et quartier : vos produits apparaissent '
              'dans les filtres par province sur l\'accueil.',
            ),
          ),
          _toolChip(
            Icons.chat_rounded,
            'Support clients',
            () => Navigator.pushNamed(context, AppRoutes.messages),
          ),
          _toolChip(
            Icons.analytics_outlined,
            'Mes statistiques',
            () => _showStatsSheet(),
          ),
        ],
      ),
    );
  }

  Widget _toolChip(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: (MediaQuery.sizeOf(context).width - 42) / 2,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8ECF4)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: PremiumTheme.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tips() {
    const tips = [
      ('Publiez en collection', 'Regroupez 5–20 produits par publication : chaque article a sa carte sur l\'accueil.'),
      ('Stock à jour', 'Mettez le stock réel par taille pour éviter les ruptures et garder la confiance.'),
      ('Marque visible', 'Renseignez toujours la marque : les acheteurs filtrent par marque sur la recherche.'),
      ('Republiez', 'Depuis Profil → Mes annonces, republiez pour remonter en tête du fil.'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
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
      ),
    );
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
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Compris'),
              ),
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
