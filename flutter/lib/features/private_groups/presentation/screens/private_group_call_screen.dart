import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/screenshot_protection_service.dart';

/// Private group call (50 flower rooms) — open-source SFU client.
///
/// Uses LiveKit OSS (Apache 2.0) connecting to your self-hosted
/// LiveKit server. Token minted server-side by the `livekit-token`
/// edge function so the API secret never leaves the backend.
///
/// Billing: men pay ₹4/min, host (woman) earns ₹1/min per active man —
/// computed entirely server-side via the canonical billing RPCs.
class PrivateGroupCallScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String roomName;
  final bool isHost;
  final String userGender;

  const PrivateGroupCallScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.userGender,
    this.isHost = false,
  });

  @override
  ConsumerState<PrivateGroupCallScreen> createState() =>
      _PrivateGroupCallScreenState();
}

class _PrivateGroupCallScreenState
    extends ConsumerState<PrivateGroupCallScreen> {
  final _supabase = Supabase.instance.client;
  Room? _room;
  bool _connecting = true;
  bool _micEnabled = true;
  String? _error;
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  // Hosts publish camera + mic. Men are subscribers only (with mic).
  bool get _publishVideo => widget.isHost;

  @override
  void initState() {
    super.initState();
    ref.read(screenshotProtectionProvider).enable();
    _join();
  }

  Future<void> _join() async {
    try {
      await [Permission.microphone, if (_publishVideo) Permission.camera]
          .request();

      // 1. Mint short-lived JWT from edge function.
      final tokenResp = await _supabase.functions.invoke(
        'livekit-token',
        body: {
          'room': widget.roomId,
          'identity': _supabase.auth.currentUser!.id,
          'name': widget.roomName,
          'can_publish': _publishVideo,
        },
      );
      final data = tokenResp.data as Map<String, dynamic>?;
      if (data == null || data['token'] == null) {
        throw 'Could not get LiveKit token';
      }
      final token = data['token'] as String;
      final wsUrl = data['ws_url'] as String;

      // 2. Connect to SFU.
      _room = Room();
      await _room!.connect(
        wsUrl,
        token,
        roomOptions: RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultVideoPublishOptions: const VideoPublishOptions(
            videoEncoding: VideoEncoding(
              maxBitrate: 600 * 1000, // 600 kbps @ 480p — medium quality, no blur
              maxFramerate: 24,
            ),
          ),
        ),
      );

      // 3. Publish (host only) — men join muted/no-video.
      if (_publishVideo) {
        await _room!.localParticipant?.setCameraEnabled(true);
      }
      await _room!.localParticipant?.setMicrophoneEnabled(_micEnabled);

      _room!.addListener(_onRoomChange);

      _startTimer();
      if (mounted) setState(() => _connecting = false);
    } catch (e) {
      debugPrint('[GroupCall] join failed: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _connecting = false;
        });
      }
    }
  }

  void _onRoomChange() => setState(() {});

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _toggleMic() async {
    setState(() => _micEnabled = !_micEnabled);
    await _room?.localParticipant?.setMicrophoneEnabled(_micEnabled);
  }

  Future<void> _leave() async {
    await _room?.disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    ref.read(screenshotProtectionProvider).disable();
    _room?.removeListener(_onRoomChange);
    _room?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    if (_connecting) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 48),
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close')),
              ],
            ),
          ),
        ),
      );
    }

    final hostTrack = _firstHostVideoTrack();
    final activeMen = _room?.remoteParticipants.values
            .where((p) => p.isMicrophoneEnabled())
            .length ??
        0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Host video (full screen)
          Positioned.fill(
            child: hostTrack != null
                ? VideoTrackRenderer(hostTrack, fit: VideoViewFit.cover)
                : Container(
                    color: Colors.grey.shade900,
                    child: const Center(
                      child: Text('Waiting for host…',
                          style: TextStyle(color: Colors.white70)),
                    ),
                  ),
          ),

          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.local_florist,
                        color: Colors.pinkAccent, size: 16),
                    const SizedBox(width: 6),
                    Text(widget.roomName,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text(_fmt(_elapsed),
                        style: const TextStyle(color: Colors.white70)),
                  ]),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.people,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                    Text('$activeMen',
                        style: const TextStyle(color: Colors.white)),
                  ]),
                ),
              ],
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 32 + MediaQuery.of(context).padding.bottom,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _circle(
                  icon: _micEnabled ? Icons.mic : Icons.mic_off,
                  bg: _micEnabled ? Colors.white24 : Colors.red,
                  onTap: _toggleMic,
                ),
                const SizedBox(width: 24),
                _circle(
                  icon: Icons.call_end,
                  bg: Colors.red,
                  size: 70,
                  onTap: _leave,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  VideoTrack? _firstHostVideoTrack() {
    for (final p in _room?.remoteParticipants.values ?? <RemoteParticipant>[]) {
      for (final pub in p.videoTrackPublications) {
        final t = pub.track;
        if (t is VideoTrack) return t;
      }
    }
    if (_publishVideo) {
      final localPub =
          _room?.localParticipant?.videoTrackPublications.firstOrNull;
      final lt = localPub?.track;
      if (lt is VideoTrack) return lt;
    }
    return null;
  }

  Widget _circle({
    required IconData icon,
    required Color bg,
    required VoidCallback onTap,
    double size = 56,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: size * 0.45),
        onPressed: onTap,
      ),
    );
  }
}
