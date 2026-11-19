import 'package:flutter/foundation.dart';

import 'package:letter_signing/workspace/models.dart';

/// Task lifecycle values as the server sends them.
class TaskStatus {
  const TaskStatus._();
  static const open = 'open';
  static const awaitingApproval = 'awaiting_approval';
  static const done = 'done';
  static const cancelled = 'cancelled';
  static const all = [open, awaitingApproval, done, cancelled];

  /// Still being worked on (not finished, not cancelled).
  static bool isActive(String status) =>
      status == open || status == awaitingApproval;
}

class TaskPriority {
  const TaskPriority._();
  static const low = 'low';
  static const normal = 'normal';
  static const high = 'high';
  static const urgent = 'urgent';
  static const all = [low, normal, high, urgent];
}

/// How a task's progress is computed.
class ProgressMode {
  const ProgressMode._();
  static const manual = 'manual';
  static const checklist = 'checklist';
}

@immutable
class ChecklistCount {
  const ChecklistCount({this.done = 0, this.total = 0});
  final int done;
  final int total;

  factory ChecklistCount.fromJson(Object? raw) {
    final j = asMap(raw);
    return ChecklistCount(
      done: asInt(j['done']) ?? 0,
      total: asInt(j['total']) ?? 0,
    );
  }
}

/// A task as the lists show it (`GET /tasks`).
@immutable
class TaskBrief {
  const TaskBrief({
    required this.id,
    required this.subjectId,
    required this.title,
    this.status = TaskStatus.open,
    this.priority = TaskPriority.normal,
    this.progress = 0,
    this.dueAt,
    this.allDay = false,
    this.projectId,
    this.columnId,
    this.rank = 0,
    this.ownerIds = const [],
    this.myRoles = const [],
    this.labelIds = const [],
    this.checklist = const ChecklistCount(),
    this.unseen = false,
    this.updatedAt,
  });

  final String id;
  final String subjectId;
  final String title;
  final String status;
  final String priority;
  final int progress;
  final DateTime? dueAt;
  final bool allDay;
  final String? projectId;

  /// Board column inside [projectId] (null for personal tasks).
  final int? columnId;

  /// Position inside the column; lower first.
  final int rank;
  final List<int> ownerIds;
  final List<String> myRoles;
  final List<int> labelIds;
  final ChecklistCount checklist;
  final bool unseen;
  final DateTime? updatedAt;

  factory TaskBrief.fromJson(Map<String, dynamic> j) => TaskBrief(
    id: asString(j['id']),
    subjectId: asString(j['subject_id']),
    title: asString(j['title']),
    status: asString(j['status'], TaskStatus.open),
    priority: asString(j['priority'], TaskPriority.normal),
    progress: (asInt(j['progress']) ?? 0).clamp(0, 100),
    dueAt: parseDate(j['due_at']),
    allDay: j['all_day'] == true,
    projectId: j['project_id'] as String?,
    columnId: asInt(j['column_id']),
    rank: asInt(j['rank']) ?? 0,
    ownerIds: asIntList(j['owner_ids']),
    myRoles: [
      if (j['my_roles'] is List)
        for (final r in j['my_roles'] as List)
          if (r is String) r,
    ],
    labelIds: asIntList(j['label_ids']),
    checklist: ChecklistCount.fromJson(j['checklist']),
    unseen: j['unseen'] == true,
    updatedAt: parseDate(j['updated_at']),
  );

  /// The same task shown in another board column.
  TaskBrief copyWithColumn(int column) => TaskBrief(
    id: id,
    subjectId: subjectId,
    title: title,
    status: status,
    priority: priority,
    progress: progress,
    dueAt: dueAt,
    allDay: allDay,
    projectId: projectId,
    columnId: column,
    rank: rank,
    ownerIds: ownerIds,
    myRoles: myRoles,
    labelIds: labelIds,
    checklist: checklist,
    unseen: unseen,
    updatedAt: updatedAt,
  );

