import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../services/data_service.dart';
import '../widgets/user_avatar.dart';
import '../widgets/legal_document_sheet.dart';
import 'business_hub_screen.dart';
import 'chat_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DataService _dataService = DataService();
  bool _loading = true;
  Map<String, dynamic>? _kyc;
  List<Map<String, dynamic>> _blockedUsers = [];
  String _appVersion = '';

  Map<String, dynamic>? get _user => _dataService.currentUser;

  bool get _isOfficialSeller =>
      _user != null &&
      (_user!['is_verified_seller'] == true || _user!['status'] == AppStatus.official);

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _load();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = '${info.version}+${info.buildNumber}');
    } catch (_) {
      _appVersion = '1.0.0+1';
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (await _dataService.hasVerifiedProfile()) {
        await _dataService.refreshUser();
        _kyc = await _dataService.fetchKycStatus();
        _blockedUsers = await _dataService.fetchBlockedUsers();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.surface,
      body: Column(
        children: [
          _settingsHeader(context),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: PremiumTheme.blue))
                : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAccountCard(),
            const SizedBox(height: 20),
            if (_isOfficialSeller) ...[
              _buildSection(
                'Boutique Pro',
                [
                  _buildMenuItem(
                    'Espace Pro',
                    Icons.dashboard_rounded,
                    PremiumTheme.blue,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BusinessHubScreen()),
                    ),
                  ),
                  _buildMenuItem(
                    'Publier une collection',
                    Icons.grid_view_rounded,
                    PremiumTheme.emerald,
                    () => Navigator.pushNamed(context, AppRoutes.officialCatalogPublish),
                  ),
                  _buildMenuItem(
                    'Paiements & Mobile Money',
                    Icons.payments_rounded,
                    PremiumTheme.gold,
                    () => Navigator.pushNamed(context, AppRoutes.paymentSettings),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            _buildSection(
              'Compte',
              [
                _buildMenuItem(
                  'Modifier profil',
                  Icons.edit_rounded,
                  AppColors.primary,
                  () async {
                    final ok = await Navigator.pushNamed(context, AppRoutes.editProfile);
                    if (ok == true) _load();
                  },
                ),
                if (!_isOfficialSeller)
                  _buildMenuItem(
                    'Devenir vendeur officiel',
                    Icons.store_rounded,
                    AppColors.gold,
                    () async {
                      await Navigator.pushNamed(context, AppRoutes.officialSeller);
                      _load();
                    },
                  ),
                _buildMenuItem(
                  'Supprimer mon compte',
                  Icons.delete_forever_rounded,
                  AppColors.danger,
                  _deleteAccount,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Notifications section
            _buildSection(
              "Notifications",
              [
                _buildMenuItem(
                  "Paramètres de notification",
                  Icons.notifications_rounded,
                  AppColors.textPrimary,
                  () {
                    _showNotificationSettings();
                  },
                ),
                _buildMenuItem(
                  "Préférences de chat",
                  Icons.chat_rounded,
                  AppColors.textPrimary,
                  () {
                    _showChatPreferences();
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Privacy section
            _buildSection(
              "Confidentialité",
              [
                _buildMenuItem(
                  "Paramètres de confidentialité",
                  Icons.lock_rounded,
                  AppColors.textPrimary,
                  () => Navigator.pushNamed(context, AppRoutes.privacy),
                ),
                _buildMenuItem(
                  "Bloquer des utilisateurs",
                  Icons.block_rounded,
                  AppColors.danger,
                  () {
                    _showBlockedUsers();
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Payment section
            if (!_isOfficialSeller)
              _buildSection(
                "Paiement",
                [
                  _buildMenuItem(
                    "Méthodes de paiement",
                    Icons.payment_rounded,
                    AppColors.textPrimary,
                    () => Navigator.pushNamed(context, AppRoutes.paymentSettings),
                  ),
                  _buildMenuItem(
                    "Historique des transactions",
                    Icons.history_rounded,
                    AppColors.textPrimary,
                    () {
                      _showTransactionHistory();
                    },
                  ),
                ],
              ),
            if (!_isOfficialSeller) const SizedBox(height: 24),
            if (_isOfficialSeller)
              _buildSection(
                'Commandes',
                [
                  _buildMenuItem(
                    'Historique des ventes',
                    Icons.receipt_long_rounded,
                    PremiumTheme.blue,
                    _showTransactionHistory,
                  ),
                ],
              ),
            if (_isOfficialSeller) const SizedBox(height: 24),
            
            // Support section
            _buildSection(
              "Aide",
              [
                _buildMenuItem(
                  "Centre d'aide",
                  Icons.help_rounded,
                  AppColors.textPrimary,
                  () {
                    _showHelpCenter();
                  },
                ),
                _buildMenuItem(
                  "Contacter le support",
                  Icons.support_agent_rounded,
                  AppColors.primary,
                  () {
                    _showSupportContact();
                  },
                ),
                _buildMenuItem(
                  "Signaler un problème",
                  Icons.report_rounded,
                  AppColors.danger,
                  () {
                    _showReportIssue();
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Legal section
            _buildSection(
              "Informations légales",
              [
                _buildMenuItem(
                  "Conditions générales",
                  Icons.description_rounded,
                  AppColors.textPrimary,
                  () {
                    _showTermsOfService();
                  },
                ),
                _buildMenuItem(
                  "Politique de confidentialité",
                  Icons.privacy_tip_rounded,
                  AppColors.textPrimary,
                  () {
                    _showPrivacyPolicy();
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Logout button
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
                  ),
                ),
                child: const Text(
                  "Déconnexion",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // App version
            Center(
              child: Text(
                "${AppStrings.appName} v${_appVersion.isEmpty ? '1.0.0+1' : _appVersion}",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    final u = _user;
    final name = _dataService.profileDisplayName(u);
    final phone = u?['phone_e164']?.toString() ?? '—';
    final verified = _isOfficialSeller;
    String kycLabel = 'Compte particulier';
    Color kycColor = PremiumTheme.textMuted;
    if (verified) {
      kycLabel = 'Boutique officielle certifiée';
      kycColor = PremiumTheme.gold;
    } else if (_kyc != null) {
      final st = _kyc!['status']?.toString() ?? '';
      kycLabel = 'Demande KYC : $st';
      kycColor = st == 'pending' ? PremiumTheme.gold : (st == 'rejected' ? AppColors.danger : PremiumTheme.blue);
    }

    return Container(
      padding: const EdgeInsets.all(18),
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
          Row(
            children: [
              UserAvatar(
                imageUrl: _dataService.profileAvatarUrl,
                name: name,
                radius: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: PremiumTheme.display.copyWith(fontSize: 18)),
                    Text(phone, style: PremiumTheme.body.copyWith(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              if (verified)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: PremiumTheme.gold.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_rounded, color: PremiumTheme.gold, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(kycLabel, style: TextStyle(color: kycColor, fontWeight: FontWeight.w700, fontSize: 11)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final ok = await Navigator.pushNamed(context, AppRoutes.editProfile);
                    if (ok == true) _load();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                  child: const Text('Modifier profil'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    if (_isOfficialSeller) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BusinessHubScreen()),
                      );
                    } else {
                      await Navigator.pushNamed(context, AppRoutes.officialSeller);
                    }
                    _load();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumTheme.gold,
                    foregroundColor: PremiumTheme.navy,
                  ),
                  child: Text(_isOfficialSeller ? 'Espace Pro' : 'Vendeur pro'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _settingsHeader(BuildContext context) {
    return Container(
      decoration: PremiumTheme.heroGradient,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Paramètres', style: PremiumTheme.display.copyWith(fontSize: 22)),
                    Text('Compte, paiements, sécurité', style: PremiumTheme.body.copyWith(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.tune_rounded, color: PremiumTheme.gold, size: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: PremiumTheme.h1.copyWith(fontSize: 16),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: PremiumTheme.radiusMd,
            border: Border.all(color: const Color(0xFFE8ECF4)),
            boxShadow: PremiumTheme.softShadow,
          ),
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textSecondary,
        size: 20,
      ),
      onTap: onTap,
    );
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer mon compte'),
        content: const Text(
          'Cette action est définitive. Vos annonces actives seront retirées et vos données personnelles anonymisées.\n\n'
          'Les commandes en cours doivent être finalisées avant la suppression.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _dataService.deleteAccount();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, AppRoutes.welcome);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Compte supprimé')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Impossible de supprimer le compte. Vérifiez qu\'aucune commande n\'est en cours.',
                      ),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Déconnexion"),
        content: const Text("Êtes-vous sûr de vouloir vous déconnecter?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _dataService.clearAllData();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.welcome);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text("Se déconnecter"),
          ),
        ],
      ),
    );
  }

  void _showNotificationSettings() {
    bool pushNotifications = true;
    bool newMessages = true;
    bool listingUpdates = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Paramètres de notification"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text("Notifications push"),
                subtitle: const Text("Recevoir des alertes importantes"),
                value: pushNotifications,
                onChanged: (value) {
                  setState(() {
                    pushNotifications = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text("Nouveaux messages"),
                subtitle: const Text("Alertes pour les nouveaux messages"),
                value: newMessages,
                onChanged: (value) {
                  setState(() {
                    newMessages = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text("Mises à jour d'annonces"),
                subtitle: const Text("Changements sur vos annonces"),
                value: listingUpdates,
                onChanged: (value) {
                  setState(() {
                    listingUpdates = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Paramètres sauvegardés"),
                    backgroundColor: AppColors.secondary,
                  ),
                );
              },
              child: const Text("Sauvegarder"),
            ),
          ],
        ),
      ),
    );
  }

  void _showChatPreferences() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Préférences de chat"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("Son des messages"),
              trailing: const Icon(Icons.volume_up_rounded),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Son activé"),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
            ),
            ListTile(
              title: const Text("Vibrations"),
              trailing: const Icon(Icons.vibration_rounded),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Vibrations activées"),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
            ),
            ListTile(
              title: const Text("Messages lus automatiquement"),
              trailing: const Icon(Icons.mark_email_read_rounded),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Marquage automatique activé"),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }

  void _showPrivacySettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Paramètres de confidentialité"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("Profil privé"),
              subtitle: const Text("Seuls vos contacts peuvent voir votre profil"),
              trailing: const Icon(Icons.lock_rounded),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Profil privé activé"),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
            ),
            ListTile(
              title: const Text("Masquer statut en ligne"),
              subtitle: const Text("Personne ne voit quand vous êtes en ligne"),
              trailing: const Icon(Icons.visibility_off_rounded),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Statut masqué"),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
            ),
            ListTile(
              title: const Text("Contrôle des données"),
              subtitle: const Text("Gérer vos données personnelles"),
              trailing: const Icon(Icons.storage_rounded),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Accès au contrôle des données"),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }

  void _showBlockedUsers() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Utilisateurs bloqués'),
        content: SizedBox(
          height: 220,
          width: double.maxFinite,
          child: _blockedUsers.isEmpty
              ? const Center(child: Text('Aucun utilisateur bloqué'))
              : ListView.builder(
                  itemCount: _blockedUsers.length,
                  itemBuilder: (_, index) {
                    final user = _blockedUsers[index];
                    final uid = user['user_id']?.toString() ?? '';
                    return ListTile(
                      title: Text(user['name']?.toString() ?? 'Utilisateur'),
                      trailing: IconButton(
                        icon: const Icon(Icons.lock_open_rounded, color: AppColors.danger),
                        onPressed: () async {
                          if (uid.isEmpty) return;
                          await _dataService.unblockPeer(uid);
                          if (!ctx.mounted) return;
                          setState(() {
                            _blockedUsers.removeAt(index);
                          });
                          Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Utilisateur débloqué'),
                                backgroundColor: AppColors.secondary,
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

  void _showPaymentMethods() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Méthodes de paiement"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCB05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.phone_android, color: Colors.black),
              ),
              title: const Text("MTN Mobile Money"),
              subtitle: const Text("+243 812 345 678"),
              trailing: const Icon(Icons.check_circle, color: AppColors.secondary),
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6600),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.phone_android, color: Colors.white),
              ),
              title: const Text("Orange Money"),
              subtitle: const Text("+243 899 123 456"),
              trailing: const Icon(Icons.add_circle_outline),
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.phone_android, color: Colors.white),
              ),
              title: const Text("Moov Money"),
              subtitle: const Text("Non configuré"),
              trailing: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Ajouter une méthode de paiement"),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            child: const Text("Ajouter"),
          ),
        ],
      ),
    );
  }

  Future<void> _showTransactionHistory() async {
    List<Map<String, dynamic>> orders = [];
    try {
      orders = await _dataService.fetchMyOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger),
      );
      return;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mes commandes'),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: orders.isEmpty
              ? const Center(
                  child: Text('Aucune commande pour le moment', textAlign: TextAlign.center),
                )
              : ListView.separated(
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final o = orders[i];
                    final status = o['status']?.toString() ?? '';
                    final amount = o['amount_cdf'] ?? 0;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        status == 'paid' ? Icons.check_circle : Icons.receipt_long,
                        color: status == 'paid' ? PremiumTheme.emerald : PremiumTheme.blue,
                      ),
                      title: Text('Commande #${o['id']}'),
                      subtitle: Text('Statut: $status'),
                      trailing: Text('$amount CDF', style: const TextStyle(fontWeight: FontWeight.w700)),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Future<void> _openTeamChat() async {
    try {
      final contact = await _dataService.fetchSupportContact();
      if (!mounted) return;
      final peerId = contact['peer_id']?.toString();
      if (peerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support indisponible'), backgroundColor: AppColors.danger),
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            peerId: peerId,
            peerName: contact['display_name']?.toString() ?? 'Centre d\'aide SombaTeka',
            isTeamPeer: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _showHelpCenter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Centre d'aide"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_rounded, color: AppColors.primary),
              title: const Text('Centre d\'aide SombaTeka'),
              subtitle: const Text('Messages, décisions et assistance'),
              onTap: () {
                Navigator.pop(context);
                _openTeamChat();
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_rounded),
              title: const Text('Notifications'),
              subtitle: const Text('Alertes KYC, modération, avertissements'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }

  void _showSupportContact() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Contacter le support"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_rounded, color: AppColors.primary),
              title: const Text('Centre d\'aide SombaTeka'),
              subtitle: const Text('Discussion directe dans l\'app'),
              onTap: () {
                Navigator.pop(context);
                _openTeamChat();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }

  void _showReportIssue() {
    final TextEditingController _issueController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Signaler un problème"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Décrivez le problème que vous rencontrez:"),
            const SizedBox(height: 16),
            TextField(
              controller: _issueController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: "Description du problème...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: "Type de problème",
                border: OutlineInputBorder(),
              ),
              items: [
                'Bug technique',
                'Problème de paiement',
                'Compte utilisateur',
                'Autre',
              ].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Problème signalé avec succès"),
                  backgroundColor: AppColors.secondary,
                ),
              );
            },
            child: const Text("Envoyer"),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService() {
    LegalDocumentSheet.showTerms(context);
  }

  void _showPrivacyPolicy() {
    LegalDocumentSheet.showPrivacy(context);
  }
}
