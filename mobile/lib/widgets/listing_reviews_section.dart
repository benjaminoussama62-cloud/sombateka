import 'package:flutter/material.dart';

import '../theme/premium_theme.dart';
import '../utils/date_format.dart';
import 'review_sheet.dart';

/// Bloc avis style Wildberries : note publique, commentaires réservés aux acheteurs.
class ListingReviewsSection extends StatelessWidget {
  const ListingReviewsSection({
    super.key,
    required this.reviews,
    this.eligibility,
    required this.listingTitle,
    required this.listingId,
    required this.onSubmit,
  });

  final Map<String, dynamic> reviews;
  final Map<String, dynamic>? eligibility;
  final String listingTitle;
  final int listingId;
  final Future<void> Function(int rating, String? comment) onSubmit;

  double get _avg => (reviews['average_rating'] as num?)?.toDouble() ?? 0;
  int get _count => (reviews['review_count'] as num?)?.toInt() ?? 0;
  bool get _canRead => reviews['can_read_comments'] == true;
  bool get _canReviewSeller => eligibility?['can_review_seller'] == true;

  @override
  Widget build(BuildContext context) {
    final isOfficial = reviews['is_official'] == true;
    if (_count == 0 && !_canReviewSeller && !isOfficial) {
      return const SizedBox.shrink();
    }

    final items = (reviews['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final dist = Map<String, dynamic>.from(reviews['distribution'] as Map? ?? {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Avis clients', style: PremiumTheme.h1.copyWith(fontSize: 17)),
            const Spacer(),
            if (_count > 0)
              Text(
                '$_count avis',
                style: PremiumTheme.body.copyWith(fontSize: 13, color: PremiumTheme.textMuted),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: PremiumTheme.radiusMd,
            border: Border.all(color: const Color(0xFFE8ECF4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Text(
                        _count > 0 ? _avg.toStringAsFixed(1) : '—',
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, height: 1),
                      ),
                      const SizedBox(height: 4),
                      _stars(_count > 0 ? _avg.round().clamp(1, 5) : 0, size: 18),
                      if (_count > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '$_count évaluation${_count > 1 ? 's' : ''}',
                            style: PremiumTheme.body.copyWith(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(child: _distributionBars(dist, _count)),
                ],
              ),
              if (!_canRead && _count > 0) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reviews['comments_locked_message']?.toString() ??
                              'Les avis détaillés sont réservés aux clients ayant acheté ce produit.',
                          style: PremiumTheme.body.copyWith(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_canRead && items.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                ...items.take(8).map(_reviewTile),
              ],
              if (_canReviewSeller) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openReviewSheet(context),
                    icon: const Icon(Icons.rate_review_outlined, size: 18),
                    label: Text(
                      'Noter ${eligibility?['review_target_name'] ?? 'le vendeur'}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB800),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _distributionBars(Map<String, dynamic> dist, int total) {
    return Column(
      children: List.generate(5, (i) {
        final star = 5 - i;
        final n = (dist[star.toString()] as num?)?.toInt() ?? 0;
        final ratio = total > 0 ? n / total : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              SizedBox(
                width: 12,
                child: Text('$star', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFFB800)),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFEEF2F7),
                    color: const Color(0xFFFFB800),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 24,
                child: Text('$n', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _reviewTile(Map<String, dynamic> r) {
    final rating = (r['rating'] as num?)?.toInt() ?? 0;
    final name = r['reviewer_name']?.toString() ?? 'Acheteur';
    final comment = r['comment']?.toString().trim() ?? '';
    final created = r['created_at'];
    final dt = created is DateTime
        ? created
        : (created != null ? DateTime.tryParse(created.toString()) : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: PremiumTheme.blue.withValues(alpha: 0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: PremiumTheme.blue, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    if (dt != null)
                      Text(
                        formatChatDaySeparator(dt),
                        style: PremiumTheme.body.copyWith(fontSize: 11),
                      ),
                  ],
                ),
              ),
              _stars(rating, size: 14),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(comment, style: PremiumTheme.body.copyWith(fontSize: 14, height: 1.45)),
          ],
        ],
      ),
    );
  }

  Widget _stars(int rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: const Color(0xFFFFB800),
        );
      }),
    );
  }

  Future<void> _openReviewSheet(BuildContext context) async {
    final target = eligibility?['review_target_name']?.toString() ?? 'le vendeur';
    final result = await showReviewSheet(
      context,
      listingTitle: listingTitle,
      title: 'Votre avis',
      subtitle: 'Évaluez $target pour cette transaction',
    );
    if (result == null || !context.mounted) return;
    await onSubmit(result['rating'] as int, result['comment']?.toString());
  }
}
