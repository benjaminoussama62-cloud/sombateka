import 'package:flutter/material.dart';
import '../theme/premium_theme.dart';

Future<int?> showBuyerPickerSheet(
  BuildContext context, {
  required String listingTitle,
  required List<Map<String, dynamic>> buyers,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.person_search_rounded, size: 40, color: PremiumTheme.blue),
                    const SizedBox(height: 12),
                    const Text('Qui a acheté ?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                      listingTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (buyers.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Aucun acheteur dans la messagerie pour cette annonce.\nMarquez quand même comme vendu.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: buyers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final b = buyers[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: PremiumTheme.blue.withValues(alpha: 0.1),
                          child: Text(
                            (b['name']?.toString() ?? '?').substring(0, 1).toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w800, color: PremiumTheme.blue),
                          ),
                        ),
                        title: Text(b['name']?.toString() ?? 'Acheteur'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pop(ctx, b['user_id'] as int),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, -1),
                        child: const Text('Vendu sans acheteur'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
