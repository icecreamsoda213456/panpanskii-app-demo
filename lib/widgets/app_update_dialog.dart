import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/app_update_config.dart';
import '../models/app_update_info.dart';
import '../services/app_update_service.dart';

class AppUpdateCoordinator {
  AppUpdateCoordinator._();

  static const AppUpdateService _service = AppUpdateService();
  static bool _isChecking = false;
  static bool _isDialogVisible = false;
  static bool _automaticCheckScheduled = false;

  static void scheduleAutomaticCheck(BuildContext context) {
    if (_automaticCheckScheduled) {
      return;
    }
    _automaticCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        checkAndShow(context);
      }
    });
  }

  static Future<void> checkAndShow(
    BuildContext context, {
    bool showLatestMessage = false,
  }) async {
    if (_isChecking ||
        _isDialogVisible ||
        !Platform.isAndroid ||
        !AppUpdateConfig.isConfigured) {
      if (showLatestMessage &&
          context.mounted &&
          !AppUpdateConfig.isConfigured) {
        _showSnackBar(
          context,
          'Add the private update manifest link before checking for updates.',
        );
      }
      return;
    }

    _isChecking = true;
    try {
      final result = await _service.checkForUpdate();
      if (!context.mounted) {
        return;
      }
      if (result == null) {
        if (showLatestMessage) {
          _showSnackBar(context, 'You are using the latest version.');
        }
        return;
      }

      _isDialogVisible = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (dialogContext) => AppUpdateDialog(
          result: result,
          service: _service,
        ),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Automatic update check failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (showLatestMessage && context.mounted) {
        _showSnackBar(
          context,
          'Could not check for updates. Please try again.',
        );
      }
    } finally {
      _isChecking = false;
      _isDialogVisible = false;
    }
  }

  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({
    super.key,
    required this.result,
    required this.service,
  });

  final AppUpdateCheckResult result;
  final AppUpdateService service;

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  _UpdateDialogStage _stage = _UpdateDialogStage.available;
  AppDownloadProgress? _progress;
  File? _downloadedApk;
  String? _errorMessage;
  bool _operationRunning = false;

  AppUpdateInfo get _update => widget.result.update;

  bool get _canClose {
    return switch (_stage) {
      _UpdateDialogStage.available => !_update.forceUpdate,
      _UpdateDialogStage.error => true,
      _UpdateDialogStage.permission => !_update.forceUpdate,
      _UpdateDialogStage.downloading || _UpdateDialogStage.preparing => false,
    };
  }

  Future<void> _downloadAndInstall() async {
    if (_operationRunning) {
      return;
    }
    _operationRunning = true;
    setState(() {
      _stage = _UpdateDialogStage.downloading;
      _progress = const AppDownloadProgress(
        receivedBytes: 0,
        totalBytes: null,
      );
      _errorMessage = null;
    });

    try {
      final apk = await widget.service.downloadApk(
        _update,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _progress = progress);
          }
        },
      );
      if (!mounted) {
        return;
      }
      _downloadedApk = apk;
      await _prepareInstaller(apk);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Update download failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (mounted) {
        setState(() {
          _stage = _UpdateDialogStage.error;
          _errorMessage = 'Update download failed. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _operationRunning = false);
      } else {
        _operationRunning = false;
      }
    }
  }

  Future<void> _prepareInstaller(File apk) async {
    if (!mounted) {
      return;
    }
    setState(() => _stage = _UpdateDialogStage.preparing);

    if (!await widget.service.hasInstallPermission()) {
      if (mounted) {
        setState(() => _stage = _UpdateDialogStage.permission);
      }
      return;
    }
    await _openInstaller(apk);
  }

  Future<void> _requestPermissionAndContinue() async {
    if (_operationRunning) {
      return;
    }
    final apk = _downloadedApk;
    if (apk == null) {
      await _downloadAndInstall();
      return;
    }

    _operationRunning = true;
    try {
      final granted = await widget.service.requestInstallPermission();
      if (!mounted) {
        return;
      }
      if (!granted) {
        setState(() => _stage = _UpdateDialogStage.permission);
        return;
      }
      setState(() => _stage = _UpdateDialogStage.preparing);
      await _openInstaller(apk);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Install permission request failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (mounted) {
        setState(() {
          _stage = _UpdateDialogStage.error;
          _errorMessage =
              'Android could not open the update permission. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _operationRunning = false);
      } else {
        _operationRunning = false;
      }
    }
  }

  Future<void> _openInstaller(File apk) async {
    final result = await widget.service.openInstaller(apk);
    if (!mounted) {
      return;
    }

    switch (result) {
      case AppInstallerLaunchResult.opened:
        Navigator.of(context, rootNavigator: true).pop();
        return;
      case AppInstallerLaunchResult.permissionRequired:
        setState(() => _stage = _UpdateDialogStage.permission);
        return;
      case AppInstallerLaunchResult.unavailable:
        setState(() {
          _stage = _UpdateDialogStage.error;
          _errorMessage =
              'Android could not open the package installer. Please try again.';
        });
        return;
    }
  }

  Future<void> _retry() async {
    final apk = _downloadedApk;
    if (apk != null && await apk.exists()) {
      await _prepareInstaller(apk);
      return;
    }
    await _downloadAndInstall();
  }

  void _close() {
    if (_canClose) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _canClose,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.sizeOf(context).height - 48,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFFFC857).withValues(alpha: .65),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: .28),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: SingleChildScrollView(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: _buildContent(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return switch (_stage) {
      _UpdateDialogStage.available => _buildAvailable(context),
      _UpdateDialogStage.downloading => _buildDownloading(context),
      _UpdateDialogStage.preparing => _buildPreparing(context),
      _UpdateDialogStage.permission => _buildPermission(context),
      _UpdateDialogStage.error => _buildError(context),
    };
  }

  Widget _buildAvailable(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _UpdateHeader(
          icon: Icons.local_florist_rounded,
          title: _update.title,
          subtitle: 'Version ${_update.version} is ready',
        ),
        const SizedBox(height: 16),
        Text(
          _update.message,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: scheme.onSurface,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
        ),
        if (_update.changes.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'What\'s new',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 176),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final change in _update.changes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              change,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        if (_update.forceUpdate) ...[
          const SizedBox(height: 12),
          _UpdateNotice(
            icon: Icons.info_rounded,
            text: 'This update is required to continue safely.',
            color: scheme.error,
          ),
        ],
        const SizedBox(height: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _downloadAndInstall,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Update Now'),
            ),
            if (!_update.forceUpdate)
              TextButton(onPressed: _close, child: const Text('Later')),
          ],
        ),
      ],
    );
  }

  Widget _buildDownloading(BuildContext context) {
    final progress = _progress;
    final fraction = progress?.fraction;
    final percent = fraction == null ? null : (fraction * 100).round();
    final received = progress?.receivedBytes ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _UpdateHeader(
          icon: Icons.downloading_rounded,
          title: 'Downloading update...',
          subtitle: 'Panpanskii ${_update.version}',
        ),
        const SizedBox(height: 22),
        LinearProgressIndicator(value: fraction),
        const SizedBox(height: 10),
        Text(
          percent == null
              ? '${_formatBytes(received)} downloaded'
              : '$percent%  -  ${_formatBytes(received)}',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Keep Panpanskii open while the APK is downloading.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildPreparing(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _UpdateHeader(
          icon: Icons.inventory_2_rounded,
          title: 'Preparing update...',
          subtitle: 'Android will ask you to confirm the installation.',
        ),
        SizedBox(height: 24),
        CircularProgressIndicator(),
        SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPermission(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _UpdateHeader(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Allow Panpanskii updates',
          subtitle: 'One Android setting is needed',
        ),
        const SizedBox(height: 16),
        Text(
          'To update Panpanskii directly, Android needs permission to install updates from this app. You only need to enable this for Panpanskii.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 14),
        _UpdateNotice(
          icon: Icons.security_rounded,
          text:
              'Android will still show the package installer and ask you to confirm every update.',
          color: scheme.primary,
        ),
        const SizedBox(height: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed:
                  _operationRunning ? null : _requestPermissionAndContinue,
              icon: const Icon(Icons.settings_rounded),
              label: const Text('Open Settings'),
            ),
            if (!_update.forceUpdate)
              TextButton(onPressed: _close, child: const Text('Later')),
          ],
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _UpdateHeader(
          icon: Icons.error_outline_rounded,
          title: 'Update paused',
          subtitle: 'Your current app is still safe to use',
        ),
        const SizedBox(height: 16),
        _UpdateNotice(
          icon: Icons.refresh_rounded,
          text: _errorMessage ?? 'Update download failed. Please try again.',
          color: scheme.error,
        ),
        const SizedBox(height: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _operationRunning ? null : _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
            TextButton(onPressed: _close, child: const Text('Close')),
          ],
        ),
      ],
    );
  }
}

class _UpdateHeader extends StatelessWidget {
  const _UpdateHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFC857).withValues(alpha: .18),
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(
            dimension: 48,
            child: Icon(icon, color: const Color(0xFFFFB23F)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UpdateNotice extends StatelessWidget {
  const _UpdateNotice({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _UpdateDialogStage {
  available,
  downloading,
  preparing,
  permission,
  error,
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) {
    return '${kilobytes.toStringAsFixed(1)} KB';
  }
  return '${(kilobytes / 1024).toStringAsFixed(1)} MB';
}
