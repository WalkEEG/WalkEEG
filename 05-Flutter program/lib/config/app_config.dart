/// WalkEEG cloud config — fill after `sam deploy`.
class AppConfig {
  static const region = 'us-west-2';
  static const userPoolId = 'us-west-2_dAEz0O1L6';
  static const userPoolClientId = '4matr1fcv1tik7lopqlt0o4gfg';
  static const identityPoolId = 'us-west-2:392942ae-68b2-449c-bfd8-7bb2cfdd0bbd';
  static const dataBucket = 'walkeeg-data-prod';
  static const apiBaseUrl =
      'https://bllirwud22.execute-api.us-west-2.amazonaws.com/prod';

  static String get userPoolProvider =>
      'cognito-idp.$region.amazonaws.com/$userPoolId';

  static bool get isConfigured =>
      !userPoolId.startsWith('REPLACE') &&
      !identityPoolId.startsWith('REPLACE');
}
