import 'package:flutter/material.dart';

import '../utils/listing_utils.dart';
import '../widgets/cart_added_sheet.dart';
import 'data_service.dart';
import 'marketplace_ui.dart';

/// Ajout au panier + alerte design app.
class CartUiHelper {
  CartUiHelper._();

  static final _data = DataService();

  static Future<void> addListing(
    BuildContext context,
    Map<String, dynamic> listing, {
    VoidCallback? onViewCart,
    String? variantSize,
    String? variantColor,
  }) async {
    try {
      final uid = _data.currentUser?['id']?.toString();
      if (isOwnListing(listing, uid)) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('C\'est votre annonce — gérez-la depuis votre profil'),
            backgroundColor: Color(0xFF059669),
          ),
        );
        return;
      }
      await _data.addListingToCart(
        listing,
        variantSize: variantSize,
        variantColor: variantColor,
      );
      if (!context.mounted) return;
      final count = _data.cartItems.length;
      await showCartAddedSheet(
        context,
        listing: listing,
        cartCount: count,
        onViewCart: onViewCart,
      );
    } catch (e) {
      if (!context.mounted) return;
      await MarketplaceUi.showActionError(context, e);
    }
  }

  /// Ajoute ou retire du panier (toggle) — état carte mis à jour avant l'API.
  static Future<void> toggleListing(
    BuildContext context,
    Map<String, dynamic> listing, {
    VoidCallback? onViewCart,
  }) async {
    final id = int.tryParse(listing['id']?.toString() ?? '');
    if (id == null) return;
    if (_data.isInCart(id)) {
      try {
        await _data.removeFromCart(id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Retiré du panier'),
            backgroundColor: Color(0xFF059669),
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        await MarketplaceUi.showActionError(context, e);
      }
      return;
    }
    await addListing(context, listing, onViewCart: onViewCart);
  }
}
