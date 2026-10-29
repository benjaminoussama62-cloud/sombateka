import 'package:flutter/material.dart';

import '../theme/premium_theme.dart';
import '../utils/listing_attributes.dart';
import 'color_picker_field.dart';
import 'publish_field_styles.dart';
import 'size_selector_field.dart';

/// Paramètres annonce selon catégorie (mode, véhicule, immobilier…).
class ListingExtraParams extends StatelessWidget {
  const ListingExtraParams({
    super.key,
    required this.category,
    this.selectedSize,
    this.onSizeChanged,
    this.condition,
    this.onConditionChanged,
    this.brandController,
    this.selectedColor,
    this.onColorChanged,
    this.sizeRequired = true,
    this.vehicleYear,
    this.onVehicleYearChanged,
    this.mileageController,
    this.modelController,
    this.fuel,
    this.onFuelChanged,
    this.surfaceController,
    this.rooms,
    this.onRoomsChanged,
    this.listingTypeAttr,
    this.onListingTypeChanged,
  });

  final String category;
  final String? selectedSize;
  final ValueChanged<String>? onSizeChanged;
  final String? condition;
  final ValueChanged<String>? onConditionChanged;
  final TextEditingController? brandController;
  final String? selectedColor;
  final ValueChanged<String>? onColorChanged;
  final bool sizeRequired;
  final String? vehicleYear;
  final ValueChanged<String>? onVehicleYearChanged;
  final TextEditingController? mileageController;
  final TextEditingController? modelController;
  final String? fuel;
  final ValueChanged<String>? onFuelChanged;
  final TextEditingController? surfaceController;
  final String? rooms;
  final ValueChanged<String>? onRoomsChanged;
  final String? listingTypeAttr;
  final ValueChanged<String>? onListingTypeChanged;

  @override
  Widget build(BuildContext context) {
    if (!ListingAttributes.categorySupportsExtraParams(category)) {
      return const SizedBox.shrink();
    }

    final isFashion = ListingAttributes.categoryNeedsSize(category);
    final isVehicle = ListingAttributes.isVehicleCategory(category);
    final isRealEstate = ListingAttributes.isRealEstateCategory(category) || ListingAttributes.isHotelCategory(category);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isFashion && onSizeChanged != null) ...[
          SizeSelectorField(
            category: category,
            selectedSize: selectedSize,
            onChanged: onSizeChanged!,
          ),
          const SizedBox(height: 18),
        ],
        if (isVehicle) ...[
          Text('Année', style: PublishFieldStyles.label),
          const SizedBox(height: 8),
          _chipRow(ListingAttributes.vehicleYears, vehicleYear, onVehicleYearChanged),
          const SizedBox(height: 14),
          Text('Carburant', style: PublishFieldStyles.label),
          const SizedBox(height: 8),
          _chipRow(ListingAttributes.fuelTypes, fuel, onFuelChanged),
          if (modelController != null) ...[
            const SizedBox(height: 14),
            Text('Modèle', style: PublishFieldStyles.label),
            const SizedBox(height: 6),
            TextField(
              controller: modelController,
              style: PublishFieldStyles.input,
              decoration: PublishFieldStyles.decoration('Ex: Corolla, RAV4, CBR…'),
            ),
          ],
          if (mileageController != null) ...[
            const SizedBox(height: 14),
            Text('Kilométrage (km)', style: PublishFieldStyles.label),
            const SizedBox(height: 6),
            TextField(
              controller: mileageController,
              keyboardType: TextInputType.number,
              style: PublishFieldStyles.input,
              decoration: PublishFieldStyles.decoration('Ex: 45000'),
            ),
          ],
          const SizedBox(height: 18),
        ],
        if (isRealEstate) ...[
          Text('Type d\'annonce', style: PublishFieldStyles.label),
          const SizedBox(height: 8),
          _chipRow(ListingAttributes.realEstateTypes, listingTypeAttr, onListingTypeChanged),
          if (surfaceController != null) ...[
            const SizedBox(height: 14),
            Text('Surface (m²)', style: PublishFieldStyles.label),
            const SizedBox(height: 6),
            TextField(
              controller: surfaceController,
              keyboardType: TextInputType.number,
              style: PublishFieldStyles.input,
              decoration: PublishFieldStyles.decoration('Ex: 120'),
            ),
          ],
          const SizedBox(height: 14),
          Text('Pièces / chambres', style: PublishFieldStyles.label),
          const SizedBox(height: 8),
          _chipRow(ListingAttributes.roomCounts, rooms, onRoomsChanged),
          const SizedBox(height: 18),
        ],
        if (onConditionChanged != null) ...[
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
                onSelected: (_) => onConditionChanged!(c),
                selectedColor: PremiumTheme.blue.withValues(alpha: 0.18),
                checkmarkColor: PremiumTheme.blue,
                backgroundColor: Colors.white,
                side: BorderSide(color: sel ? PremiumTheme.blue : const Color(0xFFCBD5E1)),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (brandController != null && (isFashion || isVehicle)) ...[
          Text('Marque (optionnel)', style: PublishFieldStyles.label),
          const SizedBox(height: 6),
          TextField(
            controller: brandController,
            style: PublishFieldStyles.input,
            decoration: PublishFieldStyles.decoration(
              isVehicle ? 'Ex: Toyota, Honda…' : 'Ex: Nike, Zara, Adidas…',
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (onColorChanged != null && isFashion)
          ColorPickerField(
            selectedColor: selectedColor,
            onChanged: onColorChanged!,
          ),
        if (sizeRequired && isFashion)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              ListingAttributes.isShoeCategory(category)
                  ? 'Pointure obligatoire pour les chaussures'
                  : 'Taille obligatoire pour cette catégorie',
              style: PublishFieldStyles.input.copyWith(fontSize: 11, color: PremiumTheme.textMuted),
            ),
          ),
      ],
    );
  }

  Widget _chipRow(List<String> options, String? selected, ValueChanged<String>? onChanged) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final sel = selected == o;
        return FilterChip(
          label: Text(o, style: sel ? PublishFieldStyles.chipLabelSelected : PublishFieldStyles.chipLabel),
          selected: sel,
          onSelected: onChanged == null ? null : (_) => onChanged(o),
          selectedColor: PremiumTheme.blue.withValues(alpha: 0.18),
          checkmarkColor: PremiumTheme.blue,
        );
      }).toList(),
    );
  }
}
