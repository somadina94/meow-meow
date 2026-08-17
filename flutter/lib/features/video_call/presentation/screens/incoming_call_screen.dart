import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'video_call_screen.dart';

/// Full-screen incoming call ringer.
///
/// Plays the tring-tring sound, shows caller info, accept/decline.
/// Auto-dismisses after 35s setup timeout (matches WhatsApp calling memory).
class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerId;
  final String callerName;
  final String? callerAvatar;
  final bool isVideo;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
    this.isVideo = true,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  Timer? _timeoutTimer;
  final _supabase = Supabase.instance.client;
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _startRingtone();
    _timeoutTimer = Timer(const Duration(seconds: 35), _decline);
  }

  Future<void> _startRingtone() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/tring.mp3'));
    } catch (_) {}
  }

  Future<void> _stopRingtone() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    _timeoutTimer?.cancel();
    await _stopRingtone();
    await _supabase.from('video_call_sessions').update({
      'status': 'connected',
      'accepted_at': DateTime.now().toIso8601String(),
    }).eq('id', widget.callId);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => VideoCallScreen(
        callId: widget.callId,
        peerId: widget.callerId,
        peerName: widget.callerName,
        isCaller: false,
      ),
    ));
  }

  Future<void> _decline() async {
    _timeoutTimer?.cancel();
    await _stopRingtone();
    await _supabase.from('video_call_sessions').update({
      'status': 'declined',
      'ended_at': DateTime.now().toIso8601String(),
    }).eq('id', widget.callId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            Text('Incoming ${widget.isVideo ? "video" : "voice"} call',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 40),
            CircleAvatar(
              radius: 70,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
              backgroundImage: widget.callerAvatar != null
                  ? NetworkImage(widget.callerAvatar!)
                  : null,
              child: widget.callerAvatar == null
                  ? Text(widget.callerName.isNotEmpty
                          ? widget.callerName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 48))
                  : null,
            ),
            const SizedBox(height: 24),
            Text(widget.callerName,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CallButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    label: 'Decline',
                    onTap: _decline,
                  ),
                  _CallButton(
                    icon: widget.isVideo ? Icons.videocam : Icons.call,
                    color: Colors.green,
                    label: 'Accept',
                    onTap: _accept,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }
}
