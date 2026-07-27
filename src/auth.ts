import NextAuth from "next-auth";
import Apple from "next-auth/providers/apple";
import Credentials from "next-auth/providers/credentials";
import Facebook from "next-auth/providers/facebook";
import Google from "next-auth/providers/google";
import { getEnabledSocialProviders } from "@/lib/auth/providers";
import {
  getUserById,
  upsertOAuthUser,
  verifyEmailPassword,
} from "@/lib/data/users";

function socialProviders() {
  const providers = [];
  const enabled = getEnabledSocialProviders();

  if (enabled.includes("google")) {
    providers.push(
      Google({
        clientId: process.env.AUTH_GOOGLE_ID!,
        clientSecret: process.env.AUTH_GOOGLE_SECRET!,
        allowDangerousEmailAccountLinking: true,
      }),
    );
  }

  if (enabled.includes("facebook")) {
    providers.push(
      Facebook({
        clientId: process.env.AUTH_FACEBOOK_ID!,
        clientSecret: process.env.AUTH_FACEBOOK_SECRET!,
        allowDangerousEmailAccountLinking: true,
      }),
    );
  }

  if (enabled.includes("apple")) {
    providers.push(
      Apple({
        clientId: process.env.AUTH_APPLE_ID!,
        clientSecret: process.env.AUTH_APPLE_SECRET!,
        allowDangerousEmailAccountLinking: true,
      }),
    );
  }

  return providers;
}

export { getEnabledSocialProviders };

export const { handlers, auth, signIn, signOut } = NextAuth({
  trustHost: true,
  secret: process.env.AUTH_SECRET,
  session: { strategy: "jwt" },
  pages: {
    signIn: "/auth/sign-in",
    error: "/auth/sign-in",
  },
  providers: [
    Credentials({
      name: "Email",
      credentials: {
        email: { label: "Email", type: "email" },
        password: { label: "Password", type: "password" },
      },
      authorize: async (credentials) => {
        const email = String(credentials?.email ?? "")
          .trim()
          .toLowerCase();
        const password = String(credentials?.password ?? "");
        if (!email || !password) return null;
        const user = await verifyEmailPassword(email, password);
        if (!user) return null;
        return {
          id: user.id,
          email: user.email,
          name: user.name,
          image: user.image,
          role: user.role,
          phone: user.phone,
          city: user.city,
          region: user.region,
          sellerId: user.sellerId,
        };
      },
    }),
    ...socialProviders(),
  ],
  callbacks: {
    async signIn({ user, account }) {
      if (!account || account.provider === "credentials") return true;
      if (!user.email) return false;

      const provider = account.provider as "google" | "facebook" | "apple";
      const dbUser = await upsertOAuthUser({
        email: user.email,
        name: user.name,
        image: user.image,
        provider,
        providerAccountId: account.providerAccountId,
      });
      user.id = dbUser.id;
      user.role = dbUser.role;
      user.phone = dbUser.phone;
      user.city = dbUser.city;
      user.region = dbUser.region;
      user.sellerId = dbUser.sellerId;
      return true;
    },
    async jwt({ token, user, trigger, session }) {
      if (user?.id) {
        token.sub = user.id;
        token.userId = user.id;
        token.role = user.role;
        token.phone = user.phone;
        token.city = user.city;
        token.region = user.region;
        token.sellerId = user.sellerId;
        token.name = user.name;
        token.email = user.email;
        token.picture = user.image;
      }

      if (trigger === "update" && session?.user) {
        token.name = session.user.name ?? token.name;
        token.picture = session.user.image ?? token.picture;
        token.phone = session.user.phone ?? token.phone;
        token.city = session.user.city ?? token.city;
        token.region = session.user.region ?? token.region;
        token.role = session.user.role ?? token.role;
        token.sellerId = session.user.sellerId ?? token.sellerId;
      }

      if (typeof token.userId === "string") {
        const fresh = await getUserById(token.userId);
        if (fresh) {
          token.name = fresh.name;
          token.email = fresh.email;
          token.picture = fresh.image;
          token.role = fresh.role;
          token.phone = fresh.phone;
          token.city = fresh.city;
          token.region = fresh.region;
          token.sellerId = fresh.sellerId;
        }
      }

      return token;
    },
    async session({ session, token }) {
      if (session.user) {
        session.user.id = String(token.userId ?? token.sub ?? "");
        session.user.name = typeof token.name === "string" ? token.name : session.user.name;
        session.user.email =
          typeof token.email === "string" ? token.email : session.user.email;
        session.user.image =
          typeof token.picture === "string" ? token.picture : session.user.image;
        session.user.role = token.role as
          | "buyer"
          | "seller"
          | "both"
          | undefined;
        session.user.phone =
          typeof token.phone === "string" ? token.phone : undefined;
        session.user.city =
          typeof token.city === "string" ? token.city : undefined;
        session.user.region =
          typeof token.region === "string" ? token.region : undefined;
        session.user.sellerId =
          typeof token.sellerId === "string" ? token.sellerId : undefined;
      }
      return session;
    },
  },
});
