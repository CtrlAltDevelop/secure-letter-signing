import 'dart:typed_data';

import 'package:letter_signing/letters/models.dart' show AppNotification;
import 'package:letter_signing/prefs/models.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// Typed access to `/me/prefs`, `/me/personal-email`, `/me/background`, `/me/notifications`,
/// `/me/mentions` and the status text of `PATCH /me`.
class PrefsApi {
  PrefsApi(this.workspace);

  final WorkspaceApi workspace;

  Future<UserPrefs> prefs() async =>
      UserPrefs.fromJson(await workspace.call('GET', '/me/prefs'));

  /// Only the given fields change. Pass [clearBirthday] / [clearDnd] to send an explicit null.
  Future<UserPrefs> patch({
    String? theme,
    DateTime? birthday,
    bool clearBirthday = false,
    bool? birthdayVisible,
    DateTime? dndUntil,
    bool clearDnd = false,
  }) async => UserPrefs.fromJson(
    await workspace.call(
      'PATCH',
      '/me/prefs',
      body: {
        'theme': ?theme,
        if (clearBirthday) 'birthday': null,
        if (birthday != null)
          'birthday':
              '${birthday.year.toString().padLeft(4, '0')}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}',
        'birthday_visible': ?birthdayVisible,
        if (clearDnd) 'dnd_until': null,
        if (dndUntil != null) 'dnd_until': dndUntil.toUtc().toIso8601String(),
      },
    ),
  );

  Future<void> setPersonalEmail(String email) =>
      workspace.call('POST', '/me/personal-email', body: {'email': email});

  Future<UserPrefs> verifyPersonalEmail(String token) async =>
      UserPrefs.fromJson(
        await workspace.call(
          'POST',
          '/me/personal-email/verify',
          body: {'token': token},
        ),
      );

  Future<Uint8List> background() => workspace.getBytes('/me/background');

  Future<UserPrefs> uploadBackground(String name, Uint8List bytes) async =>
      UserPrefs.fromJson(
        await workspace.postFile('/me/background', name: name, bytes: bytes),
      );

  Future<void> deleteBackground() => workspace.call('DELETE', '/me/background');

  /// The current status text (`GET /me` has `status_text`).
  Future<String> statusText() async =>
      asString(asMap(await workspace.call('GET', '/me'))['status_text']);

  Future<void> saveProfile({String? statusText, String? title}) =>
      workspace.call(
        'PATCH',
        '/me',
        body: {'status_text': ?statusText, 'title': ?title},
      );

  Future<List<AppNotification>> notifications({int limit = 200}) async => [
    for (final j in asMapList(
      await workspace.call('GET', '/me/notifications?limit=$limit'),
    ))
      AppNotification.fromJson(j),
  ].reversed.toList();

  Future<void> markAllRead() =>
      workspace.call('POST', '/me/notifications/read');

  Future<List<MentionItem>> mentions({int limit = 50}) async => [
    for (final j in asMapList(
      await workspace.call('GET', '/me/mentions?limit=$limit'),
    ))
      MentionItem.fromJson(j),
  ];
}
