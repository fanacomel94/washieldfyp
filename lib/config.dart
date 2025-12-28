/*class AppConfig {
  // ✅ Emulator (Android): 10.0.2.2
  // ✅ Real device on same WiFi: use your laptop IP e.g. http://192.168.1.10:3000
  // phone device "http://172.20.10.3:3000"
  static const String baseUrl = "http://10.0.2.2:3000";
}*/
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class AppConfig {
  // ✅ Change this to your laptop IP on the same WiFi
  static const String _pcIpBase = "http://172.20.10.3:3000"; //hotspot fana

  static Future<String> getBaseUrl() async {
    if (!Platform.isAndroid) return _pcIpBase;

    final info = await DeviceInfoPlugin().androidInfo;
    final isEmulator = !info.isPhysicalDevice;

    return isEmulator
        ? "http://10.0.2.2:3000" // emulator
        : _pcIpBase; // real phone APK  }
  }
}
