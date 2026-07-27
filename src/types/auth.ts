import type { DefaultSession } from "next-auth";

export type AuthProviderId = "credentials" | "google" | "facebook" | "apple";

export interface UserAddress {
  id: string;
  label: string;
  line1: string;
  line2?: string;
  city: string;
  region: string;
  phone?: string;
  isDefault?: boolean;
}

export interface HubsomUser {
  id: string;
  email: string;
  name: string;
  passwordHash?: string;
  image?: string;
  phone?: string;
  city?: string;
  region?: string;
  bio?: string;
  role: "buyer" | "seller" | "both";
  sellerId?: string;
  addresses: UserAddress[];
  providers: AuthProviderId[];
  oauthIds: Partial<Record<"google" | "facebook" | "apple", string>>;
  emailVerified: boolean;
  createdAt: string;
  updatedAt: string;
}

export type PublicUser = Omit<HubsomUser, "passwordHash" | "oauthIds">;

declare module "next-auth" {
  interface Session {
    user: {
      id: string;
      role?: HubsomUser["role"];
      phone?: string;
      city?: string;
      region?: string;
      sellerId?: string;
    } & DefaultSession["user"];
  }

  interface User {
    role?: HubsomUser["role"];
    phone?: string;
    city?: string;
    region?: string;
    sellerId?: string;
  }
}

declare module "@auth/core/jwt" {
  interface JWT {
    userId?: string;
    role?: HubsomUser["role"];
    phone?: string;
    city?: string;
    region?: string;
    sellerId?: string;
  }
}
