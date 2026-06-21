import 'package:flutter/material.dart';

import '../utils/listing_utils.dart';
import '../widgets/cart_added_sheet.dart';
import 'data_service.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }
}
