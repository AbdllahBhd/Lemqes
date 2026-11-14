const _latin = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'æ': 'ae',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'œ': 'oe',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ɛ': 'e',
  'ɣ': 'g',
  'ḍ': 'd',
  'ḥ': 'h',
  'ṣ': 's',
  'ṭ': 't',
  'ẓ': 'z',
  'ǧ': 'g',
  'č': 'c',
};

/// Lower-cases and strips Latin diacritics, apostrophes and hyphens so
/// "Bou Saâda" matches "bou saada" and "M'Sila" matches "msila".
///
/// Arabic passes through unchanged: folding Arabic letters is a later
/// milestone, so Arabic search is an exact substring match.
String foldLatin(String input) {
  final b = StringBuffer();
  for (final ch in input.toLowerCase().split('')) {
    if (ch == "'" || ch == '’') continue;
    b.write(ch == '-' ? ' ' : _latin[ch] ?? ch);
  }
  return b.toString();
}

/// Whether [query] finds [nameFr], [nameAr] or [code].
bool matchesPlace(
  String query, {
  required String nameFr,
  required String nameAr,
  String? code,
}) {
  final q = query.trim();
  if (q.isEmpty) return true;
  if (nameAr.contains(q)) return true;
  final folded = foldLatin(q);
  return foldLatin(nameFr).contains(folded) ||
      (code != null && code.startsWith(folded));
}
