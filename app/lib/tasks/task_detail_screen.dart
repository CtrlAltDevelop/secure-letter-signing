import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/letters/letter_widgets.dart' show SkeletonList;
import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/tasks/task_detail_controller.dart';
import 'package:letter_signing/tasks/task_detail_sections.dart';
import 'package:letter_signing/tasks/task_dialogs.dart';
import 'package:letter_signing/tasks/task_form_screen.dart';
import 'package:letter_signing/tasks/task_project_card.dart';
import 'package:letter_signing/tasks/tasks_env.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/subject_controller.dart';
import 'package:letter_signing/workspace/widgets/comment_thread.dart';
import 'package:letter_signing/workspace/widgets/file_list.dart';
import 'package:letter_signing/workspace/widgets/history_list.dart';
import 'package:letter_signing/workspace/widgets/reminders_card.dart';
import 'package:letter_signing/workspace/widgets/seen_by_sheet.dart';

/// One task: header, progress, people, checklist, actions, and tabs for comments, files and
/// history. Opening it marks the task as seen.
class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, required this.env, required this.taskId});
  final TasksEnv env;
  final String taskId;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late final TaskDetailController _detail = TaskDetailController(
    api: widget.env.api,
    live: widget.env.live,
    taskId: widget.taskId,
    projects: widget.env.projects,
  );
  SubjectController? _subject;
  List<LabelInfo> _labels = const [];
  DetailTab _tab = DetailTab.comments;

  @override
  void initState() {
    super.initState();
    _detail.addListener(_onDetail);
    unawaited(_detail.load());
    unawaited(_loadLabels());
  }

  @override
  void dispose() {
    _detail.removeListener(_onDetail);
    _detail.dispose();
    _subject?.dispose();
    super.dispose();
  }

  Future<void> _loadLabels() async {
    final labels = await widget.env.labels();
    if (mounted) setState(() => _labels = labels);
  }

  /// Creates the subject controller once the task (and so its subject id) is known.
  void _onDetail() {
    final task = _detail.task;
    if (task == null || _subject != null) return;
    final subject = SubjectController(
      api: widget.env.api.workspace,
      live: widget.env.live,
      subjectId: task.subjectId,
    );
    _subject = subject;
    unawaited(subject.loadComments());
  }

  void _report(ActionOutcome outcome, [Object? error]) {
    if (outcome == ActionOutcome.ok || !mounted) return;
    final l = AppLocalizations.of(context);
    final text = switch (outcome) {
      ActionOutcome.conflict => l.taskConflict,
      ActionOutcome.forbidden => l.taskForbidden,
      ActionOutcome.notFound => l.taskNotFound,
      _ => '${error ?? l.taskActionFailed}',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    if (outcome == ActionOutcome.notFound) Navigator.of(context).maybePop();
  }

  Future<void> _act(Future<ActionOutcome> Function() action) async {
    final outcome = await action();
    _report(outcome, _detail.lastError);
  }

  Future<void> _complete() async {
    final l = AppLocalizations.of(context);
    final note = await showNoteDialog(
      context,
      title: l.taskComplete,
      confirmLabel: l.taskComplete,
      hint: l.taskNoteOptional,
    );
    if (note != null) await _act(() => _detail.complete(note: note));
  }

  Future<void> _approve() async {
    final l = AppLocalizations.of(context);
    final note = await showNoteDialog(
      context,
      title: l.taskApprove,
      confirmLabel: l.taskApprove,
      hint: l.taskNoteOptional,
    );
    if (note != null) await _act(() => _detail.approve(note: note));
  }

  Future<void> _reject() async {
    final l = AppLocalizations.of(context);
    final note = await showNoteDialog(
      context,
      title: l.taskReject,
      confirmLabel: l.taskReject,
      hint: l.taskRejectNoteRequired,
      required: true,
    );
    if (note != null) await _act(() => _detail.reject(note));
  }

  Future<void> _cancel() async {
    final l = AppLocalizations.of(context);
    final yes = await showConfirmDialog(
      context,
      title: l.taskCancel,
      message: l.taskCancelConfirm,
      confirmLabel: l.taskCancelYes,
    );
    if (yes) await _act(_detail.cancel);
  }

  Future<void> _copyTo(String? projectId) async {
    final outcome = await _detail.copyTo(
      projectId,
      copied: (_) {
        if (!mounted) return;
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.taskCopied)));
      },
    );
    _report(outcome, _detail.lastError);
  }

  Future<void> _edit(TaskOut task) async {
    final saved = await Navigator.of(context).push<TaskOut>(
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(env: widget.env, task: task),
      ),
    );
    if (saved != null) await _detail.reload();
  }

  void _selectTab(DetailTab tab) {
    setState(() => _tab = tab);
    final subject = _subject;
    if (subject == null) return;
    if (tab == DetailTab.files && subject.files == null) {
      unawaited(subject.loadFiles());
    }
    if (tab == DetailTab.history) unawaited(subject.loadHistory());
  }

  Future<bool> _post(
    SubjectController s,
    String text, {
    int? parentId,
    required String kind,
    int? progress,
  }) async {
    final outcome = await s.postComment(
      text,
      parentId: parentId,
      kind: kind,
      progress: progress,
    );
    _report(outcome, s.lastError);
    if (outcome == ActionOutcome.ok) unawaited(_detail.reload());
    return outcome == ActionOutcome.ok;
  }

  Future<bool> _viaSubject(
    SubjectController s,
    Future<ActionOutcome> Function() action,
  ) async {
    final outcome = await action();
    _report(outcome, s.lastError);
    return outcome == ActionOutcome.ok;
  }

  Future<void> _upload(SubjectController s) async {
    final picked = await widget.env.pickFile();
    if (picked == null) return;
    await _viaSubject(
      s,
      () => s.uploadFile(
        name: picked.name,
        bytes: picked.bytes,
        contentType: picked.contentType,
      ),
    );
    unawaited(_detail.reload());
  }

  Future<void> _download(SubjectController s, FileInfo f) async {
    final bytes = await s.download(f);
    if (bytes == null) {
      _report(ActionOutcome.failed, s.lastError);
      return;
    }
    await widget.env.saveFile(bytes, name: f.name, mimeType: f.contentType);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _detail,
      builder: (context, _) {
        final task = _detail.task;
        return Scaffold(
          appBar: AppBar(
            title: Text(l.taskDetailTitle),
            actions: [
              if (task != null) ...[
                IconButton(
                  tooltip: l.seenByTitle,
                  icon: const Icon(Icons.visibility_outlined),
                  onPressed: () => unawaited(
                    showSeenBySheet(
                      context,
                      () => widget.env.api.workspace.seenBy(task.subjectId),
                    ),
                  ),
                ),
                if (task.can.edit && task.isActive)
                  IconButton(
                    tooltip: l.taskEdit,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => unawaited(_edit(task)),
                  ),
              ],
            ],
          ),
          body: _body(context, task),
        );
      },
    );
  }

  Widget _body(BuildContext context, TaskOut? task) {
    final l = AppLocalizations.of(context);
    if (task == null) {
      if (_detail.error != null) {
        return EmptyState(
          icon: Icons.cloud_off_outlined,
          title: l.taskLoadFailed,
          message: '${_detail.error}',
          action: OutlinedButton.icon(
            onPressed: () => unawaited(_detail.load()),
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
          for (final w in _sections(task))
            Padding(padding: const EdgeInsets.only(bottom: 12), child: w),
        ],
      ),
    );
  }

  List<Widget> _sections(TaskOut task) => [
    TaskHeaderCard(task: task, labels: _labels),
    TaskActionBar(
      task: task,
      busy: _detail.busy,
      onComplete: () => unawaited(_complete()),
      onApprove: () => unawaited(_approve()),
      onReject: () => unawaited(_reject()),
      onReopen: () => unawaited(_act(_detail.reopen)),
      onCancel: () => unawaited(_cancel()),
    ),
    TaskProgressCard(
      task: task,
      onChanged: (v) => unawaited(_act(() => _detail.setProgress(v))),
    ),
    if (task.description.trim().isNotEmpty)
      TaskDescriptionCard(text: task.description),
    TaskPeopleCard(task: task),
    if (task.checklistItems.isNotEmpty || task.canEditChecklist)
      TaskChecklistCard(
        task: task,
        onToggle: (item, {required done}) =>
            unawaited(_act(() => _detail.toggleItem(item, done: done))),
        onAdd: (t) => unawaited(_act(() => _detail.addItem(t))),
        onRemove: (i) => unawaited(_act(() => _detail.removeItem(i))),
        onMove: (a, b) => unawaited(_act(() => _detail.moveItem(a, b))),
      ),
    TaskProjectCard(
      task: task,
      api: widget.env.projects,
      onMove: (p, c) => unawaited(_act(() => _detail.move(p, c))),
      onCopy: (p) => unawaited(_copyTo(p)),
    ),
    RemindersCard(api: widget.env.api.workspace, subjectId: task.subjectId),
    DetailTabChips(
      selected: _tab,
      onSelected: _selectTab,
      commentCount: _subject?.comments?.length ?? task.commentCount,
      fileCount: _subject?.files?.length ?? task.fileCount,
    ),
    _tabBody(task),
  ];

  Widget _tabBody(TaskOut task) {
    final subject = _subject;
    if (subject == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: subject,
      builder: (context, _) => switch (_tab) {
        DetailTab.comments => CommentThread(
          comments: subject.comments,
          currentUserId: widget.env.userId,
          canComment: task.can.comment,
          allowReports: true,
          onPost: (text, {parentId, required kind, progress}) => _post(
            subject,
            text,
            parentId: parentId,
            kind: kind,
            progress: progress,
          ),
          onEdit: (id, text) =>
              _viaSubject(subject, () => subject.editComment(id, text)),
          onDelete: (id) =>
              _viaSubject(subject, () => subject.deactivateComment(id)),
        ),
        DetailTab.files => FileList(
          files: subject.files,
          currentUserId: widget.env.userId,
          canUpload: task.can.comment,
          onUpload: () => _upload(subject),
          onDownload: (f) => _download(subject, f),
          onDeactivate: (f) =>
              _viaSubject(subject, () => subject.deactivateFile(f.id)),
        ),
        DetailTab.history => HistoryList(entries: subject.history),
      },
    );
  }
}
