import { auth } from "@/auth";
import { redirect } from "next/navigation";

export async function requireUser(callbackPath: string) {
  const session = await auth();
  if (!session?.user?.id) {
    redirect(`/auth/sign-in?callbackUrl=${encodeURIComponent(callbackPath)}`);
  }
  return session;
}
