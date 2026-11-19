import 'package:flutter/foundation.dart';

import 'package:letter_signing/workspace/models.dart';

class CustomerKind {
  const CustomerKind._();
  static const person = 'person';
  static const company = 'company';
  static const all = [person, company];
}

class CustomerStatus {
  const CustomerStatus._();
  static const active = 'active';
  static const inactive = 'inactive';
  static const archived = 'archived';
  static const all = [active, inactive, archived];
}

class MemberRole {
  const MemberRole._();
  static const manager = 'manager';
  static const member = 'member';
  static const viewer = 'viewer';
  static const all = [manager, member, viewer];
}

/// A person on a customer file with their role.
@immutable
class CustomerMember {
  const CustomerMember({required this.user, required this.role});

  final UserRef user;
  final String role;

  factory CustomerMember.fromJson(Map<String, dynamic> j) => CustomerMember(
    user: UserRef.maybe(j['user']) ?? const UserRef(id: 0),
    role: asString(j['role'], MemberRole.member),
  );

  Map<String, dynamic> toJson() => {'user_id': user.id, 'role': role};
}

/// What the viewer may do on a customer file (`can` of `CustomerOut`).
@immutable
class CustomerCan {
  const CustomerCan({
    this.comment = false,
    this.label = false,
    this.link = false,
    this.event = false,
    this.call = false,
    this.edit = false,
    this.members = false,
  });

  final bool comment;
  final bool label;
  final bool link;
  final bool event;
  final bool call;
  final bool edit;
  final bool members;

  factory CustomerCan.fromJson(Object? raw) {
    final j = asMap(raw);
    bool f(String k) => j[k] == true;
    return CustomerCan(
      comment: f('comment'),
      label: f('label'),
      link: f('link'),
      event: f('event'),
      call: f('call'),
      edit: f('edit'),
      members: f('members'),
    );
  }
}

/// A customer file: `CustomerBrief` fields plus, when loaded with `GET /customers/{id}`, the
/// detail fields (address, notes, members, rights).
@immutable
class Customer {
  const Customer({
    required this.id,
    required this.subjectId,
    required this.name,
    this.kind = CustomerKind.person,
    this.legalName = '',
    this.nationalId = '',
    this.registrationNo = '',
    this.phone = '',
    this.mobile = '',
    this.email = '',
    this.status = CustomerStatus.active,
    this.ownerId = 0,
    this.myRole = '',
    this.labelIds = const [],
    this.unseen = false,
    this.address = '',
    this.notes = '',
    this.owner,
    this.members = const [],
    this.can = const CustomerCan(),
  });

  final String id;
  final String subjectId;
  final String name;
  final String kind;
  final String legalName;
  final String nationalId;
  final String registrationNo;
  final String phone;
  final String mobile;
  final String email;
  final String status;
  final int ownerId;
  final String myRole;
  final List<int> labelIds;
  final bool unseen;
  final String address;
  final String notes;
  final UserRef? owner;
  final List<CustomerMember> members;
  final CustomerCan can;

  bool get isCompany => kind == CustomerKind.company;

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
    id: asString(j['id']),
    subjectId: asString(j['subject_id']),
    name: asString(j['name']),
    kind: asString(j['kind'], CustomerKind.person),
    legalName: asString(j['legal_name']),
    nationalId: asString(j['national_id']),
    registrationNo: asString(j['registration_no']),
    phone: asString(j['phone']),
    mobile: asString(j['mobile']),
    email: asString(j['email']),
    status: asString(j['status'], CustomerStatus.active),
    ownerId: asInt(j['owner_id']) ?? 0,
    myRole: asString(j['my_role']),
    labelIds: asIntList(j['label_ids']),
    unseen: j['unseen'] == true,
    address: asString(asMap(j['address'])['text']),
    notes: asString(asMap(j['notes'])['text']),
    owner: UserRef.maybe(j['owner']),
    members: [
      for (final m in asMapList(j['members'])) CustomerMember.fromJson(m),
    ],
    can: CustomerCan.fromJson(j['can']),
  );
}

/// Filters of `GET /customers`; empty values are not sent.
@immutable
class CustomerFilter {
  const CustomerFilter({
    this.q = '',
    this.statuses = const {},
    this.kind = '',
    this.labelId,
    this.mine = false,
  });

  final String q;
  final Set<String> statuses;
  final String kind;
  final int? labelId;
  final bool mine;

  int get activeCount => [
    q.isNotEmpty,
    statuses.isNotEmpty,
    kind.isNotEmpty,
    labelId != null,
    mine,
  ].where((e) => e).length;

  CustomerFilter copyWith({
    String? q,
    Set<String>? statuses,
    String? kind,
    int? labelId,
    bool clearLabel = false,
    bool? mine,
  }) => CustomerFilter(
    q: q ?? this.q,
    statuses: statuses ?? this.statuses,
    kind: kind ?? this.kind,
    labelId: clearLabel ? null : (labelId ?? this.labelId),
    mine: mine ?? this.mine,
  );

  Map<String, Object?> toQuery({int limit = 50, int offset = 0}) => {
    'q': q,
    'status': (statuses.toList()..sort()).join(','),
    'kind': kind,
    'label': labelId,
    'mine': mine ? 'true' : null,
    'limit': limit,
    'offset': offset,
  };
}

