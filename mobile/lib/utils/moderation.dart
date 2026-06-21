/// Mots interdits (alignés sur backend/app/constants.py) — pré-contrôle avant publication.
const List<String> bannedWordsPreview = [
  'arme',
  'armes',
  'fusil',
  'pistolet',
  'drogue',
  'cannabis',
  'arnaque',
  'escroc',
  'faux billet',
  'fausse monnaie',
  'contrefaçon',
  'organes',
];

String? findBannedTermInText(String text) {
  final lower = text.toLowerCase();
  for (final term in bannedWordsPreview) {
    if (lower.contains(term)) return term;
  }
  return null;
}

String? validateListingText({required String title, String? description}) {
  final hit = findBannedTermInText('$title ${description ?? ''}');
  if (hit != null) {
    return 'Contenu interdit détecté (« $hit »). Modifiez votre annonce.';
  }
  return null;
}
