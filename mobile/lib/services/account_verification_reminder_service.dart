import 'package:shared_preferences/shared_preferences.dart';

/// Rappel « Compte non vérifié » dans les notifications, tous les 3 jours max.
class AccountVerificationReminderService {
  AccountVerificationReminderService._();

  static const localNotificationId = -9001;
  static const _lastDismissedKey = 'account_verify_notif_last_dismissed_ms';
  static const reminderInterval = Duration(days: 3);

  static bool isUserUnverified(Map<String, dynamic>? user) {
    if (user == null) return false;
    if (user['is_verified_seller'] == true) return false;
    if (user['account_verified'] == true || user['email_verified'] == true) return false;
    return true;
  }

  static Future<bool> isDue() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_lastDismissedKey);
    if (lastMs == null) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    return DateTime.now().difference(last) >= reminderInterval;
  }

  static Future<Map<String, dynamic>?> buildIfDue(Map<String, dynamic>? user) async {
    if (!isUserUnverified(user)) return null;
    if (!await isDue()) return null;
    return {
      'id': localNotificationId,
      'type': 'account_verification',
      'title': 'Compte non vérifié',
      'body':
          'Confirmez votre compte dans Paramètres pour inspirer confiance aux acheteurs. Badge visible sur votre profil et vos annonces.',
      'is_read': false,
      'is_local': true,
      'important': true,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static Future<void> markDismissedForCycle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastDismissedKey, DateTime.now().millisecondsSinceEpoch);
  }

  static void mergeIntoList(
    List<Map<String, dynamic>> items,
    Map<String, dynamic>? local,
  ) {
    items.removeWhere(
      (n) => n['type'] == 'account_verification' && n['is_local'] == true,
    );
    if (local != null) {
      items.insert(0, local);
    }
  }
}
