import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_service.dart';
import 'package:letter_signing/letters/letters_env.dart';
import 'package:letter_signing/letters/letter_widgets.dart';
import 'package:letter_signing/letters/models.dart';
import 'package:letter_signing/letters/sign_widgets.dart';
import 'package:letter_signing/screens/biometric_enrol.dart';
import 'package:letter_signing/screens/ui_bits.dart';
import 'package:letter_signing/theme/app_theme.dart';
import 'package:letter_signing/theme/widgets.dart';

const _approvalTimeout = Duration(minutes: 5);
const _pollEvery = Duration(seconds: 3);

/// Decision and note, then a way to prove it is you: signing PIN, fingerprint/face on this device,
/// or approval on another of your devices. Pops the updated [LetterBrief].
class SignScreen extends StatefulWidget {
  const SignScreen({
    super.key,
    required this.env,
    required this.letter,
    this.approvalTimeout = _approvalTimeout,
    this.pollEvery = _pollEvery,
  });
  final LettersEnv env;
  final LetterDetail letter;

  /// How long to wait for another device before falling back to the PIN.
  final Duration approvalTimeout;

  /// Fallback polling of the request when no live frame arrives.
  final Duration pollEvery;

  @override
  State<SignScreen> createState() => _SignScreenState();
}

class _SignScreenState extends State<SignScreen> {
  String _decision = 'approved';
  final _note = TextEditingController();
  final _pin = TextEditingController();
  List<SessionInfo> _sessions = const [];
  bool _biometricsHere = false;
  bool _busy = false;
  String? _error;
  String? _pinError;
  SignRequest? _request;
  String _askedDevice = '';
  StreamSubscription<LiveEvent>? _live;
  Timer? _poll;
  Timer? _deadline;

