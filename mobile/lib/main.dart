import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config/sentry_config.dart';
import 'config/app_config.dart';
import 'services/push_notification_service.dart';
import 'services/safety_reminder_service.dart';
import 'screens/splash_screen.dart';
import 'screens/intro_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/publish_tab_router.dart';
import 'screens/publish_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/official_seller_screen.dart';
import 'screens/payment_settings_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/detail_screen.dart';
import 'screens/similar_products_screen.dart';
import 'screens/official_catalog_publish_screen.dart';
import 'screens/business_hub_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/public_profile_screen.dart';
import 'core/offline/offline_cache.dart';
import 'services/data_service.dart';
import 'theme/premium_theme.dart';
import 'utils/pwa.dart';
import 'utils/st_web_scroll_behavior.dart';
import 'utils/st_web_splash.dart';
import 'widgets/st_error_screen.dart';
import 'utils/responsive.dart';
import 'utils/constants.dart';
import 'utils/app_theme.dart';
import 'widgets/sombateka_wordmark.dart';
import 'components/custom_bottom_bar.dart';
import 'widgets/store_app_banner.dart';
import 'widgets/web_desktop_nav.dart';
import 'security/cyber_army_mobile.dart';

void main() {
  SentryConfig.launch(
    bootstrap: _bootstrap,
    app: const SombaTekaApp(),
  );
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Jamais d'écran vide/invisible en cas d'erreur de build — écran brandé + rechargement.
  StErrorScreen.install();
  // DevAlpha Cyber Army — mobile shield
  try {
    if (AppConfig.cyberHqUrl.isNotEmpty && AppConfig.cyberAgentKey.isNotEmpty) {
      final army = CyberArmyMobile(
        hqUrl: AppConfig.cyberHqUrl,
        agentKey: AppConfig.cyberAgentKey,
        appId: 'sombateka',
      );
      unawaited(army.init());
    }
  } catch (e, st) {
    debugPrint('cyber-army mobile init skipped: $e\n$st');
  }
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  try {
    await initializeDateFormatting('fr_FR', null)
        .timeout(const Duration(seconds: 3));
  } catch (_) {}
  // Cache offline avant 1er frame — stale-first home. Jamais bloquant :
  // timeout strict, sinon l'app démarre sans cache (dégradé, pas mort).
  try {
    await OfflineCache.init().timeout(const Duration(seconds: 3));
  } catch (e, st) {
    debugPrint('OfflineCache.init failed or timed out (app continues): $e\n$st');
  }
  // Polices en arrière-plan — ne jamais bloquer le 1er frame (Meta-like).
  unawaited(preloadPremiumFonts().catchError((_) {}));
  if (!kIsWeb) {
    unawaited(PushNotificationService.instance.init().catchError((e, st) {
      debugPrint('PushNotificationService.init failed (app continues): $e\n$st');
    }));
  }
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
}

class SombaTekaApp extends StatelessWidget {
  const SombaTekaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      scrollBehavior: kIsWeb ? const StWebScrollBehavior() : null,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        Widget content = child ?? const SizedBox.shrink();

        if (kIsWeb) {
          // Toujours navy sous Flutter web : évite le flash gris/bleu vide
          // pendant le chargement (splash HTML → intro), surtout desktop.
          content = ColoredBox(
            color: PremiumTheme.homeHeaderColor,
            child: content,
          );
        }

        final data = mq.copyWith(
          textScaler: mq.textScaler.clamp(
            minScaleFactor: 0.85,
            maxScaleFactor: 1.2,
          ),
        );

