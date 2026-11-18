import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:letter_signing/api/api_client.dart';

void main() {
  test('refreshes once on 401 and retries with the new access token', () async {
    final store = MemoryTokenStore();
    await store.writeRefresh('r1');
    var refreshes = 0;
    final client = MockClient((req) async {
      if (req.url.path == '/api/auth/refresh') {
        refreshes++;
        return http.Response(
          jsonEncode({'access': 'a2', 'refresh': 'r2'}),
          200,
        );
      }
      final ok = req.headers['Authorization'] == 'Bearer a2';
      return http.Response(
        jsonEncode(ok ? {'ok': true} : {'detail': 'no'}),
        ok ? 200 : 401,
      );
    });
    final api = ApiClient(baseUrl: 'http://x', store: store, client: client);

    final results = await Future.wait([
      api.call('GET', '/me'),
      api.call('GET', '/me'),
    ]);

    expect(results.map((r) => (r as Map)['ok']), [true, true]);
    expect(refreshes, 1);
    expect(await store.readRefresh(), 'r2');
  });
}
