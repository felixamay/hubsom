import 'package:flutter/foundation.dart';

/// How far each shop clip has got in its cloud upload.
///
/// Publish returns as soon as the clip is saved on the device, so the upload
/// itself finishes in the background. Without this, a seller on a slow link
/// sees no sign that anything is happening and assumes Publish hung.
abstract final class ShopVideoUploadProgress {
  static final ValueNotifier<Map<String, double>> active =
      ValueNotifier<Map<String, double>>(const {});

  static double? of(String videoId) => active.value[videoId];

  static bool get isUploading => active.value.isNotEmpty;

  static void start(String videoId) => _set(videoId, 0);

  static void report(String videoId, double fraction) {
    _set(videoId, fraction.clamp(0.0, 1.0));
  }

  static void finish(String videoId) {
    if (!active.value.containsKey(videoId)) return;
    final next = Map<String, double>.from(active.value)..remove(videoId);
    active.value = next;
  }

  static void _set(String videoId, double fraction) {
    if (videoId.isEmpty) return;
    final current = active.value[videoId];
    // Progress events fire often; only rebuild on a visible change.
    if (current != null && (fraction - current).abs() < 0.01 && fraction < 1) {
      return;
    }
    active.value = Map<String, double>.from(active.value)
      ..[videoId] = fraction;
  }

  @visibleForTesting
  static void reset() => active.value = const {};
}
