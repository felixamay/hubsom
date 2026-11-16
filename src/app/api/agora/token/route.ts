import { NextResponse } from "next/server";
import { RtcRole, RtcTokenBuilder } from "agora-token";
import { auth } from "@/auth";
import { findStreamByChannelName } from "@/lib/data/stream-registry";
import { isStreamHost } from "@/lib/live/host-auth";
import type { AgoraRole, AgoraTokenRequest, AgoraTokenResponse } from "@/lib/streaming/agora";

export const runtime = "nodejs";

function numericUid(uid: string | number | undefined): number {
  if (typeof uid === "number" && Number.isFinite(uid)) return Math.abs(Math.floor(uid));
  if (typeof uid === "string" && /^\d+$/.test(uid)) return Number(uid);
  // Agora allows 0 for auto-assign on some clients; we prefer explicit random uid
  return Math.floor(Math.random() * 100_000_000) + 1;
}

export async function POST(request: Request) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const body = (await request.json()) as AgoraTokenRequest;
  const appId = (process.env.NEXT_PUBLIC_AGORA_APP_ID ?? "").trim();
  const certificate = (process.env.AGORA_APP_CERTIFICATE ?? "").trim();
  const channelName = body.channelName?.trim();
  const expireSeconds = body.expireSeconds ?? 3600;
  const uid = numericUid(body.uid);

  if (!channelName) {
    return NextResponse.json({ error: "channelName required" }, { status: 400 });
  }

  let role: AgoraRole = "subscriber";
  if (body.role === "publisher") {
    const stream = await findStreamByChannelName(channelName);
    if (stream && (await isStreamHost(session.user.id, stream))) {
      role = "publisher";
    }
  }

  const expiresAt = Math.floor(Date.now() / 1000) + expireSeconds;

  if (!appId) {
    return NextResponse.json(
      {
        error: "Agora is not configured",
        demoMode: true,
        certificateRequired: Boolean(certificate),
      },
      { status: 503 },
    );
  }

  // Project without App Certificate: null token is valid.
  if (!certificate) {
    const open: AgoraTokenResponse = {
      appId,
      channelName,
      token: null,
      uid,
      role,
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
    role === "publisher" ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER,
    expireSeconds,
    expireSeconds,
  );

  const response: AgoraTokenResponse = {
    appId,
    channelName,
    token,
    uid,
    role,
    demoMode: false,
    certificateRequired: true,
    expiresAt,
  };

  return NextResponse.json(response);
}
