import 'dart:async';

import 'package:flutter/material.dart';
import '../config/app_config.dart';
import 'package:flutter/services.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../utils/api_errors.dart';
import '../utils/responsive.dart';
import '../services/data_service.dart';
import '../services/social_auth_service.dart';
import '../widgets/auth_hero_background.dart';
import '../widgets/sombateka_wordmark.dart';
import '../widgets/social_login_buttons.dart';
import '../widgets/brand/auth_provider_icon.dart';
import '../widgets/st_icon.dart';
import '../widgets/st_safe_area.dart';
import '../widgets/legal_document_sheet.dart';
import '../security/screen_shield.dart';
import '../utils/friendly_error.dart';

enum AuthMode { register, login, resetPassword }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with TickerProviderStateMixin {
  late AnimationController _sheetController;
  late Animation<double> _sheetSlide;
  late Animation<double> _sheetOpacity;

  AuthMode _mode = AuthMode.login;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailCodeController = TextEditingController();
  final String _selectedCode = '+243';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _sendingEmailCode = false;
  bool _resetCodeSent = false;

  // CGU
  bool _cguAccepted = false;
  bool _submitting = false;

  // Indicateur de validité du formulaire
  bool get _isFormValid {
    final emailOk = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(_emailController.text.trim());
    if (_mode == AuthMode.resetPassword) {
      final codeOk = _emailCodeController.text.trim().length >= 4;
      final passOk = _passwordController.text.length >= 8;
      final confirmOk = _passwordController.text == _confirmPasswordController.text;
      return emailOk && _resetCodeSent && codeOk && passOk && confirmOk;
    }
    if (_mode == AuthMode.login) {
      final passOk = _passwordController.text.isNotEmpty;
      return emailOk && passOk && _cguAccepted;
    }
    final passOk = _passwordController.text.length >= 8;
    final phoneOk = _phoneController.text.trim().length >= 9;
    final confirmOk = _passwordController.text == _confirmPasswordController.text;
    return emailOk &&
        passOk &&
        confirmOk &&
        phoneOk &&
        _nameController.text.trim().isNotEmpty &&
        _cguAccepted;
  }

  @override
  void initState() {
    super.initState();
    // Interdit captures / enregistrement sur login · register · reset
    unawaited(CyberScreenShield.enable());

    _sheetController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    )..value = 1.0;
    _sheetSlide = Tween<double>(begin: 0, end: 0).animate(_sheetController);
    _sheetOpacity = Tween<double>(begin: 1, end: 1).animate(_sheetController);

