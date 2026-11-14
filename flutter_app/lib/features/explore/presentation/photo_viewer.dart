import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/lemqes_typography.dart';
import '../../../shared/widgets/ltr.dart';

/// Opens [urls] full screen at [initial]; swiping moves between photos.
Future<void> showPhotoViewer(
  BuildContext context, {
  required List<String> urls,
  required int initial,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => PhotoViewer(urls: urls, initial: initial),
  ),
);

class PhotoViewer extends StatefulWidget {
  const PhotoViewer({required this.urls, required this.initial, super.key});

  final List<String> urls;
  final int initial;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initial,
  );
  late int _index = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = widget.urls.length;
    final textTheme = Theme.of(context).textTheme;
    // Photos are seen on black in both themes, so the chrome is white.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              key: const Key('photoViewer'),
              controller: _pages,
              itemCount: total,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => Semantics(
                image: true,
                label: l10n.photoViewerPosition(i + 1, total),
                child: Image.network(
                  widget.urls[i],
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            semanticsLabel: l10n.loading,
                          ),
                        ),
                  errorBuilder: (context, _, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.broken_image_outlined,
                          size: 40,
                          color: Colors.white70,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.photoUnavailable,
                          style: textTheme.bodyLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('photoViewerClose'),
                      tooltip: MaterialLocalizations.of(context)
                          .closeButtonTooltip,
                      color: Colors.white,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    // The page itself announces its position.
                    ExcludeSemantics(
                      child: Ltr(
                        child: Text(
                          '${_index + 1} / $total',
                          style: textTheme.titleMedium!
                              .merge(lemqesNumeric)
                              .copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
