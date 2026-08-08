import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/onboarding_service.dart';
import '../config/app_config.dart';
import '../widgets/app_tour_overlay.dart';
import '../widgets/premium_profile_header.dart';
import '../widgets/account_setup_banner.dart';
import '../widgets/finalize_account_sheet.dart';
import '../widgets/app_confirm_dialog.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../utils/listing_utils.dart';
import '../services/data_service.dart';
import '../services/listing_actions.dart';
import '../utils/app_feedback.dart';
import 'business_hub_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onOpenMessages, this.onOpenBusinessHub});

  /// Bascule vers l'onglet Messages (coque principale) — évite une page sans navigation.
  final VoidCallback? onOpenMessages;

  /// Bascule vers l'onglet Espace Pro (menu principal).
  final VoidCallback? onOpenBusinessHub;

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  int _selectedTab = 0;
  final DataService _dataService = DataService();
  bool _checking = true;
  bool _verified = false;
  int _finalizedPeopleCount = 0;
  int _activeListingsCount = 0;
  List<Map<String, dynamic>> _reviews = [];

  Map<String, dynamic>? get _user => _dataService.currentUser;

  String? get _userId => _user?['id']?.toString();

  bool get _isOfficial =>
      _user != null &&
      (_user!['is_verified_seller'] == true || _user!['status'] == AppStatus.official);

  List<String> get _tabs =>
      _isOfficial ? ['Mon catalogue', 'Favoris', 'Avis'] : ['Mes annonces', 'Favoris', 'Avis'];

  // Annonces réelles de l'utilisateur
  List<Map<String, dynamic>> get _userListings {
    final uid = _userId;
    if (uid != null && uid.isNotEmpty) return _dataService.getUserListings(uid);
    return [];
  }

  List<Map<String, dynamic>> get _favorites {
    final uid = _userId;
    if (uid != null && uid.isNotEmpty) return _dataService.getUserFavorites(uid);
    return [];
  }

  // Getters manquants pour la compatibilité
  List<Map<String, dynamic>> get _myListings => _userListings;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppTourPresenter.maybeShow(context, AppTourPage.profile);
    });
  }

  int get _activeListingsCountLive {
    final uid = _userId;
    if (uid == null) return _activeListingsCount;
    final mine = _dataService.myListings.isNotEmpty
        ? _dataService.myListings
        : _dataService.getUserListings(uid);
    return mine.where((l) {
      final s = (l['status']?.toString() ?? 'active').toLowerCase();
      return s == 'active';
    }).length;
  }

  /// Recharge nom, photo et stats depuis l’API (appelé à l’ouverture de l’onglet Profil).
  Future<void> reloadProfile() => _loadProfile();

  void _openClientsInbox() {
    final open = widget.onOpenMessages;
    if (open != null) {
      open();
      return;
    }
    Navigator.pushNamed(context, AppRoutes.messages);
  }

  Future<void> _loadProfile() async {
    try {
      final ok = await _dataService.hasVerifiedProfile();
      if (ok) {
        await _dataService.refreshUser();
        await _dataService.refreshListings();
        await _dataService.refreshMyListings();
        await _dataService.refreshConversations();
        _reviews = await _dataService.fetchMyReviews();
        _finalizedPeopleCount = await _dataService.countFinalizedOperationPeople();
        _activeListingsCount = _dataService.myListings.where((l) {
          final s = (l['status']?.toString() ?? 'active').toLowerCase();
          return s == 'active';
        }).length;
      }
      if (mounted) {
        setState(() {
          _verified = ok;
          _checking = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _verified = false; _checking = false; });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fond navy dès l'ouverture — jamais de flash blanc (scaffold parent / 1er paint).
    const profileBg = PremiumTheme.homeHeaderColor;
    if (_checking) {
      return const Scaffold(
        backgroundColor: profileBg,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (!_verified) {
      return _buildLoginGate(context);
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
      backgroundColor: profileBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            PremiumProfileHeader(
              name: _dataService.profileDisplayName(_user),
              phone: _user?['phone']?.toString() ?? _user?['phone_e164']?.toString() ?? '',
              city: '',
              avatarUrl: _dataService.profileAvatarUrl,
              status: _user?['status']?.toString() ?? AppStatus.ordinary,
              averageRating: (_user?['average_rating'] as num?)?.toDouble() ?? 0,
              reviewCount: (_user?['review_count'] as num?)?.toInt() ?? 0,
              accountVerified:
                  _user?['account_verified'] == true || _user?['email_verified'] == true,
              onAvatarTap: () async {
                final ok = await Navigator.pushNamed(context, AppRoutes.editProfile);
                if (ok == true) _loadProfile();
              },
              onSettings: () async {
                await Navigator.pushNamed(context, AppRoutes.settings);
                _loadProfile();
              },
            ),

            if (_dataService.needsAccountSetup(_user)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: AccountSetupBanner(
                  needsPhone: _dataService.needsPhone(_user),
                  needsPassword: _dataService.needsPassword(_user),
                  onTap: () async {
                    final ok = await showFinalizeAccountSheet(context);
                    if (ok == true) _loadProfile();
                  },
                ),
              ),
            ],

            if (_isOfficial) ...[
              const SizedBox(height: 16),
              _buildOfficialProPanel(),
            ],

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _buildProfileStatsRow(),
            ),

            const SizedBox(height: 24),
            
            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: PremiumTheme.radiusMd,
                border: Border.all(color: const Color(0xFFE8ECF4)),
              ),
              child: Row(
                children: List.generate(_tabs.length, (index) {
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedTab == index ? PremiumTheme.blue : Colors.transparent,
                          borderRadius: PremiumTheme.radiusMd,
                        ),
                        child: Text(
                          _tabs[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _selectedTab == index ? Colors.white : PremiumTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            
            const SizedBox(height: 20),

            // Tab content
            _buildTabContent(),
            
            // Actions
            if (!_isOfficial)
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.gold, AppColors.gold.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Devenir vendeur officiel",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Badge certifié, catalogues illimités, mise en avant sur l'accueil et messagerie clients — la vitrine digne d'une vraie boutique.",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _GoldChip(label: 'KYC'),
                        _GoldChip(label: 'Catalogues'),
                        _GoldChip(label: 'Priorité accueil'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await Navigator.pushNamed(context, AppRoutes.officialSeller);
                          _loadProfile();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: AppColors.gold,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                          ),
                        ),
                        child: const Text(
                          "Demander le badge officiel",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 120),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildOfficialProPanel() {
    final stats = _dataService.getBusinessDashboardStats();
    final shopName = _user?['official_name']?.toString().trim().isNotEmpty == true
        ? _user!['official_name'].toString()
        : _dataService.profileDisplayName(_user);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [PremiumTheme.navy, Color(0xFF1E3A8A), PremiumTheme.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: PremiumTheme.radiusLg,
        boxShadow: PremiumTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: PremiumTheme.gold, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shopName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Boutique officielle · ${stats['productCount']} produits · ${stats['publicationCount']} catalogues · ${stats['promotedOnHome']} en avant',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            child: Row(
              children: [
                Expanded(child: _proAction(Icons.dashboard_rounded, 'Espace Pro', () {
                  if (widget.onOpenBusinessHub != null) {
                    widget.onOpenBusinessHub!();
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BusinessHubScreen(
                        onOpenMessages: () {
                          Navigator.of(context).pop();
                          _openClientsInbox();
                        },
                      ),
                    ),
                  );
                })),
                const SizedBox(width: 8),
                Expanded(child: _proAction(Icons.grid_view_rounded, 'Catalogue', () {
                  Navigator.pushNamed(context, AppRoutes.officialCatalogPublish);
                })),
                const SizedBox(width: 8),
                Expanded(child: _proAction(Icons.chat_rounded, 'Clients', _openClientsInbox)),
                if (AppConfig.paymentsEnabled) ...[
                  const SizedBox(width: 8),
                  Expanded(child: _proAction(Icons.payments_rounded, 'Paiements', () {
                    Navigator.pushNamed(context, AppRoutes.paymentSettings);
                  })),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _proAction(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStatsRow() {
    final active = _activeListingsCountLive;
    return Column(
      children: [
        _profileStatCard(
          value: '$active',
          label: 'Annonces actives',
          subtitle: 'En ligne sur SombaTeka',
          icon: Icons.check_circle_outline,
          color: PremiumTheme.emerald,
          fullWidth: true,
        ),
        const SizedBox(height: 10),
        _profileStatCard(
          value: '$_finalizedPeopleCount',
          label: 'Opérations finalisées',
          subtitle: 'Personnes · achat ou vente confirmé',
          icon: Icons.handshake_rounded,
          color: PremiumTheme.blue,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _profileStatCard({
    required String value,
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: PremiumTheme.radiusMd,
        border: Border.all(color: const Color(0xFFE8ECF4)),
        boxShadow: PremiumTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                value,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color, height: 1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          Text(subtitle, style: PremiumTheme.label.copyWith(fontSize: 9, height: 1.25)),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildMyListings();
      case 1:
        return _buildFavorites();
      case 2:
        return _buildReviews();
      default:
        return _buildMyListings();
    }
  }

  Widget _buildMyListings() {
    if (_myListings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.storefront_outlined, size: 64, color: PremiumTheme.textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('Aucune annonce', style: PremiumTheme.h1.copyWith(fontSize: 18)),
            const SizedBox(height: 6),
            Text('Publiez depuis l’onglet Vendre', style: PremiumTheme.body, textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          ..._myListings.map((listing) => _buildListingCard(listing)).toList(),
        ],
      ),
    );
  }

  Widget _buildFavorites() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          ..._favorites.map((item) => _buildFavoriteCard(item)).toList(),
        ],
      ),
    );
  }

  Widget _buildReviews() {
    if (_reviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.star_border_rounded, size: 64, color: PremiumTheme.gold.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('Aucun avis pour le moment', style: PremiumTheme.h1.copyWith(fontSize: 18)),
            Text('Les acheteurs laisseront des avis après vos ventes', style: PremiumTheme.body, textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: _reviews.map((r) {
          final rating = (r['rating'] as num?)?.toInt() ?? 5;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: PremiumTheme.radiusMd,
              border: Border.all(color: const Color(0xFFE8ECF4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ...List.generate(5, (i) => Icon(
                      i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: const Color(0xFFFFB800),
                      size: 18,
                    )),
                    const Spacer(),
                    Text(r['reviewer_name']?.toString() ?? 'Acheteur', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                if ((r['listing_title']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(r['listing_title'].toString(), style: PremiumTheme.label.copyWith(color: PremiumTheme.blue)),
                ],
                if ((r['comment']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(r['comment'].toString(), style: PremiumTheme.body.copyWith(fontSize: 13)),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildListingCard(Map<String, dynamic> listing) {
    final l = normalizeListing(listing);
    final id = int.tryParse(l['id']?.toString() ?? '');
    final status = l['status']?.toString() ?? 'active';
    final img = l['imageUrl']?.toString() ?? '';
    final isActive = status == 'active';
    final isSold = status == 'sold';

    String statusLabel = 'Actif';
    Color statusColor = PremiumTheme.emerald;
    if (isSold) {
      statusLabel = 'Vendu';
      statusColor = AppColors.warning;
    } else if (!isActive) {
      statusLabel = 'Masqué';
      statusColor = AppColors.textSecondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: PremiumTheme.radiusMd,
        border: Border.all(color: const Color(0xFFE8ECF4)),
        boxShadow: PremiumTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => Navigator.pushNamed(context, AppRoutes.detail, arguments: l),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: PremiumTheme.radiusMd,
                    child: img.isNotEmpty
                        ? CachedNetworkImage(imageUrl: img, width: 72, height: 72, fit: BoxFit.cover)
                        : Container(
                            width: 72,
                            height: 72,
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(Icons.image_outlined, color: PremiumTheme.textMuted),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l['title']?.toString() ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(l['price']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w900, color: PremiumTheme.blue, fontSize: 16)),
                        if ((l['size']?.toString() ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Taille ${l['size']}', style: PremiumTheme.label.copyWith(fontSize: 11)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _listingAction(
                  icon: Icons.refresh_rounded,
                  label: 'Republier',
                  color: PremiumTheme.blue,
                  onTap: id == null
                      ? null
                      : () async {
                          final ok = await showAppConfirmDialog(
                            context,
                            title: 'Republier l\'annonce ?',
                            message: 'Elle réapparaîtra en haut des résultats comme une nouvelle annonce.',
                            confirmLabel: 'Republier',
                            icon: Icons.publish_rounded,
                          );
                          if (ok == true && mounted) {
                            await _dataService.republishListing(id);
                            await _loadProfile();
                            if (!mounted) return;
                            showAppSuccess(context, 'Annonce republiée avec succès');
                          }
                        },
                ),
                if (!isSold)
                  _listingAction(
                    icon: Icons.sell_rounded,
                    label: 'Vendu',
                    color: AppColors.warning,
                    onTap: id == null
                        ? null
                        : () async {
                            final ok = await showAppConfirmDialog(
                              context,
                              title: 'Marquer comme vendu ?',
                              message: 'L\'annonce ne sera plus visible dans le catalogue.',
                              confirmLabel: 'Oui, vendu',
                              icon: Icons.check_circle_outline_rounded,
                            );
                            if (ok == true && mounted) {
                              await markListingAsSoldFlow(
                                context,
                                _dataService,
                                listingId: id,
                                listingTitle: l['title']?.toString() ?? 'Annonce',
                              );
                              await _loadProfile();
                            }
                          },
                  ),
                _listingAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'Supprimer',
                  color: AppColors.danger,
                  onTap: id == null
                      ? null
                      : () async {
                          final ok = await showAppConfirmDialog(
                            context,
                            title: 'Supprimer l\'annonce ?',
                            message: 'Cette action retire définitivement votre publication.',
                            confirmLabel: 'Supprimer',
                            destructive: true,
                            icon: Icons.delete_forever_rounded,
                          );
                          if (ok == true && mounted) {
                            await _dataService.deleteMyListing(id);
                            await _loadProfile();
                            if (!mounted) return;
                            showAppSuccess(context, 'Annonce supprimée');
                          }
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _listingAction({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        backgroundColor: color.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildLoginGate(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.homeHeaderColor,
      body: ColoredBox(
        color: PremiumTheme.homeHeaderColor,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 24),
                Text(
                  'Créez votre compte',
                  style: PremiumTheme.display.copyWith(fontSize: 26),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Connectez-vous par email, Google ou Apple pour accéder à votre profil, publier et contacter les vendeurs.',
                  style: PremiumTheme.body.copyWith(color: Colors.white70, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pushNamed(context, AppRoutes.auth);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: PremiumTheme.navy,
                      shape: RoundedRectangleBorder(borderRadius: PremiumTheme.radiusLg),
                    ),
                    child: const Text('Créer un compte / Se connecter', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.welcome),
                  child: const Text('Retour', style: TextStyle(color: Colors.white60)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.image_outlined,
              size: 30,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['price']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['sellerName']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (item['isVerified'])
                      const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: AppColors.gold,
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
}

class _GoldChip extends StatelessWidget {
  const _GoldChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black87),
      ),
    );
  }
}
