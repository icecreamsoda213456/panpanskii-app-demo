import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/app_update_config.dart';
import '../models/app_update_info.dart';

class AppUpdateService {
  const AppUpdateService();

  Future<AppUpdateCheckResult?> checkForUpdate() async {
    if (!Platform.isAndroid || !AppUpdateConfig.isConfigured) {
      return null;
    }

    final manifestUri = Uri.parse(AppUpdateConfig.manifestUrl);
    _requireHttps(manifestUri, fieldName: 'manifestUrl');

    final manifest = await _loadManifest(manifestUri);
    final packageInfo = await PackageInfo.fromPlatform();
    final installedVersionCode = int.tryParse(packageInfo.buildNumber);
    if (installedVersionCode == null) {
      throw const FormatException(
        'The installed Android versionCode is not numeric.',
      );
    }
    if (manifest.versionCode <= installedVersionCode) {
      return null;
    }

    return AppUpdateCheckResult(
      update: manifest,
      installedVersion: packageInfo.version,
      installedVersionCode: installedVersionCode,
    );
  }

  Future<File> downloadApk(
    AppUpdateInfo update, {
    required ValueChanged<AppDownloadProgress> onProgress,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Private APK updates are Android-only.');
    }

    final apkUri = update.apkUri;
    _requireHttps(apkUri, fieldName: 'apkUrl');

    final cacheRoot = await getTemporaryDirectory();
    final updateDirectory = Directory(
      '${cacheRoot.path}${Platform.pathSeparator}updates',
    );
    await updateDirectory.create(recursive: true);
    await _cleanObsoleteUpdates(updateDirectory);

    final fileName = 'panpanskii_update_${update.versionCode}.apk';
    final destination = File(
      '${updateDirectory.path}${Platform.pathSeparator}$fileName',
    );
    final partial = File('${destination.path}.part');
    await _deleteIfPresent(partial);
    await _deleteIfPresent(destination);

    final client = _createHttpClient();
    IOSink? sink;
    try {
      final request =
          await client.getUrl(apkUri).timeout(AppUpdateConfig.checkTimeout);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Panpanskii private updater',
      );
      request.followRedirects = true;
      request.maxRedirects = 10;

      final response =
          await request.close().timeout(AppUpdateConfig.checkTimeout);
      _validateDownloadResponse(response);

      final totalBytes =
          response.contentLength > 0 ? response.contentLength : null;
      var receivedBytes = 0;
      sink = partial.openWrite();

      await for (final chunk
          in response.timeout(AppUpdateConfig.downloadTimeout)) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        onProgress(
          AppDownloadProgress(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
          ),
        );
      }
      await sink.flush();
      await sink.close();
      sink = null;

