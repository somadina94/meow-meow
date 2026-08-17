import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/ice_config.dart';
import '../../../../core/services/screenshot_protection_service.dart';
import '../../../../core/services/video_call_circuit_breaker.dart';
import '../../../../core/theme/app_colors.dart';

/// 1:1 video / audio call — pure open-source P2P WebRTC.
///
/// Signaling uses Supabase realtime broadcast on a per-call channel,
/// matching the React `useP2PCall.ts` pattern:
///   channel name: `call:<callId>`
///   events:       offer | answer | ice | bye
///
/// No central media server. Audio + video go peer-to-peer; TURN relay
/// kicks in only when symmetric NAT blocks direct connection.
class VideoCallScreen extends ConsumerStatefulWidget {
  final String callId;
  final String recipientId;
  final String recipientName;
  final String? recipientPhoto;
  final bool isIncoming;
  final bool audioOnly;
  final double ratePerMinute;

  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.recipientId,
    required this.recipientName,
    this.recipientPhoto,
    this.isIncoming = false,
    this.audioOnly = false,
    this.ratePerMinute = 8,
  });

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  final _supabase = Supabase.instance.client;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  RealtimeChannel? _signalChannel;
  RealtimeChannel? _statusChannel;
  Timer? _timer;

  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = true;
  bool _isConnecting = true;
  bool _isConnected = false;
  bool _isEnding = false;
  Duration _duration = Duration.zero;
  double _cost = 0;

  @override
  void initState() {
    super.initState();
    if (VideoCallCircuitBreaker.instance.isTripped) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final mins =
            VideoCallCircuitBreaker.instance.remaining.inMinutes;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Calls are temporarily disabled (high server load). Try again in $mins min.'),
        ));
        Navigator.of(context).pop();
      });
      return;
    }
    ref.read(screenshotProtectionProvider).enable();
    _isVideoOff = widget.audioOnly;
    _start();
  }

  Future<void> _start() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    await [Permission.microphone, if (!widget.audioOnly) Permission.camera]
        .request();

    try {
      _pc = await createPeerConnection(IceConfig.config);
      _wirePeerEvents();

      // Local media
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': widget.audioOnly
            ? false
            : {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
                'frameRate': {'ideal': 30, 'max': 30},
              },
      });
      _localRenderer.srcObject = _localStream;
      for (final track in _localStream!.getTracks()) {
        await _pc!.addTrack(track, _localStream!);
      }

      _openSignalingChannel();
      _watchRemoteHangup();

      // Caller (man) sends the offer; callee (woman) waits.
      if (!widget.isIncoming) {
        await _sendOffer();
      }
    } catch (e) {
      debugPrint('[Call] start failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start call: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  // ── peer events ──────────────────────────────────────────────────────────
  void _wirePeerEvents() {
    _pc!.onIceCandidate = (cand) {
      if (cand.candidate == null) return;
      _signalChannel?.sendBroadcastMessage(
        event: 'ice',
        payload: {
          'candidate': cand.candidate,
          'sdpMid': cand.sdpMid,
          'sdpMLineIndex': cand.sdpMLineIndex,
        },
      );
    };
    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams.first;
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _isConnected = true;
          });
          _startTimer();
        }
      }
    };
    _pc!.onConnectionState = (state) {
      debugPrint('[Call] pc state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        VideoCallCircuitBreaker.instance.trip();
        _endCall();
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _endCall();
      }
    };
  }

  // ── signaling ────────────────────────────────────────────────────────────
  void _openSignalingChannel() {
    _signalChannel = _supabase
        .channel('call:${widget.callId}',
            opts: const RealtimeChannelConfig(self: false))
        .onBroadcast(
          event: 'offer',
          callback: (payload) => _handleOffer(payload['payload']),
        )
        .onBroadcast(
          event: 'answer',
          callback: (payload) => _handleAnswer(payload['payload']),
        )
        .onBroadcast(
          event: 'ice',
          callback: (payload) => _handleIce(payload['payload']),
        )
        .onBroadcast(
          event: 'bye',
          callback: (_) => _endCall(remote: true),
        )
        .subscribe();
  }

  Future<void> _sendOffer() async {
    final offer = await _pc!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': !widget.audioOnly,
    });
    await _pc!.setLocalDescription(offer);
    _signalChannel?.sendBroadcastMessage(
      event: 'offer',
      payload: {'sdp': offer.sdp, 'type': offer.type},
    );
  }

  Future<void> _handleOffer(Map<String, dynamic> p) async {
    await _pc!.setRemoteDescription(
        RTCSessionDescription(p['sdp'] as String, p['type'] as String));
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    _signalChannel?.sendBroadcastMessage(
      event: 'answer',
      payload: {'sdp': answer.sdp, 'type': answer.type},
    );
  }

  Future<void> _handleAnswer(Map<String, dynamic> p) async {
    await _pc!.setRemoteDescription(
        RTCSessionDescription(p['sdp'] as String, p['type'] as String));
  }

  Future<void> _handleIce(Map<String, dynamic> p) async {
    await _pc!.addCandidate(RTCIceCandidate(
      p['candidate'] as String?,
      p['sdpMid'] as String?,
      p['sdpMLineIndex'] as int?,
    ));
  }

  // ── DB watch (other side updated status to ended) ────────────────────────
  void _watchRemoteHangup() {
    _statusChannel = _supabase
        .channel('call-status:${widget.callId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'video_call_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'call_id',
            value: widget.callId,
          ),
          callback: (payload) {
            final status = payload.newRecord['status'] as String?;
            if (status == 'ended' && !_isEnding) _endCall(remote: true);
          },
        )
        .subscribe();
  }

  // ── timer / cost ─────────────────────────────────────────────────────────
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _duration += const Duration(seconds: 1);
        _cost = (_duration.inSeconds / 60) * widget.ratePerMinute;
      });
    });
  }

  // ── controls ─────────────────────────────────────────────────────────────
  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !_isMuted);
  }

  void _toggleVideo() {
    if (widget.audioOnly) return;
    setState(() => _isVideoOff = !_isVideoOff);
    _localStream?.getVideoTracks().forEach((t) => t.enabled = !_isVideoOff);
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    Helper.setSpeakerphoneOn(_isSpeakerOn);
  }

  Future<void> _switchCamera() async {
    final track = _localStream?.getVideoTracks().firstOrNull;
    if (track != null) await Helper.switchCamera(track);
  }

  Future<void> _endCall({bool remote = false}) async {
    if (_isEnding) return;
    _isEnding = true;

    if (!remote) {
      _signalChannel?.sendBroadcastMessage(event: 'bye', payload: {});
    }
    try {
      final uid = _supabase.auth.currentUser?.id;
      await _supabase.from('video_call_sessions').update({
        'status': 'ended',
        'ended_at': DateTime.now().toUtc().toIso8601String(),
        'end_reason': remote ? 'partner_ended' : 'user_ended',
      }).eq('call_id', widget.callId);

      // Resume any chats paused for this call (P3 → P1 priority).
      if (uid != null) {
        await _supabase
            .from('active_chat_sessions')
            .update({'status': 'active', 'end_reason': null})
            .or('man_user_id.eq.$uid,woman_user_id.eq.$uid')
            .eq('status', 'paused')
            .eq('end_reason', 'video_call_priority');
      }
    } catch (e) {
      debugPrint('[Call] end update failed: $e');
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    ref.read(screenshotProtectionProvider).disable();
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _pc?.close();
    _pc?.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    if (_signalChannel != null) _supabase.removeChannel(_signalChannel!);
    if (_statusChannel != null) _supabase.removeChannel(_statusChannel!);
    super.dispose();
  }

  // ── UI ───────────────────────────────────────────────────────────────────
  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return h > 0 ? '${two(h)}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote (full screen)
          Positioned.fill(
            child: _isConnected && _remoteRenderer.srcObject != null
                ? RTCVideoView(_remoteRenderer,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                : Container(
                    color: Colors.grey.shade900,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundImage: widget.recipientPhoto != null
                                ? NetworkImage(widget.recipientPhoto!)
                                : null,
                            child: widget.recipientPhoto == null
                                ? Text(widget.recipientName[0].toUpperCase(),
                                    style: const TextStyle(fontSize: 40))
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Text(widget.recipientName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (_isConnecting)
                            const Text('Connecting…',
                                style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
          ),

          // Local preview (top-right)
          if (!widget.audioOnly && !_isVideoOff)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              right: 20,
              child: Container(
                width: 100,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: RTCVideoView(_localRenderer, mirror: true),
                ),
              ),
            ),

          // Status badge
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20,
            child: _isConnected
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Colors.green, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(_fmt(_duration),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Text('₹${_cost.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ]),
                  )
                : const SizedBox.shrink(),
          ),

          // Controls
          Positioned(
            bottom: 40 + MediaQuery.of(context).padding.bottom,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Btn(
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                      label: 'Speaker',
                      onTap: _toggleSpeaker,
                    ),
                    const SizedBox(width: 20),
                    if (!widget.audioOnly)
                      _Btn(
                        icon: Icons.flip_camera_ios,
                        label: 'Flip',
                        onTap: _switchCamera,
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Btn(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      label: _isMuted ? 'Unmute' : 'Mute',
                      onTap: _toggleMute,
                      bg: _isMuted ? Colors.red : Colors.white24,
                    ),
                    const SizedBox(width: 20),
                    _Btn(
                      icon: Icons.call_end,
                      label: 'End',
                      onTap: () => _endCall(),
                      bg: Colors.red,
                      iconColor: Colors.white,
                      size: 70,
                    ),
                    const SizedBox(width: 20),
                    if (!widget.audioOnly)
                      _Btn(
                        icon:
                            _isVideoOff ? Icons.videocam_off : Icons.videocam,
                        label: _isVideoOff ? 'Video' : 'Video',
                        onTap: _toggleVideo,
                        bg: _isVideoOff ? Colors.red : Colors.white24,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? bg;
  final Color? iconColor;
  final double size;
  const _Btn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.bg,
    this.iconColor,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              color: bg ?? Colors.white24, shape: BoxShape.circle),
          child: IconButton(
            icon: Icon(icon,
                color: iconColor ?? Colors.white, size: size * 0.45),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.7), fontSize: 12)),
      ],
    );
  }
}

