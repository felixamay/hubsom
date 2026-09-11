/**
 * Hubsom live commerce — Agora RTC
 *
 * Required for real camera/mic streaming:
 * 1. NEXT_PUBLIC_AGORA_APP_ID  — from https://console.agora.io → Project → App ID
 * 2. AGORA_APP_CERTIFICATE     — Project → App Certificate (if enabled on the project)
 *
 * Optional later (cloud recording / push / scale):
 * 3. AGORA_CUSTOMER_ID / AGORA_CUSTOMER_SECRET — RESTful API for cloud recording
 * 4. AGORA_RECORDING_BUCKET + credentials — storage for replays
 */

export const AGORA_APP_ID = process.env.NEXT_PUBLIC_AGORA_APP_ID ?? "";

export const STREAMING_TARGETS = {
  maxLatencyMs: 2000,
  adaptiveBitrate: true,
  resolutions: ["720p", "1080p"] as const,
  concurrentViewersTarget: 10_000,
};

export function isAgoraConfigured(): boolean {
  return Boolean(AGORA_APP_ID.trim());
}

export function agoraCertificateConfigured(): boolean {
  return Boolean((process.env.AGORA_APP_CERTIFICATE ?? "").trim());
}

export type AgoraRole = "publisher" | "subscriber";

export interface AgoraTokenRequest {
  channelName: string;
  uid?: string | number;
  role: AgoraRole;
  expireSeconds?: number;
}

export interface AgoraTokenResponse {
  appId: string;
  channelName: string;
  token: string | null;
  uid: number;
  role: AgoraRole;
  demoMode: boolean;
  certificateRequired: boolean;
  expiresAt: number;
}

export interface AgoraStatusResponse {
  configured: boolean;
  appIdPresent: boolean;
  certificatePresent: boolean;
  mode: "live" | "demo";
  message: string;
  required: Array<{ key: string; purpose: string; where: string }>;
}
