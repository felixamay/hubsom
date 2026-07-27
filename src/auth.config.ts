import type { NextAuthConfig } from "next-auth";

/**
 * Edge-safe Auth.js config (no Node-only imports).
 * Full providers + Node callbacks live in `auth.ts`.
 */
export const authConfig = {
  trustHost: true,
  secret: process.env.AUTH_SECRET,
  session: { strategy: "jwt" },
  pages: {
    signIn: "/auth/sign-in",
    error: "/auth/sign-in",
  },
  providers: [],
  callbacks: {
    authorized({ auth, request }) {
      const { pathname, search } = request.nextUrl;
      const loggedIn = Boolean(auth?.user);

      // Auth.js routes + our signup/providers helpers must stay public.
      if (pathname.startsWith("/api/auth")) return true;

      // Huber delivery webhooks (signed when HUBERS_WEBHOOK_SECRET is set).
      if (pathname.startsWith("/api/integrations/hubers")) return true;

      // Public promotions feed for storefront / admin preview.
      if (pathname === "/api/promotions" || pathname.startsWith("/api/promotions/")) {
        return true;
      }

      // HubsomAdmin integration (API key checked in route handlers).
      if (pathname.startsWith("/api/admin")) return true;

      const isAuthPage =
        pathname.startsWith("/auth/sign-in") ||
        pathname.startsWith("/auth/sign-up");

      if (isAuthPage) {
        if (loggedIn) {
          const callback = request.nextUrl.searchParams.get("callbackUrl");
          const dest =
            callback && callback.startsWith("/") && !callback.startsWith("//")
              ? callback
              : "/";
          return Response.redirect(new URL(dest, request.nextUrl));
        }
        return true;
      }

      if (!loggedIn) {
        if (pathname.startsWith("/api/")) {
          return Response.json(
            { error: "Sign in required" },
            { status: 401 },
          );
        }

        const signIn = new URL("/auth/sign-in", request.nextUrl.origin);
        const callbackUrl = `${pathname}${search}`;
        if (callbackUrl && callbackUrl !== "/") {
          signIn.searchParams.set("callbackUrl", callbackUrl);
        }
        return Response.redirect(signIn);
      }

      return true;
    },
  },
} satisfies NextAuthConfig;
