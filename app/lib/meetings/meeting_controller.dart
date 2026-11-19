import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/letters/models.dart' show LiveEvent;
import 'package:letter_signing/meetings/meetings_api.dart';
import 'package:letter_signing/meetings/models.dart';
import 'package:letter_signing/workspace/subject_controller.dart'
    show ActionOutcome, outcomeOf;

/// One meeting: loads it, applies every action and reloads on live events of its subject.
class MeetingController extends ChangeNotifier {
  MeetingController({
    required this.api,
    required this.live,
    required this.meetingId,
  }) {
    _sub = live.events.listen((e) {
      final subject = _meeting?.subjectId;
      if (e.isWorkspace && subject != null && e.raw['subject_id'] == subject) {
        unawaited(reload());
      }
    });
  }

  final MeetingsApi api;
  final LiveService live;
  final String meetingId;
  StreamSubscription<LiveEvent>? _sub;
  bool _disposed = false;
  MeetingOut? _meeting;
  Object? _error;
  Object? _lastError;

  MeetingOut? get meeting => _meeting;

  /// Failure of the initial load (the screen shows a retry).
  Object? get error => _error;

  /// Failure of the last action, for messages.
  Object? get lastError => _lastError;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    try {
      _meeting = await api.get(meetingId);
      _error = null;
    } on Object catch (e) {
      _error = e;
    }
    _notify();
  }

  /// Reloads quietly; a failure keeps what is shown.
  Future<void> reload() async {
    try {
      _meeting = await api.get(meetingId);
      _notify();
    } on Object catch (e) {
      _lastError = e;
    }
  }

  /// Runs a write; a returned meeting replaces the current one, otherwise it reloads.
  Future<ActionOutcome> _act(Future<Object?> Function() action) async {
    try {
      final result = await action();
      if (result is MeetingOut) {
        _meeting = result;
        _notify();
      } else {
        await reload();
      }
      return ActionOutcome.ok;
    } on Object catch (e) {
      _lastError = e;
      return outcomeOf(e);
    }
  }

  /// [action] is `schedule`, `hold`, `close`, `reopen` or `cancel`.
  Future<ActionOutcome> transition(String action) =>
      _act(() => api.transition(meetingId, action));

  Future<ActionOutcome> markAttendance(Attendee a, String attendance) => _act(
    () =>
        api.markAttendance(meetingId, attendeeId: a.id, attendance: attendance),
  );

  Future<ActionOutcome> saveMinutes(String text) => _act(
    () => api.patch(meetingId, {
      'description': {'text': text},
    }),
  );

  Future<ActionOutcome> patchFields(Map<String, dynamic> fields) =>
      _act(() => api.patch(meetingId, fields));

  Future<ActionOutcome> setAttendees(List<AttendeeDraft> attendees) =>
      _act(() => api.setAttendees(meetingId, attendees));

  Future<ActionOutcome> addResolution({
    required String text,
    DateTime? dueAt,
    List<int> ownerIds = const [],
  }) => _act(
    () => api.addResolution(
      meetingId,
      text: text,
      dueAt: dueAt,
      ownerIds: ownerIds,
    ),
  );

  Future<ActionOutcome> editResolution(
    int id, {
    String? text,
    DateTime? dueAt,
    List<int>? ownerIds,
    String? status,
    bool? active,
  }) => _act(
    () => api.editResolution(
      meetingId,
      id,
      text: text,
      dueAt: dueAt,
      ownerIds: ownerIds,
      status: status,
      active: active,
    ),
  );

  Future<ActionOutcome> signWithPin({
    required String decision,
    required String note,
    required String pin,
  }) => _act(
    () => api.signWithPin(meetingId, decision: decision, note: note, pin: pin),
  );

  Future<ActionOutcome> signWithBiometric({
    required String decision,
    required String note,
  }) => _act(
    () => api.signWithBiometric(meetingId, decision: decision, note: note),
  );

  /// Reminders created, or null when the call failed.
  Future<int?> remind(int offsetMinutes) async {
    try {
      return await api.remind(meetingId, offsetMinutes);
    } on Object catch (e) {
      _lastError = e;
      return null;
    }
  }

  Future<SmsResult?> sendSms(String text) async {
    try {
      return await api.sendSms(meetingId, text);
    } on Object catch (e) {
      _lastError = e;
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
