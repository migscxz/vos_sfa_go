// lib/core/api/global_remote_api.dart

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class GlobalRemoteApi {
  final http.Client _client = http.Client();

  /// Generic fetch for a collection endpoint.
  ///
  /// Supports multiple API response shapes:
  /// 1) Directus: { "data": [ ... ] }
  /// 2) Custom:  { "rows": [ ... ] }
  /// 3) Mixed:   { "data": { "rows": [ ... ] } }
  Future<List<Map<String, dynamic>>> fetchList(
      String endpoint, {
        Map<String, String>? query,
      }) async {
    final baseUri = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    final mergedQuery = <String, String>{
      'limit': '-1',
      if (query != null) ...query,
    };

    final uri = baseUri.replace(queryParameters: mergedQuery);

    print('Fetching: $uri');

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch $endpoint. Status: ${response.statusCode}. Body: ${response.body}',
      );
    }

    final decodedAny = jsonDecode(response.body);

    if (decodedAny is List) {
      // Some APIs return the list directly
      return decodedAny.whereType<Map<String, dynamic>>().toList(growable: false);
    }

    if (decodedAny is! Map<String, dynamic>) {
      return <Map<String, dynamic>>[];
    }

    // --- 1) Directus standard: { data: [ ... ] }
    final data = decodedAny['data'];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList(growable: false);
    }

    // --- 2) Your custom units format: { rows: [ ... ] }
    final rows = decodedAny['rows'];
    if (rows is List) {
      return rows.whereType<Map<String, dynamic>>().toList(growable: false);
    }

    // --- 3) Sometimes: { data: { rows: [ ... ] } }
    if (data is Map<String, dynamic>) {
      final innerRows = data['rows'];
      if (innerRows is List) {
        return innerRows.whereType<Map<String, dynamic>>().toList(growable: false);
      }
    }

    return <Map<String, dynamic>>[];
  }

  void dispose() {
    _client.close();
  }
}
