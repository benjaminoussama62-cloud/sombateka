/// Action marketplace bloquée (connexion, finalisation, session expirée).
enum MarketplaceBlockReason { loginRequired, finalizeAccount, sessionExpired }

class MarketplaceBlockedException implements Exception {
  MarketplaceBlockedException(this.message, {required this.reason});

  final String message;
  final MarketplaceBlockReason reason;

  @override
  String toString() => message;
}
