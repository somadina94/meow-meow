import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps the app and signs the user out after 15 minutes of inactivity.
///
/// Any pointer event (tap, drag, scroll) resets the timer.
/// Mirrors the React `useIdleAutoLogout` hook (15 min).
class IdleTimeoutWrapper extends StatefulWidget {
  final Widget child;
  final Duration timeout;

  const IdleTimeoutWrapper({
    super.key,
    required this.child,
    this.timeout = const Duration(minutes: 15),
  });

  @override
  State<IdleTimeoutWrapper> createState() => _IdleTimeoutWrapperState();
}

class _IdleTimeoutWrapperState extends State<IdleTimeoutWrapper> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, _logout);
  }

  Future<void> _logout() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return;
    try {
      await client.auth.signOut();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restart(),
      onPointerMove: (_) => _restart(),
      onPointerSignal: (_) => _restart(),
      child: widget.child,
    );
  }
}
