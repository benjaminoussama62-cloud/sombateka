import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../utils/listing_utils.dart';
import 'app_confirm_dialog.dart';

/// Ligne panier : quantité uniquement pour vendeurs officiels.
class CartItemTile extends StatefulWidget {
  const CartItemTile({
    super.key,
    required this.item,
    required this.onQtyChanged,
    required this.onRemove,
    this.onTap,
  });

  final Map<String, dynamic> item;
  final Future<void> Function(int newQty) onQtyChanged;
  final Future<void> Function() onRemove;
  final VoidCallback? onTap;

  @override
  State<CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends State<CartItemTile> {
  late int _qty;
  bool _busy = false;

  bool get _showQty => widget.item['is_official'] == true || widget.item['is_catalog'] == true;

  int get _maxQty {
    final m = widget.item['max_quantity'] as int?;
    if (m != null && m > 0) return m;
    return 99;
  }

  @override
  void initState() {
    super.initState();
    _qty = widget.item['quantity'] as int? ?? 1;
  }

  @override
  void didUpdateWidget(CartItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final q = widget.item['quantity'] as int? ?? 1;
    if (!_busy && q != _qty) _qty = q;
  }

  Future<void> _setQty(int next) async {
    if (_busy || next == _qty) return;
    if (next < 1) {
      await _confirmRemove();
      return;
    }
    if (next > _maxQty) next = _maxQty;
    HapticFeedback.lightImpact();
    final prev = _qty;
    setState(() {
      _qty = next;
      _busy = true;
    });
    try {
      await widget.onQtyChanged(next);
    } catch (_) {
      if (mounted) setState(() => _qty = prev);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRemove() async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Retirer du panier ?',
      message: 'Cet article sera supprimé de votre panier.',
      confirmLabel: 'Supprimer',
      cancelLabel: 'Garder',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (ok == true) {
      HapticFeedback.mediumImpact();
      setState(() => _busy = true);
      try {
        await widget.onRemove();
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = widget.item['primary_image_url']?.toString() ?? '';
    final title = widget.item['title']?.toString() ?? 'Article';
    final priceCdf = widget.item['price_cdf'];
    final priceStr = priceCdf != null ? '${_formatCdf(priceCdf)} CDF' : '';
    final variantLabel = widget.item['variant_label']?.toString();

    return Material(
      color: Colors.white,
      borderRadius: PremiumTheme.radiusMd,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: PremiumTheme.radiusMd,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: PremiumTheme.radiusMd,
            border: Border.all(color: const Color(0xFFE8ECF4)),
            boxShadow: PremiumTheme.softShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: PremiumTheme.radiusMd,
                  child: img.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: normalizeListing({'primary_image_url': img})['imageUrl']?.toString() ?? img,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        )
                      : SizedBox(width: 80, height: 80, child: _imgPlaceholder()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      if (variantLabel != null && variantLabel.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(variantLabel, style: PremiumTheme.body.copyWith(fontSize: 12, color: PremiumTheme.textMuted)),
                      ],
                      const SizedBox(height: 4),
                      Text(priceStr, style: const TextStyle(color: PremiumTheme.blue, fontWeight: FontWeight.w900, fontSize: 15)),
                      if (_showQty) ...[
                        const SizedBox(height: 8),
                        _qtyStepper(),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : _confirmRemove,
                  icon: const Icon(Icons.close_rounded, color: PremiumTheme.textMuted, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _qtyStepper() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _qtyBtn(Icons.remove_rounded, _busy || _qty <= 1 ? null : () => _setQty(_qty - 1)),
          GestureDetector(
            onTap: _busy ? null : (_qty == 1 ? _confirmRemove : null),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Container(
                key: ValueKey(_qty),
                width: 44,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: PremiumTheme.blue))
                    : Text(
                        '$_qty',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: _qty == 1 ? AppColors.danger : PremiumTheme.textDark,
                        ),
                      ),
              ),
            ),
          ),
          _qtyBtn(Icons.add_rounded, _busy || _qty >= _maxQty ? null : () => _setQty(_qty + 1)),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: onTap == null ? PremiumTheme.textMuted.withValues(alpha: 0.35) : PremiumTheme.blue),
        ),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        color: const Color(0xFFF1F5F9),
        child: const Center(child: Icon(Icons.image_outlined, color: PremiumTheme.textMuted, size: 28)),
      );

  String _formatCdf(dynamic v) {
    final n = v is int ? v : int.tryParse(v.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }
}