// Re-export incoming call screen kept from earlier.
class IncomingCallScreen extends StatelessWidget {
  final String callerId;
  final String callerName;
  final String? callerPhoto;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingCallScreen({
    super.key,
    required this.callerId,
    required this.callerName,
    this.callerPhoto,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 60,
              backgroundImage:
                  callerPhoto != null ? NetworkImage(callerPhoto!) : null,
              child: callerPhoto == null
                  ? Text(callerName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 40))
                  : null,
            ),
            const SizedBox(height: 24),
            Text(callerName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Incoming video call…',
                style: TextStyle(color: Colors.white70, fontSize: 16)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: IconButton(
                        icon: const Icon(Icons.call_end,
                            color: Colors.white, size: 32),
                        onPressed: onDecline),
                  ),
                  const SizedBox(height: 12),
                  const Text('Decline',
                      style: TextStyle(color: Colors.white70)),
                ]),
                const SizedBox(width: 80),
                Column(children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                        color: Colors.green, shape: BoxShape.circle),
                    child: IconButton(
                        icon: const Icon(Icons.videocam,
                            color: Colors.white, size: 32),
                        onPressed: onAccept),
                  ),
                  const SizedBox(height: 12),
                  const Text('Accept',
                      style: TextStyle(color: Colors.white70)),
                ]),
              ],
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
