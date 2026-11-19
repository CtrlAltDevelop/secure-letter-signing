import 'package:flutter/foundation.dart';

import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/money.dart';

class FinanceKind {
  static const cash = 'cash';
  static const cheque = 'cheque';
  static const probable = 'probable';
  static const voided = 'void';

  /// Kinds a user can create (void is a status set through the void action).
  static const creatable = [cash, cheque, probable];
}

class FinanceDirection {
  static const receipt = 'receipt';
  static const payment = 'payment';
  static const all = [receipt, payment];
}

class FinanceStatus {
  static const confirmed = 'confirmed';
  static const pending = 'pending';
  static const voided = 'void';
  static const all = [confirmed, pending, voided];
}

/// A finance document (`DocOut`). Amounts are whole rials.
@immutable
class FinanceDoc {
  const FinanceDoc({
    required this.id,
    required this.subjectId,
    required this.kind,
    required this.direction,
    required this.amount,
    required this.date,
    required this.status,
    this.customerId,
    this.customerName,
    this.dueDate,
    this.description = '',
    this.overdue = false,
    this.createdBy,
    this.voidedBy,
    this.voidReason = '',
    this.labelIds = const [],
    this.fileCount = 0,
  });

  final String id;
  final String subjectId;
  final String? customerId;
  final String? customerName;
  final String kind;
  final String direction;
  final int amount;
  final DateTime date;
  final DateTime? dueDate;
  final String description;
  final String status;
  final bool overdue;
  final UserRef? createdBy;
  final UserRef? voidedBy;
  final String voidReason;
  final List<int> labelIds;
  final int fileCount;

  bool get isVoid => status == FinanceStatus.voided;
  bool get isPending => status == FinanceStatus.pending;
  bool get isReceipt => direction == FinanceDirection.receipt;

  /// The date the report files this document under: the due date while pending.
  DateTime get reportDate => isPending ? (dueDate ?? date) : date;

  factory FinanceDoc.fromJson(Map<String, dynamic> j) => FinanceDoc(
    id: asString(j['id']),
    subjectId: asString(j['subject_id']),
    customerId: j['customer_id'] as String?,
    customerName: j['customer_name'] as String?,
    kind: asString(j['kind'], FinanceKind.cash),
    direction: asString(j['direction'], FinanceDirection.receipt),
    amount: asInt(j['amount']) ?? 0,
    date: parseDay(j['date']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    dueDate: parseDay(j['due_date']),
    description: asString(asMap(j['description'])['text']),
    status: asString(j['status'], FinanceStatus.confirmed),
    overdue: j['overdue'] == true,
    createdBy: UserRef.maybe(j['created_by']),
    voidedBy: UserRef.maybe(j['voided_by']),
    voidReason: asString(asMap(j['void_reason'])['text']),
    labelIds: asIntList(j['label_ids']),
    fileCount: asInt(j['file_count']) ?? 0,
  );
}

/// The editable fields of a document (create and edit form).
@immutable
class FinanceDraft {
  const FinanceDraft({
    required this.kind,
    required this.direction,
    required this.amount,
    required this.date,
    this.dueDate,
    this.description = '',
    this.customerId,
  });

  final String kind;
  final String direction;
  final int amount;
  final DateTime date;
  final DateTime? dueDate;
  final String description;
  final String? customerId;

  bool get needsDueDate => kind != FinanceKind.cash;

  Map<String, dynamic> toCreateJson() => {
    'kind': kind,
    'direction': direction,
    'amount': amount,
    'date': dayIso(date),
    if (needsDueDate && dueDate != null) 'due_date': dayIso(dueDate!),
    'description': {'text': description},
    'customer_id': ?customerId,
  };

  /// Only the fields that differ from [d].
  Map<String, dynamic> toPatchJson(FinanceDoc d) => {
    if (kind != d.kind) 'kind': kind,
    if (direction != d.direction) 'direction': direction,
    if (amount != d.amount) 'amount': amount,
    if (dayIso(date) != dayIso(d.date)) 'date': dayIso(date),
    if (needsDueDate &&
        dueDate != null &&
        (d.dueDate == null || dayIso(dueDate!) != dayIso(d.dueDate!)))
      'due_date': dayIso(dueDate!),
    if (description != d.description) 'description': {'text': description},
  };
}

/// Filters of `GET /finance/docs`; empty values are not sent.
@immutable
class FinanceFilter {
  const FinanceFilter({
    this.q = '',
    this.kinds = const [],
    this.direction = '',
    this.statuses = const [],
    this.labelId,
    this.from,
    this.to,
    this.customerId = '',
  });

