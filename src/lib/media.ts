/** Chrome throws AbortError when play() races pause() (unmount, navigation, second play). */

export function isPlayAbortError(err: unknown): boolean {
  if (!err) return false;
  const name = (err as { name?: string }).name;
  const msg = String((err as { message?: string }).message || err);
  return name === "AbortError" || /play\(\) request was interrupted|interrupted by a call to pause/i.test(msg);
}

export function playMedia(el: HTMLMediaElement | null | undefined): Promise<void> {
  if (!el) return Promise.resolve();
  return el.play().then(() => undefined).catch((err) => {
    if (isPlayAbortError(err)) return;
    throw err;
  });
}
