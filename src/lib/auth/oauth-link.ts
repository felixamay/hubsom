import type { AuthProviderId, HubsomUser } from "@/types/auth";

export type OAuthLinkInput = {
  name?: string | null;
  image?: string | null;
  provider: "google" | "facebook" | "apple";
  providerAccountId: string;
};

/**
 * Attach a verified OAuth identity to an existing Hubsom user.
 *
 * Credentials sign-up never verifies email, so a stranger can pre-register
 * `victim@gmail.com` with a password. When the real owner later signs in
 * with Google/Facebook/Apple, we must drop that password — otherwise the
 * attacker keeps a credentials backdoor into the linked account.
 */
export function applyOAuthLink(
  user: HubsomUser,
  input: OAuthLinkInput,
  now: string,
): HubsomUser {
  const alreadyHasThisProvider =
    user.oauthIds[input.provider] === input.providerAccountId;
  const { passwordHash: _passwordHash, ...rest } = user;
  const providers = Array.from(
    new Set([...user.providers, input.provider]),
  ) as AuthProviderId[];
  const oauthName = input.name?.trim();

  return {
    ...rest,
    name: alreadyHasThisProvider
      ? user.name || oauthName || user.email.split("@")[0]
      : oauthName || user.name || user.email.split("@")[0],
    image: input.image || user.image,
    providers,
    oauthIds: { ...user.oauthIds, [input.provider]: input.providerAccountId },
    emailVerified: true,
    updatedAt: now,
  };
}
