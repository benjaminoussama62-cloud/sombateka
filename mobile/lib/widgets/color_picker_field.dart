import 'package:flutter/material.dart';

import '../utils/listing_attributes.dart';
import 'publish_field_styles.dart';

/// Sélecteur couleur visuel (pastilles) — plus clair que des chips texte.
class ColorPickerField extends StatelessWidget {
  const ColorPickerField({
    super.key,
    required this.selectedColor,
    required this.onChanged,
    this.label = 'Couleur',
    this.compact = false,
  });

  final String? selectedColor;
  final ValueChanged<String> onChanged;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: PublishFieldStyles.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: compact ? 8 : 10,
          runSpacing: compact ? 8 : 10,
          children: ListingAttributes.colorOptions.map((opt) {
            final name = opt.$1;
            final color = opt.$2;
            final sel = selectedColor == name;
            return InkWell(
              onTap: () => onChanged(name),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: compact ? 34 : 40,
                    height: compact ? 34 : 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sel ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                        width: sel ? 3 : 1.5,
                      ),
                      boxShadow: sel
                          ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 6, spreadRadius: 1)]
                          : null,
                    ),
                    child: sel
                        ? Icon(
                            Icons.check_rounded,
                            size: compact ? 18 : 20,
                            color: _checkIconColor(color),
                          )
                        : null,
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _checkIconColor(Color bg) {
    final lum = bg.computeLuminance();
    return lum > 0.55 ? const Color(0xFF0F172A) : Colors.white;
  }
}
