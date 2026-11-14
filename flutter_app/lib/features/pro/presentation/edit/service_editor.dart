import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/theme/lemqes_tokens.dart';
import '../../../../shared/widgets/lemqes_primary_button.dart';
import '../../../auth/presentation/auth_fields.dart';
import '../../data/price_parse.dart';
import '../../data/pro_models.dart';

/// What the editor sheet was closed with.
sealed class ServiceEditorResult {
  const ServiceEditorResult();
}

class ServiceSaved extends ServiceEditorResult {
  const ServiceSaved(this.draft);
  final ProServiceDraft draft;
}

class ServiceRemoved extends ServiceEditorResult {
  const ServiceRemoved();
}

/// Opens [ServiceEditor] in a bottom sheet; null when dismissed.
Future<ServiceEditorResult?> showServiceEditor(
  BuildContext context, {
  ServicePreset? preset,
  ProService? existing,
  required List<ServiceCategory> categories,
}) => showModalBottomSheet<ServiceEditorResult>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(LemqesShape.sheetRadius),
    ),
  ),
  builder: (sheet) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      24 + MediaQuery.viewInsetsOf(sheet).bottom,
    ),
    child: ServiceEditor(
      preset: preset,
      existing: existing,
      categories: categories,
      onSaved: (d) => Navigator.of(sheet).pop(ServiceSaved(d)),
      onRemove: existing == null
          ? null
          : () => Navigator.of(sheet).pop(const ServiceRemoved()),
    ),
  ),
);

/// Price and duration of one service: a preset (prefilled, name fixed), a
/// custom one (name and category typed), or an [existing] row being edited.
///
/// Numbers are read through [parsePriceDzd] / [parseDurationMin], so Eastern
/// Arabic digits and thousands spaces are accepted and written back in Latin
/// digits once saved.
class ServiceEditor extends StatefulWidget {
  const ServiceEditor({
    super.key,
    this.preset,
    this.existing,
    required this.categories,
    required this.onSaved,
    this.onRemove,
  });

  final ServicePreset? preset;
  final ProService? existing;

  /// Offered to a custom service; the first is preselected.
  final List<ServiceCategory> categories;
  final ValueChanged<ProServiceDraft> onSaved;
  final VoidCallback? onRemove;

  @override
  State<ServiceEditor> createState() => _ServiceEditorState();
}

class _ServiceEditorState extends State<ServiceEditor> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _duration;
  late ServiceCategory _category;
  late bool _active;
  String? _nameError;
  String? _priceError;
  String? _durationError;

  bool get _custom =>
      widget.preset == null &&
      (widget.existing == null || widget.existing!.presetKey == null);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final p = widget.preset;
    _name = TextEditingController(text: e?.customName);
    _price = TextEditingController(
      text: (e?.priceDzd ?? p?.defaultPriceDzd)?.toString(),
    );
    _duration = TextEditingController(
      text: (e?.durationMin ?? p?.defaultDurationMin)?.toString(),
    );
    _category =
        e?.category ??
        p?.category ??
        (widget.categories.isEmpty
            ? ServiceCategory.hair
            : widget.categories.first);
    _active = e?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _duration.dispose();
    super.dispose();
  }

  void _save() {
    final l10n = context.l10n;
    final name = _name.text.trim();
    final price = parsePriceDzd(_price.text);
    final duration = parseDurationMin(_duration.text);
    setState(() {
      _nameError = !_custom
          ? null
          : name.isEmpty
          ? l10n.serviceNameRequired
          : name.characters.length < 2 || name.characters.length > 60
          ? l10n.serviceNameLength
          : null;
      _priceError = _price.text.trim().isEmpty
          ? l10n.servicePriceRequired
          : price == null
          ? l10n.servicePriceInvalid
          : null;
      _durationError = _duration.text.trim().isEmpty
          ? l10n.serviceDurationRequired
          : duration == null
          ? l10n.serviceDurationInvalid
          : null;
    });
    if (_nameError != null || price == null || duration == null) return;
    _price.text = '$price';
    _duration.text = '$duration';
    widget.onSaved(
      ProServiceDraft(
        id: widget.existing?.id,
        presetKey: _custom
            ? null
            : (widget.preset?.key ?? widget.existing?.presetKey),
        customName: _custom ? name : null,
        category: _category,
        priceDzd: price,
        durationMin: duration,
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final title = _custom
        ? (widget.existing?.customName ?? l10n.serviceEditorNewTitle)
        : widget.preset?.name(locale) ?? widget.existing?.presetKey ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: 16),
        if (_custom) ...[
          TextField(
            key: const Key('serviceNameField'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            maxLength: 60,
            decoration: lemqesFieldDecoration(
              context,
              label: l10n.serviceNameLabel,
              error: _nameError,
            ).copyWith(counterText: ''),
          ),
          const SizedBox(height: 16),
          Text(l10n.serviceCategoryLabel, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in widget.categories)
                ChoiceChip(
                  key: Key('category_${c.toDb()}'),
                  label: Text(l10n.serviceCategoryName(c.toDb())),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _NumberField(
                fieldKey: const Key('servicePriceField'),
                controller: _price,
                label: l10n.servicePriceLabel,
                suffix: 'DA',
                error: _priceError,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NumberField(
                fieldKey: const Key('serviceDurationField'),
                controller: _duration,
                label: l10n.serviceDurationLabel,
                suffix: l10n.serviceMinutesSuffix,
                error: _durationError,
              ),
            ),
          ],
        ),
        if (widget.existing != null) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('serviceActiveSwitch'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.serviceActiveLabel),
            subtitle: Text(l10n.serviceActiveHint),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
        ],
        const SizedBox(height: 24),
        LemqesPrimaryButton(
          key: const Key('serviceSave'),
          label: l10n.serviceSave,
          expand: true,
          onPressed: _save,
        ),
        if (widget.onRemove != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('serviceRemove'),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: theme.colorScheme.error,
            ),
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.serviceRemove),
            onPressed: widget.onRemove,
          ),
        ],
      ],
    );
  }
}

/// A whole-number field; digits always run left to right.
class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.suffix,
    required this.error,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String suffix;
  final String? error;

  @override
  Widget build(BuildContext context) => TextField(
    key: fieldKey,
    controller: controller,
    keyboardType: TextInputType.number,
    textInputAction: TextInputAction.next,
    textDirection: TextDirection.ltr,
    decoration: lemqesFieldDecoration(
      context,
      label: label,
      error: error,
    ).copyWith(suffixText: suffix),
  );
}
