import type { Metadata } from "next";
import { requireUser } from "@/lib/auth/session";
import {
  listConversationsForUser,
  listMessageableUsers,
} from "@/lib/data/messages";
import { MessagesInbox } from "@/components/messages/MessagesInbox";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Messages",
};

export default async function MessagesPage() {
  const session = await requireUser("/messages");
  const [conversations, people] = await Promise.all([
    listConversationsForUser(session.user.id),
    listMessageableUsers(session.user.id),
  ]);

  return (
    <MessagesInbox
      currentUserId={session.user.id}
      initialConversations={conversations}
      people={people}
    />
  );
}
