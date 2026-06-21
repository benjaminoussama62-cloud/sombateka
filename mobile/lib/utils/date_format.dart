import 'package:intl/intl.dart';

String formatMessageTime(dynamic value) {
  DateTime dt;
  if (value is DateTime) {
    dt = value.toLocal();
  } else if (value == null) {
    return '';
  } else {
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return '';
    dt = parsed.toLocal();
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);

  if (day == today) {
    return DateFormat('HH:mm').format(dt);
  }
  if (day == today.subtract(const Duration(days: 1))) {
    return 'Hier ${DateFormat('HH:mm').format(dt)}';
  }
  if (now.difference(dt).inDays < 7) {
    return DateFormat('EEE HH:mm', 'fr_FR').format(dt);
  }
  return DateFormat('dd/MM/yyyy HH:mm').format(dt);
}

/// Séparateur de jour dans le fil de chat (style WhatsApp).
String formatChatDaySeparator(DateTime value) {
  final dt = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);

  if (day == today) return "Aujourd'hui";
  if (day == today.subtract(const Duration(days: 1))) return 'Hier';
  if (now.difference(dt).inDays < 7) {
    return DateFormat('EEEE d MMMM', 'fr_FR').format(dt);
  }
  return DateFormat('d MMMM yyyy', 'fr_FR').format(dt);
}

/// Heure sous la bulle (HH:mm).
String formatChatBubbleTime(DateTime value) {
  return DateFormat('HH:mm').format(value.toLocal());
}
