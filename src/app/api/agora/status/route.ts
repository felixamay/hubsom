import { NextResponse } from "next/server";
import type { AgoraStatusResponse } from "@/lib/streaming/agora";

export const runtime = "nodejs";

export async function GET() {
  const appIdPresent = Boolean((process.env.NEXT_PUBLIC_AGORA_APP_ID ?? "").trim());
  const certificatePresent = Boolean(
    (process.env.AGORA_APP_CERTIFICATE ?? "").trim(),
  );

  const required: AgoraStatusResponse["required"] = [
    {
      key: "NEXT_PUBLIC_AGORA_APP_ID",
      purpose: "Join Agora RTC channels from the browser (host + viewers)",
      where: "Agora Console → Project Management → App ID",
    },
    {
      key: "AGORA_APP_CERTIFICATE",
      purpose:
        "Secure token generation (required if App Certificate is enabled on the project)",
      where: "Agora Console → Project → App Certificate → Enable / copy primary",
    },
  ];

  const payload: AgoraStatusResponse = {
    configured: appIdPresent,
    appIdPresent,
    certificatePresent,
    mode: appIdPresent ? "live" : "demo",
    message: appIdPresent
      ? certificatePresent
        ? "Agora ready — App ID + Certificate configured. Hosts can go live with secure tokens."
        : "Agora App ID found. Certificate missing — works only if App Certificate is disabled on the Agora project. Prefer adding AGORA_APP_CERTIFICATE."
      : "Agora not configured. Add NEXT_PUBLIC_AGORA_APP_ID (and AGORA_APP_CERTIFICATE) to enable real camera/mic streaming.",
    required,
  };

  return NextResponse.json(payload);
}
