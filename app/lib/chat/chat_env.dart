import 'dart:typed_data';

import 'package:letter_signing/chat/chat_api.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/tasks/tasks_env.dart';
import 'package:letter_signing/utils/save_bytes.dart';
import 'package:letter_signing/workspace/file_pick.dart';
import 'package:letter_signing/workspace/models.dart';

/// An image read from the system clipboard (null when it holds none).
typedef ClipboardImageFn = Future<PickedFile?> Function();

/// A finished voice recording (null when cancelled).
typedef VoiceRecordFn = Future<PickedFile?> Function();

/// What the chat screens need: the API, the shared live stream, the user, the Tasks env (for
/// "message to task") and the platform hooks tests replace.
///
/// Two hooks have no default because no package for them is in `pubspec.yaml`:
/// - [readClipboardImage]: plug a clipboard package (e.g. `pasteboard`) here and a paste
///   button appears in the composer; pasted text already works through the text field.
/// - [recordVoice]: plug a recorder package (e.g. `record`) here and a microphone button
///   appears in DMs; the result is sent as a `voice` message.
class ChatEnv {
  ChatEnv({
    required this.api,
    required this.live,
    required this.userId,
    required this.tasks,
    this.userName = '',
    this.canCreateGroup = false,
    this.readClipboardImage,
    this.recordVoice,
    FilePickFn? pickFile,
    SaveFile? saveFile,
  }) : pickFile = pickFile ?? pickOneFile,
       saveFile = saveFile ?? saveBytes;

  final ChatApi api;
  final LiveService live;
  final int userId;
  final TasksEnv tasks;
  final String userName;

  /// The `chat.create_group` permission.
  final bool canCreateGroup;
  final ClipboardImageFn? readClipboardImage;
  final VoiceRecordFn? recordVoice;
  final FilePickFn pickFile;
  final SaveFile saveFile;

  Future<List<UserRef>>? _directory;

  /// Colleagues for the pickers, fetched once.
  Future<List<UserRef>> directory() =>
      _directory ??= api.workspace.directory().catchError((Object _) {
        _directory = null;
        return <UserRef>[];
      });

  /// Saves downloaded bytes through the platform share/save hook.
  Future<void> save(Uint8List bytes, String name, String type) =>
      saveFile(bytes, name: name, mimeType: type);
}
