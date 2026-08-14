import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class CognitoSession {
  CognitoSession({
    required this.idToken,
    required this.accessToken,
    required this.refreshToken,
    required this.identityId,
    required this.userId,
    required this.email,
    required this.name,
  });

  final String idToken;
  final String accessToken;
  final String refreshToken;
  final String identityId;
  final String userId;
  final String email;
  final String name;
}

class AwsCredentials {
  AwsCredentials({
    required this.accessKeyId,
    required this.secretAccessKey,
    required this.sessionToken,
    required this.expiration,
  });

  final String accessKeyId;
  final String secretAccessKey;
  final String sessionToken;
  final DateTime expiration;
}

class CognitoAuth {
  static const _kIdToken = 'walkeeg_id_token';
  static const _kAccessToken = 'walkeeg_access_token';
  static const _kRefreshToken = 'walkeeg_refresh_token';
  static const _kIdentityId = 'walkeeg_identity_id';
  static const _kUser = 'walkeeg_user';

  Future<Map<String, dynamic>> _idpRequest(
    String target,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse(
      'https://cognito-idp.${AppConfig.region}.amazonaws.com/',
    );
    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': target,
      },
      body: jsonEncode(body),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Cognito error');
    }
    return data;
  }

  Future<Map<String, dynamic>> _identityRequest(
    String target,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse(
      'https://cognito-identity.${AppConfig.region}.amazonaws.com/',
    );
    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': target,
      },
      body: jsonEncode(body),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Identity error');
    }
    return data;
  }

  Future<String> _getIdentityId(String idToken) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_kIdentityId);
    if (cached != null && cached.isNotEmpty) return cached;

    final data = await _identityRequest(
      'AWSCognitoIdentityService.GetId',
      {
        'IdentityPoolId': AppConfig.identityPoolId,
        'Logins': {AppConfig.userPoolProvider: idToken},
      },
    );
    final identityId = data['IdentityId'] as String;
    await prefs.setString(_kIdentityId, identityId);
    return identityId;
  }

  Future<CognitoSession> login(String email, String password) async {
    final data = await _idpRequest(
      'AWSCognitoIdentityProviderService.InitiateAuth',
      {
        'AuthFlow': 'USER_PASSWORD_AUTH',
        'ClientId': AppConfig.userPoolClientId,
        'AuthParameters': {'USERNAME': email, 'PASSWORD': password},
      },
    );
    final ar = data['AuthenticationResult'] as Map<String, dynamic>;
    final idToken = ar['IdToken'] as String;
    final identityId = await _getIdentityId(idToken);
    final payload = _decodeJwt(idToken);

    final session = CognitoSession(
      idToken: idToken,
      accessToken: ar['AccessToken'] as String,
      refreshToken: ar['RefreshToken'] as String? ?? '',
      identityId: identityId,
      userId: payload['sub'] as String,
      email: payload['email'] as String? ?? email,
      name: payload['name'] as String? ?? email.split('@').first,
    );
    await _saveSession(session);
    return session;
  }

  Future<CognitoSession> register(
    String name,
    String email,
    String password,
  ) async {
    await _idpRequest(
      'AWSCognitoIdentityProviderService.SignUp',
      {
        'ClientId': AppConfig.userPoolClientId,
        'Username': email,
        'Password': password,
        'UserAttributes': [
          {'Name': 'email', 'Value': email},
          {'Name': 'name', 'Value': name},
        ],
      },
    );
    return login(email, password);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kIdToken);
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
    await prefs.remove(_kIdentityId);
    await prefs.remove(_kUser);
  }

  Future<CognitoSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final idToken = prefs.getString(_kIdToken);
    if (idToken == null) return null;
    final userJson = prefs.getString(_kUser);
    if (userJson == null) return null;
    final user = jsonDecode(userJson) as Map<String, dynamic>;
    var session = CognitoSession(
      idToken: idToken,
      accessToken: prefs.getString(_kAccessToken) ?? '',
      refreshToken: prefs.getString(_kRefreshToken) ?? '',
      identityId: prefs.getString(_kIdentityId) ?? '',
      userId: user['userId'] as String,
      email: user['email'] as String,
      name: user['name'] as String,
    );
    if (_isJwtExpired(session.idToken, skewSeconds: 60)) {
      try {
        session = await refreshSession(session);
      } catch (_) {
        await logout();
        return null;
      }
    }
    return session;
  }

  bool _isJwtExpired(String token, {int skewSeconds = 0}) {
    final payload = _decodeJwt(token);
    final exp = payload['exp'];
    if (exp is! num) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now + skewSeconds >= exp.toInt();
  }

  Future<CognitoSession> refreshSession(CognitoSession session) async {
    if (session.refreshToken.isEmpty) {
      throw Exception('Session expired. Please sign in again.');
    }
    final data = await _idpRequest(
      'AWSCognitoIdentityProviderService.InitiateAuth',
      {
        'AuthFlow': 'REFRESH_TOKEN_AUTH',
        'ClientId': AppConfig.userPoolClientId,
        'AuthParameters': {'REFRESH_TOKEN': session.refreshToken},
      },
    );
    final ar = data['AuthenticationResult'] as Map<String, dynamic>;
    final idToken = ar['IdToken'] as String;
    final identityId = session.identityId.isNotEmpty
        ? session.identityId
        : await _getIdentityId(idToken);
    final payload = _decodeJwt(idToken);
    final refreshed = CognitoSession(
      idToken: idToken,
      accessToken: ar['AccessToken'] as String? ?? session.accessToken,
      refreshToken: ar['RefreshToken'] as String? ?? session.refreshToken,
      identityId: identityId,
      userId: payload['sub'] as String? ?? session.userId,
      email: payload['email'] as String? ?? session.email,
      name: payload['name'] as String? ?? session.name,
    );
    await _saveSession(refreshed);
    return refreshed;
  }

  Future<CognitoSession> ensureFreshSession(CognitoSession session) async {
    if (!_isJwtExpired(session.idToken, skewSeconds: 120)) return session;
    return refreshSession(session);
  }

  Future<AwsCredentials> getCredentials(CognitoSession session) async {
    session = await ensureFreshSession(session);
    final data = await _identityRequest(
      'AWSCognitoIdentityService.GetCredentialsForIdentity',
      {
        'IdentityId': session.identityId,
        'Logins': {AppConfig.userPoolProvider: session.idToken},
      },
    );
    final creds = data['Credentials'] as Map<String, dynamic>;
    return AwsCredentials(
      accessKeyId: creds['AccessKeyId'] as String,
      secretAccessKey: creds['SecretKey'] as String,
      sessionToken: creds['SessionToken'] as String,
      expiration: _parseAwsTimestamp(creds['Expiration']),
    );
  }

  /// AWS Timestamp may be ISO-8601 string or Unix seconds (num/double).
  static DateTime _parseAwsTimestamp(dynamic value) {
    if (value is String) return DateTime.parse(value);
    if (value is num) {
      final n = value.toDouble();
      // Heuristic: ms since epoch vs seconds since epoch.
      if (n > 1e12) {
        return DateTime.fromMillisecondsSinceEpoch(n.round());
      }
      return DateTime.fromMillisecondsSinceEpoch((n * 1000).round());
    }
    throw FormatException('Invalid AWS timestamp: $value (${value.runtimeType})');
  }

  Future<void> _saveSession(CognitoSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kIdToken, session.idToken);
    await prefs.setString(_kAccessToken, session.accessToken);
    await prefs.setString(_kRefreshToken, session.refreshToken);
    await prefs.setString(_kIdentityId, session.identityId);
    await prefs.setString(
      _kUser,
      jsonEncode({
        'userId': session.userId,
        'email': session.email,
        'name': session.name,
      }),
    );
  }

  Map<String, dynamic> _decodeJwt(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return {};
    final normalized = base64Url.normalize(parts[1]);
    return jsonDecode(utf8.decode(base64Url.decode(normalized)))
        as Map<String, dynamic>;
  }
}
