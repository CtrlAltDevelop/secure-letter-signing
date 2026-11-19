import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/workspace/widgets/bookmark_button.dart';
import 'package:letter_signing/letters/letter_widgets.dart' show SkeletonList;
import 'package:letter_signing/letters/letterhead.dart';
import 'package:letter_signing/meetings/meeting_actions.dart';
import 'package:letter_signing/meetings/meeting_controller.dart';
import 'package:letter_signing/meetings/meeting_form_screen.dart';
import 'package:letter_signing/meetings/meeting_print.dart';
import 'package:letter_signing/meetings/meeting_resolutions.dart';
import 'package:letter_signing/meetings/meeting_sections.dart';
import 'package:letter_signing/meetings/meeting_sign_screen.dart';
import 'package:letter_signing/meetings/meetings_env.dart';
import 'package:letter_signing/meetings/models.dart';
import 'package:letter_signing/tasks/task_detail_screen.dart';
import 'package:letter_signing/tasks/task_detail_sections.dart'
    show DetailTab, DetailTabChips;
import 'package:letter_signing/tasks/task_dialogs.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/video/video_api.dart';
import 'package:letter_signing/video/video_call_button.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/subject_controller.dart';
import 'package:letter_signing/workspace/widgets/comment_thread.dart';
import 'package:letter_signing/workspace/widgets/file_list.dart';
import 'package:letter_signing/workspace/widgets/history_list.dart';
import 'package:letter_signing/workspace/widgets/seen_by_sheet.dart';

/// One meeting: info, attendees with attendance, resolutions, minutes, signatures, lifecycle
/// buttons, reminders and SMS, print, and comments/files/history.
class MeetingDetailScreen extends StatefulWidget {
  const MeetingDetailScreen({
    super.key,
    required this.env,
    required this.meetingId,
  });
  final MeetingsEnv env;
  final String meetingId;

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailState();
}

class _MeetingDetailState extends State<MeetingDetailScreen> {
  late final MeetingController _c = MeetingController(
    api: widget.env.api,
    live: widget.env.live,
    meetingId: widget.meetingId,
  );
  SubjectController? _subject;
  List<UserRef> _directory = const [];
  DetailTab _tab = DetailTab.comments;
  bool _busy = false;

