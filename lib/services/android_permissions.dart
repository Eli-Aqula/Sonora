import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// A thin helper around `permission_handler` for a single use case:
/// gaining access to the user's local audio files on Android.
///
/// Android 13+ requires `READ_MEDIA_AUDIO`, older versions need the
/// regular `READ_EXTERNAL_STORAGE`. On other platforms this is a
/// no-op (true).
///
/// We determine the version via `Platform.version` — a string like
/// `"3.5.0 (stable)"` — though what matters isn't the string itself but
/// the fact that `Permission.audio` only exists on 13+; on 12 and below
/// it returns `denied` with no chance to request it. So we try both
/// paths in sequence, with storage requested first on API <= 32.
class AndroidPermissions {
  AndroidPermissions._();

  /// Requests the needed permission if it's not already granted. Returns
  /// true if the permission is granted (or the platform doesn't need it).
  static Future<bool> ensureAudioAccess() async {
    if (!Platform.isAndroid) return true;

    // First check whether it's already been granted.
    if (await Permission.audio.isGranted) return true;
    if (await Permission.storage.isGranted) return true;

    // Request both permissions at once — permission_handler decides
    // what to show on a given API level; the "extra" one is just skipped.
    final results = await [
      Permission.audio,
      Permission.storage,
    ].request();

    final audio = results[Permission.audio] ?? PermissionStatus.denied;
    final storage = results[Permission.storage] ?? PermissionStatus.denied;
    return audio.isGranted || storage.isGranted;
  }

  /// True if the permission is "permanently denied" and the system
  /// settings screen is needed.
  static Future<bool> isPermanentlyDenied() async {
    if (!Platform.isAndroid) return false;
    if (await Permission.audio.isPermanentlyDenied) return true;
    if (await Permission.storage.isPermanentlyDenied) return true;
    return false;
  }

  /// Open the system app settings screen.
  static Future<bool> openSettings() => openAppSettings();
}
