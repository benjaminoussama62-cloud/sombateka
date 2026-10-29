import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/cart_ui_helper.dart';
import '../services/data_service.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../utils/listing_utils.dart';
import '../utils/responsive.dart';
import '../utils/marketplace_layout.dart';
import '../widgets/marketplace_product_card.dart';
import '../widgets/user_avatar.dart';
import '../widgets/account_verification_badge.dart';
import 'chat_screen.dart';

/// Profil public vendeur (style Kufar) — données non sensibles uniquement.
class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, required this.userId, this.listingContext});

  final int userId;
  final Map<String, dynamic>? listingContext;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _data = DataService();
  bool _loading = true;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _load();
    _loadSessionData();
  }

  Future<void> _loadSessionData() async {
    await _data.loadFavorites();
    await _data.loadCart();
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    Map<String, dynamic>? p;
    try {
      p = await _data.fetchPublicUserProfile(widget.userId);
    } catch (_) {}
    p ??= _profileFromListingContext(widget.listingContext);
    if (mounted) setState(() {
      _profile = p;
      _loading = false;
    });
  }

  Map<String, dynamic>? _profileFromListingContext(Map<String, dynamic>? listing) {
    if (listing == null) return null;
    final name = listing['sellerName']?.toString().trim();
    if (name == null || name.isEmpty || name == 'Vendeur') return null;
    return {
      'display_name': name,
      'avatar_url': listing['sellerAvatarUrl'],
      'official_logo_url': listing['sellerLogoUrl'],
      'profile_public': listing['sellerProfilePublic'] != false,
      'is_official': listing['isOfficial'] == true,
      'is_verified_seller': listing['isVerified'] == true,
      'account_verified': listing['sellerAccountVerified'] == true,
      'email_verified': listing['sellerAccountVerified'] == true,
      'average_rating': (listing['sellerRating'] as num?)?.toDouble() ?? 0,
      'review_count': (listing['sellerReviewCount'] as num?)?.toInt() ?? 0,
      'active_listings_count': 1,
      'allow_messages': true,
      'listings': [],
      'partial_from_listing': true,
    };
  }

  bool get _isOfficial => _profile?['is_official'] == true || _profile?['is_verified_seller'] == true;

  bool get _accountVerified =>
      _profile?['account_verified'] == true || _profile?['email_verified'] == true;

  String get _displayName => _profile?['display_name']?.toString() ?? 'Vendeur SombaTeka';

  String? get _avatarUrl {
    final logo = _profile?['official_logo_url']?.toString();
    if (_isOfficial && logo != null && logo.isNotEmpty) return logo;
    final av = _profile?['avatar_url']?.toString();
    return av != null && av.isNotEmpty ? av : null;
  }

  List<Map<String, dynamic>> get _listings {
    final raw = (_profile?['listings'] as List?) ?? [];
    final uid = _data.currentUser?['id']?.toString();
    return raw
        .map((e) => normalizeListing(
              Map<String, dynamic>.from(e as Map),
              favoriteIds: _data.favoriteIds,
              currentUserId: uid,
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: PremiumTheme.blue))
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 236,
                  backgroundColor: PremiumTheme.navy,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: PremiumTheme.heroGradient,
                      padding: EdgeInsets.fromLTRB(
                        20,
                        MediaQuery.viewPaddingOf(context).top + 56,
                        20,
                        20,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          UserAvatar(imageUrl: _avatarUrl, name: _displayName, radius: 40),
                          const SizedBox(height: 10),
                          Text(
                            _displayName,
                            textAlign: TextAlign.center,
                            style: PremiumTheme.display.copyWith(fontSize: 20, color: Colors.white),
                          ),
                          if (_isOfficial) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: PremiumTheme.gold,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Boutique officielle',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: PremiumTheme.navy),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 10),
                            AccountVerificationBadge(
                              verified: _accountVerified,
                              lightOnDark: true,
                              prominent: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _body()),
              ],
            ),
    );
  }

  Widget _body() {
    if (_profile == null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Text('Profil vendeur indisponible', style: PremiumTheme.h1),
              const SizedBox(height: 8),
              Text(
                'L\'annonce est bien active, mais le profil public n\'est pas encore accessible sur le serveur. Utilisez « Écrire au vendeur » depuis la fiche produit.',
                textAlign: TextAlign.center,
                style: PremiumTheme.body.copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final partial = _profile!['partial_from_listing'] == true;

    final public = _profile!['profile_public'] != false;
    final rating = (_profile!['average_rating'] as num?)?.toDouble() ?? 0;
    final reviews = (_profile!['review_count'] as num?)?.toInt() ?? 0;
    final active = (_profile!['active_listings_count'] as num?)?.toInt() ?? _listings.length;
    final memberSince = _profile!['member_since']?.toString();
    final phone = _profile!['phone_display']?.toString();
    final allowMsg = _profile!['allow_messages'] != false;

    final bio = _profile!['profile_bio']?.toString().trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isOfficial && !_accountVerified) AccountVerificationNotice(verified: _accountVerified),
          if (partial)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: PremiumTheme.blue.withValues(alpha: 0.08),
                borderRadius: PremiumTheme.radiusMd,
                border: Border.all(color: PremiumTheme.blue.withValues(alpha: 0.2)),
              ),
              child: Text(
                'Informations limitées — profil complet après mise à jour du serveur.',
                style: PremiumTheme.body.copyWith(fontSize: 12),
              ),
            ),
          if (!public)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: PremiumTheme.radiusMd,
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ce vendeur a choisi un profil privé. Seules les annonces visibles restent accessibles via la messagerie.',
                      style: PremiumTheme.body.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              _statTile('$active', 'Annonces actives', PremiumTheme.blue),
              const SizedBox(width: 10),
              _statTile(reviews > 0 ? rating.toStringAsFixed(1) : '—', 'Note moyenne', PremiumTheme.emerald),
              const SizedBox(width: 10),
              _statTile('$reviews', 'Avis', PremiumTheme.navy),
            ],
          ),
          if (memberSince != null && memberSince.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              () {
                final dt = DateTime.tryParse(memberSince);
                if (dt == null) return 'Membre SombaTeka';
                return 'Membre depuis ${DateFormat('MMMM yyyy', 'fr_FR').format(dt.toLocal())}';
              }(),
              style: PremiumTheme.label.copyWith(fontSize: 11),
            ),
          ],
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('À propos', style: PremiumTheme.h1.copyWith(fontSize: 15)),
            const SizedBox(height: 6),
            Text(bio, style: PremiumTheme.body.copyWith(fontSize: 13, height: 1.45)),
          ],
          if (phone != null && phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 14, color: PremiumTheme.textMuted.withValues(alpha: 0.8)),
                const SizedBox(width: 6),
                Text(phone, style: PremiumTheme.label.copyWith(fontSize: 11)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Numéro complet et données personnelles jamais affichés sans consentement du vendeur.',
            style: PremiumTheme.label.copyWith(fontSize: 9, color: PremiumTheme.textMuted),
          ),
          if (allowMsg && widget.listingContext != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _contactAboutListing,
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: const Text('Contacter à propos de cette annonce'),
                style: FilledButton.styleFrom(
                  backgroundColor: PremiumTheme.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
          if (public && _listings.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Annonces de $_displayName', style: PremiumTheme.h1.copyWith(fontSize: 17)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: MarketplaceLayout.productGridDelegate(context),
              itemCount: _listings.length,
              itemBuilder: (_, i) {
                final l = _listings[i];
                return MarketplaceProductCard(
                  listing: l,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.detail, arguments: l),
                  onFavorite: () async {
                    await _data.toggleFavorite(l['id']?.toString() ?? '');
                    if (mounted) setState(() {});
                  },
                  onAddToCart: l['isOwnListing'] == true
                      ? null
                      : () async {
                          await CartUiHelper.toggleListing(context, l);
                          if (mounted) setState(() {});
                        },
                );
              },
            ),
          ] else if (public && _listings.isEmpty) ...[
            const SizedBox(height: 32),
            Center(
              child: Text('Aucune annonce active pour le moment', style: PremiumTheme.body),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statTile(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: PremiumTheme.radiusMd,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: PremiumTheme.label.copyWith(fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Future<void> _contactAboutListing() async {
    final listing = widget.listingContext;
    if (listing == null) return;
    final peerId = widget.userId.toString();
    final listingId = listing['id']?.toString();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerId: peerId,
          peerName: _displayName,
          listingId: listingId,
          listingTitle: listing['title']?.toString(),
          isOfficialPeer: listing['isOfficial'] == true,
          peerAccountVerified: _accountVerified,
          peerEmailVerified: _accountVerified,
        ),
      ),
    );
  }
}
