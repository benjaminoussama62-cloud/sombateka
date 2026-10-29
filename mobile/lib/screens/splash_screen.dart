import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_services.dart';
import '../services/data_service.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../utils/deep_link_listing.dart';
import '../utils/st_web_splash.dart';
import '../widgets/auth_hero_background.dart';
import '../widgets/sombateka_wordmark.dart';
import '../widgets/st_footer_credit.dart';

/// Splash — même langage visuel que Intro / Auth ([AuthHeroBackground]).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _enter;
  late Animation<double> _fadeIn;
  late Animation<double> _rise;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))
      ..forward();
    _fadeIn = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    _rise = Tween<double>(begin: 10, end: 0).animate(
      CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    if (kIsWeb) {
      final listingId = currentWebListingId();
      // Prefetch deep-link pendant la résolution de route (gain ~1s).
      final detailFuture = listingId != null
          ? DataService().fetchListingDetail(listingId).catchError((_) => null)
          : null;
      final routeFuture = _resolveNextRouteFast();
      if (AppConstants.splashDurationWeb > Duration.zero) {
        await Future.delayed(AppConstants.splashDurationWeb);
      }
      if (!mounted) return;
      final route = await routeFuture.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => AppRoutes.main,
      );
      if (!mounted) return;
      await Navigator.pushReplacementNamed(context, route);
      if (!mounted) return;
      if (listingId != null &&
          detailFuture != null &&
          (route == AppRoutes.main || route == AppRoutes.home)) {
        final listing = await detailFuture;
        if (!mounted || listing == null) return;
        Navigator.of(context).pushNamed(AppRoutes.detail, arguments: listing);
        WidgetsBinding.instance.addPostFrameCallback((_) => stHideHtmlSplash());
      }
      return;
    }
    await Future.delayed(AppConstants.splashDurationMobile);
    await _navigateNext();
  }

  Future<String> _resolveNextRouteFast() async {
    try {
      if (await AppServices.instance.auth.hasSession()) {
        Future<void>(() async {
          try {
            await DataService().refreshUser();
          } catch (_) {}
        });
      }
    } catch (_) {}
    return AppRoutes.main;
  }

  Future<void> _navigateNext() async {
    if (!mounted) return;
    final route = await _resolveNextRouteFast();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Web : opaque dès frame 0 (le HTML splash couvre ; pas de fade-from-0 = flash bleu).
    final content = Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SombaTekaWordmark(
                  iconSize: 88,
                  fontSize: 38,
                  animate: false,
                ),
                const SizedBox(height: 14),
                Text(
                  AppStrings.tagline,
                  textAlign: TextAlign.center,
                  style: PremiumTheme.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: 132,
                  height: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: StFooterCredit(),
        ),
      ],
    );

    return Scaffold(
      body: AuthHeroBackground(
        child: kIsWeb
            ? content
            : FadeTransition(
                opacity: _fadeIn,
                child: AnimatedBuilder(
                  animation: _rise,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, _rise.value),
                    child: child,
                  ),
                  child: content,
                ),
              ),
      ),
    );
  }
}
