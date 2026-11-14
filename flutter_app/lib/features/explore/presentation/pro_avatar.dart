import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/lemqes_typography.dart';
import '../../pro/data/photo_uploader.dart';
import '../../pro/data/pro_providers.dart';

final _joiningScript = RegExp(
  '[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
);

/// Up to two initials, one per word, from a pro-typed name (any script).
///
/// Arabic-script names get one: two Arabic letters join into a word, and
/// some pairs spell offensive ones.
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final count = _joiningScript.hasMatch(name) ? 1 : 2;
  return words.take(count).map((w) => w.characters.first.toUpperCase()).join();
}

/// A pro's round profile photo; the initials tile stands in while it loads,
/// when there is none and when it cannot be fetched. Decorative: the name
/// beside it is what screen readers read.
class ProAvatar extends ConsumerWidget {
  const ProAvatar({required this.name, this.path, this.size = 56, super.key});

  final String name;

  /// The `avatars` object path, or null when the pro has no photo.
  final String? path;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = this.path;
    final initials = _Initials(text: initialsOf(name), size: size);
    return ExcludeSemantics(
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: path == null
              ? initials
              : Image.network(
                  ref
                      .watch(photoUploaderProvider)
                      .publicUrl(avatarsBucket, path),
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : initials,
                  errorBuilder: (_, _, _) => initials,
                ),
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.text, required this.size});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ColoredBox(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: EdgeInsets.all(size * 0.2),
        // Scales down rather than clipping at large text sizes.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: lemqesWeight(
              theme.textTheme.titleLarge!.copyWith(
                fontFamily: 'Alexandria',
                fontSize: size * 0.36,
                color: scheme.onSecondaryContainer,
              ),
              FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
