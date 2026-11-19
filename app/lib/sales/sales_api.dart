import 'package:letter_signing/sales/models.dart';
import 'package:letter_signing/workspace/models.dart';
import 'package:letter_signing/workspace/workspace_api.dart';

/// Typed access to `/sales`. Labels and files use the subject endpoints on [workspace].
/// Errors 403 (not owner/creator), 404, 409 (wrong state) are typed exceptions.
class SalesApi {
  SalesApi(this.workspace);

  final WorkspaceApi workspace;

  Future<Lead> _lead(String method, String path, {Object? body}) async =>
      Lead.fromJson(asMap(await workspace.call(method, path, body: body)));

  Future<List<Lead>> list(
    LeadFilter filter, {
    int limit = 100,
    int offset = 0,
  }) async {
    final q = WorkspaceApi.query(filter.toQuery(limit: limit, offset: offset));
    final data = await workspace.call('GET', '/sales/leads$q');
    return [for (final j in asMapList(data)) Lead.fromJson(j)];
  }

  Future<Lead> get(String id) => _lead('GET', '/sales/leads/$id');

  Future<Lead> create(LeadDraft d) =>
      _lead('POST', '/sales/leads', body: d.toCreateJson());

  Future<Lead> patch(String id, Map<String, dynamic> fields) =>
      _lead('PATCH', '/sales/leads/$id', body: fields);

  Future<Lead> win(String id) => _lead('POST', '/sales/leads/$id/win');

  Future<Lead> lose(String id, String reason) =>
      _lead('POST', '/sales/leads/$id/lose', body: {'reason': reason});

  Future<Lead> reopen(String id) => _lead('POST', '/sales/leads/$id/reopen');

  Future<SalesSummary> summary() async => SalesSummary.fromJson(
    asMap(await workspace.call('GET', '/sales/summary')),
  );

  Future<List<Lead>> forCustomer(String customerId) async => [
    for (final j in asMapList(
      await workspace.call('GET', '/customers/$customerId/leads'),
    ))
      Lead.fromJson(j),
  ];
}