      await _validateDownloadedApk(partial, update);
      return partial.rename(destination.path);
    } catch (error, stackTrace) {
      await sink?.close();
      await _deleteIfPresent(partial);
      _debugLog('APK download failed', error, stackTrace);
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> hasInstallPermission() async {
    if (!Platform.isAndroid) {
      return false;
    }
    return Permission.requestInstallPackages.isGranted;
  }

  Future<bool> requestInstallPermission() async {
    if (!Platform.isAndroid) {
      return false;
    }
    final status = await Permission.requestInstallPackages.request();
    return status.isGranted;
  }

  Future<AppInstallerLaunchResult> openInstaller(File apk) async {
    if (!Platform.isAndroid || !await apk.exists()) {
      return AppInstallerLaunchResult.unavailable;
    }
    if (!await hasInstallPermission()) {
      return AppInstallerLaunchResult.permissionRequired;
    }

    final result = await OpenFilex.open(
      apk.path,
      type: 'application/vnd.android.package-archive',
    );
    return switch (result.type) {
      ResultType.done => AppInstallerLaunchResult.opened,
      ResultType.permissionDenied =>
        AppInstallerLaunchResult.permissionRequired,
      ResultType.fileNotFound ||
      ResultType.noAppToOpen ||
      ResultType.error =>
        AppInstallerLaunchResult.unavailable,
    };
  }

  Future<AppUpdateInfo> _loadManifest(Uri uri) async {
    final client = _createHttpClient();
    try {
      final request =
          await client.getUrl(uri).timeout(AppUpdateConfig.checkTimeout);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Panpanskii update checker',
      );
      request.followRedirects = true;
      request.maxRedirects = 10;

      final response =
          await request.close().timeout(AppUpdateConfig.checkTimeout);
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Manifest request returned HTTP ${response.statusCode}.',
          uri: uri,
        );
      }
      _rejectInsecureRedirects(response);
      if (_isHtml(response.headers.contentType?.mimeType)) {
        throw const FormatException(
          'Google Drive returned HTML instead of update JSON.',
        );
      }

      final bytes = BytesBuilder(copy: false);
      await for (final chunk
          in response.timeout(AppUpdateConfig.checkTimeout)) {
        bytes.add(chunk);
        if (bytes.length > 1024 * 1024) {
          throw const FormatException('Update manifest is unexpectedly large.');
        }
      }

      final body = utf8.decode(bytes.takeBytes()).trim();
      if (body.isEmpty || _looksLikeHtml(body)) {
        throw const FormatException('Update manifest is empty or invalid.');
      }
      return AppUpdateInfo.fromJson(jsonDecode(body));
    } catch (error, stackTrace) {
      _debugLog('Update manifest check failed', error, stackTrace);
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  HttpClient _createHttpClient() {
    return HttpClient()
      ..connectionTimeout = AppUpdateConfig.checkTimeout
      ..idleTimeout = const Duration(seconds: 20);
  }

  void _validateDownloadResponse(HttpClientResponse response) {
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'APK request returned HTTP ${response.statusCode}.',
      );
    }
    _rejectInsecureRedirects(response);
    if (_isHtml(response.headers.contentType?.mimeType)) {
      throw const FormatException(
        'Google Drive returned an HTML page instead of an APK.',
      );
    }
    if (response.contentLength == 0) {
      throw const FormatException('The downloaded APK is empty.');
    }
  }

  Future<void> _validateDownloadedApk(
    File file,
    AppUpdateInfo update,
  ) async {
    final size = await file.length();
    if (size < AppUpdateConfig.minimumApkBytes) {
      throw const FormatException('The downloaded APK is too small.');
    }

    final randomAccessFile = await file.open();
    late final List<int> signature;
    try {
      signature = await randomAccessFile.read(4);
    } finally {
      await randomAccessFile.close();
    }
    final isZipHeader = signature.length == 4 &&
        signature[0] == 0x50 &&
        signature[1] == 0x4B &&
        signature[2] == 0x03 &&
        signature[3] == 0x04;
    if (!isZipHeader) {
      throw const FormatException(
        'The downloaded file is not a valid APK container.',
      );
    }

    final expectedSha256 = update.sha256;
    if (expectedSha256 != null) {
      final actualSha256 = await sha256.bind(file.openRead()).first;
      if (actualSha256.toString().toLowerCase() != expectedSha256) {
        throw const FormatException('The APK integrity check failed.');
      }
    }
  }

  Future<void> _cleanObsoleteUpdates(Directory directory) async {
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final name = entity.uri.pathSegments.last;
      if (RegExp(r'^panpanskii_update_[0-9]+\.apk(?:\.part)?$')
          .hasMatch(name)) {
        await _deleteIfPresent(entity);
      }
    }
  }

  Future<void> _deleteIfPresent(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException catch (error, stackTrace) {
      _debugLog('Could not remove obsolete update file', error, stackTrace);
    }
  }

  void _requireHttps(Uri uri, {required String fieldName}) {
    if (uri.scheme.toLowerCase() != 'https' || uri.host.isEmpty) {
      throw FormatException('$fieldName must be a valid HTTPS URL.');
    }
  }

  void _rejectInsecureRedirects(HttpClientResponse response) {
    final hasInsecureRedirect = response.redirects.any(
      (redirect) => redirect.location.scheme.toLowerCase() == 'http',
    );
    if (hasInsecureRedirect) {
      throw const FormatException('An insecure update redirect was rejected.');
    }
  }

  bool _isHtml(String? mimeType) {
    return mimeType?.toLowerCase().contains('text/html') ?? false;
  }

  bool _looksLikeHtml(String text) {
    final prefix = text.toLowerCase();
    return prefix.startsWith('<!doctype html') ||
        prefix.startsWith('<html') ||
        prefix.startsWith('<head');
  }

  void _debugLog(String message, Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      debugPrint('$message: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
