import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { requireUser } from "@/lib/auth/session";
import { listThread, markThreadRead } from "@/lib/data/messages";
import { MessageThread } from "@/components/messages/MessageThread";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Chat",
};

export default async function MessageThreadPage({
  params,
}: {
  params: Promise<{ userId: string }>;
}) {
  const session = await requireUser("/messages");
  const { userId: peerUserId } = await params;

  if (peerUserId === session.user.id) {
    notFound();
  }

  const thread = await listThread(session.user.id, peerUserId);
  if (!thread) notFound();

  await markThreadRead(session.user.id, peerUserId);

  return (
    <MessageThread
      currentUserId={session.user.id}
      peer={thread.peer}
      initialMessages={thread.messages}
    />
  );
}
