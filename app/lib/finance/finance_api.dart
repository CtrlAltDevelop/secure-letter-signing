import 'package:letter_signing/finance/models.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/money.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// Typed access to `/finance`. Labels and files use the subject endpoints on [workspace].
/// Errors 403/404/409 are typed exceptions (409: the document is already void).
class FinanceApi {
  FinanceApi(this.workspace);

  final WorkspaceApi workspace;

  Future<FinanceDoc> _doc(String method, String path, {Object? body}) async =>
      FinanceDoc.fromJson(
        asMap(await workspace.call(method, path, body: body)),
      );

  Future<List<FinanceDoc>> list(
    FinanceFilter filter, {
    int limit = 100,
    int offset = 0,
  }) async {
    final q = WorkspaceApi.query(filter.toQuery(limit: limit, offset: offset));
    final data = await workspace.call('GET', '/finance/docs$q');
    return [for (final j in asMapList(data)) FinanceDoc.fromJson(j)];
  }

  Future<FinanceDoc> get(String id) => _doc('GET', '/finance/docs/$id');

  Future<FinanceDoc> create(FinanceDraft d) =>
      _doc('POST', '/finance/docs', body: d.toCreateJson());

  Future<FinanceDoc> patch(String id, Map<String, dynamic> fields) =>
      _doc('PATCH', '/finance/docs/$id', body: fields);

  Future<FinanceDoc> confirm(String id, {DateTime? date}) => _doc(
    'POST',
    '/finance/docs/$id/confirm',
    body: {'date': date == null ? null : dayIso(date)},
  );

  Future<FinanceDoc> voidDoc(String id, String reason) =>
      _doc('POST', '/finance/docs/$id/void', body: {'reason': reason});

  /// Jalali buckets by [groupBy] (`month` or `year`).
  Future<FinanceSummary> summary({
    String groupBy = 'month',
    int? labelId,
    DateTime? from,
    DateTime? to,
  }) async {
    final q = WorkspaceApi.query({
      'group_by': groupBy,
      'calendar': 'jalali',
      'label': labelId,
      'from': from == null ? null : dayIso(from),
      'to': to == null ? null : dayIso(to),
    });
    return FinanceSummary.fromJson(
      asMap(await workspace.call('GET', '/finance/summary$q')),
    );
  }

  Future<CustomerFinance> customer(String customerId) async =>
      CustomerFinance.fromJson(
        asMap(
          await workspace.call(
            'GET',
            '/customers/$customerId/finance?limit=100',
          ),
        ),
      );
}
