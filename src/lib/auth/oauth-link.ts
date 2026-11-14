/**
 * Verified OAuth must not leave a password backdoor on an unverified
 * credentials account that merely shares the same email.
 *
 * Attack: POST /api/auth/signup with the victim's email (no verification),
 * then wait for the victim to "Continue with Google". Linking by email
 * would otherwise let the attacker keep signing in with the squat password.
 */

export type OAuthProvider = "google" | "facebook" | "apple";

export function isUnverifiedPasswordSquat(
  user: {
    passwordHash?: string;
    emailVerified: boolean;
    oauthIds: Partial<Record<OAuthProvider, string>>;
  },
  provider: OAuthProvider,
): boolean {
  if (user.oauthIds[provider]) return false;
  return Boolean(user.passwordHash) && !user.emailVerified;
}

export function nextSessionEpoch(sessionEpoch?: number): number {
  return (sessionEpoch ?? 0) + 1;
}

/**
 * Existing JWTs must match the user's current epoch. A brand-new sign-in
 * (`isNewSignIn`) adopts the epoch instead of being rejected.
 */
export function sessionEpochRevoked(
  tokenEpoch: number | undefined,
  userEpoch: number | undefined,
  isNewSignIn: boolean,
): boolean {
  if (isNewSignIn) return false;
  const epoch = userEpoch ?? 0;
  return epoch > 0 && (tokenEpoch ?? 0) !== epoch;
}