        return MediaQuery(data: data, child: content);
      },
      // Point d'entrée : toujours SplashScreen
      initialRoute: AppRoutes.splash,
      navigatorObservers: [StSplashHideObserver()],
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.splash:
            return _buildRoute(const SplashScreen(), settings);
          case AppRoutes.intro:
            return _buildSlideRoute(const IntroScreen(), settings);
          case AppRoutes.welcome:
            return _buildSlideRoute(const WelcomeScreen(), settings);
          case AppRoutes.auth:
            return _buildSlideRoute(const AuthScreen(), settings);
          case AppRoutes.otp:
            return _buildSlideRoute(const AuthScreen(), settings);
          case AppRoutes.main:
          case AppRoutes.home:
            return _buildFadeRoute(const MainScreen(), settings);
          case AppRoutes.search: {
            final args = settings.arguments;
            Uint8List? imageBytes;
            String? imageFilename;
            if (args is Map) {
              final raw = args['imageSearchBytes'];
              if (raw is Uint8List) imageBytes = raw;
              imageFilename = args['imageSearchFilename']?.toString();
            }
            return _buildRoute(
              SearchScreen(
                initialImageBytes: imageBytes,
                initialImageFilename: imageFilename,
              ),
              settings,
            );
          }
          case AppRoutes.favorites:
            return _buildRoute(const FavoritesScreen(), settings);
          case AppRoutes.editProfile:
            return _buildRoute(const EditProfileScreen(), settings);
          case AppRoutes.officialSeller:
            return _buildRoute(const OfficialSellerScreen(), settings);
          case AppRoutes.paymentSettings:
            if (!AppConfig.paymentsEnabled) {
              return _buildRoute(const SettingsScreen(), settings);
            }
            return _buildRoute(const PaymentSettingsScreen(), settings);
          case AppRoutes.privacy:
            return _buildRoute(const PrivacyScreen(), settings);
          case AppRoutes.publish:
            return _buildRoute(const PublishScreen(), settings);
          case AppRoutes.messages:
            return _buildRoute(const MessagesScreen(), settings);
          case AppRoutes.notifications:
            return _buildRoute(const NotificationsScreen(), settings);
          case AppRoutes.profile:
            return _buildRoute(const ProfileScreen(), settings);
          case AppRoutes.settings:
            return _buildRoute(const SettingsScreen(), settings);
          case AppRoutes.detail:
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return _buildRoute(DetailScreen(listing: args), settings);
          case AppRoutes.similarProducts:
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return _buildRoute(SimilarProductsScreen(listing: args), settings);
          case AppRoutes.officialCatalogPublish:
            return _buildRoute(const OfficialCatalogPublishScreen(), settings);
          case AppRoutes.businessHub:
            return _buildRoute(const BusinessHubScreen(), settings);
          case AppRoutes.payment:
            if (!AppConfig.paymentsEnabled) {
              return _buildRoute(const SettingsScreen(), settings);
            }
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return _buildRoute(PaymentScreen(listing: args), settings);
          case AppRoutes.publicProfile: {
            final args = settings.arguments;
            final userId = args is Map ? int.tryParse(args['userId']?.toString() ?? '') : null;
            if (userId == null) return _buildRoute(const MainScreen(), settings);
            final listing = args is Map ? args['listing'] as Map<String, dynamic>? : null;
            return _buildRoute(PublicProfileScreen(userId: userId, listingContext: listing), settings);
          }
          default:
            return _buildRoute(const SplashScreen(), settings);
        }
      },
    );
  }

  // Transition standard — instantanée
  PageRoute _buildRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (_, __, ___, child) => child,
    );
  }

  // Transition rapide (intro, auth, welcome…)
  PageRoute _buildSlideRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (_, animation, __, child) => child,
    );
  }

  // Transition fade (passage vers l'app principale)
  PageRoute _buildFadeRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 120),
      reverseTransitionDuration: const Duration(milliseconds: 100),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }
}

/// Masque le splash HTML dès qu'une vraie route est peinte — quelle qu'elle soit
/// (main, intro, auth en entree directe, deep-link). Le splash ne disparaît
/// jamais "avant" le contenu : +400 ms couvre la transition de route.
class StSplashHideObserver extends NavigatorObserver {
  bool _done = false;

  void _maybeHide(Route<dynamic>? route) {
    if (_done || !kIsWeb) return;
    if (route == null || route.settings.name == AppRoutes.splash) return;
    _done = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 400), stHideHtmlSplash);
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _maybeHide(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _maybeHide(newRoute);
}

