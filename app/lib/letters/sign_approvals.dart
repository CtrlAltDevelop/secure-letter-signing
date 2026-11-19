import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:letter_signing/auth/biometrics.dart';
import 'package:letter_signing/l10n/tr.dart';
import 'package:letter_signing/letters/letter_service.dart';
import 'package:letter_signing/letters/letters_api.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/letters/models.dart';

/// Signature requests other devices of this user have addressed to this device.
/// Fed by live `sign_request` frames and by `GET /sign-requests/incoming` on start and on every reconnect.
class SignApprovals extends ChangeNotifier {
  SignApprovals({
    required this.api,
    required this.live,
    required this.biometrics,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _events = live.events.listen(_onEvent);
    _connection = live.connection.listen((up) {
      if (up) unawaited(refresh());
    });
  }

  final LettersApi api;
  final LiveService live;
  final Biometrics biometrics;
  final DateTime Function() _clock;
  late final StreamSubscription<LiveEvent> _events;
  late final StreamSubscription<bool> _connection;
  List<SignRequest> _pending = const [];

  /// Requests waiting for this device, oldest first.
  List<SignRequest> get pending => _pending;

  /// Loads the pending requests. Failures keep what is already known.
  Future<void> refresh() async {
    try {
      _replace(await api.incomingSignRequests());
    } on Exception {
      // Offline: live frames and the next reconnect refresh it.
    }
  }

  void _replace(List<SignRequest> requests) {
    _pending = _usable(requests);
    notifyListeners();
  }

  List<SignRequest> _usable(Iterable<SignRequest> requests) {
    final now = _clock();
    final byId = {
      for (final r in requests)
        if (r.isPending && r.expiresAt.isAfter(now)) r.id: r,
    };
    return byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  void _onEvent(LiveEvent e) {
    final request = e.request;
    if (request == null) return;
    final others = _pending.where((r) => r.id != request.id);
    _pending = _usable([...others, request]);
    notifyListeners();
  }

  void _drop(String id) {
    _pending = [
      for (final r in _pending)
        if (r.id != id) r,
    ];
    notifyListeners();
  }

  /// Fingerprint/face first, then `POST /sign-requests/{id}/approve`.
  Future<void> approve(SignRequest request) async {
    final reason = request.decision == 'approved'
        ? tr.approvalBioReasonApprove(request.letterTitle)
        : tr.approvalBioReasonReject(request.letterTitle);
    final ok = await biometrics.authenticate(reason);
    if (!ok) throw LetterException(tr.approvalBioFailed);
    await api.approveSignRequest(request.id);
    _drop(request.id);
  }

  Future<void> decline(SignRequest request) async {
    await api.declineSignRequest(request.id);
    _drop(request.id);
  }

  @override
  void dispose() {
    unawaited(_events.cancel());
    unawaited(_connection.cancel());
    super.dispose();
  }
}