  final String q;
  final List<String> kinds;
  final String direction;
  final List<String> statuses;
  final int? labelId;
  final DateTime? from;
  final DateTime? to;
  final String customerId;

  bool get filtered =>
      q.isNotEmpty ||
      kinds.isNotEmpty ||
      direction.isNotEmpty ||
      statuses.isNotEmpty ||
      labelId != null;

  FinanceFilter copyWith({
    String? q,
    List<String>? kinds,
    String? direction,
    List<String>? statuses,
    int? labelId,
    bool clearLabel = false,
  }) => FinanceFilter(
    q: q ?? this.q,
    kinds: kinds ?? this.kinds,
    direction: direction ?? this.direction,
    statuses: statuses ?? this.statuses,
    labelId: clearLabel ? null : (labelId ?? this.labelId),
    from: from,
    to: to,
    customerId: customerId,
  );

  Map<String, Object?> toQuery({int limit = 100, int offset = 0}) => {
    'q': q,
    'kind': kinds.join(','),
    'direction': direction,
    'status': statuses.join(','),
    'label': labelId,
    'from': from == null ? null : dayIso(from!),
    'to': to == null ? null : dayIso(to!),
    'customer': customerId,
    'limit': limit,
    if (offset > 0) 'offset': offset,
  };
}

/// The six report figures of `Stats` plus the two nets.
@immutable
class FinanceStats {
  const FinanceStats({
    this.confirmedReceipts = 0,
    this.confirmedPayments = 0,
    this.probableReceipts = 0,
    this.probablePayments = 0,
    this.overdueReceipts = 0,
    this.overduePayments = 0,
    this.net = 0,
    this.projectedNet = 0,
  });

  final int confirmedReceipts;
  final int confirmedPayments;
  final int probableReceipts;
  final int probablePayments;
  final int overdueReceipts;
  final int overduePayments;
  final int net;
  final int projectedNet;

  factory FinanceStats.fromJson(Map<String, dynamic> j) => FinanceStats(
    confirmedReceipts: asInt(j['confirmed_receipts']) ?? 0,
    confirmedPayments: asInt(j['confirmed_payments']) ?? 0,
    probableReceipts: asInt(j['probable_receipts']) ?? 0,
    probablePayments: asInt(j['probable_payments']) ?? 0,
    overdueReceipts: asInt(j['overdue_receipts']) ?? 0,
    overduePayments: asInt(j['overdue_payments']) ?? 0,
    net: asInt(j['net']) ?? 0,
    projectedNet: asInt(j['projected_net']) ?? 0,
  );
}

/// One period of `GET /finance/summary`.
@immutable
class FinanceBucket {
  const FinanceBucket({
    required this.period,
    required this.stats,
    this.start,
    this.end,
    this.jalaliYear,
    this.jalaliMonth,
  });

  final String period;
  final FinanceStats stats;
  final DateTime? start;
  final DateTime? end;
  final int? jalaliYear;
  final int? jalaliMonth;

  factory FinanceBucket.fromJson(Map<String, dynamic> j) => FinanceBucket(
    period: asString(j['period']),
    stats: FinanceStats.fromJson(j),
    start: parseDay(j['start']),
    end: parseDay(j['end']),
    jalaliYear: asInt(j['jalali_year']),
    jalaliMonth: asInt(j['jalali_month']),
  );
}

@immutable
class FinanceSummary {
  const FinanceSummary({required this.totals, required this.buckets});
  final FinanceStats totals;
  final List<FinanceBucket> buckets;

  factory FinanceSummary.fromJson(Map<String, dynamic> j) => FinanceSummary(
    totals: FinanceStats.fromJson(asMap(j['totals'])),
    buckets: [
      for (final b in asMapList(j['buckets'])) FinanceBucket.fromJson(b),
    ],
  );
}

/// `GET /customers/{id}/finance`.
@immutable
class CustomerFinance {
  const CustomerFinance({required this.documents, required this.totals});
  final List<FinanceDoc> documents;
  final FinanceStats totals;

  factory CustomerFinance.fromJson(Map<String, dynamic> j) => CustomerFinance(
    documents: [
      for (final d in asMapList(j['documents'])) FinanceDoc.fromJson(d),
    ],
    totals: FinanceStats.fromJson(asMap(j['totals'])),
  );
}