  /// Past its due date while still active. An all-day due date is overdue only after that
  /// local day has ended.
  bool isOverdue([DateTime? now]) {
    final due = dueAt?.toLocal();
    if (due == null || !TaskStatus.isActive(status)) return false;
    final current = (now ?? DateTime.now()).toLocal();
    if (allDay) {
      final endOfDay = DateTime(due.year, due.month, due.day + 1);
      return !current.isBefore(endOfDay);
    }
    return current.isAfter(due);
  }
}

/// One approver in the approval chain.
@immutable
class ApproverInfo {
  const ApproverInfo({
    required this.user,
    this.position = 0,
    this.decision = '',
    this.decidedAt,
  });

  final UserRef user;
  final int position;
  final String decision;
  final DateTime? decidedAt;

  bool get approved => decision == 'approve' || decision == 'approved';
  bool get rejected => decision == 'reject' || decision == 'rejected';
  bool get pending => !approved && !rejected;

  factory ApproverInfo.fromJson(Map<String, dynamic> j) => ApproverInfo(
    user: UserRef.maybe(j['user']) ?? const UserRef(id: 0),
    position: asInt(j['position']) ?? 0,
    decision: asString(j['decision']),
    decidedAt: parseDate(j['decided_at']),
  );
}

@immutable
class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.text,
    this.done = false,
    this.doneBy,
    this.doneAt,
  });

  final int id;
  final String text;
  final bool done;
  final UserRef? doneBy;
  final DateTime? doneAt;

  factory ChecklistItem.fromJson(Map<String, dynamic> j) => ChecklistItem(
    id: asInt(j['id']) ?? 0,
    text: asString(j['text']),
    done: j['done'] == true,
    doneBy: UserRef.maybe(j['done_by']),
    doneAt: parseDate(j['done_at']),
  );
}

/// What the current user may do with a task. `complete` and `reopen` are optional because
/// older servers only send the first four flags.
@immutable
class TaskCan {
  const TaskCan({
    this.edit = false,
    this.progress = false,
    this.approve = false,
    this.comment = false,
    this.complete,
    this.reopen,
    this.move,
  });

  final bool edit;
  final bool progress;
  final bool approve;
  final bool comment;
  final bool? complete;
  final bool? reopen;

  /// Optional: older servers do not send it (then [edit] decides).
  final bool? move;

  factory TaskCan.fromJson(Object? raw) {
    final j = asMap(raw);
    return TaskCan(
      edit: j['edit'] == true,
      progress: j['progress'] == true,
      approve: j['approve'] == true,
      comment: j['comment'] == true,
      complete: j['complete'] as bool?,
      reopen: j['reopen'] as bool?,
      move: j['move'] as bool?,
    );
  }
}

/// A task in full (`GET /tasks/{id}` and every mutation).
@immutable
class TaskOut extends TaskBrief {
  const TaskOut({
    required super.id,
    required super.subjectId,
    required super.title,
    super.status,
    super.priority,
    super.progress,
    super.dueAt,
    super.allDay,
    super.projectId,
    super.columnId,
    super.rank,
    super.ownerIds,
    super.myRoles,
    super.labelIds,
    super.checklist,
    super.unseen,
    super.updatedAt,
    this.description = '',
    this.creator,
    this.owners = const [],
    this.approvers = const [],
    this.followers = const [],
    this.checklistItems = const [],
    this.startAt,
    this.progressMode = ProgressMode.manual,
    this.version = 0,
    this.completedAt,
    this.createdAt,
    this.commentCount = 0,
    this.fileCount = 0,
    this.can = const TaskCan(),
  });

  final String description;
  final UserRef? creator;
  final List<UserRef> owners;
  final List<ApproverInfo> approvers;
  final List<UserRef> followers;
  final List<ChecklistItem> checklistItems;
  final DateTime? startAt;
  final String progressMode;
  final int version;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final int commentCount;
  final int fileCount;
  final TaskCan can;

