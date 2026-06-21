import 'package:flutter/material.dart';

import '../theme/premium_theme.dart';
import '../utils/rdc_locations.dart';
import 'province_picker_sheet.dart';
import 'publish_field_styles.dart';

/// Sélecteur province → ville/commune → quartier (+ avenue/n°) — toute la RDC.
class LocationPickerFields extends StatelessWidget {
  const LocationPickerFields({
    super.key,
    required this.province,
    required this.commune,
    required this.quartier,
    required this.onProvinceChanged,
    required this.onCommuneChanged,
    required this.onQuartierChanged,
    this.avenueController,
    this.numeroController,
    this.compact = false,
  });

  final String? province;
  final String? commune;
  final String? quartier;
  final ValueChanged<String> onProvinceChanged;
  final ValueChanged<String> onCommuneChanged;
  final ValueChanged<String> onQuartierChanged;
  final TextEditingController? avenueController;
  final TextEditingController? numeroController;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final prov = province ?? RdcLocations.kinshasa;
    final cities = RdcLocations.citiesFor(prov);
    final quartiers = RdcLocations.quartiersFor(prov, commune);
    final cityLabel = RdcLocations.isKinshasa(prov) ? 'Commune' : 'Ville';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Localisation', style: PublishFieldStyles.label),
        if (!compact) ...[
          const SizedBox(height: 4),
          Text(
            '26 provinces RDC — choisissez province, $cityLabel et quartier',
            style: PublishFieldStyles.input.copyWith(fontSize: 12, color: PremiumTheme.textMuted),
          ),
        ],
        const SizedBox(height: 10),
        Text('Province *', style: PublishFieldStyles.label.copyWith(fontSize: 12)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showProvincePickerSheet(context, selected: prov);
            if (picked == null || picked.isEmpty) return;
            onProvinceChanged(picked);
            onCommuneChanged('');
            onQuartierChanged('');
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PremiumTheme.blue.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: PremiumTheme.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(prov, style: PublishFieldStyles.input.copyWith(fontWeight: FontWeight.w700)),
                ),
                Text(
                  'Changer',
                  style: PublishFieldStyles.input.copyWith(fontSize: 12, color: PremiumTheme.blue, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('$cityLabel *', style: PublishFieldStyles.label.copyWith(fontSize: 12)),
        const SizedBox(height: 6),
        SizedBox(
          height: compact ? 36 : 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cities.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final c = cities[i];
              final sel = commune == c;
              return FilterChip(
                label: Text(c, style: sel ? PublishFieldStyles.chipLabelSelected : PublishFieldStyles.chipLabel),
                selected: sel,
                onSelected: (_) {
                  onCommuneChanged(c);
                  onQuartierChanged('');
                },
                selectedColor: PremiumTheme.blue.withValues(alpha: 0.18),
                checkmarkColor: PremiumTheme.blue,
                backgroundColor: Colors.white,
                side: BorderSide(color: sel ? PremiumTheme.blue : const Color(0xFFCBD5E1)),
              );
            },
          ),
        ),
        if (commune != null && commune!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Quartier *', style: PublishFieldStyles.label.copyWith(fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: quartiers.map((q) {
              final sel = quartier == q;
              return FilterChip(
                label: Text(q, style: sel ? PublishFieldStyles.chipLabelSelected : PublishFieldStyles.chipLabel),
                selected: sel,
                onSelected: (_) => onQuartierChanged(q),
                selectedColor: PremiumTheme.blue.withValues(alpha: 0.18),
                checkmarkColor: PremiumTheme.blue,
                backgroundColor: Colors.white,
                side: BorderSide(color: sel ? PremiumTheme.blue : const Color(0xFFCBD5E1)),
              );
            }).toList(),
          ),
        ],
        if (avenueController != null || numeroController != null) ...[
          const SizedBox(height: 14),
          Text('Adresse précise (optionnel)', style: PublishFieldStyles.label.copyWith(fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            'Avenue et numéro — à préciser vous-même pour le rendez-vous',
            style: PublishFieldStyles.input.copyWith(fontSize: 11, color: PremiumTheme.textMuted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (avenueController != null)
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: avenueController,
                    style: PublishFieldStyles.input,
                    decoration: PublishFieldStyles.decoration('Avenue (ex: Av. Lumumba)'),
                  ),
                ),
              if (avenueController != null && numeroController != null) const SizedBox(width: 10),
              if (numeroController != null)
                Expanded(
                  child: TextField(
                    controller: numeroController,
                    style: PublishFieldStyles.input,
                    decoration: PublishFieldStyles.decoration('N°'),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
