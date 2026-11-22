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

// Dart port of public.f_search_fold / public.f_name_skeleton (supabase/migrations/
// 20261122000200_search_fold.sql). supabase/tests/fold_vectors.json is the one table both are
// tested against, so a change to either side starts there.

const _arabicFrom = 'أإآٱةىؤئکی٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹';
const _arabicTo = 'ااااهيويكي01234567890123456789';

// Letters of the sound skeleton: each Arabic letter as the Algerian-French reading of it.
const _skeletonFrom = 'اءبتثجحخدذرزسشصضطظعغفقكلمنهويپ';
const _skeletonTo = 'aabttjhxddrzscsdtzagfkklmnhuib';

final _marks = RegExp('[ً-ٰٟـ]');
final _punct = RegExp(
  '[!-/:-@[-`{-~¡-¿'
  '،؛؟٪-٭۔‐-‧‰-⁞]',
);
final _spaces = RegExp('[\\s ]+');
final _hasLetter = RegExp('[a-zء-ي]');
final _doubled = RegExp(r'([a-z])\1+');

String _translate(String s, String from, String to) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString();
}

/// The key both sides of a name search compare: lower case, Latin diacritics and apostrophes
/// gone, Arabic hamza/ya/ta marbuta variants merged, harakat and tatweel removed, Arabic-Indic
/// and Persian digits as 0-9, punctuation as a space. "Bou Saâda" and "bou saada" meet, and so
/// do "أحمد" and "احمد".
String searchFold(String input) {
  final b = StringBuffer();
  for (final ch in input.toLowerCase().split('')) {
    if (_apostrophes.contains(ch)) continue;
    b.write(_latin[ch] ?? ch);
  }
  final s = _translate(
    b.toString().replaceAll(_marks, ''),
    _arabicFrom,
    _arabicTo,
  );
  return s.replaceAll(_punct, ' ').replaceAll(_spaces, ' ').trim();
}

const _apostrophes = "'’‘ʿʾʼ`";

/// A sound skeleton that makes "Amine" and "أمين" equal: per word, Arabic read the
/// Algerian-French way and Latin digraphs (ch, kh, gh, dj ...) merged into one letter, vowels
/// dropped except a word's first, doubled letters collapsed, spaces gone. Arabizi digits 3 7 9
/// 5 2 count as ع ح ق خ ء.
String nameSkeleton(String input) {
  final out = StringBuffer();
  for (var t in searchFold(input).split(' ')) {
    if (!_hasLetter.hasMatch(t)) {
      out.write(t);
      continue;
    }
    t = t.replaceFirst(RegExp('^و'), 'w');
    t = t.replaceFirst(RegExp('^ي'), 'y');
    t = t.replaceFirstMapped(RegExp('(.)ه\$'), (m) => m[1]!);
    t = t.replaceFirst(RegExp('^ou'), 'w');
    t = t.replaceFirstMapped(RegExp(r'([aeiou])h$'), (m) => m[1]!);
    t = t
        .replaceAll('ch', '#')
        .replaceAll('sh', '#')
        .replaceAll('kh', 'x')
        .replaceAll('gh', 'g')
        .replaceAll('dj', 'j')
        .replaceAll('th', 't')
        .replaceAll('dh', 'd');
    t = t.replaceAllMapped(RegExp('c([eiy])'), (m) => 's${m[1]}');
    t = _translate(t, 'cq#37952', 'kkcahkxa');
    t = _translate(t, _skeletonFrom, _skeletonTo);
    t = t.substring(0, 1) + t.substring(1).replaceAll(RegExp('[aeiouyw]'), '');
    t = t.replaceFirst(RegExp('^[aeiou]'), 'a');
    out.write(t.replaceAllMapped(_doubled, (m) => m[1]!));
  }
  return out.toString();
}

/// Whether [query] finds [nameFr], [nameAr] or [code]: by fold, or by skeleton so that "Tizi"
/// finds "تيزي وزو". The skeleton needs two letters here (the server needs three): the list is
/// short and has no index, and a commune name's skeleton is often only two letters long.
bool matchesPlace(
  String query, {
  required String nameFr,
  required String nameAr,
  String? code,
}) {
  final q = query.trim();
  if (q.isEmpty) return true;
  final folded = searchFold(q);
  if (folded.isEmpty) return false;
  if (searchFold(nameFr).contains(folded) ||
      searchFold(nameAr).contains(folded) ||
      (code != null && code.startsWith(folded))) {
    return true;
  }
  final skeleton = nameSkeleton(q);
  return skeleton.length >= 2 &&
      (nameSkeleton(nameFr).contains(skeleton) ||
          nameSkeleton(nameAr).contains(skeleton));
}
