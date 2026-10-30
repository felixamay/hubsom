import { NextResponse } from "next/server";
import { RtcRole, RtcTokenBuilder } from "agora-token";
import { auth } from "@/auth";
import {
  clampTokenExpireSeconds,
  resolveAgoraUid,
  userCanPublishOnStream,
  wantsPublisherRole,
} from "@/lib/agora-publish-auth";
import { getSeller } from "@/lib/data/sellers";
import { findStreamByChannelName } from "@/lib/data/stream-registry";
import { getUserById } from "@/lib/data/users";
import type { AgoraTokenRequest, AgoraTokenResponse } from "@/lib/streaming/agora";

export const runtime = "nodejs";

export async function POST(request: Request) {
  const body = (await request.json()) as AgoraTokenRequest;
  const appId = (process.env.NEXT_PUBLIC_AGORA_APP_ID ?? "").trim();
  const certificate = (process.env.AGORA_APP_CERTIFICATE ?? "").trim();
  const channelName = body.channelName?.trim();
  const isPublisher = wantsPublisherRole(body.role);
  const expireSeconds = clampTokenExpireSeconds(body.expireSeconds);

  if (!channelName) {
    return NextResponse.json({ error: "channelName required" }, { status: 400 });
  }

  if (isPublisher) {
    const session = await auth();
    if (!session?.user?.id) {
      return NextResponse.json({ error: "Sign in required" }, { status: 401 });
    }

    const stream = await findStreamByChannelName(channelName);
    if (!stream) {
      return NextResponse.json({ error: "Live show not found" }, { status: 404 });
    }

    const [user, seller] = await Promise.all([
      getUserById(session.user.id),
      getSeller(stream.sellerId),
    ]);

    const canPublish = userCanPublishOnStream({
      userId: session.user.id,
      userSellerId: user?.sellerId ?? session.user.sellerId,
      streamSellerId: stream.sellerId,
      sellerOwnerUserId: seller?.ownerUserId,
      hostUserIds: stream.hosts?.map((h) => h.id),
    });
    if (!canPublish) {
      return NextResponse.json(
        { error: "Only the host can publish to this live show" },
        { status: 403 },
      );
    }
  }

  const role = isPublisher ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER;
  const uid = resolveAgoraUid({
    requestedUid: body.uid,
    isPublisher,
  });
  const grantedRole = isPublisher ? "publisher" : "subscriber";
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
      role: grantedRole,
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
    role: grantedRole,
    demoMode: false,
    certificateRequired: true,
    expiresAt,
  };

  return NextResponse.json(response);
}
