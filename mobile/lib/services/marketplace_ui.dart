import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../utils/api_errors.dart';
import '../utils/constants.dart';
import '../utils/marketplace_action.dart';
import '../widgets/finalize_account_sheet.dart';
import 'data_service.dart';

/// Messages utilisateur pour panier / favoris (jamais de DioException brute).
class MarketplaceUi {
  MarketplaceUi._();

  static Future<bool> ensureAccess(BuildContext context) async {
    try {
      await DataService().ensureMarketplaceAccess();
      return true;
    } catch (e) {
      await showActionError(context, e);
      return false;
    }
  }

  static Future<void> showActionError(BuildContext context, Object error) async {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (error is MarketplaceBlockedException) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 4),
          action: _actionFor(context, error.reason),
        ),
      );
      if (error.reason == MarketplaceBlockReason.finalizeAccount) {
        await showFinalizeAccountSheet(context);
      }
      return;
    }

    if (error is DioException && error.response?.statusCode == 401) {
      await DataService().handleSessionExpired();
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Session expirée. Connectez-vous pour continuer.'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Connexion',
            textColor: Colors.white,
            onPressed: () => Navigator.pushNamed(context, AppRoutes.welcome),
          ),
        ),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          friendlyApiError(error, fallback: 'Action impossible pour le moment. Réessayez.'),
        ),
        backgroundColor: const Color(0xFFDC2626),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static SnackBarAction? _actionFor(BuildContext context, MarketplaceBlockReason reason) {
    switch (reason) {
      case MarketplaceBlockReason.loginRequired:
      case MarketplaceBlockReason.sessionExpired:
        return SnackBarAction(
          label: 'Connexion',
          textColor: Colors.white,
          onPressed: () => Navigator.pushNamed(context, AppRoutes.welcome),
        );
      case MarketplaceBlockReason.finalizeAccount:
        return SnackBarAction(
          label: 'Finaliser',
          textColor: Colors.white,
          onPressed: () => showFinalizeAccountSheet(context),
        );
    }
  }
}
