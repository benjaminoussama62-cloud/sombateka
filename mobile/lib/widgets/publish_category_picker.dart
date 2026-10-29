import 'package:flutter/material.dart';

import '../theme/premium_theme.dart';
import '../utils/listing_catalog.dart';
import 'publish_field_styles.dart';

/// Sélecteur catégorie par groupe (style marketplace).
class PublishCategoryPicker extends StatefulWidget {
  const PublishCategoryPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  State<PublishCategoryPicker> createState() => _PublishCategoryPickerState();
}

class _PublishCategoryPickerState extends State<PublishCategoryPicker> {
  late String _group;

  @override
  void initState() {
    super.initState();
    _group = ListingCatalog.groupFor(widget.selected) ?? ListingCatalog.groupNames().first;
  }

  @override
  void didUpdateWidget(covariant PublishCategoryPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _group = ListingCatalog.groupFor(widget.selected) ?? _group;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subs = ListingCatalog.groups[_group] ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Type d\'annonce', style: PublishFieldStyles.label),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ListingCatalog.groupNames().length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final g = ListingCatalog.groupNames()[i];
              final sel = g == _group;
              return FilterChip(
                avatar: Icon(
                  ListingCatalog.iconForGroup(g),
                  size: 16,
                  color: sel ? PremiumTheme.blue : PremiumTheme.textMuted,
                ),
                label: Text(g, style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.w800 : FontWeight.w600)),
                selected: sel,
                onSelected: (_) => setState(() => _group = g),
                selectedColor: PremiumTheme.blue.withValues(alpha: 0.14),
                checkmarkColor: PremiumTheme.blue,
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Text('Catégorie', style: PublishFieldStyles.label),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 160),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subs.map((c) {
                final sel = widget.selected == c;
                return FilterChip(
                  label: Text(c, style: sel ? PublishFieldStyles.chipLabelSelected : PublishFieldStyles.chipLabel),
                  selected: sel,
                  onSelected: (_) => widget.onSelected(c),
                  selectedColor: PremiumTheme.blue.withValues(alpha: 0.15),
                  checkmarkColor: PremiumTheme.blue,
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