    _nameController.addListener(() => setState(() {}));
    _emailController.addListener(() => setState(() {}));
    _phoneController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
    _emailCodeController.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null && args['mode'] == 'register') {
      setState(() => _mode = AuthMode.register);
    } else if (args != null && args['mode'] == 'login') {
      setState(() => _mode = AuthMode.login);
    }
  }

  @override
  void dispose() {
    unawaited(CyberScreenShield.disable());
    _sheetController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_isFormValid || _submitting) return;
    HapticFeedback.lightImpact();
    setState(() => _submitting = true);
    try {
      final email = _emailController.text.trim();
      final data = DataService();
      if (_mode == AuthMode.login) {
        await data.loginWithPassword(
          email: email,
          password: _passwordController.text,
        );
        if (!mounted) return;
        await data.refreshListings();
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.main, (_) => false);
      } else if (_mode == AuthMode.resetPassword) {
        await data.resetPasswordWithCode(
          email: email,
          code: _emailCodeController.text.trim(),
          newPassword: _passwordController.text,
        );
        if (!mounted) return;
        await data.refreshListings();
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.main, (_) => false);
      } else {
        final phone = DataService.normalizePhoneE164('$_selectedCode${_phoneController.text.trim()}');
        await data.registerAccount(
          email: email,
          password: _passwordController.text,
          phoneE164: phone,
          displayName: _nameController.text.trim(),
        );
        if (!mounted) return;
        await data.refreshListings();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compte créé. Confirmez-le dans Paramètres → Vérifier mon compte.'),
            backgroundColor: AppColors.secondary,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.main, (_) => false);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = friendlyError(e, fallback: 'Inscription ou connexion impossible');
      if (_mode == AuthMode.login && msg.contains('Créez un compte')) {
        _goRegister();
      } else if (_mode == AuthMode.login && msg.contains('Google ou Apple')) {
        // Rester sur l'écran connexion — message déjà affiché.
      } else if (_mode == AuthMode.register && msg.contains('Connectez-vous')) {
        _goLogin();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.isNotEmpty ? msg : 'Erreur de connexion'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _sendResetPasswordCode() async {
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrez votre adresse e-mail')),
      );
      return;
    }
    setState(() => _sendingEmailCode = true);
    try {
      await DataService().requestPasswordReset(email);
      if (!mounted) return;
      setState(() => _resetCodeSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code de réinitialisation envoyé par e-mail.'),
          backgroundColor: AppColors.secondary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyApiError(e, fallback: 'Envoi impossible')),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingEmailCode = false);
    }
  }

  void _startForgotPassword() {
    setState(() {
      _mode = AuthMode.resetPassword;
      _resetCodeSent = false;
      _emailCodeController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  void _backToLogin() {
    setState(() {
      _mode = AuthMode.login;
      _resetCodeSent = false;
      _emailCodeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = _mode == AuthMode.register;
    final compact = Responsive.isCompact(context);
    final viewH = MediaQuery.sizeOf(context).height;
    final heroH = (viewH * (compact ? 0.36 : 0.40)).clamp(220.0, compact ? 280.0 : 320.0);
    final topInset = MediaQuery.viewPaddingOf(context).top;

    if (Responsive.isDesktopWeb(context)) {
      return Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: Row(
          children: [
            Expanded(
              child: _buildTopSection(isRegister, compact, shrink: false, fullHeight: true),
            ),
            Expanded(
              child: _buildAuthFormPanel(topInset: 0, showBack: true),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: PremiumTheme.navy,
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: PremiumTheme.heroGradient,
        child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: double.infinity),
            child: Column(
              children: [
                SizedBox(
                  height: heroH,
                  child: _buildTopSection(isRegister, compact, shrink: compact || viewH < 700),
                ),
                Expanded(child: _buildAuthFormPanel(topInset: 0, showBack: false)),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildAuthFormPanel({required double topInset, required bool showBack}) {
    return AnimatedBuilder(
      animation: _sheetController,
      builder: (_, child) => Opacity(
        opacity: _sheetOpacity.value,
        child: Transform.translate(
          offset: Offset(0, _sheetSlide.value),
          child: child,
        ),
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: showBack
              ? BorderRadius.zero
              : const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: showBack
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: showBack
              ? BorderRadius.zero
              : const BorderRadius.vertical(top: Radius.circular(28)),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: StBottomInset.padding(context, left: 24, top: 24, right: 24, bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showBack)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                if (_mode == AuthMode.login) ...[
                  Text(
                    'Compte existant requis — email + mot de passe',
                    style: PremiumTheme.h1.copyWith(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  _buildCGUSection(),
                  const SizedBox(height: 20),
                  if (AppConfig.showSocialLogin) ...[
                    SocialLoginButtons(
                      onGoogle: _cguAccepted && AppConfig.showGoogleLogin
                          ? () => _socialSignIn('google')
                          : null,
                      onApple: _cguAccepted && AppConfig.showAppleLogin
                          ? () => _socialSignIn('apple')
                          : null,
                      showApple: AppConfig.showAppleLogin,
                      layout: Responsive.isDesktopWeb(context)
                          ? SocialLoginLayout.row
                          : SocialLoginLayout.column,
                    ),
                    const SizedBox(height: 20),
                    _buildDivider(label: 'ou par e-mail'),
                    const SizedBox(height: 20),
                  ],
                  _buildLoginForm(),
                ] else if (_mode == AuthMode.resetPassword) ...[
                  Text(
                    'Mot de passe oublié',
                    style: PremiumTheme.h1.copyWith(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Un code de réinitialisation sera envoyé à votre e-mail.',
                    textAlign: TextAlign.center,
                    style: PremiumTheme.body.copyWith(fontSize: 13, color: Colors.grey[600], height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  _buildResetPasswordForm(),
                ] else ...[
                  Text(
                    'Informations du compte',
                    style: PremiumTheme.h1.copyWith(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  _buildCGUSection(),
                  const SizedBox(height: 20),
                  _buildRegisterForm(),
                ],
                const SizedBox(height: 20),
                _buildSubmitButton(),
                const SizedBox(height: 16),
                _buildSwitchModeLink(),
                if (_mode == AuthMode.resetPassword) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _backToLogin,
                      child: const Text(
                        'Retour à la connexion',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                  ),
                ] else if (_mode == AuthMode.login) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.main,
                        (_) => false,
                      ),
                      child: Text(
                        'Continuer sans compte',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection(bool isRegister, bool compact, {bool shrink = false, bool fullHeight = false}) {
    final content = Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 4 : 8, 16, compact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: fullHeight ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          if (!fullHeight)
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const StIcon(
                    icon: Icons.arrow_back_rounded,
                    webGlyph: '←',
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          if (!fullHeight) SizedBox(height: compact ? 6 : 10),
          SombaTekaWordmark(
            iconSize: fullHeight ? 72 : (shrink ? 40 : (compact ? 44 : 52)),
            fontSize: fullHeight ? 36 : (shrink ? 22 : (compact ? 24 : 28)),
            animate: false,
          ),
          SizedBox(height: compact ? 6 : (fullHeight ? 20 : 10)),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _mode == AuthMode.register
                  ? 'Créer un compte'
                  : _mode == AuthMode.resetPassword
                      ? 'Mot de passe oublié'
                      : 'Se connecter',
              key: ValueKey('title-$_mode'),
              textAlign: TextAlign.center,
              style: PremiumTheme.display.copyWith(fontSize: fullHeight ? 32 : (shrink ? 20 : (compact ? 22 : 26))),
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _mode == AuthMode.register
                  ? 'E-mail valide, téléphone RDC et mot de passe — vérifiez le compte ensuite dans Paramètres.'
                  : _mode == AuthMode.resetPassword
                      ? 'Réinitialisez votre accès avec le code reçu par e-mail.'
                      : 'Connectez-vous avec le compte que vous avez déjà créé.',
              key: ValueKey('sub-$_mode'),
              textAlign: TextAlign.center,
              style: PremiumTheme.body.copyWith(
                color: Colors.white60,
                fontSize: fullHeight ? 16 : (compact ? 13 : 14),
                height: 1.45,
              ),
            ),
          ),
          SizedBox(height: compact ? 6 : (fullHeight ? 16 : 10)),
          _buildTrustPills(compact),
        ],
      ),
    );

    return AuthHeroBackground(
      child: Container(
        width: double.infinity,
        height: fullHeight ? double.infinity : null,
        child: Stack(
          children: [
            if (fullHeight) Center(child: content) else content,
          ],
        ),
      ),
    );
  }

  void _goLogin() {
    Navigator.pushReplacementNamed(context, AppRoutes.auth, arguments: {'mode': 'login'});
  }

  void _goRegister() {
    Navigator.pushReplacementNamed(context, AppRoutes.auth, arguments: {'mode': 'register'});
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        _InputField(
          controller: _emailController,
          label: 'Adresse email',
          hint: 'votre.email@gmail.com',
          icon: Icons.email_rounded,
          webGlyph: '✉️',
          keyboardType: TextInputType.emailAddress,
          brandIcon: AuthProviderKind.email,
        ),
        const SizedBox(height: 14),
        _InputField(
          controller: _passwordController,
          label: 'Mot de passe',
          hint: 'Votre mot de passe',
          icon: Icons.lock_rounded,
          webGlyph: '🔒',
          obscureText: _obscurePassword,
          suffix: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _startForgotPassword,
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text(
              'Mot de passe oublié ?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResetPasswordForm() {
    return Column(
      children: [
        _InputField(
          controller: _emailController,
          label: 'Adresse email',
          hint: 'votre.email@gmail.com',
          icon: Icons.email_rounded,
          webGlyph: '✉️',
          keyboardType: TextInputType.emailAddress,
          brandIcon: AuthProviderKind.email,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _sendingEmailCode ? null : _sendResetPasswordCode,
          icon: _sendingEmailCode
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.mail_outline_rounded, size: 18),
          label: Text(_resetCodeSent ? 'Renvoyer le code' : 'Recevoir le code par e-mail'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 46),
            foregroundColor: AppColors.primary,
          ),
        ),
        const SizedBox(height: 14),
        _InputField(
          controller: _emailCodeController,
          label: 'Code reçu par e-mail',
          hint: '6 chiffres',
          icon: Icons.pin_rounded,
          webGlyph: '🔢',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 14),
        _InputField(
          controller: _passwordController,
          label: 'Nouveau mot de passe',
          hint: '8 caractères minimum',
          icon: Icons.lock_rounded,
          webGlyph: '🔒',
          obscureText: _obscurePassword,
          suffix: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 14),
        _InputField(
          controller: _confirmPasswordController,
          label: 'Confirmer le mot de passe',
          hint: 'Retapez le mot de passe',
          icon: Icons.lock_rounded,
          webGlyph: '🔒',
          obscureText: _obscureConfirm,
          suffix: IconButton(
            icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      children: [
        _InputField(
          controller: _nameController,
          label: 'Nom complet',
          hint: 'Jean Mukendi',
          icon: Icons.person_rounded,
          webGlyph: '👤',
        ),
        const SizedBox(height: 14),
        _InputField(
          controller: _emailController,
          label: 'Adresse e-mail',
          hint: 'votre.email@gmail.com',
          icon: Icons.email_rounded,
          webGlyph: '✉️',
          keyboardType: TextInputType.emailAddress,
          brandIcon: AuthProviderKind.email,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Text(
            'Adresse e-mail personnelle (Gmail, Outlook…). Un seul compte par e-mail.',
            style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.35),
          ),
        ),
        const SizedBox(height: 14),
        _buildPhoneField(),
        const SizedBox(height: 14),
        _InputField(
          controller: _passwordController,
          label: 'Mot de passe',
          hint: '8 caractères minimum',
          icon: Icons.lock_rounded,
          webGlyph: '🔒',
          obscureText: _obscurePassword,
          suffix: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 14),
        _InputField(
          controller: _confirmPasswordController,
          label: 'Confirmer le mot de passe',
          hint: 'Retapez le mot de passe',
          icon: Icons.lock_outline_rounded,
          webGlyph: '🔒',
          obscureText: _obscureConfirm,
          suffix: IconButton(
            icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
      ],
    );
  }

  Widget _buildTrustPills(bool compact) {
    final pills = _mode == AuthMode.login
        ? <Widget>[
            const Icon(Icons.lock_rounded, size: 14, color: Colors.white),
            const AuthProviderIcon(kind: AuthProviderKind.google, size: 14),
            const AuthProviderIcon(kind: AuthProviderKind.apple, size: 14, color: Colors.white),
          ]
        : <Widget>[
            const Icon(Icons.lock_rounded, size: 14, color: Colors.white),
            const Icon(Icons.phone_android_rounded, size: 14, color: Colors.white),
            const Icon(Icons.verified_rounded, size: 14, color: Colors.white),
          ];
    final labels = _mode == AuthMode.login
        ? ['Mot de passe', 'Google', 'Apple']
        : ['Mot de passe sécurisé', 'Téléphone unique', 'Compte vérifiable'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (var i = 0; i < pills.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _trustPill(pills[i], labels[i], compact: compact),
            ),
        ],
      ),
    );
  }

  Widget _trustPill(Widget icon, String label, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 6 : 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Text(
            label,
            style: PremiumTheme.label.copyWith(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> _socialSignIn(String provider) async {
    if (!_cguAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acceptez les conditions d\'utilisation')),
      );
      return;
    }
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
            content: Text('Compte connecté. Finalisez-le dans Paramètres (téléphone + mot de passe).'),
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
    }
  }

  void _switchAuthMode() {
    if (_mode == AuthMode.register) {
      _goLogin();
    } else {
      _goRegister();
    }
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NUMÉRO DE TÉLÉPHONE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
              ),
              child: Text(_selectedCode, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: '812 345 678',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Numéro mobile RDC (+243 8xx / 9xx). Un seul compte par numéro. Pas d\'e-mails jetables.',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildCGUSection() {
    return Container(
      decoration: BoxDecoration(
        color: _cguAccepted ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _cguAccepted ? const Color(0xFFBBF7D0) : const Color(0xFFFDBA74),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Text(
              _mode == AuthMode.login
                  ? 'Acceptation obligatoire avant de vous connecter'
                  : 'Acceptation obligatoire pour créer un compte',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _cguAccepted ? const Color(0xFF166534) : const Color(0xFF9A3412),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _cguAccepted = !_cguAccepted),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _cguAccepted ? AppColors.secondary : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _cguAccepted ? AppColors.secondary : const Color(0xFFD1D5DB),
                        width: 2,
                      ),
                    ),
                    child: _cguAccepted
                        ? const Text(
                            '✓',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.5),
                        children: [
                          const TextSpan(text: "J'ai lu et j'accepte les "),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () => LegalDocumentSheet.showTerms(context),
                              child: const Text(
                                "Conditions générales d'utilisation",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(text: ' et la '),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () => LegalDocumentSheet.showPrivacy(context),
                              child: const Text(
                                'Politique de confidentialité',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          TextSpan(text: ' de ${AppStrings.appName}.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => LegalDocumentSheet.showTerms(context),
                    icon: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('CGU complètes', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => LegalDocumentSheet.showPrivacy(context),
                    icon: const Icon(Icons.privacy_tip_outlined, size: 16),
                    label: const Text('Confidentialité', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final enabled = _isFormValid && !_submitting;
    return GestureDetector(
      onTap: enabled ? _submit : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: enabled
              ? const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : const Color(0xFFE5E7EB),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ]
              : null,
        ),
        child: Center(
          child: _submitting
              ? const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Text(
                  _mode == AuthMode.register
                      ? 'Créer mon compte →'
                      : _mode == AuthMode.resetPassword
                          ? 'Réinitialiser le mot de passe →'
                          : 'Se connecter →',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: enabled ? Colors.white : const Color(0xFF9CA3AF),
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDivider({String label = 'ou continuer avec'}) {
    return Row(
      children: [
        Expanded(
          child: Divider(color: Colors.grey[200]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
        Expanded(
          child: Divider(color: Colors.grey[200]),
        ),
      ],
    );
  }

  Widget _buildSwitchModeLink() {
    if (_mode == AuthMode.resetPassword) return const SizedBox.shrink();
    final isRegister = _mode == AuthMode.register;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isRegister ? 'Déjà un compte ? ' : 'Pas encore inscrit ? ',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        GestureDetector(
          onTap: _switchAuthMode,
          child: Text(
            isRegister ? 'Se connecter' : 'Créer un compte',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Sous-widgets réutilisables
// ─────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String webGlyph;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final AuthProviderKind? brandIcon;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.webGlyph,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.suffix,
    this.brandIcon,
  });

  @override
  Widget build(BuildContext context) {
    final prefix = brandIcon != null
        ? Padding(
            padding: const EdgeInsets.only(left: 12, right: 6),
            child: AuthProviderIcon(kind: brandIcon!, size: 22),
          )
        : Padding(
            padding: const EdgeInsets.only(left: 14, right: 8),
            child: StIcon(
              icon: icon,
              webGlyph: webGlyph,
              color: const Color(0xFF9CA3AF),
              size: 20,
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            suffixIcon: suffix,
            prefixIcon: prefix,
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}