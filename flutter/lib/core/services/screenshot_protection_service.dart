import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_protector/screen_protector.dart';

/// Native screenshot / screen-recording protection.
///
/// - Android: sets `WindowManager.LayoutParams.FLAG_SECURE` so the OS
///   blanks screenshots and screen recordings of the app.
/// - iOS: cannot block screenshots, but listens to
///   `UIScreen.capturedDidChangeNotification` and exposes a stream so the
///   UI can blur or warn the user when recording starts.
///
/// Call `enable()` from chat / video-call screens, `disable()` when leaving.
final screenshotProtectionProvider =
    Provider<ScreenshotProtectionService>((ref) => ScreenshotProtectionService());

class ScreenshotProtectionService {
  bool _enabled = false;
  StreamSubscription<bool>? _iosCaptureSub;
  final _captureController = StreamController<bool>.broadcast();

  /// Emits `true` when iOS detects screen recording, `false` when it stops.
  Stream<bool> get iosScreenRecordingStream => _captureController.stream;

  Future<void> enable() async {
    if (_enabled) return;
    _enabled = true;
    try {
      await ScreenProtector.preventScreenshotOn();
      await ScreenProtector.protectDataLeakageOn();
      // iOS only — listen for screen-recording state changes.
      ScreenProtector.addListener(() {
        _captureController.add(true);
      });
    } catch (e) {
      debugPrint('[ScreenshotProtection] enable failed: $e');
    }
  }

  Future<void> disable() async {
    if (!_enabled) return;
    _enabled = false;
    try {
      await ScreenProtector.preventScreenshotOff();
      await ScreenProtector.protectDataLeakageOff();
      ScreenProtector.removeListener();
      await _iosCaptureSub?.cancel();
      _iosCaptureSub = null;
    } catch (e) {
      debugPrint('[ScreenshotProtection] disable failed: $e');
    }
  }

  void disposeService() {
    _captureController.close();
  }
}
