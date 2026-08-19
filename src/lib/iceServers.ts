/**
 * WebRTC ICE server list.
 *
 * STUN is always included. TURN comes from VITE_TURN_* in .env
 * (baked in at Vite build time).
 */

const STUN_SERVERS: RTCIceServer[] = [
  { urls: 'stun:stun.l.google.com:19302' },
  { urls: 'stun:stun1.l.google.com:19302' },
  { urls: 'stun:stun2.l.google.com:19302' },
  { urls: 'stun:stun.cloudflare.com:3478' },
  { urls: 'stun:stun.nextcloud.com:443' },
];

function buildIceServers(): RTCIceServer[] {
  const servers: RTCIceServer[] = [...STUN_SERVERS];

  const turnUrl = import.meta.env.VITE_TURN_URL;
  const turnUser = import.meta.env.VITE_TURN_USERNAME;
  const turnCred = import.meta.env.VITE_TURN_CREDENTIAL;

  if (turnUrl && turnUser && turnCred) {
    servers.push({
      urls: turnUrl,
      username: turnUser,
      credential: turnCred,
    });
    const turnHost = turnUrl.replace(/^turns?:/, '').replace(/:\d+$/, '');
    // UDP from VITE_TURN_URL plus TCP 3478. Skip turns:5349 — coturn has no TLS certs.
    servers.push({
      urls: `turn:${turnHost}:3478?transport=tcp`,
      username: turnUser,
      credential: turnCred,
    });
  } else if (import.meta.env.DEV) {
    console.info('[ICE] No VITE_TURN_* in .env — STUN only. Video may fail behind strict NAT.');
  }

  return servers;
}

export const ICE_SERVERS: RTCConfiguration = {
  iceServers: buildIceServers(),
  iceCandidatePoolSize: 4,
};

export const ICE_SERVERS_SFU: RTCConfiguration = {
  iceServers: buildIceServers(),
  iceCandidatePoolSize: 2,
};
