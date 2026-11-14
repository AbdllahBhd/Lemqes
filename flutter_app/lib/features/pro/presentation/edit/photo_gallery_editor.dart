import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/theme/lemqes_typography.dart';
import '../../../../shared/widgets/ltr.dart';
import '../../../../shared/widgets/photo_tile.dart';
import '../../data/photo_uploader.dart';
import '../../data/pro_failure.dart';
import '../../data/pro_models.dart';
import '../../data/pro_providers.dart';
import '../setup/pro_setup_flow.dart';

/// Picks a work photo, downsized on the device (JPEG at 82 %).
final workPhotoPickerProvider = Provider<Future<XFile?> Function()>(
  (_) =>
      () => ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 82,
      ),
);

/// The database keeps at most this many work photos per profile.
const maxWorkPhotos = 9;

/// A picked photo not yet stored: uploading, or failed and waiting for a
/// retry.
class _Pending {
  _Pending(this.file, this.bytes);

  final XFile file;
  final Uint8List bytes;
  bool failed = false;
}

/// The work photos: a grid of up to [maxWorkPhotos], an add tile, removal
/// after a confirmation, and each upload's progress or retry in its own
/// tile. Why an upload failed is said by the screen's `ProFailureListener`.
class PhotoGalleryEditor extends ConsumerStatefulWidget {
  const PhotoGalleryEditor({required this.photos, super.key});

  final List<ProPhoto> photos;

  @override
  ConsumerState<PhotoGalleryEditor> createState() => _PhotoGalleryEditorState();
}

class _PhotoGalleryEditorState extends ConsumerState<PhotoGalleryEditor> {
  final _pending = <_Pending>[];

  // One write at a time: runPro reads the controller's state after each
  // action, which a second action in flight would overwrite.
  bool _busy = false;

  int get _count => widget.photos.length + _pending.length;

  Future<void> _add() async {
    if (_busy || _count >= maxWorkPhotos) return;
    setState(() => _busy = true);
    final file = await ref.read(workPhotoPickerProvider)();
    final bytes = await file?.readAsBytes();
    if (!mounted) return;
    if (file == null || bytes == null) {
      setState(() => _busy = false);
      return;
    }
    final pending = _Pending(file, bytes);
    setState(() => _pending.add(pending));
    await _upload(pending);
  }

  Future<void> _upload(_Pending pending) async {
    setState(() {
      _busy = true;
      pending.failed = false;
    });
    final failure = await runPro(ref, (p) => p.addWorkPhoto(pending.file));
    if (!mounted) return;
    setState(() {
      _busy = false;
      // At the cap a retry can only fail again; the listener says why.
      if (failure == null || failure is TooManyPhotos) {
        _pending.remove(pending);
      } else {
        pending.failed = true;
      }
    });
  }

  Future<void> _remove(ProPhoto photo) async {
    if (_busy) return;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.photoRemoveConfirmTitle),
        content: Text(l10n.photoRemoveConfirmBody),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            key: const Key('photoRemoveConfirm'),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: Theme.of(dialog).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.photoRemoveConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    await runPro(ref, (p) => p.removeWorkPhoto(photo));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final uploader = ref.watch(photoUploaderProvider);
    final full = _count >= maxWorkPhotos;
    final message = full
        ? l10n.photosLimit
        : _count == 0
        ? l10n.photosEmpty
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: message == null
                  ? const SizedBox.shrink()
                  : Text(message, style: muted),
            ),
            const SizedBox(width: 12),
            Semantics(
              label: l10n.photosCount(_count),
              excludeSemantics: true,
              child: Ltr(
                child: Text(
                  '$_count/$maxWorkPhotos',
                  style: muted.merge(lemqesNumeric),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            // Three across on a phone; tiles never shrink below a size that
            // holds two 48 dp controls.
            final columns = math.max(
              2,
              math.min(3, constraints.maxWidth ~/ 104),
            );
            return GridView.count(
              crossAxisCount: columns,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final photo in widget.photos)
                  KeyedSubtree(
                    key: Key('photo_${photo.id}'),
                    child: PhotoTile(
                      url: uploader.publicUrl(workPhotosBucket, photo.path),
                      onRemove: () => _remove(photo),
                    ),
                  ),
                for (final (i, pending) in _pending.indexed)
                  _PendingTile(
                    index: i,
                    pending: pending,
                    onRetry: _busy ? null : () => _upload(pending),
                    onDiscard: _busy
                        ? null
                        : () => setState(() => _pending.remove(pending)),
                  ),
                _AddTile(onTap: full || _busy ? null : _add),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// A picked photo over a scrim: a spinner while it uploads; retry and drop
/// once it failed.
class _PendingTile extends StatelessWidget {
  const _PendingTile({
    required this.index,
    required this.pending,
    required this.onRetry,
    required this.onDiscard,
  });

  final int index;
  final _Pending pending;
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(PhotoTile.radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: scheme.surfaceContainerHigh),
          Image.memory(
            pending.bytes,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          // Scrim keeps the white controls AA on any photo.
          const ColoredBox(color: Color(0xCC062A35)),
          if (!pending.failed)
            Center(
              key: Key('photoUploading_$index'),
              child: const SizedBox.square(
                dimension: 28,
                child: _UploadSpinner(),
              ),
            )
          else
            Semantics(
              key: Key('photoFailed_$index'),
              label: l10n.photosUploadFailed,
              child: Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    IconButton(
                      key: Key('photoRetry_$index'),
                      tooltip: l10n.actionRetry,
                      color: Colors.white,
                      icon: const Icon(Icons.refresh),
                      onPressed: onRetry,
                    ),
                    IconButton(
                      key: Key('photoDiscard_$index'),
                      tooltip: l10n.photosDiscard,
                      color: Colors.white,
                      icon: const Icon(Icons.close),
                      onPressed: onDiscard,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UploadSpinner extends StatelessWidget {
  const _UploadSpinner();

  @override
  Widget build(BuildContext context) => CircularProgressIndicator(
    strokeWidth: 3,
    color: Colors.white,
    semanticsLabel: context.l10n.photosUploading,
  );
}

/// The tile that adds a photo; [onTap] null when the gallery is full or busy.
class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onTap != null;
    final ink = enabled ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      enabled: enabled,
      label: l10n.photosAdd,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: scheme.secondaryContainer.withValues(alpha: enabled ? 1 : 0.4),
        borderRadius: BorderRadius.circular(PhotoTile.radius),
        child: InkWell(
          key: const Key('photoAdd'),
          borderRadius: BorderRadius.circular(PhotoTile.radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: ink, size: 28),
                  const SizedBox(height: 4),
                  // Two lines at most; the tile never grows with the text.
                  Flexible(
                    child: Text(
                      l10n.photosAdd,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(color: ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
