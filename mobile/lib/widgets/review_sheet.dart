import 'package:flutter/material.dart';
import '../theme/premium_theme.dart';

Future<Map<String, dynamic>?> showReviewSheet(
  BuildContext context, {
  required String listingTitle,
  String title = 'Votre avis',
  String? subtitle,
  String submitLabel = 'Envoyer mon avis',
}) {
  var rating = 5;
  final commentCtrl = TextEditingController();

  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSt) {
          final bottom = MediaQuery.paddingOf(ctx).bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(listingTitle, style: TextStyle(color: Colors.grey[600])),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      return IconButton(
                        onPressed: () => setSt(() => rating = star),
                        icon: Icon(
                          star <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                          color: const Color(0xFFFFB800),
                          size: 36,
                        ),
                      );
                    }),
                  ),
                  TextField(
                    controller: commentCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Commentaire (optionnel)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, {
                      'rating': rating,
                      'comment': commentCtrl.text.trim(),
                    }),
                    style: FilledButton.styleFrom(
                      backgroundColor: PremiumTheme.blue,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(submitLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(commentCtrl.dispose);
}