  factory TaskOut.fromJson(Map<String, dynamic> j) {
    final b = TaskBrief.fromJson(j);
    return TaskOut(
      id: b.id,
      subjectId: b.subjectId,
      title: b.title,
      status: b.status,
      priority: b.priority,
      progress: b.progress,
      dueAt: b.dueAt,
      allDay: b.allDay,
      projectId: b.projectId,
      columnId: b.columnId,
      rank: b.rank,
      ownerIds: b.ownerIds,
      myRoles: b.myRoles,
      labelIds: b.labelIds,
      checklist: b.checklist,
      unseen: b.unseen,
      updatedAt: b.updatedAt,
      description: asString(asMap(j['description'])['text']),
      creator: UserRef.maybe(j['creator']),
      owners: [for (final e in asMapList(j['owners'])) UserRef.fromJson(e)],
      approvers: [
        for (final e in asMapList(j['approvers'])) ApproverInfo.fromJson(e),
      ]..sort((a, b) => a.position.compareTo(b.position)),
      followers: [
        for (final e in asMapList(j['followers'])) UserRef.fromJson(e),
      ],
      checklistItems: [
        for (final e in asMapList(j['checklist_items']))
          ChecklistItem.fromJson(e),
      ],
      startAt: parseDate(j['start_at']),
      progressMode: asString(j['progress_mode'], ProgressMode.manual),
      version: asInt(j['version']) ?? 0,
      completedAt: parseDate(j['completed_at']),
      createdAt: parseDate(j['created_at']),
      commentCount: asInt(j['comment_count']) ?? 0,
      fileCount: asInt(j['file_count']) ?? 0,
      can: TaskCan.fromJson(j['can']),
    );
  }

  bool get isActive => TaskStatus.isActive(status);

  bool get showComplete =>
      status == TaskStatus.open && (can.complete ?? can.progress);

  bool get showDecision => status == TaskStatus.awaitingApproval && can.approve;

  bool get showReopen =>
      (status == TaskStatus.done || status == TaskStatus.cancelled) &&
      (can.reopen ?? can.edit);

  bool get showCancel => isActive && can.edit;

  /// Move/copy between projects (copy needs only visibility, move the `move` right).
  bool get canMove => can.move ?? can.edit;

  bool get progressEditable =>
      isActive && can.progress && progressMode == ProgressMode.manual;

  bool get canTickChecklist => isActive && (can.progress || can.edit);

  bool get canEditChecklist => isActive && can.edit;

  /// The approver whose turn it is, while the task awaits approval.
  ApproverInfo? get currentApprover {
    if (status != TaskStatus.awaitingApproval) return null;
    return approvers.where((a) => a.pending).firstOrNull;
  }
}

/// What stops a draft from being saved.
enum DraftIssue { titleMissing, noOwner, dueBeforeStart }

/// The editable fields of a task, for the create/edit form.
@immutable
class TaskDraft {
  const TaskDraft({
    this.title = '',
    this.description = '',
    this.priority = TaskPriority.normal,
    this.startAt,
    this.dueAt,
    this.allDay = false,
    this.ownerIds = const [],
    this.approverIds = const [],
    this.followerIds = const [],
    this.checklist = const [],
    this.labelIds = const [],
    this.projectId,
    this.columnId,
    this.customerId,
  });

  final String title;
  final String description;
  final String priority;
  final DateTime? startAt;
  final DateTime? dueAt;
  final bool allDay;
  final List<int> ownerIds;
  final List<int> approverIds;
  final List<int> followerIds;
  final List<String> checklist;
  final List<int> labelIds;

  /// Target project (and column) of a new task; null creates a personal task.
  final String? projectId;
  final int? columnId;

  /// Customer file the new task is linked to (CRM).
  final String? customerId;

