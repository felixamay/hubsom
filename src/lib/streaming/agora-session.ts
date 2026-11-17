/**
 * Helpers so an Agora reconnect effect cannot tear down the *next* session.
 *
 * The live player stores client/tracks on shared refs for the imperative
 * handle. Effect cleanup is async (leave/close). If cleanup reads those refs
 * *after* awaiting, a newer attempt may already own them — leaving the new
 * client kicks the host/viewer off the show they just rejoined.
 */

export type MutableRef<T> = { current: T };

/** Clear a shared ref only when it still points at the instance we created. */
export function dropRefIfOwned<T>(
  ref: MutableRef<T | null>,
  owned: T | null | undefined,
): void {
  if (owned != null && ref.current === owned) {
    ref.current = null;
  }
}

/**
 * Adopt a client/track into this session, or release it immediately when the
 * effect has already been disposed (replaced by a reconnect attempt).
 */
export function takeSessionResource<T>(
  disposed: boolean,
  value: T,
  ref: MutableRef<T | null>,
  release: (value: T) => void,
): T | null {
  if (disposed) {
    release(value);
    return null;
  }
  ref.current = value;
  return value;
}
