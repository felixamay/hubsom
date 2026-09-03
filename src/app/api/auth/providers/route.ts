import { NextResponse } from "next/server";
import { getEnabledSocialProviders } from "@/lib/auth/providers";

export async function GET() {
  return NextResponse.json({
    credentials: true,
    social: getEnabledSocialProviders(),
  });
}
