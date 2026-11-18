import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/keys/key_models.dart';

/// Thin typed wrapper over the `/api/keys` endpoints.
class KeysApi {
  const KeysApi(this.api);
  final ApiClient api;

  List<Map<String, dynamic>> _maps(Object? json) =>
      [for (final e in json as List) e as Map<String, dynamic>];

  Future<UserKeyInfo> upload({
    required String deviceName,
    required Map<String, dynamic> signPub,
    required Map<String, dynamic> encPub,
    required String fingerprint,
  }) async => UserKeyInfo.fromJson(
    await api.call(
          'POST',
          '/keys',
          body: {
            'device_name': deviceName,
            'sign_pub': signPub,
            'enc_pub': encPub,
            'fingerprint': fingerprint,
          },
        )
        as Map<String, dynamic>,
  );

  Future<List<UserKeyInfo>> mine() async => [
    for (final j in _maps(await api.call('GET', '/keys/mine')))
      UserKeyInfo.fromJson(j),
  ];

  Future<List<UserKeyInfo>> pending() async => [
    for (final j in _maps(await api.call('GET', '/keys/pending')))
      UserKeyInfo.fromJson(j),
  ];

  Future<List<DirectoryUser>> directory() async => [
    for (final j in _maps(await api.call('GET', '/keys/directory')))
      DirectoryUser.fromJson(j),
  ];

  Future<void> approve(String keyId) => api.call('POST', '/keys/$keyId/approve');

  Future<void> retire(String keyId) => api.call('POST', '/keys/$keyId/retire');

  /// [kind] is `export` or `import`.
  Future<void> transferEvent(String keyId, String kind) =>
      api.call('POST', '/keys/$keyId/transfer-event', body: {'kind': kind});

  Future<List<CompanyWrap>> companyMine() async => [
    for (final j in _maps(await api.call('GET', '/keys/company/mine')))
      CompanyWrap(
        version: j['version'] as int,
        keyId: j['key_id'] as String,
        wrap: Map<String, dynamic>.from(j['wrap'] as Map),
      ),
  ];

  Future<List<UserKeyInfo>> companyMissing() async => [
    for (final j in _maps(await api.call('GET', '/keys/company/missing')))
      UserKeyInfo.fromJson(j),
  ];

  /// Current company key version (0 if none exists yet).
  Future<int> companyVersion() async =>
      ((await api.call('GET', '/keys/company/status')) as Map)['version']
          as int;

  Future<void> setCompanyKey(
    int version,
    List<({String keyId, Map<String, dynamic> wrap})> wraps,
  ) => api.call(
    'POST',
    '/keys/company',
    body: {
      'version': version,
      'wraps': [
        for (final w in wraps) {'key_id': w.keyId, 'wrap': w.wrap},
      ],
    },
  );
}
