import 'dart:io' as io;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/bug_report.dart';

class DeviceInfoHelper {
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    Map<String, dynamic> info = {
      'appName': packageInfo.appName,
      'appVersion': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
      'platform': _getPlatform().name,
    };

    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        info.addAll({
          'browserName': webInfo.browserName.name,
          'userAgent': webInfo.userAgent,
          'platform': webInfo.platform,
        });
      } else if (io.Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        info.addAll({
          'manufacturer': androidInfo.manufacturer,
          'model': androidInfo.model,
          'androidVersion': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'device': androidInfo.device,
          'brand': androidInfo.brand,
        });
      } else if (io.Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        info.addAll({
          'model': iosInfo.model,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
          'name': iosInfo.name,
          'identifierForVendor': iosInfo.identifierForVendor,
        });
      } else if (io.Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        info.addAll({
          'computerName': windowsInfo.computerName,
          'numberOfCores': windowsInfo.numberOfCores,
          'systemMemoryInMegabytes': windowsInfo.systemMemoryInMegabytes,
          'productName': windowsInfo.productName,
          'displayVersion': windowsInfo.displayVersion,
        });
      } else if (io.Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        info.addAll({
          'name': linuxInfo.name,
          'version': linuxInfo.version,
          'prettyName': linuxInfo.prettyName,
          'variant': linuxInfo.variant,
        });
      } else if (io.Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        info.addAll({
          'model': macInfo.model,
          'hostName': macInfo.hostName,
          'osRelease': macInfo.osRelease,
          'kernelVersion': macInfo.kernelVersion,
        });
      }
    } catch (e) {
      info['error'] = e.toString();
    }

    return info;
  }

  static Platform _getPlatform() {
    if (kIsWeb) return Platform.WEB;
    if (io.Platform.isAndroid) return Platform.ANDROID;
    if (io.Platform.isIOS) return Platform.IOS;
    if (io.Platform.isWindows) return Platform.WINDOWS;
    if (io.Platform.isLinux) return Platform.LINUX;
    if (io.Platform.isMacOS) return Platform.MACOS;
    return Platform.WEB;
  }
}
