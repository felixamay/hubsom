import type { LiveStream } from "@/types";
import { listAllStreams } from "@/lib/data/stream-registry";

/** @deprecated Prefer listAllStreams / getStreamById from stream-registry */
export async function getStream(id: string): Promise<LiveStream | undefined> {
  const streams = await listAllStreams();
  return streams.find((s) => s.id === id);
}

export async function getLiveStreams(): Promise<LiveStream[]> {
  return (await listAllStreams()).filter((s) => s.status === "live");
}

export async function getStreamsBySeller(sellerId: string): Promise<LiveStream[]> {
  return (await listAllStreams()).filter((s) => s.sellerId === sellerId);
}
