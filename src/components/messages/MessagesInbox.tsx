"use client";

import Image from "next/image";
import Link from "next/link";
import { MessageCircle, Search } from "lucide-react";
import { useMemo, useState } from "react";
import type {
  ConversationPeer,
  ConversationSummary,
} from "@/lib/data/messages";
import { EmptyState } from "@/components/ui/EmptyState";

function timeLabel(iso: string) {
  const d = new Date(iso);
  const now = new Date();
  const sameDay =
    d.getFullYear() === now.getFullYear() &&
    d.getMonth() === now.getMonth() &&
    d.getDate() === now.getDate();
  if (sameDay) {
    return d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  }
  return d.toLocaleDateString([], { month: "short", day: "numeric" });
}

function Avatar({
  peer,
  size = 48,
}: {
  peer: ConversationPeer;
  size?: number;
}) {
  const initials = peer.name
    .split(" ")
    .map((p) => p[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();

  if (peer.image) {
    return (
      <Image
        src={peer.image}
        alt={peer.name}
        width={size}
        height={size}
        className="rounded-2xl object-cover"
        style={{ width: size, height: size }}
      />
    );
  }

  return (
    <span
      className="inline-flex items-center justify-center rounded-2xl bg-gradient-to-br from-hubsom-cyan to-hubsom-blue font-display text-sm font-bold text-white"
      style={{ width: size, height: size }}
    >
      {initials}
    </span>
  );
}

export function MessagesInbox({
  currentUserId,
  initialConversations,
  people,
}: {
  currentUserId: string;
  initialConversations: ConversationSummary[];
  people: ConversationPeer[];
}) {
  const [query, setQuery] = useState("");
  const [tab, setTab] = useState<"chats" | "people">("chats");

  const filteredConversations = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return initialConversations;
    return initialConversations.filter(
      (c) =>
        c.peer.name.toLowerCase().includes(q) ||
        c.lastMessage.text.toLowerCase().includes(q),
    );
  }, [initialConversations, query]);

  const filteredPeople = useMemo(() => {
    const q = query.trim().toLowerCase();
    const base = people.filter((p) => p.id !== currentUserId);
    if (!q) return base;
    return base.filter((p) => p.name.toLowerCase().includes(q));
  }, [people, query, currentUserId]);

  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <div className="flex items-end justify-between gap-3">
        <div>
          <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
            Messages
          </h1>
          <p className="mt-1 text-sm text-hubsom-ink/65">
            Chat with other Hubsom buyers and sellers.
          </p>
        </div>
        <MessageCircle className="mb-1 h-6 w-6 text-hubsom-gold" />
      </div>

      <label className="mt-5 flex items-center gap-2 rounded-2xl border border-hubsom-forest/10 bg-white/80 px-3 py-2.5">
        <Search className="h-4 w-4 shrink-0 text-hubsom-forest/45" />
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search chats or people…"
          className="min-w-0 flex-1 bg-transparent text-sm outline-none placeholder:text-hubsom-ink/40"
        />
      </label>

      <div className="mt-4 grid grid-cols-2 gap-1.5 rounded-2xl border border-hubsom-forest/10 bg-white/80 p-1.5">
        <button
          type="button"
          onClick={() => setTab("chats")}
          className={`rounded-xl px-3 py-2.5 text-sm font-bold transition ${
            tab === "chats"
              ? "bg-hubsom-forest text-white"
              : "text-hubsom-forest hover:bg-hubsom-mist"
          }`}
        >
          Chats
        </button>
        <button
          type="button"
          onClick={() => setTab("people")}
          className={`rounded-xl px-3 py-2.5 text-sm font-bold transition ${
            tab === "people"
              ? "bg-hubsom-forest text-white"
              : "text-hubsom-forest hover:bg-hubsom-mist"
          }`}
        >
          People
        </button>
      </div>

      <div className="mt-4 space-y-2">
        {tab === "chats" ? (
          <>
            {!filteredConversations.length ? (
              <EmptyState
                title="No conversations yet"
                body="Open People to message another Hubsom user, or message a seller from live."
              />
            ) : null}
            {!filteredConversations.length ? (
              <button
                type="button"
                onClick={() => setTab("people")}
                className="flex min-h-11 w-full items-center justify-center rounded-full bg-hubsom-gold text-sm font-bold text-hubsom-ink"
              >
                Browse people
              </button>
            ) : null}
            {filteredConversations.map((c) => (
              <Link
                key={c.conversationId}
                href={`/messages/${c.peer.id}`}
                className="flex items-center gap-3 rounded-2xl border border-hubsom-forest/10 bg-white/80 p-3 active:bg-hubsom-mist/70"
              >
                <div className="relative shrink-0">
                  <Avatar peer={c.peer} />
                  {c.unreadCount > 0 ? (
                    <span className="absolute -right-1 -top-1 flex h-5 min-w-5 items-center justify-center rounded-full bg-hubsom-live px-1 text-[10px] font-bold text-white">
                      {c.unreadCount > 9 ? "9+" : c.unreadCount}
                    </span>
                  ) : null}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center justify-between gap-2">
                    <p className="truncate font-display text-base font-bold text-hubsom-forest">
                      {c.peer.name}
                    </p>
                    <span className="shrink-0 text-[10px] font-semibold text-hubsom-ink/45">
                      {timeLabel(c.lastMessage.createdAt)}
                    </span>
                  </div>
                  <p
                    className={`mt-0.5 truncate text-xs ${
                      c.unreadCount
                        ? "font-semibold text-hubsom-ink/80"
                        : "text-hubsom-ink/55"
                    }`}
                  >
                    {c.lastMessage.fromUserId === currentUserId ? "You: " : ""}
                    {c.lastMessage.text}
                  </p>
                </div>
              </Link>
            ))}
          </>
        ) : (
          <>
            {!filteredPeople.length ? (
              <EmptyState
                title="No people found"
                body="Invite friends to Hubsom or follow sellers who have linked accounts."
                actionHref="/categories"
                actionLabel="Browse Hubsom"
              />
            ) : null}
            {filteredPeople.map((person) => (
              <Link
                key={person.id}
                href={`/messages/${person.id}`}
                className="flex items-center gap-3 rounded-2xl border border-hubsom-forest/10 bg-white/80 p-3 active:bg-hubsom-mist/70"
              >
                <Avatar peer={person} />
                <div className="min-w-0 flex-1">
                  <p className="truncate font-display text-base font-bold text-hubsom-forest">
                    {person.name}
                  </p>
                  <p className="truncate text-xs text-hubsom-ink/55">
                    {[person.city, person.region].filter(Boolean).join(", ") ||
                      "Hubsom member"}
                  </p>
                </div>
                <span className="shrink-0 rounded-lg bg-hubsom-mist px-2.5 py-1.5 text-[11px] font-bold text-hubsom-forest">
                  Message
                </span>
              </Link>
            ))}
          </>
        )}
      </div>
    </div>
  );
}
