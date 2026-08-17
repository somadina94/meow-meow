import 'dart:async';
import 'dart:io';

/// Video Call Circuit Breaker
///
/// Mirrors the React video-call CPU guard (memory: video-call-circuit-breaker).
/// If sustained CPU load exceeds the threshold, calls are killed and new calls
/// are blocked for the cooldown window (default 2 hours).
class VideoCallCircuitBreaker {
  VideoCallCircuitBreaker._();
  static final VideoCallCircuitBreaker instance = VideoCallCircuitBreaker._();

  static const double cpuThreshold = 0.95; // 95%
  static const Duration cooldown = Duration(hours: 2);
  static const Duration sampleInterval = Duration(seconds: 10);

  DateTime? _trippedUntil;
  Timer? _monitorTimer;
  final _controller = StreamController<bool>.broadcast();

  /// Emits `true` when the breaker trips, `false` when it resets.
  Stream<bool> get state => _controller.stream;

  /// True when calls are currently blocked.
  bool get isTripped =>
      _trippedUntil != null && DateTime.now().isBefore(_trippedUntil!);

  /// Remaining cooldown time, or `Duration.zero` if not tripped.
  Duration get remaining => isTripped
      ? _trippedUntil!.difference(DateTime.now())
      : Duration.zero;

  /// Begin monitoring CPU. Call once at app start (after auth).
  void startMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(sampleInterval, (_) => _sample());
  }

  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  /// Manually trip the breaker (e.g. on repeated WebRTC failures).
  void trip() {
    if (isTripped) return;
    _trippedUntil = DateTime.now().add(cooldown);
    _controller.add(true);
    Timer(cooldown, () {
      _trippedUntil = null;
      _controller.add(false);
    });
  }

  /// Manual reset (admin override).
  void reset() {
    _trippedUntil = null;
    _controller.add(false);
  }

  Future<void> _sample() async {
    final load = await _readCpuLoad();
    if (load != null && load >= cpuThreshold) {
      trip();
    }
  }

  /// Best-effort CPU load read.
  ///
  /// - Linux/Android: `/proc/loadavg` divided by core count.
  /// - iOS/macOS/other: returns null (Dart can't read system CPU without
  ///   plugins; rely on `trip()` from WebRTC failure callbacks instead).
  Future<double?> _readCpuLoad() async {
    if (!Platform.isLinux && !Platform.isAndroid) return null;
    try {
      final file = File('/proc/loadavg');
      if (!await file.exists()) return null;
      final raw = (await file.readAsString()).trim().split(' ');
      final load1 = double.tryParse(raw.first);
      if (load1 == null) return null;
      final cores = Platform.numberOfProcessors;
      return (load1 / cores).clamp(0.0, 1.0);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _monitorTimer?.cancel();
    _controller.close();
  }
}
