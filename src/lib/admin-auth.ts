import { timingSafeEqual } from "crypto";

/** Shared secret between Hubsom and HubsomAdmin. */
export function getAdminApiKey() {
  return process.env.HUBSOM_ADMIN_API_KEY?.trim() || "";
}

export function isAdminAuthorized(request: Request): boolean {
  const expected = getAdminApiKey();
  if (!expected) {
    // Dev convenience: allow when key not configured (prototype).
    // Set HUBSOM_ADMIN_API_KEY in production.
    return process.env.NODE_ENV !== "production";
  }

  const header =
    request.headers.get("x-hubsom-admin-key") ||
    request.headers.get("authorization");
  if (!header) return false;

  const provided = header.startsWith("Bearer ")
    ? header.slice("Bearer ".length).trim()
    : header.trim();

  try {
    const a = Buffer.from(expected);
    const b = Buffer.from(provided);
    return a.length === b.length && timingSafeEqual(a, b);
  } catch {
    return false;
  }
}