// ─────────────────────────────────────────
// Écran principal avec bottom navigation
// ─────────────────────────────────────────

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentIndex = 0;
  int _unreadMessages = 0;
  final _data = DataService();
  final _favoritesKey = GlobalKey<FavoritesScreenState>();
  final _homeKey = GlobalKey<HomeScreenState>();
  final _profileKey = GlobalKey<ProfileScreenState>();
  final _publishKey = GlobalKey<PublishTabRouterState>();
  final _messagesKey = GlobalKey<MessagesScreenState>();
  final _businessHubKey = GlobalKey<BusinessHubScreenState>();
  late final List<Widget> _pages;

  bool get _showEspacePro => _data.isOfficialSeller;

  void _openCartTab() {
    setState(() => _currentIndex = 1);
    _pageController.jumpToPage(1);
    _favoritesKey.currentState?.showCartTab();
  }

  void _openBusinessHubTab() {
    setState(() => _currentIndex = 5);
    _pageController.jumpToPage(5);
    _businessHubKey.currentState?.reload();
  }

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(key: _homeKey, onOpenCart: _openCartTab),
      FavoritesScreen(key: _favoritesKey),
      PublishTabRouter(
        key: _publishKey,
        onPublished: _afterPublishSuccess,
        onGoHome: _goHomeTab,
        onOpenMessages: _openMessagesTab,
      ),
      MessagesScreen(key: _messagesKey),
      ProfileScreen(
        key: _profileKey,
        onOpenMessages: _openMessagesTab,
        onOpenBusinessHub: _openBusinessHubTab,
      ),
      BusinessHubScreen(
        key: _businessHubKey,
        embedded: true,
        onPublished: _afterPublishSuccess,
        onGoHome: _goHomeTab,
        onOpenMessages: _openMessagesTab,
      ),
    ];
    _pageController = PageController();
    // Masquer le splash HTML seulement quand la transition de route est finie
    // (~300ms) — sinon il disparaît au milieu du slide et le splash Flutter
    // transparaît dessous (flash bleu + logo en double).
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future<void>.delayed(const Duration(milliseconds: 400), stHideHtmlSplash);
      });
    }
    // Badges messages après 1er frame — ne pas concurrencer le feed home.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _refreshMessageBadge();
      });
      SafetyReminderService.maybeShow(context);
    });
    // Statut bar clair sur les pages internes
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  void _openMessagesTab() {
    _onTabTap(3);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goHomeTab() {
    setState(() => _currentIndex = 0);
    _pageController.jumpToPage(0);
  }

  void _afterPublishSuccess() {
    _goHomeTab();
    _homeKey.currentState?.reloadListings();
    _publishKey.currentState?.resetForm();
  }

  Future<void> _refreshMessageBadge() async {
    try {
      await _data.refreshConversations();
    } catch (_) {}
    if (mounted) setState(() => _unreadMessages = _data.unreadMessageCount);
  }

  void _onTabTap(int index) {
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
    if (index == 0) _homeKey.currentState?.reloadListings();
    if (index == 1) _favoritesKey.currentState?.showCartTab();
    if (index == 2) _publishKey.currentState?.refreshRole();
    if (index == 3) {
      _messagesKey.currentState?.reloadConversations();
      _refreshMessageBadge();
    }
    if (index == 4) _profileKey.currentState?.reloadProfile();
    if (index == 5) _businessHubKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final showStoreBanner = kIsWeb && storeBannerShouldShow();
    final desktopWeb = Responsive.isDesktopWeb(context);
    final showPro = _showEspacePro;

    final pageContent = Column(
      children: [
        if (showStoreBanner) const StoreAppBanner(),
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              if (index == 0) _homeKey.currentState?.refreshCartBadge();
              if (index == 3) _refreshMessageBadge();
              if (index == 4) _profileKey.currentState?.reloadProfile();
              if (index == 2) _publishKey.currentState?.refreshRole();
              if (index == 5) _businessHubKey.currentState?.reload();
            },
            children: _pages,
          ),
        ),
      ],
    );

    if (desktopWeb) {
      return Scaffold(
        backgroundColor: PremiumTheme.surface,
        resizeToAvoidBottomInset: true,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WebDesktopNav(
                  currentIndex: _currentIndex,
                  messageBadge: _unreadMessages,
                  onTap: _onTabTap,
                  showEspacePro: showPro,
                ),
                Expanded(child: pageContent),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: PremiumTheme.surface,
      resizeToAvoidBottomInset: true,
      body: pageContent,
      bottomNavigationBar: CustomBottomBar(
        currentIndex: _currentIndex,
        messageBadge: _unreadMessages,
        onTap: _onTabTap,
        showEspacePro: showPro,
      ),
    );
  }
}