  factory TaskDraft.fromTask(TaskOut t) => TaskDraft(
    title: t.title,
    description: t.description,
    priority: t.priority,
    startAt: t.startAt?.toLocal(),
    dueAt: t.dueAt?.toLocal(),
    allDay: t.allDay,
    ownerIds: [for (final u in t.owners) u.id],
    approverIds: [for (final a in t.approvers) a.user.id],
    followerIds: [for (final u in t.followers) u.id],
    labelIds: t.labelIds,
  );

  /// Unset values keep the current ones; [clearStart]/[clearDue] reset a date to none.
  TaskDraft copyWith({
    String? title,
    String? description,
    String? priority,
    DateTime? startAt,
    DateTime? dueAt,
    bool clearStart = false,
    bool clearDue = false,
    bool? allDay,
    List<int>? ownerIds,
    List<int>? approverIds,
    List<int>? followerIds,
    List<String>? checklist,
    List<int>? labelIds,
    String? projectId,
    int? columnId,
    bool clearProject = false,
    String? customerId,
  }) => TaskDraft(
    title: title ?? this.title,
    description: description ?? this.description,
    priority: priority ?? this.priority,
    startAt: clearStart ? null : (startAt ?? this.startAt),
    dueAt: clearDue ? null : (dueAt ?? this.dueAt),
    allDay: allDay ?? this.allDay,
    ownerIds: ownerIds ?? this.ownerIds,
    approverIds: approverIds ?? this.approverIds,
    followerIds: followerIds ?? this.followerIds,
    checklist: checklist ?? this.checklist,
    labelIds: labelIds ?? this.labelIds,
    projectId: clearProject ? null : (projectId ?? this.projectId),
    columnId: clearProject ? null : (columnId ?? this.columnId),
    customerId: customerId ?? this.customerId,
  );

  Set<DraftIssue> get issues => {
    if (title.trim().isEmpty) DraftIssue.titleMissing,
    if (ownerIds.isEmpty) DraftIssue.noOwner,
    if (startAt != null && dueAt != null && dueAt!.isBefore(startAt!))
      DraftIssue.dueBeforeStart,
  };

  static String? _iso(DateTime? d) => d?.toUtc().toIso8601String();

  /// Body of `POST /tasks`.
  Map<String, dynamic> toCreateJson() => {
    'title': title.trim(),
    if (description.trim().isNotEmpty) 'description': {'text': description},
    'priority': priority,
    'start_at': ?_iso(startAt),
    'due_at': ?_iso(dueAt),
    'all_day': allDay,
    'owner_ids': ownerIds,
    'approver_ids': approverIds,
    'follower_ids': followerIds,
    'checklist': [
      for (final c in checklist)
        if (c.trim().isNotEmpty) c.trim(),
    ],
    'label_ids': labelIds,
    'project_id': projectId,
    if (projectId != null && columnId != null) 'column_id': columnId,
    'customer_id': ?customerId,
  };

  /// Fields of `PATCH /tasks/{id}` that differ from [t]; a cleared date is sent as null.
  Map<String, dynamic> patchAgainst(TaskOut t) => {
    if (title.trim() != t.title) 'title': title.trim(),
    if (description != t.description) 'description': {'text': description},
    if (priority != t.priority) 'priority': priority,
    if (!_same(startAt, t.startAt)) 'start_at': _iso(startAt),
    if (!_same(dueAt, t.dueAt)) 'due_at': _iso(dueAt),
    if (allDay != t.allDay) 'all_day': allDay,
  };

  static bool _same(DateTime? a, DateTime? b) =>
      a == null || b == null ? a == b : a.isAtSameMomentAs(b);

  /// True when owners, approvers or followers differ from [t].
  bool peopleChanged(TaskOut t) =>
      !listEquals(ownerIds, [for (final u in t.owners) u.id]) ||
      !listEquals(approverIds, [for (final a in t.approvers) a.user.id]) ||
      !listEquals(followerIds, [for (final u in t.followers) u.id]);
}
