import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../content/legal_content.dart';

/// Affiche les CGU ou la politique de confidentialité (texte + lien web store).
class LegalDocumentSheet extends StatelessWidget {
  const LegalDocumentSheet({
    super.key,
    required this.title,
    required this.body,
    this.webUrl,
  });

  final String title;
  final String body;
  final String? webUrl;

  static Future<void> showTerms(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => LegalDocumentSheet(
          title: LegalContent.termsTitle,
          body: LegalContent.termsBody,
          webUrl: AppConfig.termsUrl,
        ),
      );

  static Future<void> showPrivacy(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => LegalDocumentSheet(
          title: LegalContent.privacyTitle,
          body: LegalContent.privacyBody,
          webUrl: AppConfig.privacyUrl,
        ),
      );

  Future<void> _openWeb() async {
    final url = webUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            if (webUrl != null && webUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _openWeb,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text('Version en ligne : $webUrl'),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                child: Text(
                  body.trim(),
                  style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF374151)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
