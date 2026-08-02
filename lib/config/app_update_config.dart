class AppUpdateConfig {
  const AppUpdateConfig._();

  static const String manifestUrl =
      'https://raw.githubusercontent.com/icecreamsoda213456/panpanskii-app-updates/main/update_manifest.json';

  static const Duration checkTimeout = Duration(seconds: 12);
  static const Duration downloadTimeout = Duration(minutes: 12);
  static const int minimumApkBytes = 64 * 1024;

  static bool get isConfigured {
    final uri = Uri.tryParse(manifestUrl);
    return !manifestUrl.contains('PASTE_') &&
        uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty;
  }
}