  LettersEnv get env => widget.env;
  LetterDetail get letter => widget.letter;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSessions());
  }

  @override
  void dispose() {
    final waiting = _request;
    _stopTimers();
    if (waiting != null) {
      unawaited(
        env.api
            .cancelSignRequest(waiting.id)
            .then((_) {}, onError: (Object _) {}),
      );
    }
    _note.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    try {
      final all = await env.api.sessions();
      final here = await env.biometrics.available();
      if (mounted) {
        setState(() {
          _sessions = all;
          _biometricsHere = here;
        });
      }
    } on Exception {
      // The PIN always works; device choices just stay hidden.
    }
  }

  bool get _thisDeviceBiometric =>
      _sessions.any((s) => s.current && s.biometric);

  List<SessionInfo> get _otherDevices =>
      _sessions.where((s) => !s.current && s.biometric).toList();

  String get _noteText => _note.text.trim();

  String get _reason {
    final l = AppLocalizations.of(context);
    return _decision == 'approved'
        ? l.signReasonApprove(letter.title)
        : l.signReasonReject(letter.title);
  }

  /// Runs one signing attempt, showing failures inline.
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

  Future<void> _signWithPin() async {
    final problem = validatePin(_pin.text);
    setState(
      () => _pinError = problem == null
          ? null
          : AppLocalizations.of(context).signPinInvalid,
    );
    if (problem != null) return;
    await _guard(() async {
      final brief = await env.api.sign(
        letter.id,
        decision: _decision,
        note: _noteText,
        pin: _pin.text,
      );
      if (mounted) Navigator.of(context).pop(brief);
    });
  }

  Future<void> _signWithBiometrics() => _guard(() async {
    final failed = AppLocalizations.of(context).signBiometricFailed;
    if (!await env.biometrics.authenticate(_reason)) {
      throw LetterException(failed);
    }
    final brief = await env.api.signBiometric(
      letter.id,
      decision: _decision,
      note: _noteText,
    );
    if (mounted) Navigator.of(context).pop(brief);
  });

  Future<void> _askDevice(SessionInfo device) => _guard(() async {
    final request = await env.api.createSignRequest(
      letter.id,
      decision: _decision,
      note: _noteText,
      approverSessionId: device.id,
    );
    if (!mounted) return;
    _startWaiting(request, device.displayName);
  });

  void _startWaiting(SignRequest request, String device) {
    _live = env.live.events.listen((e) {
      final update = e.request;
      if (e.isSignRequestUpdate && update != null) _onUpdate(update);
    });
    _poll = Timer.periodic(widget.pollEvery, (_) => unawaited(_pollOnce()));
    _deadline = Timer(widget.approvalTimeout, () => unawaited(_onTimeout()));
    setState(() {
      _request = request;
      _askedDevice = device;
    });
  }

  void _stopTimers() {
    _poll?.cancel();
    _deadline?.cancel();
    unawaited(_live?.cancel());
    _poll = _deadline = null;
    _live = null;
  }

  Future<void> _pollOnce() async {
    final id = _request?.id;
    if (id == null) return;
    try {
      _onUpdate(await env.api.signRequest(id));
    } on Exception {
      // Keep waiting; the next tick or a live frame will tell.
    }
  }

  void _onUpdate(SignRequest update) {
    if (!mounted || update.id != _request?.id || update.isPending) return;
    _stopTimers();
    if (update.isApproved) {
      setState(() => _request = null);
      unawaited(_finish());
      return;
    }
    final l = AppLocalizations.of(context);
    setState(() {
      _request = null;
      _error = switch (update.status) {
        SignRequest.declined => l.signDeclined(_askedDevice),
        SignRequest.expired => l.signExpired,
        _ => l.signCancelled,
      };
    });
  }

  Future<void> _onTimeout() async {
    final request = _request;
    if (request == null) return;
    try {
      await env.api.cancelSignRequest(request.id);
    } on Exception {
      await _pollOnce(); // it may have been approved at the last second
      if (_request == null) return;
    }
    if (!mounted) return;
    _stopTimers();
    final l = AppLocalizations.of(context);
    setState(() {
      _request = null;
      _error = l.signNoAnswer(_askedDevice);
    });
  }

  Future<void> _cancelWaiting() async {
    final request = _request;
    if (request == null) return;
    try {
      await env.api.cancelSignRequest(request.id);
    } on Exception {
      await _pollOnce();
      if (_request == null) return;
    }
    if (!mounted) return;
    _stopTimers();
    setState(() => _request = null);
  }

  /// The other device signed; hand the refreshed letter back.
  Future<void> _finish() async {
    var brief = letter.brief;
    try {
      brief = (await env.api.detail(letter.id)).brief;
    } on Exception {
      // The caller reloads the letter anyway.
    }
    if (mounted) Navigator.of(context).pop(brief);
  }

  @override
  Widget build(BuildContext context) {
    final l = letter;
    final t = AppLocalizations.of(context);
    final signed = l.signers.where((p) => p.decision.isNotEmpty).length;
    return Scaffold(
      appBar: AppBar(title: Text(t.signTitle)),
      body: ListView(
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _summary(l, signed),
                ..._decisionSection(),
                SectionHeader(t.signHow),
                if (_error != null) ...[
                  ErrorBanner(_error!),
                  const SizedBox(height: 10),
                ],
                if (_request == null) _methods() else _waiting(),
                const SizedBox(height: Tokens.gap),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(LetterDetail l, int signed) {
    final scheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '#${toPersianDigits(l.brief.no)}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              StatusChip(l.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(l.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            t.signProgress(
              toPersianDigits(signed),
              toPersianDigits(l.signers.length),
            ),
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  List<Widget> _decisionSection() {
    final locked = _busy || _request != null;
    final t = AppLocalizations.of(context);
    return [
      SectionHeader(t.signDecision),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DecisionChoice(
                icon: Icons.check_circle_outline,
                label: t.decisionApprove,
                hint: t.signApproveHint,
                color: Tokens.ok,
                selected: _decision == 'approved',
                onTap: locked ? null : () => _pick('approved'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DecisionChoice(
                icon: Icons.cancel_outlined,
                label: t.decisionReject,
                hint: t.signRejectHint,
                color: Tokens.error,
                selected: _decision == 'rejected',
                onTap: locked ? null : () => _pick('rejected'),
              ),
            ),
          ],
        ),
      ),
      if (_decision == 'rejected')
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(t.signRejectFinal),
        ),
      const SizedBox(height: 16),
      TextField(
        controller: _note,
        enabled: !locked,
        maxLength: 2000,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: t.signNoteOptional,
          alignLabelWithHint: true,
        ),
      ),
    ];
  }

  void _pick(String decision) => setState(() => _decision = decision);

  bool get _canEnableBiometric =>
      env.enrollBiometric != null &&
      _biometricsHere &&
      _sessions.any((s) => s.current && !s.biometric);

  Future<void> _enableBiometric() async {
    final enroll = env.enrollBiometric;
    if (enroll == null) return;
    final done = await showBiometricEnrolDialog(context, enroll: enroll);
    if (done && mounted) await _loadSessions();
  }

  Widget _methods() => SignMethods(
    pin: _pin,
    pinError: _pinError,
    busy: _busy,
    onPin: _signWithPin,
    onBiometric: _thisDeviceBiometric ? _signWithBiometrics : null,
    devices: _otherDevices,
    onAsk: _askDevice,
    onEnableBiometric: _canEnableBiometric ? _enableBiometric : null,
  );

  Widget _waiting() =>
      WaitingForApproval(device: _askedDevice, onCancel: _cancelWaiting);
}
