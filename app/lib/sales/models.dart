import 'package:flutter/foundation.dart';

import 'package:letter_signing/workspace/models.dart';

class LeadStatus {
  static const open = 'open';
  static const won = 'won';
  static const lost = 'lost';
  static const all = [open, won, lost];
}

/// Probability buckets of `probability_bucket`, as the server names them.
const leadBuckets = ['0-24', '25-49', '50-74', '75-100'];

/// A sales lead (`LeadOut`); [value] is in rials, [probability] 0-100.
@immutable
class Lead {
  const Lead({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.value,
    required this.probability,
    required this.weightedValue,
    required this.status,
    required this.owner,
    this.customerId,
    this.customerName,
    this.description = '',
    this.lostReason = '',
    this.labelIds = const [],
    this.canEdit = false,
  });

  final String id;
  final String subjectId;
  final String? customerId;
  final String? customerName;
  final String title;
  final int value;
  final int probability;
  final int weightedValue;
  final String status;
  final UserRef owner;
  final String description;
  final String lostReason;
  final List<int> labelIds;
  final bool canEdit;

  bool get isOpen => status == LeadStatus.open;

  factory Lead.fromJson(Map<String, dynamic> j) => Lead(
    id: asString(j['id']),
    subjectId: asString(j['subject_id']),
    customerId: j['customer_id'] as String?,
    customerName: j['customer_name'] as String?,
    title: asString(j['title']),
    value: asInt(j['value']) ?? 0,
    probability: asInt(j['probability']) ?? 0,
    weightedValue: asInt(j['weighted_value']) ?? 0,
    status: asString(j['status'], LeadStatus.open),
    owner: UserRef.maybe(j['owner']) ?? const UserRef(id: 0),
    description: asString(asMap(j['description'])['text']),
    lostReason: asString(asMap(j['lost_reason'])['text']),
    labelIds: asIntList(j['label_ids']),
    canEdit: j['can_edit'] == true,
  );
}

/// The editable fields of a lead.
@immutable
class LeadDraft {
  const LeadDraft({
    required this.title,
    required this.value,
    required this.probability,
    this.description = '',
    this.ownerId,
    this.customerId,
  });

  final String title;
  final int value;
  final int probability;
  final String description;
  final int? ownerId;
  final String? customerId;

  Map<String, dynamic> toCreateJson() => {
    'title': title,
    'value': value,
    'probability': probability,
    'description': {'text': description},
    'owner_id': ?ownerId,
    'customer_id': ?customerId,
  };

  /// Only the fields that differ from [l].
  Map<String, dynamic> toPatchJson(Lead l) => {
    if (title != l.title) 'title': title,
    if (value != l.value) 'value': value,
    if (probability != l.probability) 'probability': probability,
    if (description != l.description) 'description': {'text': description},
    if (ownerId != null && ownerId != l.owner.id) 'owner_id': ownerId,
  };
}

/// Filters of `GET /sales/leads`; empty values are not sent.
@immutable
class LeadFilter {
  const LeadFilter({
    this.q = '',
    this.statuses = const [],
    this.labelId,
    this.bucket = '',
    this.customerId = '',
  });

  final String q;
  final List<String> statuses;
  final int? labelId;
  final String bucket;
  final String customerId;

  LeadFilter copyWith({
    String? q,
    List<String>? statuses,
    int? labelId,
    bool clearLabel = false,
  }) => LeadFilter(
    q: q ?? this.q,
    statuses: statuses ?? this.statuses,
    labelId: clearLabel ? null : (labelId ?? this.labelId),
    bucket: bucket,
    customerId: customerId,
  );

  Map<String, Object?> toQuery({int limit = 100, int offset = 0}) => {
    'q': q,
    'status': statuses.join(','),
    'label': labelId,
    'probability_bucket': bucket,
    'customer': customerId,
    'limit': limit,
    if (offset > 0) 'offset': offset,
  };
}

/// `{count, value}` (and `weighted` for open leads) of the summary.
@immutable
class SalesTotal {
  const SalesTotal({this.count = 0, this.value = 0, this.weighted = 0});
  final int count;
  final int value;
  final int weighted;

  factory SalesTotal.fromJson(Object? raw) {
    final j = asMap(raw);
    return SalesTotal(
      count: asInt(j['count']) ?? 0,
      value: asInt(j['value']) ?? 0,
      weighted: asInt(j['weighted']) ?? 0,
    );
  }
}

/// One open-lead probability bucket of the summary.
@immutable
class SalesBucket {
  const SalesBucket({
    required this.bucket,
    required this.count,
    required this.value,
    required this.weighted,
  });
  final String bucket;
  final int count;
  final int value;
  final int weighted;

  factory SalesBucket.fromJson(Map<String, dynamic> j) => SalesBucket(
    bucket: asString(j['bucket']),
    count: asInt(j['count']) ?? 0,
    value: asInt(j['value']) ?? 0,
    weighted: asInt(j['weighted']) ?? 0,
  );
}

/// Won value of one Jalali month.
@immutable
class WonMonth {
  const WonMonth({
    required this.year,
    required this.month,
    required this.count,
    required this.value,
  });
  final int year;
  final int month;
  final int count;
  final int value;

  factory WonMonth.fromJson(Map<String, dynamic> j) => WonMonth(
    year: asInt(j['jalali_year']) ?? 0,
    month: asInt(j['jalali_month']) ?? 0,
    count: asInt(j['count']) ?? 0,
    value: asInt(j['value']) ?? 0,
  );
}

/// `GET /sales/summary`.
@immutable
class SalesSummary {
  const SalesSummary({
    required this.won,
    required this.open,
    required this.lost,
    required this.byProbability,
    required this.wonByMonth,
  });
  final SalesTotal won;
  final SalesTotal open;
  final SalesTotal lost;
  final List<SalesBucket> byProbability;
  final List<WonMonth> wonByMonth;

  factory SalesSummary.fromJson(Map<String, dynamic> j) => SalesSummary(
    won: SalesTotal.fromJson(j['won']),
    open: SalesTotal.fromJson(j['open']),
    lost: SalesTotal.fromJson(j['lost']),
    byProbability: [
      for (final b in asMapList(j['by_probability'])) SalesBucket.fromJson(b),
    ],
    wonByMonth: [
      for (final m in asMapList(j['won_by_month'])) WonMonth.fromJson(m),
    ],
  );
}
