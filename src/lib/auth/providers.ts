import type { AuthProviderId } from "@/types/auth";

export function getEnabledSocialProviders(): AuthProviderId[] {
  const list: AuthProviderId[] = [];
  if (
    process.env.AUTH_GOOGLE_ID?.trim() &&
    process.env.AUTH_GOOGLE_SECRET?.trim()
  ) {
    list.push("google");
  }
  if (
    process.env.AUTH_FACEBOOK_ID?.trim() &&
    process.env.AUTH_FACEBOOK_SECRET?.trim()
  ) {
    list.push("facebook");
  }
  if (
    process.env.AUTH_APPLE_ID?.trim() &&
    process.env.AUTH_APPLE_SECRET?.trim()
  ) {
    list.push("apple");
  }
  return list;
}
