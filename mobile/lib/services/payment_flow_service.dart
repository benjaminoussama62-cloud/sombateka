import 'dart:async';

import '../config/app_config.dart';
import '../repositories/orders_repository.dart';
import 'app_services.dart';

/// Résultat d'une initiation de paiement Mobile Money.
class PaymentCheckoutResult {
  PaymentCheckoutResult({
    required this.orderId,
    required this.status,
    required this.providerReference,
    this.ussdCode,
    this.checkoutUrl,
    this.externalId,
  });

  final int orderId;
  final String status;
  final String providerReference;
  final String? ussdCode;
  final String? checkoutUrl;
  final String? externalId;

  bool get isPaid =>
      status == 'sequestre' || status == 'succes' || status == 'paid';
}

/// Logique paiement : initiation, polling statut, code de remise.
class PaymentFlowService {
  PaymentFlowService._();
  static final PaymentFlowService instance = PaymentFlowService._();

  OrdersRepository get _orders => AppServices.instance.orders;

  /// Mappe la méthode UI vers le provider API (`mtn` | `orange`).
  static String providerFromMethod(String method) {
    final m = method.toLowerCase();
    if (m.contains('orange')) return 'orange';
    return 'mtn';
  }

  Future<PaymentCheckoutResult> initiate({
    required int listingId,
    required String provider,
    String? variantSize,
    String? variantColor,
    int quantity = 1,
    String paymentChannel = 'mobile_money',
  }) async {
    final order = await _orders.createOrder(
      listingId,
      variantSize: variantSize,
      variantColor: variantColor,
      quantity: quantity,
      paymentChannel: paymentChannel,
    );
    if (paymentChannel == 'in_store') {
      return PaymentCheckoutResult(
        orderId: order['id'] as int,
        status: 'en_attente',
        providerReference: '',
      );
    }
    final orderId = order['id'] as int;
    final pay = await _orders.payOrder(orderId, provider);
    return PaymentCheckoutResult(
      orderId: orderId,
      status: pay['status']?.toString() ?? 'en_attente',
      providerReference: pay['provider_reference']?.toString() ?? '',
      ussdCode: pay['ussd_code']?.toString(),
      checkoutUrl: pay['checkout_url']?.toString(),
      externalId: pay['external_id']?.toString(),
    );
  }

  /// Attend que la commande passe en séquestre/succès (prod) ou retourne immédiatement (sandbox).
  Future<PaymentCheckoutResult> waitForPayment({
    required PaymentCheckoutResult initial,
    Duration pollInterval = const Duration(seconds: 3),
    Duration timeout = const Duration(minutes: 5),
  }) async {
    if (initial.isPaid) return initial;
    if (!AppConfig.paymentPollingEnabled) {
      // Sandbox / debug : le backend auto-complète souvent le paiement.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      final order = await _orders.getOrder(initial.orderId);
      return PaymentCheckoutResult(
        orderId: initial.orderId,
        status: order['status']?.toString() ?? initial.status,
        providerReference: initial.providerReference,
        ussdCode: initial.ussdCode,
        checkoutUrl: initial.checkoutUrl,
        externalId: initial.externalId,
      );
    }

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(pollInterval);
      final order = await _orders.getOrder(initial.orderId);
      final status = order['status']?.toString() ?? '';
      if (status == 'sequestre' || status == 'succes' || status == 'paid') {
        return PaymentCheckoutResult(
          orderId: initial.orderId,
          status: status,
          providerReference: initial.providerReference,
          ussdCode: initial.ussdCode,
          checkoutUrl: initial.checkoutUrl,
          externalId: initial.externalId,
        );
      }
    }
    throw TimeoutException(
      'Délai dépassé. Vérifiez votre téléphone et réessayez.',
      timeout,
    );
  }

  Future<Map<String, dynamic>> fetchHandover(int orderId) =>
      _orders.getHandoverCode(orderId);

  Future<void> confirmReceipt(int orderId) => _orders.confirmReceipt(orderId);

  Future<void> openDispute(
    int orderId, {
    required String reason,
    String? details,
  }) =>
      _orders.openDispute(orderId, reason: reason, details: details);
}
