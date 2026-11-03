/// TEMPLATE — copy this file to `app_config.dart` and fill in your own
/// values after running `sam deploy`.
///
///   cp lib/config/app_config.example.dart lib/config/app_config.dart
///
/// `app_config.dart` is git-ignored so your deployment values stay local.
class AppConfig {
  static const region = 'us-west-2';
  static const userPoolId = 'us-west-2_XXXXXXXXX';
  static const userPoolClientId = 'xxxxxxxxxxxxxxxxxxxxxxxxxx';
  static const identityPoolId = 'us-west-2:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx';
  static const dataBucket = 'walkeeg-data-prod';
  static const apiBaseUrl =
      'https://xxxxxxxxxx.execute-api.us-west-2.amazonaws.com/prod';
}
