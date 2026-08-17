/**
 * Browser Capability Checks
 * 
 * Runtime detection of browser features to provide graceful fallbacks.
 */

/** Check if WebRTC is fully supported (getUserMedia + RTCPeerConnection) */
export const supportsWebRTC = (): boolean => {
  return !!(
    typeof navigator !== 'undefined' &&
    navigator.mediaDevices?.getUserMedia &&
    typeof window !== 'undefined' &&
    window.RTCPeerConnection
  );
};

/** Check if backdrop-filter CSS is supported */
export const supportsBackdropFilter = (): boolean => {
  if (typeof CSS === 'undefined') return false;
  return CSS.supports('backdrop-filter', 'blur(1px)') || 
         CSS.supports('-webkit-backdrop-filter', 'blur(1px)');
};

/** Check if the app is served over HTTPS (required for WebRTC in Safari) */
export const isSecureContext = (): boolean => {
  return typeof window !== 'undefined' && window.isSecureContext;
};
