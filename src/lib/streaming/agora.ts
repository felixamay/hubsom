/**
 * Hubsom live commerce uses Agora RTC for ultra-low-latency video.
 * Configure NEXT_PUBLIC_AGORA_APP_ID (+ AGORA_APP_CERTIFICATE server-side) for production.
 * Without credentials, the player runs in high-fidelity demo mode.
 */

export const AGORA_APP_ID = process.env.NEXT_PUBLIC_AGORA_APP_ID ?? "";

export const STREAMING_TARGETS = {
  maxLatencyMs: 2000,
  adaptiveBitrate: true,
  resolutions: ["720p", "1080p"] as const,
  concurrentViewersTarget: 10_000,
};

export function isAgoraConfigured(): boolean {
  return Boolean(AGORA_APP_ID);
}

export type AgoraRole = "publisher" | "subscriber";

export interface AgoraTokenRequest {
  channelName: string;
  uid: string | number;
  role: AgoraRole;
  expireSeconds?: number;
}

export interface AgoraTokenResponse {
  appId: string;
  channelName: string;
  token: string | null;
  uid: string | number;
  role: AgoraRole;
  demoMode: boolean;
  expiresAt: number;
}
