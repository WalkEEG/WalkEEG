/// Raised when a cloud call runs before `lib/config/app_config.dart` holds
/// real deployment values (it ships as a git-ignored copy of the `.example`
/// template, so placeholders are the normal state for a fresh clone).
///
/// Callers should surface [toString] to the user. This is a setup condition,
/// not a network or credentials failure — local recording is unaffected.
class CloudNotConfiguredException implements Exception {
  const CloudNotConfiguredException([this.feature = 'cloud']);

  final String feature;

  @override
  String toString() =>
      'Cloud not configured ($feature): fill in lib/config/app_config.dart '
      'after `sam deploy`. Local recording still works.';
}
