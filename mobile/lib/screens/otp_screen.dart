import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../services/data_service.dart';
import '../services/social_auth_service.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../widgets/otp_pin_input.dart';
import '../widgets/social_login_buttons.dart';

class OTPScreen extends StatefulWidget {
  const OTPScreen({super.key});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> with SingleTickerProviderStateMixin {
  final _pinKey = GlobalKey<OtpPinInputState>();
  late AnimationController _slideCtrl;
  late Animation<double> _slideAnim;

  bool _isLoading = false;
  bool _isError = false;
  int _resendCountdown = 59;
  Timer? _timer;

  String _phoneE164 = '';
  String _email = '';
  String _channel = 'phone';
  String _userName = '';
  String? _devCode;
  bool _argsLoaded = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
    _slideAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic);
    _startResendTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args == null) return;
    _argsLoaded = true;
    _phoneE164 = DataService.normalizePhoneE164(
      args['phone_e164']?.toString() ?? args['phone']?.toString() ?? '',
    );
    _channel = args['channel']?.toString() ?? 'phone';
    _email = args['email']?.toString() ?? '';
    _userName = args['name']?.toString() ?? '';
    _devCode = args['dev_code']?.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_devCode != null && _devCode!.isNotEmpty) {
        _pinKey.currentState?.setCode(DataService.normalizeOtpCode(_devCode!));
      } else {
        _pinKey.currentState?.focus();
      }
    });
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendCountdown = 59);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  Future<void> _verify([String? codeOverride]) async {
    final code = DataService.normalizeOtpCode(
      codeOverride ?? _pinKey.currentState?.value ?? '',
    );
    if (code.length != 6 || _isLoading) return;
    if (_channel == 'phone' && _phoneE164.isEmpty) return;
    if (_channel == 'email' && _email.isEmpty) return;

    setState(() {
      _isLoading = true;
      _isError = false;
      _lastError = null;
    });

    try {
      final ds = DataService();
      if (_channel == 'email') {
        await ds.verifyEmailOtp(_email, code);
      } else {
        await ds.verifyOtp(_phoneE164, code);
      }
      if (_userName.isNotEmpty && ds.currentUser != null) {
        ds.currentUser!['display_name'] = _userName;
        ds.currentUser!['name'] = _userName;
      }
      await ds.refreshListings();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.main, (_) => false);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _isLoading = false;
        _isError = true;
        _lastError = e.toString().replaceFirst('Exception: ', '');
      });
      _pinKey.currentState?.clear();
      _pinKey.currentState?.focus();
    }
  }

  Future<void> _resend() async {
    if (_resendCountdown > 0) return;
    if (_channel == 'phone' && _phoneE164.isEmpty) return;
    if (_channel == 'email' && _email.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> r;
      if (_channel == 'email') {
        r = await DataService().sendEmailOtp(_email, displayName: _userName.isNotEmpty ? _userName : null);
      } else {
        r = await DataService().sendOtp(_phoneE164);
      }
      final code = r['dev_code']?.toString();
      if (code != null && code.isNotEmpty) {
        setState(() => _devCode = code);
        _pinKey.currentState?.setCode(DataService.normalizeOtpCode(code));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            code != null ? 'Nouveau code : ${DataService.normalizeOtpCode(code)}' : 'Code renvoyé',
          ),
          backgroundColor: AppColors.secondary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec envoi : $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _startResendTimer();
    }
  }

  Future<void> _socialLogin(String provider) async {
    setState(() => _isLoading = true);
    try {
      if (provider == 'google') {
        await SocialAuthService.instance.signInWithGoogle(context);
      } else {
        await SocialAuthService.instance.signInWithApple(context);
      }
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.main, (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connexion impossible : $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.navy,
      body: SafeArea(
        child: FadeTransition(
          opacity: _slideAnim,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
                .animate(_slideAnim),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      ),
                      const Expanded(
                        child: Text(
                          'Vérification',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.mark_email_read_rounded,
                            color: PremiumTheme.gold, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'Entrez votre code',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _channel == 'email'
                              ? 'Envoyé à\n$_email'
                              : 'Envoyé au\n$_phoneE164',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              if (_devCode != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFBBF7D0)),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Code de test (dev)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF166534),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        DataService.normalizeOtpCode(_devCode!),
                                        style: const TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 10,
                                          color: Color(0xFF15803D),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => _pinKey.currentState?.setCode(
                                          DataService.normalizeOtpCode(_devCode!),
                                        ),
                                        child: const Text('Insérer le code'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                              OtpPinInput(
                                key: _pinKey,
                                hasError: _isError,
                                onChanged: (_) {
                                  if (_isError) setState(() => _isError = false);
                                },
                                onCompleted: (code) => _verify(code),
                              ),
                              if (_isError) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _lastError ?? 'Code incorrect',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: FilledButton(
                                  onPressed: _isLoading ? null : () => _verify(),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : const Text(
                                          'Confirmer',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: _resendCountdown == 0 && !_isLoading ? _resend : null,
                                child: Text(
                                  _resendCountdown > 0
                                      ? 'Renvoyer dans ${_resendCountdown}s'
                                      : 'Renvoyer un code',
                                  style: TextStyle(
                                    color: _resendCountdown == 0
                                        ? AppColors.primary
                                        : Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (AppConfig.showSocialLogin) ...[
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'ou',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SocialLoginButtons(
                            loading: _isLoading,
                            compact: true,
                            onGoogle: () => _socialLogin('google'),
                            onApple: () => _socialLogin('apple'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
