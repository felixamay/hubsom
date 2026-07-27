import { NextResponse } from "next/server";
import { RtcRole, RtcTokenBuilder } from "agora-token";
import type { AgoraTokenRequest, AgoraTokenResponse } from "@/lib/streaming/agora";

export const runtime = "nodejs";

export async function POST(request: Request) {
  const body = (await request.json()) as AgoraTokenRequest;
  const appId = process.env.NEXT_PUBLIC_AGORA_APP_ID ?? "";
  const certificate = process.env.AGORA_APP_CERTIFICATE ?? "";
  const channelName = body.channelName?.trim();
  const uid = body.uid ?? 0;
  const expireSeconds = body.expireSeconds ?? 3600;
  const role =
    body.role === "publisher" ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER;

  if (!channelName) {
    return NextResponse.json({ error: "channelName required" }, { status: 400 });
  }

  const expiresAt = Math.floor(Date.now() / 1000) + expireSeconds;

  if (!appId || !certificate) {
    const demo: AgoraTokenResponse = {
      appId: appId || "DEMO_APP_ID",
      channelName,
      token: null,
      uid,
      role: body.role,
      demoMode: true,
      expiresAt,
    };
    return NextResponse.json(demo);
  }

  const token = RtcTokenBuilder.buildTokenWithUid(
    appId,
    certificate,
    channelName,
    typeof uid === "string" ? 0 : uid,
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
    expiresAt,
  };

  return NextResponse.json(response);
}
