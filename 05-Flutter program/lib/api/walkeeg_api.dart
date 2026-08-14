import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/cognito_auth.dart';
import '../config/app_config.dart';

class WalkeegApi {
  WalkeegApi(this.session);

  final CognitoSession session;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.idToken}',
      };

  Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/me'),
      headers: _headers,
    );
    return _parse(res);
  }

  Future<List<Map<String, dynamic>>> listSignals() async {
    final res = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/signals'),
      headers: _headers,
    );
    final data = _parse(res);
    return List<Map<String, dynamic>>.from(data['signals'] as List);
  }

  Future<Map<String, dynamic>> createSignal(Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/signals'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  Map<String, dynamic> _parse(http.Response res) {
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw Exception(data['error'] ?? 'API error ${res.statusCode}');
    }
    return data;
  }
}
