import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../widgets/st_page_header.dart';
import 'official_catalog_publish_screen.dart';
import 'official_single_product_screen.dart';

/// Onglet « Vendre un article » pour vendeurs officiels — publication uniquement.
/// Le tableau de bord (stats, stock, outils) est dans le menu Espace Pro.
class OfficialSellScreen extends StatefulWidget {
  const OfficialSellScreen({
    super.key,
    this.onPublished,
    this.onGoHome,
    this.onOpenMessages,
  });

  final VoidCallback? onPublished;
  final VoidCallback? onGoHome;
  final VoidCallback? onOpenMessages;

  @override
  State<OfficialSellScreen> createState() => OfficialSellScreenState();
}

class OfficialSellScreenState extends State<OfficialSellScreen> {
  void resetForm() {}

  Future<void> _openCatalog() async {
    HapticFeedback.mediumImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfficialCatalogPublishScreen(
          onPublished: widget.onPublished,
        ),
      ),
    );
  }

  Future<void> _openSingle() async {
    HapticFeedback.mediumImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfficialSingleProductScreen(
          onPublished: widget.onPublished,
        ),
      ),
    );
  }

  void _openHub() {
    HapticFeedback.selectionClick();
    Navigator.pushNamed(context, AppRoutes.businessHub);
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 768;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Column(
        children: [
          StPageHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vendre', style: PremiumTheme.display.copyWith(fontSize: 22)),
                const SizedBox(height: 4),
                Text(
                  'Choisissez comment publier votre article',
                  style: PremiumTheme.body.copyWith(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: desktop ? 720 : double.infinity),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(desktop ? 28 : 20, 20, desktop ? 28 : 20, 100),
                  children: [
                    _sellCard(
                      gradient: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      icon: Icons.grid_view_rounded,
                      title: 'Collection catalogue',
                      subtitle: 'Plusieurs produits en une publication — idéal pour une boutique complète',
                      onTap: _openCatalog,
                    ),
                    const SizedBox(height: 12),
                    _sellCard(
                      gradient: const [Color(0xFF059669), Color(0xFF047857)],
                      icon: Icons.shopping_bag_rounded,
                      title: 'Produit unique',
                      subtitle: 'Un article avec tailles, stock et jusqu\'à 12 photos',
                      onTap: _openSingle,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'BESOIN D\'AIDER VOTRE BOUTIQUE ?',
                      style: PremiumTheme.label.copyWith(
                        fontSize: 11,
                        letterSpacing: 1.1,
                        color: PremiumTheme.textMuted.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _openHub,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE8ECF4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: PremiumTheme.gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.dashboard_rounded, color: PremiumTheme.gold, size: 22),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Espace Pro',
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Stats, outils, conseils selon votre activité',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
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

  Widget _sellCard({
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
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 12.5, height: 1.35),
                    ),
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
}
