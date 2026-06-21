import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/premium_theme.dart';
import '../utils/listing_attributes.dart';
import 'publish_field_styles.dart';

/// Sélecteur de taille (vêtements ou chaussures).
class SizeSelectorField extends StatelessWidget {
  const SizeSelectorField({
    super.key,
    required this.category,
    required this.selectedSize,
    required this.onChanged,
  });

  final String category;
  final String? selectedSize;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final sizes = ListingAttributes.sizesForCategory(category);
    final label = ListingAttributes.sizeLabelForCategory(category);
    final isShoe = ListingAttributes.isShoeCategory(category);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: PublishFieldStyles.label),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: PremiumTheme.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Obligatoire', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: PremiumTheme.blue)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sizes.map((s) {
            final sel = selectedSize == s;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(s);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(horizontal: isShoe ? 14 : 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: sel
                      ? const LinearGradient(colors: [PremiumTheme.blue, PremiumTheme.blueGlow])
                      : null,
                  color: sel ? null : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel ? PremiumTheme.blue : const Color(0xFFE2E8F0), width: sel ? 2 : 1),
                  boxShadow: sel ? PremiumTheme.softShadow : null,
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: isShoe ? 13 : 12,
                    color: sel ? Colors.white : PremiumTheme.textDark,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
