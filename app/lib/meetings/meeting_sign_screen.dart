import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_service.dart';
import 'package:letter_signing/letters/letter_widgets.dart' show ErrorBanner;
import 'package:letter_signing/letters/models.dart' show SessionInfo;
import 'package:letter_signing/letters/sign_widgets.dart';
import 'package:letter_signing/meetings/meeting_controller.dart';
import 'package:letter_signing/meetings/meetings_env.dart';
import 'package:letter_signing/meetings/models.dart';
import 'package:letter_signing/screens/ui_bits.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/subject_controller.dart'
    show ActionOutcome;

/// Sign the minutes: a decision (a rejection needs a note) and the signing PIN or this device's
/// fingerprint/face. Pops true once signed.
class MeetingSignScreen extends StatefulWidget {
  const MeetingSignScreen({
    super.key,
    required this.env,
    required this.controller,
    required this.meeting,
  });
  final MeetingsEnv env;
  final MeetingController controller;
  final MeetingOut meeting;

  @override
  State<MeetingSignScreen> createState() => _MeetingSignState();
}

class _MeetingSignState extends State<MeetingSignScreen> {
  String _decision = 'approved';
  final _note = TextEditingController();
  final _pin = TextEditingController();
  List<SessionInfo> _sessions = const [];
  bool _busy = false;
  String? _error;
  String? _pinError;

  MeetingsEnv get env => widget.env;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSessions());
  }

  @override
  void dispose() {
    _note.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    try {
      final all = await env.api.sessions();
      if (mounted) setState(() => _sessions = all);
    } on Exception {
      // The PIN always works.
    }
  }

  bool get _thisDeviceBiometric =>
      _sessions.any((s) => s.current && s.biometric);

  String get _noteText => _note.text.trim();

  /// A rejection needs a note; returns the message, or null when fine.
  String? _noteProblem(AppLocalizations l) =>
      _decision == 'rejected' && _noteText.isEmpty
      ? l.meetingRejectNeedsNote
      : null;

  Future<void> _guard(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on LetterException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Applies the controller's outcome: pop on success, else show the server's message.
  void _finish(ActionOutcome outcome) {
    if (!mounted) return;
    if (outcome == ActionOutcome.ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _error = '${widget.controller.lastError}');
  }

  Future<void> _withPin() async {
    final l = AppLocalizations.of(context);
    final noteProblem = _noteProblem(l);
    final pinProblem = validatePin(_pin.text);
    setState(() {
      _pinError = pinProblem == null ? null : l.signPinInvalid;
      _error = noteProblem;
    });
    if (noteProblem != null || pinProblem != null) return;
    await _guard(() async {
      _finish(
        await widget.controller.signWithPin(
          decision: _decision,
          note: _noteText,
          pin: _pin.text,
        ),
      );
    });
  }

  Future<void> _withBiometrics() async {
    final l = AppLocalizations.of(context);
    final problem = _noteProblem(l);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    await _guard(() async {
      if (!await env.biometrics.authenticate(
        l.meetingSignReason(widget.meeting.title),
      )) {
        throw LetterException(l.signBiometricFailed);
      }
      _finish(
        await widget.controller.signWithBiometric(
          decision: _decision,
          note: _noteText,
        ),
      );
    });
  }

  Widget _decisionRow(AppLocalizations l) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: DecisionChoice(
            icon: Icons.check_circle_outline,
            label: l.decisionApprove,
            hint: l.meetingSignApproveHint,
            color: Tokens.ok,
            selected: _decision == 'approved',
            onTap: _busy ? null : () => setState(() => _decision = 'approved'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DecisionChoice(
            icon: Icons.cancel_outlined,
            label: l.decisionReject,
            hint: l.meetingSignRejectHint,
            color: Tokens.error,
            selected: _decision == 'rejected',
            onTap: _busy ? null : () => setState(() => _decision = 'rejected'),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.meetingSignTitle)),
      body: ListView(
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Text(
                    widget.meeting.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                SectionHeader(l.signDecision),
                _decisionRow(l),
                const SizedBox(height: 16),
                TextField(
                  controller: _note,
                  enabled: !_busy,
                  maxLength: 2000,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: _decision == 'rejected'
                        ? l.meetingSignNoteRequired
                        : l.signNoteOptional,
                    alignLabelWithHint: true,
                  ),
                ),
                SectionHeader(l.signHow),
                if (_error != null) ...[
                  ErrorBanner(_error!),
                  const SizedBox(height: 10),
                ],
                SignMethods(
                  pin: _pin,
                  pinError: _pinError,
                  busy: _busy,
                  onPin: _withPin,
                  onBiometric: _thisDeviceBiometric ? _withBiometrics : null,
                  devices: const [],
                  onAsk: (_) {},
                ),
                const SizedBox(height: Tokens.gap),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
