import '../core/api/api_client.dart';
import '../core/api/token_storage.dart';
import '../repositories/auth_repository.dart';
import '../repositories/categories_repository.dart';
import '../repositories/favorites_repository.dart';
import '../repositories/kyc_repository.dart';
import '../repositories/listings_repository.dart';
import '../repositories/messages_repository.dart';
import '../repositories/notifications_repository.dart';
import '../repositories/orders_repository.dart';
import '../repositories/cart_repository.dart';
import '../repositories/users_repository.dart';
import '../repositories/reviews_repository.dart';
import '../repositories/support_repository.dart';

/// Point d'accès unique aux services API (production).
class AppServices {
  AppServices._();
  static final AppServices instance = AppServices._();

  final TokenStorage tokens = TokenStorage();
  late final ApiClient api = ApiClient(tokens);
  late final AuthRepository auth = AuthRepository(api, tokens);
  late final CategoriesRepository categories = CategoriesRepository(api);
  late final ListingsRepository listings = ListingsRepository(api);
  late final MessagesRepository messages = MessagesRepository(api);
  late final OrdersRepository orders = OrdersRepository(api);
  late final KycRepository kyc = KycRepository(api);
  late final FavoritesRepository favorites = FavoritesRepository(api);
  late final CartRepository cart = CartRepository(api);
  late final UsersRepository users = UsersRepository(api);
  late final ReviewsRepository reviews = ReviewsRepository(api);
  late final NotificationsRepository notifications = NotificationsRepository(api);
  late final SupportRepository support = SupportRepository(api);

  Set<int> favoriteIds = {};
  List<Map<String, dynamic>> cartItems = [];

  Map<String, dynamic>? currentUser;

  Future<void> refreshUser() async {
    if (await tokens.isLoggedIn()) {
      currentUser = await auth.fetchMe();
    }
  }
}
