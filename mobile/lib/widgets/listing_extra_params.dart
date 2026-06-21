import 'package:flutter/material.dart';

import '../theme/premium_theme.dart';
import '../utils/listing_attributes.dart';
import 'color_picker_field.dart';
import 'publish_field_styles.dart';
import 'size_selector_field.dart';

/// Paramètres annonce mode (taille, état, marque, couleur) — Publier + Recherche.
class ListingExtraParams extends StatelessWidget {
  const ListingExtraParams({
    super.key,
    required this.category,
    required this.selectedSize,
    required this.onSizeChanged,
    this.condition,
    this.onConditionChanged,
    this.brandController,
    this.selectedColor,
    this.onColorChanged,
    this.sizeRequired = true,
  });

  final String category;
  final String? selectedSize;
  final ValueChanged<String> onSizeChanged;
  final String? condition;
  final ValueChanged<String>? onConditionChanged;
  final TextEditingController? brandController;
  final String? selectedColor;
  final ValueChanged<String>? onColorChanged;
  final bool sizeRequired;

  @override
  Widget build(BuildContext context) {
    if (!ListingAttributes.categorySupportsExtraParams(category)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizeSelectorField(
          category: category,
          selectedSize: selectedSize,
          onChanged: onSizeChanged,
        ),
        const SizedBox(height: 18),
        Text('État', style: PublishFieldStyles.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ListingAttributes.conditions.map((c) {
            final sel = condition == c;
            return FilterChip(
              label: Text(c, style: sel ? PublishFieldStyles.chipLabelSelected : PublishFieldStyles.chipLabel),
              selected: sel,
              onSelected: onConditionChanged == null ? null : (_) => onConditionChanged!(c),
              selectedColor: PremiumTheme.blue.withValues(alpha: 0.18),
              checkmarkColor: PremiumTheme.blue,
              backgroundColor: Colors.white,
              side: BorderSide(color: sel ? PremiumTheme.blue : const Color(0xFFCBD5E1)),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (brandController != null) ...[
          Text('Marque (optionnel)', style: PublishFieldStyles.label),
          const SizedBox(height: 6),
          TextField(
            controller: brandController,
            style: PublishFieldStyles.input,
            decoration: PublishFieldStyles.decoration('Ex: Nike, Zara, Adidas…'),
          ),
          const SizedBox(height: 16),
        ],
        if (onColorChanged != null)
          ColorPickerField(
            selectedColor: selectedColor,
            onChanged: onColorChanged!,
          ),
        if (sizeRequired)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Taille obligatoire pour cette catégorie',
              style: PublishFieldStyles.input.copyWith(fontSize: 11, color: PremiumTheme.textMuted),
            ),
          ),
      ],
    );
  }
}