  MeetingsEnv get env => widget.env;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onController);
    unawaited(_c.load());
    unawaited(_loadDirectory());
  }

  @override
  void dispose() {
    _c
      ..removeListener(_onController)
      ..dispose();
    _subject?.dispose();
    super.dispose();
  }

  Future<void> _loadDirectory() async {
    final dir = await env.directory();
    if (mounted) setState(() => _directory = dir);
  }

  void _onController() {
    final m = _c.meeting;
    if (m == null || _subject != null) return;
    final subject = SubjectController(
      api: env.api.workspace,
      live: env.live,
      subjectId: m.subjectId,
    );
    _subject = subject;
    unawaited(subject.loadComments());
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _report(ActionOutcome outcome) {
    if (outcome == ActionOutcome.ok || !mounted) return;
    final l = AppLocalizations.of(context);
    _toast(switch (outcome) {
      ActionOutcome.forbidden => l.taskForbidden,
      ActionOutcome.notFound => l.meetingNotFound,
      _ => '${_c.lastError ?? l.taskActionFailed}',
    });
    if (outcome == ActionOutcome.notFound) Navigator.of(context).maybePop();
  }

  Future<void> _act(Future<ActionOutcome> Function() action) async {
    setState(() => _busy = true);
    final outcome = await action();
    if (mounted) setState(() => _busy = false);
    _report(outcome);
  }

  Future<void> _transition(String action) async {
    final l = AppLocalizations.of(context);
    final confirm = switch (action) {
      'cancel' => (l.meetingActionCancel, l.meetingConfirmCancel),
      'close' => (l.meetingActionClose, l.meetingConfirmClose),
      'reopen' => (l.meetingActionReopen, l.meetingConfirmReopen),
      _ => null,
    };
    if (confirm != null) {
      final yes = await showConfirmDialog(
        context,
        title: confirm.$1,
        message: confirm.$2,
        confirmLabel: confirm.$1,
      );
      if (!yes) return;
    }
    await _act(() => _c.transition(action));
  }

  Future<void> _edit(MeetingOut m) async {
    final saved = await Navigator.of(context).push<MeetingOut>(
      MaterialPageRoute(
        builder: (_) => MeetingFormScreen(env: env, meeting: m),
      ),
    );
    if (saved != null) await _c.reload();
  }

  Future<void> _editMinutes(MeetingOut m) async {
    final l = AppLocalizations.of(context);
    final text = await showDialog<String>(
      context: context,
      builder: (_) =>
          _MinutesDialog(initial: m.description, title: l.meetingEditMinutes),
    );
    if (text != null) await _act(() => _c.saveMinutes(text));
  }

  Future<void> _addResolution() async {
    final input = await showResolutionSheet(context, directory: _directory);
    if (input == null) return;
    await _act(
      () => _c.addResolution(
        text: input.text,
        dueAt: input.dueAt,
        ownerIds: input.ownerIds,
      ),
    );
  }

  Future<void> _editResolution(Resolution r) async {
    final input = await showResolutionSheet(
      context,
      directory: _directory,
      initial: r,
    );
    if (input == null) return;
    await _act(
      () => _c.editResolution(
        r.id,
        text: input.text,
        dueAt: input.dueAt,
        ownerIds: input.ownerIds,
      ),
    );
  }

  Future<void> _deactivateResolution(Resolution r) async {
    final l = AppLocalizations.of(context);
    final yes = await showConfirmDialog(
      context,
      title: l.resolutionDeactivate,
      message: l.resolutionDeactivateConfirm,
      confirmLabel: l.resolutionDeactivate,
    );
    if (yes) await _act(() => _c.editResolution(r.id, active: false));
  }

  void _openTask(String taskId) => unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(env: env.tasks, taskId: taskId),
      ),
    ),
  );

  Future<void> _sign(MeetingOut m) async {
    final signed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MeetingSignScreen(env: env, controller: _c, meeting: m),
      ),
    );
    if (signed == true) await _c.reload();
  }

  Future<void> _remind() async {
    final l = AppLocalizations.of(context);
    final minutes = await showRemindDialog(context);
    if (minutes == null) return;
    final n = await _c.remind(minutes);
    _toast(
      n == null ? '${_c.lastError}' : l.meetingRemindDone(toPersianDigits(n)),
    );
  }

  Future<void> _sms() async {
    final l = AppLocalizations.of(context);
    final text = await showSmsDialog(context);
    if (text == null) return;
    final r = await _c.sendSms(text);
    _toast(
      r == null
          ? '${_c.lastError}'
          : l.meetingSmsDone(
              toPersianDigits(r.sent),
              toPersianDigits(r.withoutPhone),
            ),
    );
  }

  Future<void> _print(MeetingOut m) async {
    var head = const Letterhead();
    try {
      head = Letterhead.fromJson(
        asMap(await env.api.workspace.call('GET', '/me/letterhead')),
      );
    } on Object {
      // Printing works without a letterhead.
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            MeetingPrintScreen(meeting: m, head: head, directory: _directory),
      ),
    );
  }

  bool _canSignNow(MeetingOut m) =>
      m.can.sign &&
      m.status == MeetingStatus.held &&
      !m.currentSignatures.any((s) => s.user.id == env.userId);

  void _selectTab(DetailTab tab) {
    setState(() => _tab = tab);
    final s = _subject;
    if (s == null) return;
    if (tab == DetailTab.files && s.files == null) unawaited(s.loadFiles());
    if (tab == DetailTab.history) unawaited(s.loadHistory());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final m = _c.meeting;
        return Scaffold(
          appBar: AppBar(
            title: Text(l.meetingDetailTitle),
            actions: [if (m != null) ..._appBarActions(m, l)],
          ),
          body: _body(m, l),
        );
      },
    );
  }

  List<Widget> _appBarActions(MeetingOut m, AppLocalizations l) => [
    VideoCallButton(api: VideoApi(env.api.workspace), subjectId: m.subjectId),
    BookmarkButton(api: env.api.workspace, module: 'meetings', id: m.id),
    IconButton(
      tooltip: l.meetingPrint,
      icon: const Icon(Icons.print_outlined),
      onPressed: () => unawaited(_print(m)),
    ),
    IconButton(
      tooltip: l.seenByTitle,
      icon: const Icon(Icons.visibility_outlined),
      onPressed: () => unawaited(
        showSeenBySheet(context, () => env.api.workspace.seenBy(m.subjectId)),
      ),
    ),
    if (m.can.manage &&
        (m.status == MeetingStatus.draft ||
            m.status == MeetingStatus.scheduled))
      IconButton(
        tooltip: l.meetingEdit,
        icon: const Icon(Icons.edit_outlined),
        onPressed: () => unawaited(_edit(m)),
      ),
  ];

  Widget _body(MeetingOut? m, AppLocalizations l) {
    if (m == null) {
      if (_c.error != null) {
        return EmptyState(
          icon: Icons.cloud_off_outlined,
          title: l.meetingLoadFailed,
          message: '${_c.error}',
          action: OutlinedButton.icon(
            onPressed: () => unawaited(_c.load()),
            icon: const Icon(Icons.refresh),
            label: Text(l.commonRetry),
          ),
        );
      }
      return const SkeletonList(count: 3);
    }
    return PageBody(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          MeetingInfoCard(meeting: m),
          const SizedBox(height: 12),
          MeetingActionBar(
            meeting: m,
            busy: _busy,
            onAction: (a) => unawaited(_transition(a)),
            onRemind: () => unawaited(_remind()),
            onSms: () => unawaited(_sms()),
          ),
          AttendeesSection(
            meeting: m,
            onMark: (a, v) => _act(() => _c.markAttendance(a, v)),
          ),
          ResolutionsSection(
            meeting: m,
            directory: _directory,
            onAdd: () => unawaited(_addResolution()),
            onEdit: (r) => unawaited(_editResolution(r)),
            onDeactivate: (r) => unawaited(_deactivateResolution(r)),
            onOpenTask: _openTask,
          ),
          MinutesSection(meeting: m, onEdit: () => unawaited(_editMinutes(m))),
          SignaturesSection(
            meeting: m,
            onSign: _canSignNow(m) ? () => unawaited(_sign(m)) : null,
          ),
          const SizedBox(height: 16),
          _tabs(m),
        ],
      ),
    );
  }

  Widget _tabs(MeetingOut m) {
    final s = _subject;
    if (s == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailTabChips(
            selected: _tab,
            onSelected: _selectTab,
            commentCount: s.comments?.length ?? 0,
            fileCount: s.files?.length ?? 0,
          ),
          const SizedBox(height: 8),
          _tabBody(m, s),
        ],
      ),
    );
  }

  Future<bool> _via(
    SubjectController s,
    Future<ActionOutcome> Function() f,
  ) async {
    final outcome = await f();
    if (outcome != ActionOutcome.ok && mounted) {
      _toast('${s.lastError ?? outcome.name}');
    }
    return outcome == ActionOutcome.ok;
  }

  Widget _tabBody(MeetingOut m, SubjectController s) => switch (_tab) {
    DetailTab.comments => CommentThread(
      comments: s.comments,
      currentUserId: env.userId,
      canComment: m.can.comment,
      onPost: (text, {parentId, required kind, progress}) =>
          _via(s, () => s.postComment(text, parentId: parentId, kind: kind)),
      onEdit: (id, text) => _via(s, () => s.editComment(id, text)),
      onDelete: (id) => _via(s, () => s.deactivateComment(id)),
    ),
    DetailTab.files => FileList(
      files: s.files,
      currentUserId: env.userId,
      canUpload: m.can.comment,
      onUpload: () => _upload(s),
      onDownload: (f) => _download(s, f),
      onDeactivate: (f) => _via(s, () => s.deactivateFile(f.id)),
    ),
    DetailTab.history => HistoryList(entries: s.history),
  };

  Future<void> _upload(SubjectController s) async {
    final picked = await env.pickFile();
    if (picked == null) return;
    await _via(
      s,
      () => s.uploadFile(
        name: picked.name,
        bytes: picked.bytes,
        contentType: picked.contentType,
      ),
    );
  }

  Future<void> _download(SubjectController s, FileInfo f) async {
    final bytes = await s.download(f);
    if (bytes == null) {
      _toast('${s.lastError}');
      return;
    }
    await env.saveFile(bytes, name: f.name, mimeType: f.contentType);
  }
}

class _MinutesDialog extends StatefulWidget {
  const _MinutesDialog({required this.initial, required this.title});
  final String initial;
  final String title;

  @override
  State<_MinutesDialog> createState() => _MinutesDialogState();
}

class _MinutesDialogState extends State<_MinutesDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        minLines: 6,
        maxLines: 12,
        decoration: InputDecoration(labelText: l.meetingMinutes),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _text.text),
          child: Text(l.commonSave),
        ),
      ],
    );
  }
}
