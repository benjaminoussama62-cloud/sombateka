import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../content/legal_content.dart';
import '../theme/premium_theme.dart';
import '../widgets/legal_document_sheet.dart';
import 'app_services.dart';

/// Rappels prudence anti-escroquerie (style marketplaces type Kufar).
class SafetyReminderService {
  SafetyReminderService._();

  static const _lastShownKey = 'safety_reminder_last_shown_ms';
  static const reminderInterval = Duration(days: 3);

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_lastShownKey);
    if (lastMs == null) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    return DateTime.now().difference(last) >= reminderInterval;
  }

  static Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastShownKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> maybeShow(BuildContext context) async {
    if (!await AppServices.instance.auth.hasSession()) return;
    if (!await shouldShow()) return;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: PremiumTheme.radiusLg),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_outlined, color: Color(0xFFD97706)),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Restez prudents',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            LegalContent.safetyReminderBody,
            style: PremiumTheme.body.copyWith(fontSize: 13, height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              LegalDocumentSheet.showTerms(ctx);
            },
            child: const Text('Voir les CGU'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: PremiumTheme.blue),
            child: const Text('J\'ai compris'),
          ),
        ],
      ),
    );
    await markShown();
  }
}
