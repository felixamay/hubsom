"use client";

import Image from "next/image";
import Link from "next/link";
import { FormEvent, useEffect, useRef, useState } from "react";
import { ArrowLeft, Send } from "lucide-react";
import type { ConversationPeer, DirectMessage } from "@/lib/data/messages";

export function MessageThread({
  currentUserId,
  peer,
  initialMessages,
}: {
  currentUserId: string;
  peer: ConversationPeer;
  initialMessages: DirectMessage[];
}) {
  const [messages, setMessages] = useState(initialMessages);
  const [text, setText] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const endRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    const next = text.trim();
    if (!next || busy) return;
    setBusy(true);
    setError(null);
    try {
      const res = await fetch(`/api/messages/${peer.id}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text: next }),
      });
      const data = (await res.json()) as {
        message?: DirectMessage;
        error?: string;
      };
      if (!res.ok || !data.message) {
        setError(data.error ?? "Could not send");
        return;
      }
      setMessages((prev) => [...prev, data.message!]);
      setText("");
    } catch {
      setError("Network error. Try again.");
    } finally {
      setBusy(false);
    }
  }

  const initials = peer.name
    .split(" ")
    .map((p) => p[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();

  return (
    <div className="mx-auto flex h-[calc(100svh-3.5rem-5.5rem)] max-w-lg flex-col">
      <div className="flex items-center gap-3 border-b border-hubsom-forest/10 bg-white/90 px-3 py-3 backdrop-blur">
        <Link
          href="/messages"
          className="inline-flex h-9 w-9 items-center justify-center rounded-xl border border-hubsom-forest/10 bg-hubsom-mist text-hubsom-forest"
          aria-label="Back to messages"
        >
          <ArrowLeft className="h-4 w-4" />
        </Link>
        {peer.image ? (
          <Image
            src={peer.image}
            alt=""
            width={40}
            height={40}
            className="h-10 w-10 rounded-2xl object-cover"
          />
        ) : (
          <span className="inline-flex h-10 w-10 items-center justify-center rounded-2xl bg-gradient-to-br from-hubsom-cyan to-hubsom-blue font-display text-sm font-bold text-white">
            {initials}
          </span>
        )}
        <div className="min-w-0 flex-1">
          <p className="truncate font-display text-base font-bold text-hubsom-forest">
            {peer.name}
          </p>
          <p className="truncate text-[11px] text-hubsom-ink/50">
            {[peer.city, peer.region].filter(Boolean).join(" · ") ||
              "Direct message"}
          </p>
        </div>
      </div>

      <div className="scrollbar-thin flex-1 space-y-2.5 overflow-y-auto px-4 py-4">
        {!messages.length ? (
          <p className="rounded-2xl bg-hubsom-mist px-4 py-3 text-center text-sm text-hubsom-ink/60">
            Say hello to {peer.name.split(" ")[0]} — your messages stay between
            you two.
          </p>
        ) : null}
        {messages.map((m) => {
          const mine = m.fromUserId === currentUserId;
          return (
            <div
              key={m.id}
              className={`flex ${mine ? "justify-end" : "justify-start"}`}
            >
              <div
                className={`max-w-[80%] rounded-2xl px-3.5 py-2.5 text-sm ${
                  mine
                    ? "rounded-br-md bg-hubsom-forest text-white"
                    : "rounded-bl-md bg-white text-hubsom-ink ring-1 ring-hubsom-forest/10"
                }`}
              >
                <p className="whitespace-pre-wrap break-words">{m.text}</p>
                <p
                  className={`mt-1 text-[10px] ${
                    mine ? "text-white/65" : "text-hubsom-ink/40"
                  }`}
                >
                  {new Date(m.createdAt).toLocaleTimeString([], {
                    hour: "2-digit",
                    minute: "2-digit",
                  })}
                </p>
              </div>
            </div>
          );
        })}
        <div ref={endRef} />
      </div>

      <form
        onSubmit={onSubmit}
        className="border-t border-hubsom-forest/10 bg-white/95 px-3 py-3 backdrop-blur"
        style={{ paddingBottom: "max(0.75rem, env(safe-area-inset-bottom))" }}
      >
        {error ? (
          <p className="mb-2 text-xs font-medium text-hubsom-live">{error}</p>
        ) : null}
        <div className="flex items-center gap-2">
          <input
            ref={inputRef}
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder={`Message ${peer.name.split(" ")[0]}…`}
            className="min-w-0 flex-1 rounded-2xl border border-hubsom-forest/12 bg-hubsom-mist px-3.5 py-2.5 text-sm outline-none focus:border-hubsom-gold"
            maxLength={2000}
          />
          <button
            type="submit"
            disabled={busy || !text.trim()}
            className="inline-flex h-11 w-11 items-center justify-center rounded-2xl bg-hubsom-gold text-hubsom-ink disabled:opacity-50"
            aria-label="Send message"
          >
            <Send className="h-4 w-4" />
          </button>
        </div>
      </form>
    </div>
  );
}
