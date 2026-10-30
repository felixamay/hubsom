/**
 * Guardrails for Agora RTC tokens. Any signed-in caller used to be able to
 * POST /api/agora/token with role=publisher (or a colliding uid) and take
 * over someone else's live camera.
 */

export const DEFAULT_TOKEN_EXPIRE_SECONDS = 3600;
export const MIN_TOKEN_EXPIRE_SECONDS = 60;
export const MAX_TOKEN_EXPIRE_SECONDS = 24 * 60 * 60;

export function wantsPublisherRole(role: unknown): boolean {
  return role === "publisher";
}

export function userCanPublishOnStream(input: {
  userId?: string | null;
  userSellerId?: string | null;
  streamSellerId: string;
  sellerOwnerUserId?: string | null;
  hostUserIds?: readonly string[] | null;
}): boolean {
  const userId = input.userId?.trim();
  if (!userId) return false;
  if (input.userSellerId && input.userSellerId === input.streamSellerId) {
    return true;
  }
  if (input.sellerOwnerUserId && input.sellerOwnerUserId === userId) {
    return true;
  }
  if (input.hostUserIds?.some((id) => id && id === userId)) {
    return true;
  }
  return false;
}

export function clampTokenExpireSeconds(
  value: unknown,
  fallback = DEFAULT_TOKEN_EXPIRE_SECONDS,
): number {
  const raw = value === undefined || value === null ? fallback : value;
  const n = typeof raw === "number" ? raw : Number(raw);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(
    Math.max(Math.floor(n), MIN_TOKEN_EXPIRE_SECONDS),
    MAX_TOKEN_EXPIRE_SECONDS,
  );
}

export function numericUid(uid: unknown): number {
  if (typeof uid === "number" && Number.isFinite(uid)) {
    return Math.abs(Math.floor(uid));
  }
  if (typeof uid === "string" && /^\d+$/.test(uid)) return Number(uid);
  return Math.floor(Math.random() * 100_000_000) + 1;
}

/**
 * Viewers must not pick a uid — Agora drops the existing peer on a collision,
 * so uid=1 (Flutter host) would kick the seller off their own show.
 * Hosts may keep a stable uid so reconnects resume the same publisher slot.
 */
export function resolveAgoraUid(input: {
  requestedUid: unknown;
  isPublisher: boolean;
}): number {
  if (input.isPublisher) return numericUid(input.requestedUid);
  // Skip 0/1 so a viewer token cannot occupy the Flutter host slot (uid 1).
  return Math.floor(Math.random() * 100_000_000) + 2;
}
