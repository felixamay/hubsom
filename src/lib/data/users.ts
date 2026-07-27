import bcrypt from "bcryptjs";
import { readJsonFile, slugify, writeJsonFile } from "@/lib/data/persist";
import type {
  AuthProviderId,
  HubsomUser,
  PublicUser,
  UserAddress,
} from "@/types/auth";

const FILE = "users.json";
type Store = { users: HubsomUser[] };

async function load(): Promise<Store> {
  const store = await readJsonFile<Store>(FILE, { users: [] });
  // Backfill lists for older accounts.
  store.users = store.users.map((u) => ({
    ...u,
    followingSellerIds: Array.isArray(u.followingSellerIds)
      ? u.followingSellerIds
      : [],
    savedProductIds: Array.isArray(u.savedProductIds) ? u.savedProductIds : [],
  }));
  return store;
}

async function save(store: Store) {
  await writeJsonFile(FILE, store);
}

export function toPublicUser(user: HubsomUser): PublicUser {
  const { passwordHash: _passwordHash, oauthIds: _oauthIds, ...rest } = user;
  return rest;
}

export async function listUsers(): Promise<HubsomUser[]> {
  return (await load()).users;
}

export async function getUserById(id: string): Promise<HubsomUser | undefined> {
  return (await load()).users.find((u) => u.id === id);
}

export async function getUserByEmail(
  email: string,
): Promise<HubsomUser | undefined> {
  const normalized = email.trim().toLowerCase();
  return (await load()).users.find((u) => u.email === normalized);
}

export async function createEmailUser(input: {
  name: string;
  email: string;
  password: string;
}): Promise<HubsomUser> {
  const store = await load();
  const email = input.email.trim().toLowerCase();
  if (!email || !email.includes("@")) {
    throw new Error("Valid email required");
  }
  if (store.users.some((u) => u.email === email)) {
    throw new Error("An account with this email already exists");
  }
  if (input.password.length < 8) {
    throw new Error("Password must be at least 8 characters");
  }

  const now = new Date().toISOString();
  const user: HubsomUser = {
    id: `user-${Date.now().toString(36)}`,
    email,
    name: input.name.trim() || email.split("@")[0],
    passwordHash: await bcrypt.hash(input.password, 10),
    image: "/brand/hubsom-logo.png",
    role: "buyer",
    followingSellerIds: [],
    savedProductIds: [],
    addresses: [],
    providers: ["credentials"],
    oauthIds: {},
    emailVerified: false,
    createdAt: now,
    updatedAt: now,
  };

  store.users.unshift(user);
  await save(store);
  return user;
}

export async function verifyEmailPassword(
  email: string,
  password: string,
): Promise<HubsomUser | null> {
  const user = await getUserByEmail(email);
  if (!user?.passwordHash) return null;
  const ok = await bcrypt.compare(password, user.passwordHash);
  return ok ? user : null;
}

export async function upsertOAuthUser(input: {
  email: string;
  name?: string | null;
  image?: string | null;
  provider: "google" | "facebook" | "apple";
  providerAccountId: string;
}): Promise<HubsomUser> {
  const store = await load();
  const email = input.email.trim().toLowerCase();
  const now = new Date().toISOString();

  let user =
    store.users.find((u) => u.oauthIds[input.provider] === input.providerAccountId) ??
    store.users.find((u) => u.email === email);

  if (user) {
    const providers = Array.from(
      new Set([...user.providers, input.provider]),
    ) as AuthProviderId[];
    user = {
      ...user,
      name: user.name || input.name?.trim() || user.email.split("@")[0],
      image: input.image || user.image,
      providers,
      oauthIds: { ...user.oauthIds, [input.provider]: input.providerAccountId },
      emailVerified: true,
      updatedAt: now,
    };
    const idx = store.users.findIndex((u) => u.id === user!.id);
    store.users[idx] = user;
    await save(store);
    return user;
  }

  user = {
    id: `user-${Date.now().toString(36)}`,
    email,
    name: input.name?.trim() || email.split("@")[0],
    image: input.image || "/brand/hubsom-logo.png",
    role: "buyer",
    followingSellerIds: [],
    savedProductIds: [],
    addresses: [],
    providers: [input.provider],
    oauthIds: { [input.provider]: input.providerAccountId },
    emailVerified: true,
    createdAt: now,
    updatedAt: now,
  };
  store.users.unshift(user);
  await save(store);
  return user;
}

export async function updateUserProfile(
  userId: string,
  patch: Partial<
    Pick<
      HubsomUser,
      | "name"
      | "phone"
      | "city"
      | "region"
      | "bio"
      | "image"
      | "role"
      | "sellerId"
      | "addresses"
      | "followingSellerIds"
      | "savedProductIds"
    >
  >,
): Promise<HubsomUser | undefined> {
  const store = await load();
  const idx = store.users.findIndex((u) => u.id === userId);
  if (idx < 0) return undefined;
  store.users[idx] = {
    ...store.users[idx],
    ...patch,
    id: userId,
    updatedAt: new Date().toISOString(),
  };
  await save(store);
  return store.users[idx];
}

export async function upsertAddress(
  userId: string,
  address: Omit<UserAddress, "id"> & { id?: string },
): Promise<HubsomUser | undefined> {
  const user = await getUserById(userId);
  if (!user) return undefined;

  let addresses = [...user.addresses];
  const id = address.id ?? `addr-${Date.now().toString(36)}`;
  const next: UserAddress = {
    id,
    label: address.label.trim() || "Home",
    line1: address.line1.trim(),
    line2: address.line2?.trim(),
    city: address.city.trim() || "Accra",
    region: address.region.trim() || "Greater Accra",
    phone: address.phone?.trim(),
    isDefault: Boolean(address.isDefault),
  };

  if (!next.line1) throw new Error("Address line is required");

  const existingIdx = addresses.findIndex((a) => a.id === id);
  if (existingIdx >= 0) addresses[existingIdx] = next;
  else addresses.push(next);

  if (next.isDefault) {
    addresses = addresses.map((a) => ({ ...a, isDefault: a.id === id }));
  } else if (!addresses.some((a) => a.isDefault) && addresses.length) {
    addresses[0] = { ...addresses[0], isDefault: true };
  }

  return updateUserProfile(userId, { addresses });
}

export async function deleteAddress(
  userId: string,
  addressId: string,
): Promise<HubsomUser | undefined> {
  const user = await getUserById(userId);
  if (!user) return undefined;
  let addresses = user.addresses.filter((a) => a.id !== addressId);
  if (addresses.length && !addresses.some((a) => a.isDefault)) {
    addresses = addresses.map((a, i) => ({ ...a, isDefault: i === 0 }));
  }
  return updateUserProfile(userId, { addresses });
}

export function suggestSellerSlug(name: string) {
  return slugify(name) || "hubsom-store";
}
