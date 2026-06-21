import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/custom_top_bar.dart';
import '../utils/constants.dart';
import '../services/data_service.dart';
import '../services/payment_flow_service.dart';
import 'chat_screen.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> listing;

  const PaymentScreen({super.key, required this.listing});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  final DataService _dataService = DataService();
  
  String _selectedPaymentMethod = PaymentMethod.mtn;
  String _checkoutMode = 'mobile_money'; // mobile_money | in_store
  bool _inStoreReserved = false;
  bool _isProcessing = false;
  bool _paymentComplete = false;
  bool _awaitingPayment = false;
  int? _orderId;
  PaymentCheckoutResult? _checkout;
  String? _handoverCode;
  String? _pollStatusMessage;
  int _quantity = 1;
  bool _includeShipping = false;
  double _shippingCost = 5000;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  double get _subtotal {
    final price = double.tryParse(widget.listing['price'].toString().replaceAll(' FC', '').replaceAll(' ', '')) ?? 0;
    return price * _quantity;
  }

  double get _total {
    double total = _subtotal;
    if (_includeShipping) {
      total += _shippingCost;
    }
    return total;
  }

  double get _commission {
    return _subtotal * 0.05; // 5% commission
  }

  bool get _canPayInStore {
    final dm = widget.listing['delivery_method']?.toString() ?? '';
    return dm == 'pickup_store';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomTopBar(
        title: "Paiement sécurisé",
        showBackButton: true,
      ),
      body: _paymentComplete
          ? _buildSuccessView()
          : _inStoreReserved
              ? _buildInStoreSuccessView()
              : _awaitingPayment
              ? _buildAwaitingPaymentView()
              : _buildPaymentForm(),
      bottomNavigationBar: (_paymentComplete || _awaitingPayment || _inStoreReserved) ? null : _buildBottomButton(),
    );
  }

  Widget _buildPaymentForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.listing['delivery_method_label'] != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.listing['delivery_method_label'].toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Product summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.image_outlined,
                    size: 30,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.listing['title'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.listing['category'],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Quantity
          Row(
            children: [
              const Text(
                "Quantité",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _quantity > 1 ? () {
                        setState(() {
                          _quantity--;
                        });
                      } : null,
                      child: Container(
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.remove_rounded),
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 40,
                      child: Center(
                        child: Text(
                          _quantity.toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _quantity++;
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.add_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Shipping option
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_shipping_rounded, color: AppColors.primary),
                    const SizedBox(width: 12),
                    const Text(
                      "Livraison",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: _includeShipping,
                      onChanged: (value) {
                        setState(() {
                          _includeShipping = value;
                        });
                      },
                    ),
                  ],
                ),
                if (_includeShipping) ...[
                  const SizedBox(height: 12),
                  Text(
                    "Livraison à domicile: ${_shippingCost.toInt()} FC",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          if (_canPayInStore) ...[
            const Text(
              'Mode d\'achat',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _checkoutModeChip(
                    label: 'Mobile Money',
                    subtitle: 'Par défaut · séquestre',
                    value: 'mobile_money',
                    icon: Icons.phone_android_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _checkoutModeChip(
                    label: 'Sur place',
                    subtitle: 'Payer en boutique',
                    value: 'in_store',
                    icon: Icons.storefront_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          if (_checkoutMode == 'mobile_money') ...[
          // Payment method
          const Text(
            "Méthode de paiement",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          
          // Mobile Money options
          Column(
            children: [
              _buildPaymentOption(
                "MTN Mobile Money",
                PaymentMethod.mtn,
                const Color(0xFFFFCB05),
                Icons.phone_android_rounded,
              ),
              const SizedBox(height: 12),
              _buildPaymentOption(
                "Orange Money",
                PaymentMethod.orange,
                const Color(0xFFFF6600),
                Icons.phone_android_rounded,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          ],
          
          // Price breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Récapitulatif",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildPriceRow("Sous-total", "${_subtotal.toInt()} FC"),
                _buildPriceRow("Commission (5%)", "${_commission.toInt()} FC"),
                if (_includeShipping)
                  _buildPriceRow("Livraison", "${_shippingCost.toInt()} FC"),
                const Divider(),
                _buildPriceRow(
                  "Total",
                  "${_total.toInt()} FC",
                  isBold: true,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _checkoutModeChip({
    required String label,
    required String subtitle,
    required String value,
    required IconData icon,
  }) {
    final sel = _checkoutMode == value;
    return GestureDetector(
      onTap: () => setState(() => _checkoutMode = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary.withValues(alpha: 0.08) : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: sel ? AppColors.primary : AppColors.textSecondary, size: 22),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 13)),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption(String title, String value, Color color, IconData icon) {
    final isSelected = _selectedPaymentMethod == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? color : AppColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isBold ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isProcessing ? null : _processPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
            ),
          ),
          child: _isProcessing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  _checkoutMode == 'in_store'
                      ? 'Réserver et contacter le vendeur'
                      : 'Payer ${_total.toInt()} FC',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildInStoreSuccessView() {
    final sellerId = widget.listing['sellerId']?.toString() ?? widget.listing['seller_id']?.toString() ?? '';
    final listingId = widget.listing['id']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.storefront_rounded, size: 72, color: AppColors.secondary),
          const SizedBox(height: 16),
          const Text(
            'Réservation confirmée',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Rendez-vous en boutique pour payer sur place. Vous pouvez maintenant écrire au vendeur.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.9)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: sellerId.isEmpty
                  ? null
                  : () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            peerId: sellerId,
                            peerName: widget.listing['sellerName']?.toString() ?? 'Boutique',
                            listingId: listingId,
                            listingTitle: widget.listing['title']?.toString(),
                            listingImageUrl: widget.listing['imageUrl']?.toString(),
                            isOfficialPeer: true,
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.chat_rounded),
              label: const Text('Contacter le vendeur'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text('Retour à l\'accueil'),
          ),
        ],
      ),
    );
  }

  Widget _buildAwaitingPaymentView() {
    final checkout = _checkout;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.phone_iphone_rounded, size: 64, color: AppColors.primary),
          const SizedBox(height: 20),
          const Text(
            'Validez sur votre téléphone',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            _pollStatusMessage ?? 'En attente de confirmation Mobile Money…',
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
            textAlign: TextAlign.center,
          ),
          if (checkout?.ussdCode != null && checkout!.ussdCode!.isNotEmpty) ...[
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Text('Composez ou suivez', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SelectableText(
                    checkout.ussdCode!,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: checkout.ussdCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copié')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copier'),
                  ),
                ],
              ),
            ),
          ],
          if (checkout?.checkoutUrl != null && checkout!.checkoutUrl!.isNotEmpty) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(checkout.checkoutUrl!);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Ouvrir la page de paiement'),
            ),
          ],
          if (checkout?.providerReference.isNotEmpty == true) ...[
            const SizedBox(height: 20),
            Text(
              'Réf. ${checkout!.providerReference}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 32),
          if (_isProcessing)
            const CircularProgressIndicator()
          else
            TextButton(
              onPressed: () => setState(() {
                _awaitingPayment = false;
                _checkout = null;
              }),
              child: const Text('Annuler'),
            ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _progressAnimation,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 60,
                color: AppColors.secondary,
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            "Paiement sécurisé !",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Vos fonds sont en séquestre chez SombaTeka jusqu'à validation de l'article.",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Montant: ${_total.toInt()} FC",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          if (_handoverCode != null) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gold),
              ),
              child: Column(
                children: [
                  const Text(
                    'Code de remise',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _handoverCode!,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Présentez ce code au vendeur lors de la remise.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 40),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Text(
                  "Prochaines étapes",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "• Le chat s'est ouvert avec le vendeur\n"
                  "• Essayez l'article au rendez-vous\n"
                  "• Validez ci-dessous pour libérer le paiement",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          if (_orderId != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmReceipt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  "J'ai reçu l'article — valider",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.messages);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    "Messages",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    "Accueil",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReceipt() async {
    if (_orderId == null) return;
    try {
      await _dataService.confirmOrderReceipt(_orderId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci ! Le vendeur sera payé (moins commission).'),
          backgroundColor: AppColors.secondary,
        ),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _processPayment() async {
    final currentUser = _dataService.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vous devez être connecté pour effectuer un paiement"),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _pollStatusMessage = _checkoutMode == 'in_store'
          ? 'Réservation en cours…'
          : 'Connexion à Mobile Money…';
    });

    try {
      final listingId = int.parse(widget.listing['id']?.toString() ?? '0');
      final provider = PaymentFlowService.providerFromMethod(_selectedPaymentMethod);
      final initial = await PaymentFlowService.instance.initiate(
        listingId: listingId,
        provider: provider,
        variantSize: widget.listing['size']?.toString() ?? widget.listing['variant_size']?.toString(),
        variantColor: widget.listing['color']?.toString() ?? widget.listing['variant_color']?.toString(),
        quantity: int.tryParse(widget.listing['quantity']?.toString() ?? '') ?? 1,
        paymentChannel: _checkoutMode,
      );

      if (_checkoutMode == 'in_store') {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _inStoreReserved = true;
          _orderId = initial.orderId;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _checkout = initial;
        _orderId = initial.orderId;
        _awaitingPayment = true;
        _pollStatusMessage = initial.ussdCode != null
            ? 'Composez le code USSD sur votre téléphone, puis attendez la confirmation.'
            : 'Confirmation du paiement en cours…';
      });

      final paid = await PaymentFlowService.instance.waitForPayment(initial: initial);
      final handover = await PaymentFlowService.instance.fetchHandover(paid.orderId);

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _awaitingPayment = false;
        _paymentComplete = true;
        _orderId = paid.orderId;
        _handoverCode = handover['handover_code']?.toString();
      });
      _progressController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _awaitingPayment = false;
        _pollStatusMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Paiement échoué: $e"),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}
