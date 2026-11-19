import 'dart:typed_data';

import 'package:flutter/widgets.dart' show BuildContext;
import 'package:letter_signing/chat/chat_api.dart';
import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/tasks/tasks_env.dart';
import 'package:letter_signing/utils/save_bytes.dart';
import 'package:letter_signing/workspace/file_pick.dart';
import 'package:letter_signing/workspace/models.dart';

/// An image read from the system clipboard (null when it holds none).
typedef ClipboardImageFn = Future<PickedFile?> Function();

/// A finished voice recording (null when cancelled).
typedef VoiceRecordFn = Future<PickedFile?> Function(BuildContext context);

/// What the chat screens need: the API, the shared live stream, the user, the Tasks env (for
/// "message to task") and the platform hooks tests replace.
///
/// [readClipboardImage] and [recordVoice] are platform hooks (the workspace plugs in
/// `pasteboard` and `record`); a null hook hides the feature, tests pass fakes.
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
