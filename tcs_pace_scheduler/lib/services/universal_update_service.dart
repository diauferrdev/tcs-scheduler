import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_html/html.dart' as html;
import 'api_service.dart';

/// Universal Update Service
/// Works on ALL platforms: Android, iOS, Web, macOS, Windows, Linux
/// Blocks UI when app is outdated (version < minVersion)
class UniversalUpdateService {
  static final UniversalUpdateService _instance = UniversalUpdateService._internal();
  factory UniversalUpdateService() => _instance;
  UniversalUpdateService._internal();

  final ApiService _apiService = ApiService();
  bool _isChecking = false;

  /// Check for updates IMMEDIATELY after login
  /// Blocks UI if app is outdated to prevent bugs
  Future<void> checkForUpdate(BuildContext context) async {
    if (_isChecking) {
      debugPrint('[Update] Already checking, skipping');
      return;
    }

    _isChecking = true;

    try {
      debugPrint('[Update] Checking for updates...');

      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      debugPrint('[Update] Current version: $currentVersion (build $currentBuild)');

      // Check backend for latest version
      final response = await _apiService.get('/api/version/current');

      final latestVersion = response['version'] as String;
      final minVersion = response['minVersion'] as String;
      final forceUpdate = response['forceUpdate'] as bool? ?? false;
      final critical = response['critical'] as bool? ?? false;
      final downloadUrls = response['downloadUrl'] as Map<String, dynamic>;
      final releaseNotes = response['releaseNotes'] as Map<String, dynamic>;

      debugPrint('[Update] Latest version: $latestVersion');
      debugPrint('[Update] Minimum version: $minVersion');

      // Check if app is below minimum version (BLOCKED)
      if (_isOlderThan(currentVersion, minVersion)) {
        debugPrint('[Update] ⚠️ App is OUTDATED! Current: $currentVersion < Min: $minVersion');
        await _showBlockingUpdateDialog(
          context: context,
          currentVersion: currentVersion,
          requiredVersion: minVersion,
          downloadUrl: _getDownloadUrlForPlatform(downloadUrls),
          releaseNotes: releaseNotes['pt-BR'] ?? releaseNotes['en'] ?? 'Atualize para continuar usando o app.',
        );
        return;
      }

      // Check if new version is available (OPTIONAL)
      if (_isNewerVersion(latestVersion, currentVersion) || forceUpdate) {
        debugPrint('[Update] ✅ Update available: $currentVersion -> $latestVersion');
        await _showOptionalUpdateDialog(
          context: context,
          currentVersion: currentVersion,
          newVersion: latestVersion,
          forceUpdate: forceUpdate || critical,
          downloadUrl: _getDownloadUrlForPlatform(downloadUrls),
          releaseNotes: releaseNotes['pt-BR'] ?? releaseNotes['en'] ?? 'Nova versão disponível!',
        );
      } else {
        debugPrint('[Update] App is up to date ✅');
      }
    } catch (e, stackTrace) {
      debugPrint('[Update] ❌ Error checking for updates: $e');
      debugPrint('[Update] Stack trace: $stackTrace');
    } finally {
      _isChecking = false;
    }
  }

  /// Get download URL for current platform
  String _getDownloadUrlForPlatform(Map<String, dynamic> urls) {
    if (kIsWeb) {
      // Web: No download URL needed - app updates on reload
      return urls['web'] ?? '';
    }

    if (Platform.isAndroid) return urls['android'] ?? '';
    if (Platform.isIOS) return urls['ios'] ?? '';
    if (Platform.isMacOS) return urls['macos'] ?? '';
    if (Platform.isWindows) return urls['windows'] ?? '';
    if (Platform.isLinux) return urls['linux'] ?? '';

    return '';
  }

  /// Compare versions (returns true if serverVersion > currentVersion)
  bool _isNewerVersion(String serverVersion, String currentVersion) {
    final serverParts = serverVersion.split('.').map(int.tryParse).whereType<int>().toList();
    final currentParts = currentVersion.split('.').map(int.tryParse).whereType<int>().toList();

    for (int i = 0; i < serverParts.length; i++) {
      if (i >= currentParts.length) return true;
      if (serverParts[i] > currentParts[i]) return true;
      if (serverParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  /// Check if current version is older than minimum version
  bool _isOlderThan(String currentVersion, String minVersion) {
    return _isNewerVersion(minVersion, currentVersion);
  }

  /// Show BLOCKING update dialog (cannot dismiss)
  /// Used when app version < minVersion
  Future<void> _showBlockingUpdateDialog({
    required BuildContext context,
    required String currentVersion,
    required String requiredVersion,
    required String downloadUrl,
    required String releaseNotes,
  }) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return showDialog(
      context: context,
      barrierDismissible: false, // Cannot close
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Cannot back button close
        child: AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: Colors.orange,
                size: 32,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Atualização Obrigatória',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sua versão do app está desatualizada e não é mais suportada.',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.red[300] : Colors.red[700],
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Versão Atual:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          currentVersion,
                          style: TextStyle(
                            color: isDark ? Colors.red[300] : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Versão Mínima:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          requiredVersion,
                          style: TextStyle(
                            color: isDark ? Colors.green[300] : Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Atualize agora para continuar usando o app.',
                style: TextStyle(fontSize: 14),
              ),
              if (releaseNotes.isNotEmpty) ...[
                SizedBox(height: 12),
                Text(
                  'Novidades:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  releaseNotes,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () => _handleUpdate(downloadUrl),
              icon: Icon(Icons.download_rounded),
              label: Text('Atualizar Agora'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show OPTIONAL update dialog (can dismiss if not forced)
  Future<void> _showOptionalUpdateDialog({
    required BuildContext context,
    required String currentVersion,
    required String newVersion,
    required bool forceUpdate,
    required String downloadUrl,
    required String releaseNotes,
  }) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) => WillPopScope(
        onWillPop: () async => !forceUpdate,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.celebration_rounded,
                color: theme.colorScheme.primary,
                size: 32,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Nova Versão Disponível',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.primary.withOpacity(0.15)
                      : theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Versão Atual:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(currentVersion),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nova Versão:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          newVersion,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (releaseNotes.isNotEmpty) ...[
                SizedBox(height: 16),
                Text(
                  'Novidades:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  releaseNotes,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ],
          ),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Depois'),
              ),
            ElevatedButton.icon(
              onPressed: () {
                _handleUpdate(downloadUrl);
                if (!forceUpdate) Navigator.pop(context);
              },
              icon: Icon(Icons.download_rounded),
              label: Text('Atualizar Agora'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle update based on platform
  Future<void> _handleUpdate(String downloadUrl) async {
    try {
      debugPrint('[Update] Opening download URL: $downloadUrl');

      if (kIsWeb) {
        // Web: Force reload to get latest version
        debugPrint('[Update] Web: Reloading page...');
        html.window.location.reload();
        return;
      }

      // Mobile/Desktop: Open download URL (Firebase App Distribution or GitHub Releases)
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('[Update] ✅ Download URL opened');
      } else {
        debugPrint('[Update] ❌ Cannot open URL: $downloadUrl');
      }
    } catch (e) {
      debugPrint('[Update] ❌ Error opening download URL: $e');
    }
  }
}
