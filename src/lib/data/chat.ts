import { readJsonFile, writeJsonFile } from "@/lib/data/persist";
import type { ChatMessage } from "@/types";

const FILE = "chat.json";
type Store = Record<string, ChatMessage[]>;

async function load(): Promise<Store> {
  return readJsonFile<Store>(FILE, {});
}

async function save(store: Store) {
  await writeJsonFile(FILE, store);
}

export async function listChatMessages(streamId: string): Promise<ChatMessage[]> {
  const store = await load();
  return store[streamId] ?? [];
}

export async function appendChatMessage(
  message: ChatMessage,
): Promise<ChatMessage> {
  const store = await load();
  const list = store[message.streamId] ?? [];
  list.push(message);
  store[message.streamId] = list.slice(-200);
  await save(store);
  return message;
}
