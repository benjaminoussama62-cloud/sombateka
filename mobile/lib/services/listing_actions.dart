import 'package:flutter/material.dart';

import '../utils/app_feedback.dart';
import '../widgets/buyer_picker_sheet.dart';
import 'data_service.dart';

/// Marque une annonce vendue + sélection acheteur + message avis.
Future<void> markListingAsSoldFlow(
  BuildContext context,
  DataService data, {
  required int listingId,
  required String listingTitle,
}) async {
  final buyers = await data.fetchListingInquirers(listingId);
  if (!context.mounted) return;

  final buyerId = await showBuyerPickerSheet(
    context,
    listingTitle: listingTitle,
    buyers: buyers,
  );
  if (buyerId == null || !context.mounted) return;

  final actualBuyer = buyerId < 0 ? null : buyerId;
  await data.markListingSold(listingId, buyerId: actualBuyer);

  if (!context.mounted) return;
  if (actualBuyer != null) {
    showAppSuccess(
      context,
      'Vendu ! Un message a été envoyé à l\'acheteur pour laisser un avis.',
    );
  } else {
    showAppSuccess(context, 'Annonce marquée comme vendue.');
  }
}
