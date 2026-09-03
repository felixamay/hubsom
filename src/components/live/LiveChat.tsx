"use client";

import { FormEvent, useEffect, useRef, useState } from "react";
import { useSession } from "next-auth/react";
import type { ChatMessage } from "@/types";

export function LiveChat({
  streamId,
  initialMessages,
  draftText,
  onDraftConsumed,
}: {
  streamId: string;
  initialMessages: ChatMessage[];
  draftText?: string | null;
  onDraftConsumed?: () => void;
}) {
  const { data: session } = useSession();
  const [messages, setMessages] = useState(initialMessages);
  const [text, setText] = useState("");
  const [error, setError] = useState<string | null>(null);
  const endRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  useEffect(() => {
    if (!draftText) return;
    setText(draftText);
    onDraftConsumed?.();
    requestAnimationFrame(() => inputRef.current?.focus());
  }, [draftText, onDraftConsumed]);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (!text.trim() || !session?.user) return;
    setError(null);
    const res = await fetch(`/api/streams/${streamId}/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text }),
    });
    const data = await res.json();
    if (!res.ok) {
      setError(data.error ?? "Could not send");
      return;
    }
    setMessages((prev) => [...prev, data.message]);
    setText("");
  }

  return (
    <div className="flex h-full min-h-0 flex-col rounded-2xl border border-white/10 bg-black/35 backdrop-blur-md">
      <div className="border-b border-white/10 px-4 py-3 text-xs font-semibold uppercase tracking-[0.18em] text-white/70">
        Live chat
      </div>
      <div className="scrollbar-thin flex-1 space-y-3 overflow-y-auto px-4 py-3 text-sm">
        {messages.map((m) => (
          <div key={m.id}>
            <span className="font-semibold text-hubsom-gold">{m.displayName}</span>
            <span className="text-white/85"> {m.text}</span>
          </div>
        ))}
        <div ref={endRef} />
      </div>
      <form onSubmit={onSubmit} className="border-t border-white/10 p-3">
        {error && <p className="mb-2 text-xs text-hubsom-live">{error}</p>}
        <div className="flex gap-2">
          <input
            ref={inputRef}
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="Say something…"
            className="min-w-0 flex-1 rounded-xl border border-white/15 bg-white/10 px-3 py-2 text-sm text-white outline-none placeholder:text-white/40 focus:border-hubsom-gold"
          />
          <button
            type="submit"
            className="rounded-xl bg-hubsom-gold px-3 py-2 text-sm font-bold text-hubsom-ink"
          >
            Send
          </button>
        </div>
      </form>
    </div>
  );
}
