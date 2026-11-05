/// TEMPLATE — copy this file to `app_config.dart` and fill in your own
/// values after running `sam deploy`.
///
///   cp lib/config/app_config.example.dart lib/config/app_config.dart
///
/// `app_config.dart` is git-ignored so your deployment values stay local.
/// The app compiles and runs with these placeholder values; cloud features
/// (login, API sync, S3 upload) report "not configured" until you fill them in.
class AppConfig {
  static const region = 'us-west-2';
  static const userPoolId = 'us-west-2_XXXXXXXXX';
  static const userPoolClientId = 'xxxxxxxxxxxxxxxxxxxxxxxxxx';
  static const identityPoolId = 'us-west-2:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx';
  static const dataBucket = 'walkeeg-data-prod';
  static const apiBaseUrl =
      'https://xxxxxxxxxx.execute-api.us-west-2.amazonaws.com/prod';

  /// Cognito issuer string, in the form
  /// `cognito-idp.<region>.amazonaws.com/<userPoolId>`.
  static String get userPoolProvider =>
      'cognito-idp.$region.amazonaws.com/$userPoolId';

  /// False while any identifier still holds a placeholder value.
  /// Cloud code paths must check this before calling AWS.
  static bool get isConfigured =>
      !userPoolId.contains('XXXX') &&
      !userPoolClientId.contains('xxxx') &&
      !identityPoolId.contains('xxxx') &&
      !apiBaseUrl.contains('xxxxxxxxxx');
}
