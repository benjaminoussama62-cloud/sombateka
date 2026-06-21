import 'package:flutter/material.dart';

import '../theme/premium_theme.dart';
import '../utils/rdc_locations.dart';

/// Feuille de sélection d'une province (26 provinces RDC, recherche intégrée).
Future<String?> showProvincePickerSheet(
  BuildContext context, {
  String? selected,
  bool includeAllOption = false,
  String allOptionLabel = 'Toutes les provinces',
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ProvincePickerSheet(
      selected: selected,
      includeAllOption: includeAllOption,
      allOptionLabel: allOptionLabel,
    ),
  );
}

class _ProvincePickerSheet extends StatefulWidget {
  const _ProvincePickerSheet({
    required this.selected,
    required this.includeAllOption,
    required this.allOptionLabel,
  });

  final String? selected;
  final bool includeAllOption;
  final String allOptionLabel;

  @override
  State<_ProvincePickerSheet> createState() => _ProvincePickerSheetState();
}

class _ProvincePickerSheetState extends State<_ProvincePickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> get _items {
    final all = RdcLocations.allProvinces;
    if (_query.trim().isEmpty) return all;
    final q = _query.trim().toLowerCase();
    return all.where((p) => p.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Choisir une province',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: PremiumTheme.textDark),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Rechercher (ex: Katanga, Kivu…)',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(12, 0, 12, bottom + 12),
              children: [
                if (widget.includeAllOption && _query.trim().isEmpty)
                  _tile(
                    widget.allOptionLabel,
                    selected: widget.selected == null,
                    onTap: () => Navigator.pop(context, ''),
                  ),
                ..._items.map(
                  (p) => _tile(
                    p,
                    selected: widget.selected == p,
                    onTap: () => Navigator.pop(context, p),
                  ),
                ),
                if (_items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Aucune province trouvée', textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(String label, {required bool selected, required VoidCallback onTap}) {
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      tileColor: selected ? PremiumTheme.blue.withValues(alpha: 0.08) : null,
      leading: Icon(
        selected ? Icons.check_circle : Icons.location_on_outlined,
        color: selected ? PremiumTheme.blue : PremiumTheme.textMuted,
        size: 20,
      ),
      title: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
      onTap: onTap,
    );
  }
}
