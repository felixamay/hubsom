import { NextResponse } from "next/server";
import { RtcRole, RtcTokenBuilder } from "agora-token";
import type { AgoraTokenRequest, AgoraTokenResponse } from "@/lib/streaming/agora";

export const runtime = "nodejs";

function numericUid(uid: string | number | undefined): number {
  if (typeof uid === "number" && Number.isFinite(uid)) return Math.abs(Math.floor(uid));
  if (typeof uid === "string" && /^\d+$/.test(uid)) return Number(uid);
  // Agora allows 0 for auto-assign on some clients; we prefer explicit random uid
  return Math.floor(Math.random() * 100_000_000) + 1;
}

export async function POST(request: Request) {
  const body = (await request.json()) as AgoraTokenRequest;
  const appId = (process.env.NEXT_PUBLIC_AGORA_APP_ID ?? "").trim();
  const certificate = (process.env.AGORA_APP_CERTIFICATE ?? "").trim();
  const channelName = body.channelName?.trim();
  const expireSeconds = body.expireSeconds ?? 3600;
  const role =
    body.role === "publisher" ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER;
  const uid = numericUid(body.uid);

  if (!channelName) {
    return NextResponse.json({ error: "channelName required" }, { status: 400 });
  }

  const expiresAt = Math.floor(Date.now() / 1000) + expireSeconds;

  if (!appId) {
    const demo: AgoraTokenResponse = {
      appId: "DEMO_APP_ID",
      channelName,
      token: null,
      uid,
      role: body.role,
      demoMode: true,
      certificateRequired: false,
      expiresAt,
    };
    return NextResponse.json(demo);
  }

  // Project without App Certificate: null token is valid.
  if (!certificate) {
    const open: AgoraTokenResponse = {
      appId,
      channelName,
      token: null,
      uid,
      role: body.role,
      demoMode: false,
      certificateRequired: false,
      expiresAt,
    };
    return NextResponse.json(open);
  }

  const token = RtcTokenBuilder.buildTokenWithUid(
    appId,
    certificate,
    channelName,
    uid,
    role,
    expireSeconds,
    expireSeconds,
  );

  const response: AgoraTokenResponse = {
    appId,
    channelName,
    token,
    uid,
    role: body.role,
    demoMode: false,
    certificateRequired: true,
    expiresAt,
  };

  return NextResponse.json(response);
}
