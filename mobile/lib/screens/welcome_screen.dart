import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/data_service.dart';
import '../services/social_auth_service.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import '../widgets/auth_hero_background.dart';
import '../widgets/brand/auth_provider_icon.dart';
import '../widgets/brand/auth_provider_chip.dart';
import '../widgets/social_login_buttons.dart';
import '../widgets/sombateka_wordmark.dart';
import '../widgets/legal_document_sheet.dart';
import '../widgets/st_footer_credit.dart';
import '../widgets/st_safe_area.dart';
import '../utils/friendly_error.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _stagger;
  bool _cguAccepted = false;
  bool _socialBusy = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _stagger = AnimationController(vsync: this, duration: Duration.zero)..value = 1.0;
  }

  void _goMainGuest() {
    HapticFeedback.lightImpact();
    Navigator.pushReplacementNamed(context, AppRoutes.main);
  }

  void _goRegister() {
    if (!_requireCgu()) return;
    HapticFeedback.mediumImpact();
    Navigator.pushNamed(context, AppRoutes.auth, arguments: {'mode': 'register'});
  }

  void _goLogin() {
    if (!_requireCgu()) return;
    HapticFeedback.mediumImpact();
    Navigator.pushNamed(context, AppRoutes.auth, arguments: {'mode': 'login'});
  }

  bool _requireCgu() {
    if (_cguAccepted) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lisez et acceptez les CGU et la Politique de confidentialité avant de continuer'),
        backgroundColor: AppColors.primary,
      ),
    );
    return false;
  }

  void _quickEmail() {
    HapticFeedback.mediumImpact();
    Navigator.pushNamed(context, AppRoutes.auth, arguments: {'mode': 'login'});
  }

  void _onQuickProvider(AuthProviderKind kind) {
    if (!_requireCgu()) return;
    switch (kind) {
      case AuthProviderKind.email:
        _quickEmail();
      case AuthProviderKind.google:
        _quickSocial('google');
      case AuthProviderKind.apple:
        _quickSocial('apple');
    }
  }

  Future<void> _quickSocial(String provider) async {
    if (!_requireCgu()) return;
    if (_socialBusy) return;
    setState(() => _socialBusy = true);
    try {
      if (provider == 'google') {
        await SocialAuthService.instance.signInWithGoogle(context);
      } else {
        await SocialAuthService.instance.signInWithApple(context);
      }
      if (!mounted) return;
      final ds = DataService();
      await ds.refreshUser();
      await ds.refreshListings();
      if (!mounted) return;
      if (ds.needsAccountSetup()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connecté. Finalisez votre compte dans Paramètres (téléphone + mot de passe).'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 5),
          ),
        );
      }
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.main, (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, fallback: 'Connexion impossible. Réessayez.'))),
      );
    } finally {
      if (mounted) setState(() => _socialBusy = false);
    }
  }

  @override
  void dispose() {
    _stagger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = Responsive.isDesktopWeb(context);
    return Scaffold(
      body: AuthHeroBackground(
        child: StSafeTop(
          child: desktop ? _buildDesktopLayout(context) : _buildMobileLayout(context),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final compact = Responsive.isCompact(context);
    final quickOptions = authProvidersForPlatform(context);
    final hasSocial = authProvidersIncludeSocial(quickOptions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(24, compact ? 12 : 16, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: SombaTekaWordmark(
                    iconSize: compact ? 50 : 56,
                    fontSize: compact ? 26 : 30,
                    animate: false,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.tagline,
                  textAlign: TextAlign.center,
                  style: PremiumTheme.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: compact ? 13 : 14,
                  ),
                ),
                SizedBox(height: compact ? 16 : 22),
                _buildActionPanel(
                  context,
                  desktop: false,
                  compact: compact,
                  quickOptions: quickOptions,
                  hasSocial: hasSocial,
                ),
              ],
            ),
          ),
        ),
        const StFooterCredit(),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final quickOptions = authProvidersForPlatform(context);
    final hasSocial = authProvidersIncludeSocial(quickOptions);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: _buildGlassActionCard(
            context,
            quickOptions: quickOptions,
            hasSocial: hasSocial,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassActionCard(
    BuildContext context, {
    required List<AuthProviderKind> quickOptions,
    required bool hasSocial,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SombaTekaWordmark(iconSize: 56, fontSize: 28, animate: false),
              const SizedBox(height: 8),
              Text(
                AppStrings.tagline,
                textAlign: TextAlign.center,
                style: PremiumTheme.body.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              _buildActionPanel(
                context,
                desktop: true,
                compact: false,
                quickOptions: quickOptions,
                hasSocial: hasSocial,
              ),
              const SizedBox(height: 12),
              const StFooterCredit(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionPanel(
    BuildContext context, {
    required bool desktop,
    required bool compact,
    required List<AuthProviderKind> quickOptions,
    required bool hasSocial,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _staggerItem(0, _cguSection(desktop: desktop)),
        SizedBox(height: desktop ? 14 : 12),
        _staggerItem(1, _primaryBtn('Créer un compte', Icons.person_add_rounded, _goRegister, desktop: desktop)),
        SizedBox(height: desktop ? 14 : 10),
        _staggerItem(2, _outlineBtn('Se connecter', _goLogin, desktop: desktop)),
        SizedBox(height: desktop ? 10 : 6),
        _staggerItem(
          3,
          Center(
            child: TextButton(
              onPressed: _goMainGuest,
              child: Text(
                'Continuer sans compte',
                style: PremiumTheme.label.copyWith(
                  color: Colors.white.withValues(alpha: desktop ? 0.75 : 0.6),
                  fontSize: desktop ? 14 : 13,
                ),
              ),
            ),
          ),
        ),
        if (quickOptions.isNotEmpty) ...[
          SizedBox(height: desktop ? 16 : 10),
          _staggerItem(4, _quickConnectDivider(desktop: desktop)),
          SizedBox(height: desktop ? 14 : 10),
          _staggerItem(
            5,
            _socialBusy
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      ),
                    ),
                  )
                : AuthProviderChipRow(
                    providers: quickOptions,
                    desktop: desktop,
                    compact: compact,
                    enabled: !_socialBusy,
                    staggerController: _stagger,
                    onProviderTap: _onQuickProvider,
                  ),
          ),
        ],
        if (!desktop) const SizedBox(height: 12),
      ],
    );
  }

  Widget _staggerItem(int index, Widget child) => child;

  Widget _quickConnectDivider({bool desktop = false}) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.22))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'ou se connecter avec',
            style: TextStyle(
              fontSize: desktop ? 12 : 11,
              color: Colors.white.withValues(alpha: 0.58),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.22))),
      ],
    );
  }

  Widget _cguSection({bool desktop = false}) {
    return Container(
      padding: EdgeInsets.all(desktop ? 14 : 12),
      decoration: BoxDecoration(
        color: _cguAccepted
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _cguAccepted ? AppColors.secondary.withValues(alpha: 0.6) : Colors.white24,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Obligatoire pour créer un compte ou se connecter',
            style: TextStyle(
              fontSize: desktop ? 11 : 10,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          _cguCheckbox(desktop: desktop),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => LegalDocumentSheet.showTerms(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text('CGU complètes', style: TextStyle(fontSize: desktop ? 11 : 10, fontWeight: FontWeight.w700)),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => LegalDocumentSheet.showPrivacy(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text('Confidentialité', style: TextStyle(fontSize: desktop ? 11 : 10, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cguCheckbox({bool desktop = false}) {
    return GestureDetector(
      onTap: () => setState(() => _cguAccepted = !_cguAccepted),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: desktop ? 22 : 20,
            height: desktop ? 22 : 20,
            decoration: BoxDecoration(
              color: _cguAccepted ? AppColors.secondary : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _cguAccepted ? AppColors.secondary : Colors.white38, width: 1.5),
            ),
            child: _cguAccepted
                ? Icon(Icons.check_rounded, size: desktop ? 15 : 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "J'ai lu et j'accepte les CGU et la Politique de confidentialité",
              style: TextStyle(
                fontSize: desktop ? 12 : 11,
                color: Colors.white.withValues(alpha: 0.88),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryBtn(String label, IconData icon, VoidCallback onTap, {bool desktop = false}) {
    return SizedBox(
      width: double.infinity,
      height: desktop ? 58 : 54,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: desktop ? 23 : 21),
        label: Text(label, style: PremiumTheme.h1.copyWith(fontSize: desktop ? 17 : 16, color: PremiumTheme.navy)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: PremiumTheme.navy,
          elevation: desktop ? 12 : 8,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(desktop ? 18 : 16)),
        ),
      ),
    );
  }

  Widget _outlineBtn(String label, VoidCallback onTap, {bool desktop = false}) {
    return SizedBox(
      width: double.infinity,
      height: desktop ? 54 : 50,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: desktop ? 0.45 : 0.38)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(desktop ? 18 : 16)),
        ),
        child: Text(label, style: PremiumTheme.h1.copyWith(fontSize: desktop ? 16 : 15, color: Colors.white)),
      ),
    );
  }
}
