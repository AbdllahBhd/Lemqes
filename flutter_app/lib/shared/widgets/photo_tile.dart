import 'package:material_ui/material_ui.dart';

import '../../core/l10n/locale_controller.dart';

/// A square gallery photo with a quiet placeholder while it loads and a clear
/// state when it cannot. [onRemove] adds a 48 dp remove control.
class PhotoTile extends StatelessWidget {
  const PhotoTile({super.key, required this.url, this.onRemove});

  final String url;
  final VoidCallback? onRemove;

  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remove = onRemove;
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: scheme.surfaceContainerHigh),
            Image.network(
              url,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Center(
                      child: SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: context.l10n.loading,
                        ),
                      ),
                    ),
              errorBuilder: (context, _, _) => Semantics(
                label: context.l10n.photoUnavailable,
                child: Center(
                  key: const Key('photoError'),
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 32,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            if (remove != null)
              PositionedDirectional(
                top: 0,
                end: 0,
                child: Semantics(
                  button: true,
                  label: context.l10n.photoRemove,
                  onTap: remove,
                  child: ExcludeSemantics(
                    child: InkResponse(
                      key: const Key('photoRemove'),
                      onTap: remove,
                      radius: 24,
                      child: SizedBox.square(
                        dimension: 48,
                        child: Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              // Scrim keeps the white glyph AA on any photo.
                              color: const Color(0xCC062A35),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            child: const SizedBox.square(
                              dimension: 32,
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
