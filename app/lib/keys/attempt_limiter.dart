import 'package:letter_signing/keys/secure_kv.dart';

/// Wrong tries allowed before a delay applies.
const freeAttempts = 10;
const _baseDelay = Duration(seconds: 30);
const _maxDelay = Duration(hours: 24);

/// Delay imposed after [failures] consecutive wrong passwords: none up to
/// [freeAttempts], then 30 s doubling with every further failure, capped at 24 h.
Duration lockoutFor(int failures) {
  if (failures < freeAttempts) return Duration.zero;
  final steps = failures - freeAttempts;
  if (steps > 12) return _maxDelay; // 30 s * 2^12 already exceeds the cap
  final delay = _baseDelay * (1 << steps);
  return delay > _maxDelay ? _maxDelay : delay;
}

/// Persisted on-device brute-force protection for the key password.
/// State survives restarts because it lives in [SecureKv].
class AttemptLimiter {
  AttemptLimiter(this._kv, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  static const failuresKey = 'key.failures';
  static const lastFailureKey = 'key.lastFailureMs';

  final SecureKv _kv;
  final DateTime Function() _now;

  Future<int> failures() async =>
      int.tryParse(await _kv.read(failuresKey) ?? '') ?? 0;

  /// Time left before the next try is allowed (zero if none).
  Future<Duration> remaining() async {
    final count = await failures();
    final last = int.tryParse(await _kv.read(lastFailureKey) ?? '');
    if (last == null) return Duration.zero;
    final until = DateTime.fromMillisecondsSinceEpoch(
      last,
    ).add(lockoutFor(count));
    final left = until.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> recordFailure() async {
    final count = await failures() + 1;
    await _kv.write(failuresKey, '$count');
    await _kv.write(lastFailureKey, '${_now().millisecondsSinceEpoch}');
  }

  Future<void> reset() async {
    await _kv.delete(failuresKey);
    await _kv.delete(lastFailureKey);
  }
}
