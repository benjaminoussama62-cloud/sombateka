import 'package:flutter/material.dart';
import '../config/app_config.dart';
import 'package:flutter/services.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../services/data_service.dart';
import '../services/social_auth_service.dart';
import '../widgets/sombateka_wordmark.dart';
import '../widgets/social_login_buttons.dart';

enum AuthMode { register, login }
enum AuthMethod { phone, email, apple }

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

  AuthMode _mode = AuthMode.register;
  AuthMethod _method = AuthMethod.phone;

  // Contrôleurs champs
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;

  // CGU
  bool _cguAccepted = false;
  bool _cguExpanded = false;
  bool _submitting = false;

  // Indicateur de validité du formulaire
  bool get _isFormValid {
    if (_method == AuthMethod.phone) {
      final phoneOk = _phoneController.text.trim().length >= 9;
      if (_mode == AuthMode.register) {
        return phoneOk && _nameController.text.trim().isNotEmpty && _cguAccepted;
      }
      return phoneOk && _cguAccepted;
    }
    if (_method == AuthMethod.email) {
      final emailOk = _emailController.text.contains('@');
      final passOk = _passwordController.text.length >= 8;
      if (_mode == AuthMode.register) {
        return emailOk && passOk && _nameController.text.trim().isNotEmpty && _cguAccepted;
      }
      return emailOk && passOk && _cguAccepted;
    }
    // Apple
    return _cguAccepted;
  }

  // Indicateur sélecteur indicatif
  String _selectedFlag = '🇨🇩';
  String _selectedCode = '+243';

  @override
  void initState() {
    super.initState();

    _sheetController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _sheetSlide = Tween<double>(begin: 80, end: 0).animate(
      CurvedAnimation(parent: _sheetController, curve: Curves.easeOutCubic),
    );
    _sheetOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _sheetController, curve: Curves.easeOut),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _sheetController.forward();
    });

    _phoneController.addListener(() => setState(() {}));
    _nameController.addListener(() => setState(() {}));
    _emailController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null && args['mode'] == 'login') {
      setState(() => _mode = AuthMode.login);
    }
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_isFormValid || _submitting) return;
    HapticFeedback.lightImpact();
    setState(() => _submitting = true);
    try {
      if (_method == AuthMethod.phone) {
        final phone = DataService.normalizePhoneE164(
          '$_selectedCode${_phoneController.text.trim()}',
        );
        Map<String, dynamic> otpResult;
        try {
          otpResult = await DataService().sendOtp(phone);
        } catch (e) {
          if (!mounted) return;
          final msg = e.toString();
          final hint = msg.contains('connection error') ||
                  msg.contains('XMLHttpRequest') ||
                  msg.contains('connection errored') ||
                  msg.contains('CORS')
              ? ' Vérifiez que l’API tourne sur ${Uri.base.host}:8000'
              : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur envoi OTP.$hint'),
              duration: const Duration(seconds: 6),
              backgroundColor: AppColors.danger,
            ),
          );
          return;
        }
        if (!mounted) return;
        Navigator.pushNamed(context, AppRoutes.otp, arguments: {
          'phone': phone,
          'phone_e164': phone,
          'channel': 'phone',
          'name': _nameController.text.trim(),
          'mode': _mode.name,
          'dev_code': otpResult['dev_code']?.toString(),
        });
      } else if (_method == AuthMethod.email) {
        final email = _emailController.text.trim();
        Map<String, dynamic> otpResult;
        try {
          otpResult = await DataService().sendEmailOtp(
            email,
            displayName: _mode == AuthMode.register ? _nameController.text.trim() : null,
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur envoi email : ${e.toString().replaceFirst('Exception: ', '')}'),
              backgroundColor: AppColors.danger,
            ),
          );
          return;
        }
        if (!mounted) return;
        Navigator.pushNamed(context, AppRoutes.otp, arguments: {
          'channel': 'email',
          'email': email,
          'name': _nameController.text.trim(),
          'mode': _mode.name,
          'dev_code': otpResult['dev_code']?.toString(),
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisez l\'onglet Téléphone ou Google / Apple ci-dessous')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = _mode == AuthMode.register;

    return Scaffold(
      backgroundColor: PremiumTheme.navy,
      body: Column(
        children: [
          _buildTopSection(isRegister),
          Expanded(
            child: AnimatedBuilder(
              animation: _sheetController,
              builder: (_, child) => Opacity(
                opacity: _sheetOpacity.value,
                child: Transform.translate(
                  offset: Offset(0, _sheetSlide.value),
                  child: child,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMethodTabs(),
                        const SizedBox(height: 24),
                        _buildForm(),
                        _buildCGUSection(),
                        const SizedBox(height: 20),
                        _buildSubmitButton(),
                        if (AppConfig.showSocialLogin) ...[
                          const SizedBox(height: 20),
                          _buildDivider(),
                          const SizedBox(height: 16),
                          SocialLoginButtons(
                            onGoogle: _cguAccepted ? () => _socialSignIn('google') : null,
                            onApple: _cguAccepted ? () => _socialSignIn('apple') : null,
                          ),
                        ],
                        const SizedBox(height: 24),
                        _buildSwitchModeLink(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSection(bool isRegister) {
    return Container(
      decoration: PremiumTheme.heroGradient,
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PremiumTheme.blue.withValues(alpha: 0.15),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: SombaTekaWordmark(iconSize: 52, fontSize: 28, animate: false),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      isRegister ? '✨ Créer un compte' : '👋 Se connecter',
                      key: ValueKey(isRegister),
                      style: PremiumTheme.display.copyWith(fontSize: 26),
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      isRegister
                          ? 'Rejoignez ${AppStrings.appName}, la marketplace pensée pour la RDC.'
                          : 'Heureux de vous revoir sur ${AppStrings.appName}.',
                      key: ValueKey('sub-$isRegister'),
                      style: PremiumTheme.body.copyWith(color: Colors.white60, fontSize: 14, height: 1.45),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTrustPills(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustPills() {
    const pills = [
      (Icons.phone_android_rounded, 'OTP sécurisé'),
      (Icons.payments_rounded, 'Mobile Money'),
      (Icons.verified_rounded, 'Vendeurs certifiés'),
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pills.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final p = pills[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(p.$1, size: 16, color: PremiumTheme.gold),
                const SizedBox(width: 6),
                Text(
                  p.$2,
                  style: PremiumTheme.label.copyWith(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          );
        },
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
      await DataService().refreshListings();
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.main, (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connexion impossible : $e')),
      );
    }
  }

  void _switchAuthMode() {
    setState(() {
      _mode = _mode == AuthMode.register ? AuthMode.login : AuthMode.register;
    });
    _sheetController
      ..reset()
      ..forward();
  }

  Widget _buildMethodTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _MethodTab(
            label: 'Téléphone',
            icon: Icons.phone_rounded,
            selected: _method == AuthMethod.phone,
            onTap: () => setState(() => _method = AuthMethod.phone),
          ),
          _MethodTab(
            label: 'Email',
            icon: Icons.email_rounded,
            selected: _method == AuthMethod.email,
            onTap: () => setState(() => _method = AuthMethod.email),
          ),
          _MethodTab(
            label: 'Apple',
            icon: Icons.apple_rounded,
            selected: _method == AuthMethod.apple,
            onTap: () => setState(() => _method = AuthMethod.apple),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    if (_method == AuthMethod.apple) {
      return _buildAppleSection();
    }
    return Column(
      children: [
        if (_mode == AuthMode.register) ...[
          _InputField(
            controller: _nameController,
            label: 'Nom complet',
            hint: 'Jean Mukendi',
            icon: Icons.person_rounded,
          ),
          const SizedBox(height: 14),
        ],
        if (_method == AuthMethod.phone) _buildPhoneField(),
        if (_method == AuthMethod.email) ...[
          _InputField(
            controller: _emailController,
            label: 'Adresse email',
            hint: 'jean@example.com',
            icon: Icons.email_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _buildPasswordField(),
        ],
      ],
    );
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
            GestureDetector(
              onTap: _showCountryPicker,
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                ),
                child: Row(
                  children: [
                    Text(_selectedFlag, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 6),
                    Text(
                      _selectedCode,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: Color(0xFF6B7280)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: '812 345 678',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFFE5E7EB), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFFE5E7EB), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MOT DE PASSE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: !_passwordVisible,
          decoration: InputDecoration(
            hintText: 'Min. 8 caractères',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            prefixIcon: const Icon(Icons.lock_rounded,
                color: Color(0xFF9CA3AF), size: 20),
            suffixIcon: GestureDetector(
              onTap: () =>
                  setState(() => _passwordVisible = !_passwordVisible),
              child: Icon(
                _passwordVisible
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: const Color(0xFF9CA3AF),
                size: 20,
              ),
            ),
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

  Widget _buildAppleSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.apple_rounded,
                color: Colors.white, size: 44),
          ),
          const SizedBox(height: 16),
          const Text(
            'Connexion avec Apple',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Votre email Apple reste privé.\nVos données ne sont jamais partagées.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Text(
              '🔒 Disponible sur iPhone (iOS 13+)',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF16A34A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCGUSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        decoration: BoxDecoration(
          color: _cguAccepted
              ? const Color(0xFFF0FDF4)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _cguAccepted
                ? const Color(0xFFBBF7D0)
                : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            // Ligne principale checkbox
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
                        color: _cguAccepted
                            ? AppColors.secondary
                            : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _cguAccepted
                              ? AppColors.secondary
                              : const Color(0xFFD1D5DB),
                          width: 2,
                        ),
                      ),
                      child: _cguAccepted
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 14)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF374151),
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(text: "J'accepte les "),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _cguExpanded = !_cguExpanded),
                                child: const Text(
                                  "Conditions d'utilisation",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                            const TextSpan(text: ' et la '),
                            const TextSpan(
                              text: 'Politique de confidentialité',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(text: ' de ${AppStrings.appName}.'),
                          ],
                        ),
                      ),
                    ),
                    // Bouton expand
                    GestureDetector(
                      onTap: () =>
                          setState(() => _cguExpanded = !_cguExpanded),
                      child: Icon(
                        _cguExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Détails expandable
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildCGUDetails(),
              crossFadeState: _cguExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCGUDetails() {
    final items = [
      {'icon': '💰', 'text': 'Commission 5 % sur les ventes des vendeurs officiels'},
      {'icon': '⚖️', 'text': 'Litiges traités depuis l\'application en cas de problème'},
      {'icon': '📅', 'text': 'Reversement vendeur sous 24 h (T+1) après confirmation'},
      {'icon': '🔒', 'text': 'Transactions sécurisées via Mobile Money (MTN, Orange)'},
      {'icon': '🛡️', 'text': 'Données personnelles protégées et jamais revendues'},
      {'icon': '🚫', 'text': 'Max 5 annonces actives pour un compte particulier'},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['icon']!, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item['text']!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4B5563),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
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
                  _mode == AuthMode.register ? 'Créer mon compte →' : 'Se connecter →',
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

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(color: Colors.grey[200]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'ou continuer avec',
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

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Choisir l\'indicatif',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...AppStrings.flagPrefixes.map((p) => ListTile(
                  leading: Text(p['flag']!, style: const TextStyle(fontSize: 24)),
                  title: Text(p['country']!,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Text(
                    p['code']!,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedFlag = p['flag']!;
                      _selectedCode = p['code']!;
                    });
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Sous-widgets réutilisables
// ─────────────────────────────────────────

class _MethodTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _MethodTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? AppColors.primary : const Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppColors.primary
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
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
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
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

class _SocialAuthButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _SocialAuthButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}