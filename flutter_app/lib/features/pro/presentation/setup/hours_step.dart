import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/router/redirect.dart';
import '../../../../shared/widgets/lemqes_primary_button.dart';
import '../../../auth/presentation/auth_widgets.dart';
import '../../../signup/presentation/signup_completion.dart';
import '../../data/pro_failure.dart';
import '../../data/pro_models.dart';
import '../../data/pro_providers.dart';
import '../edit/hours_editor.dart';
import '../pro_failure_message.dart';
import 'pro_setup_flow.dart';

/// A first week to adjust rather than build: Saturday to Thursday,
/// 09:00-19:00, Friday closed.
final _usualWeek = [
  for (final wd in [6, 7, 1, 2, 3, 4])
    DayHours(
      weekday: wd,
      opens: const TimeOfDay(hour: 9, minute: 0),
      closes: const TimeOfDay(hour: 19, minute: 0),
    ),
];

/// Setup step 3: the week, then publish. A refusal for a missing piece
/// opens the step that holds it.
class HoursStep extends ConsumerStatefulWidget {
  const HoursStep({this.incomplete = false, super.key});

  final bool incomplete;

  @override
  ConsumerState<HoursStep> createState() => _HoursStepState();
}

class _HoursStepState extends ConsumerState<HoursStep> {
  late final List<DayHours> _initial;
  late List<DayHours> _week;
  late bool _valid;
  late bool _incomplete;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(myProProvider).value?.hours ?? const [];
    _initial = saved.isEmpty ? _usualWeek : saved;
    _week = _initial;
    _valid = _week.every((d) => hoursIssue(d) == null);
    _incomplete = widget.incomplete;
  }

  Future<void> _publish() async {
    final l10n = context.l10n;
    if (_busy) return;
    if (_week.isEmpty || !_valid) {
      setState(
        () => _message = _week.isEmpty
            ? l10n.hoursAllClosed
            : l10n.hoursFixErrors,
      );
      return;
    }
    final router = GoRouter.of(context);
    setState(() {
      _busy = true;
      _message = null;
      _incomplete = false;
    });
    var failure = await runPro(ref, (p) => p.setHours(_week));
    failure ??= await runPro(ref, (p) => p.publish());
    if (!mounted) return;
    if (failure == null) {
      ref.read(signupJustCompletedProvider.notifier).set(false);
      router.go('/home');
      return;
    }
    final step = failure is ProfileIncomplete
        ? setupStepForGaps(failure.gaps) ?? 'hours'
        : 'hours';
    if (step != 'hours') {
      router.go('/pro/setup/$step?incomplete=1');
      return;
    }
    setState(() {
      _busy = false;
      if (failure is ProfileIncomplete) {
        _incomplete = true;
      } else {
        _message = proFailureMessage(l10n, failure);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SetupStepScaffold(
      index: 2,
      title: l10n.setupHoursTitle,
      body: l10n.setupHoursBody,
      onBack: () => context.go('/pro/setup/services'),
      action: LemqesPrimaryButton(
        key: const Key('setupPublish'),
        label: l10n.setupPublish,
        expand: true,
        loading: _busy,
        onPressed: _busy ? null : _publish,
      ),
      children: [
        if (_incomplete) ...[
          FailureBanner(message: l10n.setupIncomplete),
          const SizedBox(height: 16),
        ],
        if (_message != null) ...[
          FailureBanner(message: _message!),
          const SizedBox(height: 16),
        ],
        HoursEditor(
          initial: _initial,
          pickTime: ref.watch(timePickProvider),
          onChanged: (week, valid) => setState(() {
            _week = week;
            _valid = valid;
            _message = null;
          }),
        ),
      ],
    );
  }
}
