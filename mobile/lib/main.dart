import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config/sentry_config.dart';
import 'services/push_notification_service.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
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
import 'screens/settings_screen.dart';
import 'screens/payment_screen.dart';
import 'core/offline/offline_cache.dart';
import 'utils/constants.dart';
import 'utils/app_theme.dart';
import 'components/custom_bottom_bar.dart';

void main() {
  SentryConfig.launch(
    bootstrap: _bootstrap,
    app: const SombaTekaApp(),
  );
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  try {
    await initializeDateFormatting('fr_FR', null);
  } catch (_) {}
  try {
    await OfflineCache.init();
  } catch (e, st) {
    debugPrint('OfflineCache.init failed (app continues): $e\n$st');
  }
  try {
    await PushNotificationService.instance.init();
  } catch (e, st) {
    debugPrint('PushNotificationService.init failed (app continues): $e\n$st');
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
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.2,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      // Point d'entrée : toujours SplashScreen
      initialRoute: AppRoutes.splash,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.splash:
            return _buildRoute(const SplashScreen(), settings);
          case AppRoutes.welcome:
            return _buildSlideRoute(const WelcomeScreen(), settings);
          case AppRoutes.auth:
            return _buildSlideRoute(const AuthScreen(), settings);
          case AppRoutes.otp:
            return _buildSlideRoute(const OTPScreen(), settings);
          case AppRoutes.main:
          case AppRoutes.home:
            return _buildFadeRoute(const MainScreen(), settings);
          case AppRoutes.search:
            return _buildRoute(const SearchScreen(), settings);
          case AppRoutes.favorites:
            return _buildRoute(const FavoritesScreen(), settings);
          case AppRoutes.editProfile:
            return _buildRoute(const EditProfileScreen(), settings);
          case AppRoutes.officialSeller:
            return _buildRoute(const OfficialSellerScreen(), settings);
          case AppRoutes.paymentSettings:
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
          case AppRoutes.payment:
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return _buildRoute(PaymentScreen(listing: args), settings);
          default:
            return _buildRoute(const SplashScreen(), settings);
        }
      },
    );
  }

  // Transition standard (slide horizontal)
  PageRoute _buildRoute(Widget page, RouteSettings settings) {
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }

  // Transition slide vertical (pour les feuilles modal)
  PageRoute _buildSlideRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
    );
  }

  // Transition fade (pour le passage splash → app)
  PageRoute _buildFadeRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }
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
  final _favoritesKey = GlobalKey<FavoritesScreenState>();
  final _homeKey = GlobalKey<HomeScreenState>();
  final _profileKey = GlobalKey<ProfileScreenState>();
  final _publishKey = GlobalKey<PublishScreenState>();
  late final List<Widget> _pages;

  void _openCartTab() {
    setState(() => _currentIndex = 1);
    _pageController.jumpToPage(1);
    _favoritesKey.currentState?.showCartTab();
  }

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(key: _homeKey, onOpenCart: _openCartTab),
      FavoritesScreen(key: _favoritesKey),
      PublishScreen(
        key: _publishKey,
        onPublished: _afterPublishSuccess,
        onGoHome: _goHomeTab,
      ),
      const MessagesScreen(),
      ProfileScreen(key: _profileKey),
    ];
    _pageController = PageController();
    // Statut bar clair sur les pages internes
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
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

  void _onTabTap(int index) {
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
    if (index == 0) _homeKey.currentState?.reloadListings();
    if (index == 4) _profileKey.currentState?.reloadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
          if (index == 0) _homeKey.currentState?.refreshCartBadge();
          if (index == 4) _profileKey.currentState?.reloadProfile();
        },
        children: _pages,
      ),
      bottomNavigationBar: CustomBottomBar(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
      ),
    );
  }
}