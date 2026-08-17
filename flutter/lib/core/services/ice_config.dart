/// Open-source ICE / TURN configuration.
///
/// Mirrors `src/lib/iceServers.ts` from the React app:
///   - Self-hosted coturn (preferred) — overrides defaults via env vars.
///   - Free Metered.ca TURN as fallback.
///   - Google STUN as last resort.
///
/// Pass at build time:
///   flutter run \
///     --dart-define=TURN_URL=turn:turn.yourdomain.com:3478 \
///     --dart-define=TURN_USERNAME=... \
///     --dart-define=TURN_CREDENTIAL=...
class IceConfig {
  static const _turnUrl = String.fromEnvironment('TURN_URL');
  static const _turnUser = String.fromEnvironment('TURN_USERNAME');
  static const _turnCred = String.fromEnvironment('TURN_CREDENTIAL');

  static Map<String, dynamic> get config {
    final servers = <Map<String, dynamic>>[
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ];

    if (_turnUrl.isNotEmpty && _turnUser.isNotEmpty && _turnCred.isNotEmpty) {
      // Self-hosted coturn — UDP + TCP/443 fallback.
      final host = _turnUrl
          .replaceFirst(RegExp(r'^turns?:'), '')
          .replaceFirst(RegExp(r':\d+$'), '');
      servers.addAll([
        {'urls': _turnUrl, 'username': _turnUser, 'credential': _turnCred},
        {
          'urls': 'turn:$host:443?transport=tcp',
          'username': _turnUser,
          'credential': _turnCred,
        },
        {
          'urls': 'turns:$host:443?transport=tcp',
          'username': _turnUser,
          'credential': _turnCred,
        },
      ]);
    } else {
      // Free fallback (Metered.ca open-relay).
      const u = 'openrelayproject';
      const c = 'openrelayproject';
      servers.addAll([
        {'urls': 'turn:openrelay.metered.ca:80', 'username': u, 'credential': c},
        {'urls': 'turn:openrelay.metered.ca:443', 'username': u, 'credential': c},
        {
          'urls': 'turns:openrelay.metered.ca:443',
          'username': u,
          'credential': c,
        },
      ]);
    }

    return {
      'iceServers': servers,
      'sdpSemantics': 'unified-plan',
      'iceTransportPolicy': 'all',
    };
  }
}