/// The editable fields of a customer for the create/edit form.
@immutable
class CustomerDraft {
  const CustomerDraft({
    this.kind = CustomerKind.person,
    this.name = '',
    this.legalName = '',
    this.nationalId = '',
    this.registrationNo = '',
    this.phone = '',
    this.mobile = '',
    this.email = '',
    this.address = '',
    this.notes = '',
    this.status = CustomerStatus.active,
  });

  final String kind;
  final String name;
  final String legalName;
  final String nationalId;
  final String registrationNo;
  final String phone;
  final String mobile;
  final String email;
  final String address;
  final String notes;
  final String status;

  factory CustomerDraft.fromCustomer(Customer c) => CustomerDraft(
    kind: c.kind,
    name: c.name,
    legalName: c.legalName,
    nationalId: c.nationalId,
    registrationNo: c.registrationNo,
    phone: c.phone,
    mobile: c.mobile,
    email: c.email,
    address: c.address,
    notes: c.notes,
    status: c.status,
  );

  CustomerDraft copyWith({
    String? kind,
    String? name,
    String? legalName,
    String? nationalId,
    String? registrationNo,
    String? phone,
    String? mobile,
    String? email,
    String? address,
    String? notes,
    String? status,
  }) => CustomerDraft(
    kind: kind ?? this.kind,
    name: name ?? this.name,
    legalName: legalName ?? this.legalName,
    nationalId: nationalId ?? this.nationalId,
    registrationNo: registrationNo ?? this.registrationNo,
    phone: phone ?? this.phone,
    mobile: mobile ?? this.mobile,
    email: email ?? this.email,
    address: address ?? this.address,
    notes: notes ?? this.notes,
    status: status ?? this.status,
  );

  bool get nameMissing => name.trim().isEmpty;

  /// Body of `POST /customers`.
  Map<String, dynamic> toCreateJson() => {
    'kind': kind,
    'name': name.trim(),
    'legal_name': legalName.trim(),
    'national_id': nationalId.trim(),
    'registration_no': registrationNo.trim(),
    'phone': phone.trim(),
    'mobile': mobile.trim(),
    'email': email.trim(),
    'address': {'text': address},
    'notes': {'text': notes},
    'status': status,
  };

  /// Fields of `PATCH /customers/{id}` that differ from [c].
  Map<String, dynamic> patchAgainst(Customer c) => {
    if (kind != c.kind) 'kind': kind,
    if (name.trim() != c.name) 'name': name.trim(),
    if (legalName.trim() != c.legalName) 'legal_name': legalName.trim(),
    if (nationalId.trim() != c.nationalId) 'national_id': nationalId.trim(),
    if (registrationNo.trim() != c.registrationNo)
      'registration_no': registrationNo.trim(),
    if (phone.trim() != c.phone) 'phone': phone.trim(),
    if (mobile.trim() != c.mobile) 'mobile': mobile.trim(),
    if (email.trim() != c.email) 'email': email.trim(),
    if (address != c.address) 'address': {'text': address},
    if (notes != c.notes) 'notes': {'text': notes},
    if (status != c.status) 'status': status,
  };
}

class EventKind {
  const EventKind._();
  static const note = 'note';
  static const call = 'call';
  static const meeting = 'meeting';
  static const finance = 'finance';
  static const lead = 'lead';
  static const system = 'system';
  static const task = 'task';
  static const letter = 'letter';
}

/// One row of the customer timeline.
@immutable
class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.kind,
    required this.summary,
    this.at,
    this.by,
    this.refSubjectId,
  });

  final int id;
  final String kind;
  final String summary;
  final DateTime? at;
  final UserRef? by;
  final String? refSubjectId;

  factory TimelineEvent.fromJson(Map<String, dynamic> j) => TimelineEvent(
    id: asInt(j['id']) ?? 0,
    kind: asString(j['kind'], EventKind.note),
    summary: asString(j['summary']),
    at: parseDate(j['at']),
    by: UserRef.maybe(j['by']),
    refSubjectId: j['ref_subject_id'] as String?,
  );
}

/// A logged phone call.
@immutable
class CallReport {
  const CallReport({
    required this.id,
    required this.direction,
    this.contactName = '',
    this.summary = '',
    this.at,
    this.durationSeconds = 0,
    this.by,
  });

  static const incoming = 'in';
  static const outgoing = 'out';

  final int id;
  final String direction;
  final String contactName;
  final String summary;
  final DateTime? at;
  final int durationSeconds;
  final UserRef? by;

  factory CallReport.fromJson(Map<String, dynamic> j) => CallReport(
    id: asInt(j['id']) ?? 0,
    direction: asString(j['direction'], outgoing),
    contactName: asString(j['contact_name']),
    summary: asString(j['summary']),
    at: parseDate(j['at']),
    durationSeconds: asInt(j['duration_s']) ?? 0,
    by: UserRef.maybe(j['by']),
  );
}

/// Result of `POST /customers/import`.
@immutable
class ImportResult {
  const ImportResult({
    this.created = 0,
    this.skipped = 0,
    this.errors = const [],
  });

  final int created;
  final int skipped;

  /// `(row, message)` pairs; row 1 is the header.
  final List<(int, String)> errors;

  factory ImportResult.fromJson(Map<String, dynamic> j) => ImportResult(
    created: asInt(j['created']) ?? 0,
    skipped: asInt(j['skipped']) ?? 0,
    errors: [
      for (final e in asMapList(j['errors']))
        (asInt(e['row']) ?? 0, asString(e['message'])),
    ],
  );
}
