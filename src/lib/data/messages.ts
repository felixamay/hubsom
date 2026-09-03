import { getSeller } from "@/lib/data/sellers";
import { getUserById, listUsers } from "@/lib/data/users";
import { readJsonFile, writeJsonFile } from "@/lib/data/persist";

const FILE = "direct-messages.json";

export type DirectMessage = {
  id: string;
  conversationId: string;
  fromUserId: string;
  toUserId: string;
  text: string;
  createdAt: string;
  readAt?: string;
};

type Store = {
  messages: DirectMessage[];
};

export type ConversationPeer = {
  id: string;
  name: string;
  image?: string;
  city?: string;
  region?: string;
};

export type ConversationSummary = {
  conversationId: string;
  peer: ConversationPeer;
  lastMessage: DirectMessage;
  unreadCount: number;
};

async function load(): Promise<Store> {
  return readJsonFile<Store>(FILE, { messages: [] });
}

async function save(store: Store) {
  await writeJsonFile(FILE, store);
}

export function conversationIdFor(userA: string, userB: string): string {
  return [userA, userB].sort().join(":");
}

function toPeer(user: {
  id: string;
  name: string;
  image?: string;
  city?: string;
  region?: string;
}): ConversationPeer {
  return {
    id: user.id,
    name: user.name,
    image: user.image,
    city: user.city,
    region: user.region,
  };
}

/** Resolve a seller to the user account that receives DMs. */
export async function resolvePeerUserIdForSeller(
  sellerId: string,
): Promise<string | null> {
  const seller = await getSeller(sellerId);
  if (!seller) return null;
  if (seller.ownerUserId) return seller.ownerUserId;
  const users = await listUsers();
  const owner = users.find((u) => u.sellerId === sellerId);
  return owner?.id ?? null;
}

export async function listConversationsForUser(
  userId: string,
): Promise<ConversationSummary[]> {
  const store = await load();
  const mine = store.messages.filter(
    (m) => m.fromUserId === userId || m.toUserId === userId,
  );

  const byConversation = new Map<string, DirectMessage[]>();
  for (const msg of mine) {
    const list = byConversation.get(msg.conversationId) ?? [];
    list.push(msg);
    byConversation.set(msg.conversationId, list);
  }

  const summaries: ConversationSummary[] = [];
  for (const [conversationId, msgs] of byConversation) {
    const sorted = [...msgs].sort((a, b) =>
      a.createdAt < b.createdAt ? 1 : -1,
    );
    const lastMessage = sorted[0];
    const peerId =
      lastMessage.fromUserId === userId
        ? lastMessage.toUserId
        : lastMessage.fromUserId;
    const peerUser = await getUserById(peerId);
    if (!peerUser) continue;

    const unreadCount = msgs.filter(
      (m) => m.toUserId === userId && !m.readAt,
    ).length;

    summaries.push({
      conversationId,
      peer: toPeer(peerUser),
      lastMessage,
      unreadCount,
    });
  }

  return summaries.sort((a, b) =>
    a.lastMessage.createdAt < b.lastMessage.createdAt ? 1 : -1,
  );
}

export async function listThread(
  userId: string,
  peerUserId: string,
): Promise<{ peer: ConversationPeer; messages: DirectMessage[] } | null> {
  if (userId === peerUserId) return null;
  const peerUser = await getUserById(peerUserId);
  if (!peerUser) return null;

  const conversationId = conversationIdFor(userId, peerUserId);
  const store = await load();
  const messages = store.messages
    .filter((m) => m.conversationId === conversationId)
    .sort((a, b) => (a.createdAt > b.createdAt ? 1 : -1));

  return { peer: toPeer(peerUser), messages };
}

export async function markThreadRead(userId: string, peerUserId: string) {
  const conversationId = conversationIdFor(userId, peerUserId);
  const store = await load();
  let changed = false;
  const now = new Date().toISOString();
  for (const msg of store.messages) {
    if (
      msg.conversationId === conversationId &&
      msg.toUserId === userId &&
      !msg.readAt
    ) {
      msg.readAt = now;
      changed = true;
    }
  }
  if (changed) await save(store);
}

export async function sendDirectMessage(input: {
  fromUserId: string;
  toUserId: string;
  text: string;
}): Promise<DirectMessage> {
  const text = input.text.trim();
  if (!text) throw new Error("Message can’t be empty");
  if (input.fromUserId === input.toUserId) {
    throw new Error("You can’t message yourself");
  }

  const peer = await getUserById(input.toUserId);
  if (!peer) throw new Error("User not found");

  const store = await load();
  const message: DirectMessage = {
    id: `dm-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 6)}`,
    conversationId: conversationIdFor(input.fromUserId, input.toUserId),
    fromUserId: input.fromUserId,
    toUserId: input.toUserId,
    text,
    createdAt: new Date().toISOString(),
  };
  store.messages.push(message);
  await save(store);
  return message;
}

export async function countUnreadForUser(userId: string): Promise<number> {
  const store = await load();
  return store.messages.filter((m) => m.toUserId === userId && !m.readAt)
    .length;
}

/** People the current user can start a chat with (other Hubsom users). */
export async function listMessageableUsers(
  userId: string,
): Promise<ConversationPeer[]> {
  const users = await listUsers();
  return users
    .filter((u) => u.id !== userId)
    .map((u) => toPeer(u))
    .sort((a, b) => a.name.localeCompare(b.name));
}
