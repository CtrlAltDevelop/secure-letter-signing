import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/tasks/models.dart';
import 'package:letter_signing/workspace/models.dart';

/// Project lifecycle values as the server sends them.
class ProjectStatus {
  const ProjectStatus._();
  static const active = 'active';
  static const done = 'done';
  static const archived = 'archived';
  static const all = [active, done, archived];
}

class ProjectRole {
  const ProjectRole._();
  static const manager = 'manager';
  static const member = 'member';
  static const viewer = 'viewer';
  static const all = [manager, member, viewer];
}

class ColumnKind {
  const ColumnKind._();
  static const todo = 'todo';
  static const doing = 'doing';
  static const done = 'done';
}

/// Colours a project card can have (the server stores an index 0..31).
const projectPalette = [
  Color(0xFF4C8DFF),
  Color(0xFF4CD8B9),
  Color(0xFFCFA44B),
  Color(0xFFD65959),
  Color(0xFFA06CD5),
  Color(0xFFE07BB5),
  Color(0xFF5BBAD5),
  Color(0xFF8A94A6),
];

Color projectColor(int index) =>
    projectPalette[index.abs() % projectPalette.length];

DateTime? _dateOnly(Object? value) {
  final d = parseDate(value);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

String _two(int n) => n.toString().padLeft(2, '0');

String? _dateString(DateTime? d) =>
    d == null ? null : '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// A folder that groups projects: organisation-wide or personal.
@immutable
class ProjectGroup {
  const ProjectGroup({
    required this.id,
    required this.name,
    this.scope = 'org',
    this.rank = 0,
    this.active = true,
  });

  final int id;
  final String name;
  final String scope;
  final int rank;
  final bool active;

  bool get isOrg => scope == 'org';

  factory ProjectGroup.fromJson(Map<String, dynamic> j) => ProjectGroup(
    id: asInt(j['id']) ?? 0,
    name: asString(j['name']),
    scope: asString(j['scope'], 'org'),
    rank: asInt(j['rank']) ?? 0,
    active: j['active'] != false,
  );
}

/// A project as the list shows it (`GET /projects`).
@immutable
class ProjectBrief {
  const ProjectBrief({
    required this.id,
    required this.subjectId,
    required this.name,
    this.color = 0,
    this.status = ProjectStatus.active,
    this.groupId,
    this.ownerId = 0,
    this.progress = 0,
    this.startDate,
    this.endDate,
    this.myRole = ProjectRole.member,
    this.memberCount = 0,
    this.updatedAt,
  });

  final String id;
  final String subjectId;
  final String name;
  final int color;
  final String status;
  final int? groupId;
  final int ownerId;
  final int progress;
  final DateTime? startDate;
  final DateTime? endDate;
  final String myRole;
  final int memberCount;
  final DateTime? updatedAt;

  bool get isArchived => status == ProjectStatus.archived;
  bool get isManager => myRole == ProjectRole.manager;

  factory ProjectBrief.fromJson(Map<String, dynamic> j) => ProjectBrief(
    id: asString(j['id']),
    subjectId: asString(j['subject_id']),
    name: asString(j['name']),
    color: asInt(j['color']) ?? 0,
    status: asString(j['status'], ProjectStatus.active),
    groupId: asInt(j['group_id']),
    ownerId: asInt(j['owner_id']) ?? 0,
    progress: (asInt(j['progress']) ?? 0).clamp(0, 100),
    startDate: _dateOnly(j['start_date']),
    endDate: _dateOnly(j['end_date']),
    myRole: asString(j['my_role'], ProjectRole.member),
    memberCount: asInt(j['member_count']) ?? 0,
    updatedAt: parseDate(j['updated_at']),
  );
}

@immutable
class ProjectMember {
  const ProjectMember({required this.user, required this.role});

  final UserRef user;
  final String role;

  factory ProjectMember.fromJson(Map<String, dynamic> j) => ProjectMember(
    user: UserRef.maybe(j['user']) ?? const UserRef(id: 0),
    role: asString(j['role'], ProjectRole.member),
  );
}

@immutable
class ProjectColumn {
  const ProjectColumn({
    required this.id,
    required this.title,
    this.kind = ColumnKind.doing,
    this.rank = 0,
    this.taskCount = 0,
  });

  final int id;
  final String title;
  final String kind;
  final int rank;
  final int taskCount;

  factory ProjectColumn.fromJson(Map<String, dynamic> j) => ProjectColumn(
    id: asInt(j['id']) ?? 0,
    title: asString(j['title']),
    kind: asString(j['kind'], ColumnKind.doing),
    rank: asInt(j['rank']) ?? 0,
    taskCount: asInt(j['task_count']) ?? 0,
  );

  static List<ProjectColumn> parseAll(Object? raw) => [
    for (final j in asMapList(raw)) ProjectColumn.fromJson(j),
  ];
}

/// What the current user may do with a project.
@immutable
class ProjectCan {
  const ProjectCan({
    this.see = false,
    this.comment = false,
    this.edit = false,
    this.moderate = false,
    this.createTask = false,
  });

  final bool see;
  final bool comment;
  final bool edit;
  final bool moderate;
  final bool createTask;

  factory ProjectCan.fromJson(Object? raw) {
    final j = asMap(raw);
    return ProjectCan(
      see: j['see'] == true,
      comment: j['comment'] == true,
      edit: j['edit'] == true,
      moderate: j['moderate'] == true,
      createTask: j['create_task'] == true,
    );
  }
}

/// A project in full (`GET /projects/{id}` and every mutation).
@immutable
class ProjectOut extends ProjectBrief {
  const ProjectOut({
    required super.id,
    required super.subjectId,
    required super.name,
    super.color,
    super.status,
    super.groupId,
    super.ownerId,
    super.progress,
    super.startDate,
    super.endDate,
    super.myRole,
    super.memberCount,
    super.updatedAt,
    this.description = '',
    this.owner,
    this.members = const [],
    this.columns = const [],
    this.can = const ProjectCan(),
  });

  final String description;
  final UserRef? owner;
  final List<ProjectMember> members;
  final List<ProjectColumn> columns;
  final ProjectCan can;

  factory ProjectOut.fromJson(Map<String, dynamic> j) {
    final b = ProjectBrief.fromJson(j);
    return ProjectOut(
      id: b.id,
      subjectId: b.subjectId,
      name: b.name,
      color: b.color,
      status: b.status,
      groupId: b.groupId,
      ownerId: b.ownerId,
      progress: b.progress,
      startDate: b.startDate,
      endDate: b.endDate,
      myRole: b.myRole,
      memberCount: b.memberCount,
      updatedAt: b.updatedAt,
      description: asString(asMap(j['description'])['text']),
      owner: UserRef.maybe(j['owner']),
      members: [
        for (final m in asMapList(j['members'])) ProjectMember.fromJson(m),
      ],
      columns: ProjectColumn.parseAll(j['columns']),
      can: ProjectCan.fromJson(j['can']),
    );
  }

  /// Members who may be given tasks (everyone but viewers).
  List<UserRef> get assignable => [
    for (final m in members)
      if (m.role != ProjectRole.viewer) m.user,
  ];
}

/// A column of the board together with its tasks.
@immutable
class BoardColumn {
  const BoardColumn({
    required this.id,
    required this.title,
    this.kind = ColumnKind.doing,
    this.rank = 0,
    this.tasks = const [],
  });

  final int id;
  final String title;
  final String kind;
  final int rank;
  final List<TaskBrief> tasks;

  factory BoardColumn.fromJson(Map<String, dynamic> j) => BoardColumn(
    id: asInt(j['id']) ?? 0,
    title: asString(j['title']),
    kind: asString(j['kind'], ColumnKind.doing),
    rank: asInt(j['rank']) ?? 0,
    tasks: [for (final t in asMapList(j['tasks'])) TaskBrief.fromJson(t)],
  );

  BoardColumn copyWith({String? title, List<TaskBrief>? tasks}) => BoardColumn(
    id: id,
    title: title ?? this.title,
    kind: kind,
    rank: rank,
    tasks: tasks ?? this.tasks,
  );

  /// Share of finished tasks in 0..100 (cancelled tasks do not count).
  int get percentDone {
    final counted = tasks.where((t) => t.status != TaskStatus.cancelled);
    if (counted.isEmpty) return 0;
    final done = counted.where((t) => t.status == TaskStatus.done).length;
    return (done * 100 / counted.length).round();
  }
}

/// One attachment of a project (`GET /projects/{id}/files`).
@immutable
class ProjectFile {
  const ProjectFile({
    required this.id,
    required this.name,
    this.contentType = '',
    this.size = 0,
    this.taskId,
    this.taskTitle = '',
    this.uploadedBy,
    this.createdAt,
  });

  final String id;
  final String name;
  final String contentType;
  final int size;
  final String? taskId;
  final String taskTitle;
  final UserRef? uploadedBy;
  final DateTime? createdAt;

  factory ProjectFile.fromJson(Map<String, dynamic> j) => ProjectFile(
    id: asString(j['id']),
    name: asString(j['name']),
    contentType: asString(j['content_type']),
    size: asInt(j['size']) ?? 0,
    taskId: j['task_id'] as String?,
    taskTitle: asString(j['task_title']),
    uploadedBy: UserRef.maybe(j['uploaded_by']),
    createdAt: parseDate(j['created_at']),
  );

  FileInfo get asFileInfo => FileInfo(
    id: id,
    name: name,
    contentType: contentType,
    size: size,
    uploadedBy: uploadedBy,
    createdAt: createdAt,
  );
}

/// A member of the project form: who and with which role.
@immutable
class MemberDraft {
  const MemberDraft(this.userId, this.role);
  final int userId;
  final String role;

  Map<String, dynamic> toJson() => {'user_id': userId, 'role': role};
}

enum ProjectIssue { nameMissing, endBeforeStart }

/// The editable fields of a project, for the create/edit form.
@immutable
class ProjectDraft {
  const ProjectDraft({
    this.name = '',
    this.description = '',
    this.groupId,
    this.color = 0,
    this.startDate,
    this.endDate,
    this.members = const [],
  });

  final String name;
  final String description;
  final int? groupId;
  final int color;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<MemberDraft> members;

  factory ProjectDraft.fromProject(ProjectOut p) => ProjectDraft(
    name: p.name,
    description: p.description,
    groupId: p.groupId,
    color: p.color,
    startDate: p.startDate,
    endDate: p.endDate,
    members: [for (final m in p.members) MemberDraft(m.user.id, m.role)],
  );

  ProjectDraft copyWith({
    String? name,
    String? description,
    int? groupId,
    bool clearGroup = false,
    int? color,
    DateTime? startDate,
    DateTime? endDate,
    bool clearStart = false,
    bool clearEnd = false,
    List<MemberDraft>? members,
  }) => ProjectDraft(
    name: name ?? this.name,
    description: description ?? this.description,
    groupId: clearGroup ? null : (groupId ?? this.groupId),
    color: color ?? this.color,
    startDate: clearStart ? null : (startDate ?? this.startDate),
    endDate: clearEnd ? null : (endDate ?? this.endDate),
    members: members ?? this.members,
  );

  Set<ProjectIssue> get issues => {
    if (name.trim().isEmpty) ProjectIssue.nameMissing,
    if (startDate != null && endDate != null && endDate!.isBefore(startDate!))
      ProjectIssue.endBeforeStart,
  };

  /// Body of `POST /projects`.
  Map<String, dynamic> toCreateJson() => {
    'name': name.trim(),
    if (description.trim().isNotEmpty) 'description': {'text': description},
    'group_id': groupId,
    'color': color,
    'start_date': _dateString(startDate),
    'end_date': _dateString(endDate),
    'members': [for (final m in members) m.toJson()],
  };

  /// Fields of `PATCH /projects/{id}` that differ from [p].
  Map<String, dynamic> patchAgainst(ProjectOut p) => {
    if (name.trim() != p.name) 'name': name.trim(),
    if (description != p.description) 'description': {'text': description},
    if (groupId != p.groupId) 'group_id': groupId,
    if (color != p.color) 'color': color,
    if (startDate != p.startDate) 'start_date': _dateString(startDate),
    if (endDate != p.endDate) 'end_date': _dateString(endDate),
  };

  /// True when the member list differs from [p]'s.
  bool membersChanged(ProjectOut p) {
    final mine = {for (final m in members) m.userId: m.role};
    final theirs = {for (final m in p.members) m.user.id: m.role};
    return !mapEquals(mine, theirs);
  }
}
