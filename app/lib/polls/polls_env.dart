import 'package:letter_signing/letters/live_service.dart';
import 'package:letter_signing/polls/polls_api.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// What the polls screens need: the API, the shared live stream and the caller.
class PollsEnv {
  PollsEnv({required this.api, required this.live, required this.userId});

  /// For screens that only hold their own env (chat, projects, CRM): any env's workspace api.
  factory PollsEnv.of(WorkspaceApi workspace, LiveService live, int userId) =>
      PollsEnv(api: PollsApi(workspace), live: live, userId: userId);

  final PollsApi api;
  final LiveService live;
  final int userId;
}
