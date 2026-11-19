import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:letter_signing/prefs/models.dart';
import 'package:letter_signing/prefs/prefs_api.dart';
import 'package:letter_signing/prefs/theme_mode.dart';
import 'package:letter_signing/workspace/file_pick.dart';

/// Preferences of the signed-in user: theme, birthday, do-not-disturb, personal email,
/// background image and status text. Every setter returns whether the server accepted it.
class PrefsController extends ChangeNotifier {
  PrefsController(this.api, {FilePickFn? pickFile})
    : pickFile = pickFile ?? pickOneFile;

  final PrefsApi api;
  final FilePickFn pickFile;

  UserPrefs _prefs = const UserPrefs();
  String _statusText = '';
  Uint8List? _background;
  bool _loaded = false;
  bool _disposed = false;
  Object? _error;

  UserPrefs get prefs => _prefs;
  String get statusText => _statusText;
  Uint8List? get background => _background;
  bool get loaded => _loaded;
  Object? get error => _error;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Loads everything; an older server without prefs keeps the defaults.
  Future<void> load() async {
    try {
      _prefs = await api.prefs();
      appThemeMode.value = _prefs.themeMode;
      _error = null;
    } on Object catch (e) {
      _error = e;
    }
    try {
      _statusText = await api.statusText();
    } on Object {
      // Shown empty.
    }
    await _loadBackground();
    _loaded = true;
    _notify();
  }

  Future<void> _loadBackground() async {
    if (!_prefs.hasBackground) {
      _background = null;
      return;
    }
    try {
      _background = await api.background();
    } on Object {
      _background = null;
    }
  }

  Future<bool> _apply(Future<UserPrefs> Function() call) async {
    try {
      _prefs = await call();
      _error = null;
      appThemeMode.value = _prefs.themeMode;
      _notify();
      return true;
    } on Object catch (e) {
      _error = e;
      _notify();
      return false;
    }
  }

  Future<bool> setTheme(String theme) => _apply(() => api.patch(theme: theme));

  Future<bool> setBirthday(DateTime? day) =>
      _apply(() => api.patch(birthday: day, clearBirthday: day == null));

  Future<bool> setBirthdayVisible({required bool visible}) =>
      _apply(() => api.patch(birthdayVisible: visible));

  /// Silences notifications until [until]; null turns do-not-disturb off.
  Future<bool> setDnd(DateTime? until) =>
      _apply(() => api.patch(dndUntil: until, clearDnd: until == null));

  Future<bool> setPersonalEmail(String email) async {
    try {
      await api.setPersonalEmail(email);
      _prefs = await api.prefs();
      _notify();
      return true;
    } on Object catch (e) {
      _error = e;
      return false;
    }
  }

  Future<bool> verifyPersonalEmail(String token) =>
      _apply(() => api.verifyPersonalEmail(token));

  /// Picks an image and uploads it; false when cancelled or refused.
  Future<bool> chooseBackground() async {
    final file = await pickFile();
    if (file == null) return false;
    final ok = await _apply(() => api.uploadBackground(file.name, file.bytes));
    if (ok) {
      _background = file.bytes;
      _notify();
    }
    return ok;
  }

  Future<bool> removeBackground() async {
    try {
      await api.deleteBackground();
      _prefs = await api.prefs();
      _background = null;
      _notify();
      return true;
    } on Object catch (e) {
      _error = e;
      return false;
    }
  }

  Future<bool> saveProfile({String? statusText, String? title}) async {
    try {
      await api.saveProfile(statusText: statusText, title: title);
      if (statusText != null) _statusText = statusText;
      _notify();
      return true;
    } on Object catch (e) {
      _error = e;
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
