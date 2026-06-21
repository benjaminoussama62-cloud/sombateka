import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/data_service.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../utils/listing_utils.dart';
import '../utils/responsive.dart';
import '../widgets/marketplace_product_card.dart';
import 'detail_screen.dart';

/// Page « Produits similaires » (image, catégorie, couleur, paramètres, texte).
class SimilarProductsScreen extends StatefulWidget {
  const SimilarProductsScreen({super.key, required this.listing});

  final Map<String, dynamic> listing;

  @override
  State<SimilarProductsScreen> createState() => _SimilarProductsScreenState();
}

class _SimilarProductsScreenState extends State<SimilarProductsScreen> {
  final _data = DataService();
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  String? _message;
  String? _sourceTitle;
  String? _sourceImage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = int.tryParse(widget.listing['id']?.toString() ?? '');
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final r = await _data.fetchSimilarListings(id);
      if (mounted) {
        setState(() {
          _items = r.items;
          _message = r.message;
          _sourceTitle = r.sourceTitle ?? widget.listing['title']?.toString();
          _sourceImage = r.sourceImageUrl ?? widget.listing['imageUrl']?.toString();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 140,
            backgroundColor: PremiumTheme.navy,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Produits similaires',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: PremiumTheme.heroGradient,
                padding: const EdgeInsets.fromLTRB(56, 72, 16, 12),
                child: Row(
                  children: [
                    if ((_sourceImage ?? '').isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: _sourceImage!,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _sourceTitle ?? 'Annonce',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: PremiumTheme.blue)),
            )
          else if (_items.isEmpty)
            SliverFillRemaining(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _message ?? 'Aucun produit similaire trouvé.',
                  textAlign: TextAlign.center,
                  style: PremiumTheme.body,
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  '${_items.length} article(s) proche(s) — image, catégorie & caractéristiques',
                  style: PremiumTheme.label.copyWith(fontSize: 12),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: Responsive.productGridColumns(context),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: Responsive.productGridAspectRatio(context),
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final item = normalizeListing(_items[i]);
                    return MarketplaceProductCard(
                      listing: item,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailScreen(listing: item),
                        ),
                      ),
                    );
                  },
                  childCount: _items.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
