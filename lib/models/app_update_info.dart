class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.versionCode,
    required this.apkUrl,
    required this.title,
    required this.message,
    required this.changes,
    required this.forceUpdate,
    this.sha256,
  });

  factory AppUpdateInfo.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Update manifest must be a JSON object.');
    }

    final version = _requiredString(value, 'version', maxLength: 40);
    final versionCode = _requiredVersionCode(value['versionCode']);
    final apkUrl = _requiredHttpsUrl(value, 'apkUrl');
    final title = _requiredString(value, 'title', maxLength: 100);
    final message = _requiredString(value, 'message', maxLength: 600);
    final changesValue = value['changes'];
    final changes = changesValue is List
        ? changesValue
            .whereType<String>()
            .map((change) => change.trim())
            .where((change) => change.isNotEmpty)
            .map(
              (change) => change.length <= 180
                  ? change
                  : '${change.substring(0, 177)}...',
            )
            .take(20)
            .toList(growable: false)
        : const <String>[];
    final forceUpdate = value['forceUpdate'];
    if (forceUpdate != null && forceUpdate is! bool) {
      throw const FormatException('forceUpdate must be true or false.');
    }

    final rawSha256 = value['sha256'];
    String? sha256;
    if (rawSha256 != null) {
      if (rawSha256 is! String ||
          !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(rawSha256.trim())) {
        throw const FormatException(
            'sha256 must contain 64 hexadecimal characters.');
      }
      sha256 = rawSha256.trim().toLowerCase();
    }

    return AppUpdateInfo(
      version: version,
      versionCode: versionCode,
      apkUrl: apkUrl,
      title: title,
      message: message,
      changes: changes,
      forceUpdate: forceUpdate as bool? ?? false,
      sha256: sha256,
    );
  }

  final String version;
  final int versionCode;
  final String apkUrl;
  final String title;
  final String message;
  final List<String> changes;
  final bool forceUpdate;
  final String? sha256;

  Uri get apkUri => Uri.parse(apkUrl);

  static String _requiredString(
    Map<String, dynamic> value,
    String key, {
    int maxLength = 4096,
  }) {
    final field = value[key];
    if (field is! String || field.trim().isEmpty) {
      throw FormatException('$key is required.');
    }
    final cleanValue = field.trim();
    if (cleanValue.length > maxLength) {
      throw FormatException('$key is too long.');
    }
    return cleanValue;
  }

  static int _requiredVersionCode(Object? value) {
    final versionCode = switch (value) {
      int code => code,
      num code when code.isFinite && code == code.truncate() => code.toInt(),
      String code => int.tryParse(code),
      _ => null,
    };
    if (versionCode == null || versionCode <= 0) {
      throw const FormatException('versionCode must be a positive integer.');
    }
    return versionCode;
  }

  static String _requiredHttpsUrl(
    Map<String, dynamic> value,
    String key,
  ) {
    final url = _requiredString(value, key);
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty) {
      throw FormatException('$key must be a valid HTTPS URL.');
    }
    return url;
  }
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.update,
    required this.installedVersion,
    required this.installedVersionCode,
  });

  final AppUpdateInfo update;
  final String installedVersion;
  final int installedVersionCode;
}

class AppDownloadProgress {
  const AppDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;
  final int? totalBytes;

  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) {
      return null;
    }
    return (receivedBytes / total).clamp(0, 1).toDouble();
  }
}

enum AppInstallerLaunchResult {
  opened,
  permissionRequired,
  unavailable,
}
