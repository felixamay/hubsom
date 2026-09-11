"use client";

import { Shield, Sparkles } from "lucide-react";
import type { StreamHost } from "@/types";

export function ModeratorPanel({
  hosts,
  onClose,
}: {
  hosts: StreamHost[];
  onClose: () => void;
}) {
  const mods = hosts.filter((h) => h.role === "moderator" || h.role === "host");

  return (
    <div className="rounded-2xl border border-white/15 bg-hubsom-night/95 p-4 text-white shadow-2xl">
      <div className="flex items-center justify-between">
        <div className="inline-flex items-center gap-2 text-xs font-bold uppercase tracking-[0.16em] text-hubsom-gold">
          <Shield className="h-3.5 w-3.5" />
          Moderator
        </div>
        <button type="button" onClick={onClose} className="text-xs text-white/60">
          Close
        </button>
      </div>
      <ul className="mt-3 space-y-2 text-sm">
        {mods.map((m) => (
          <li key={m.id} className="flex items-center justify-between rounded-xl bg-white/5 px-3 py-2">
            <span>
              {m.name}{" "}
              <span className="text-white/45">· {m.role}</span>
            </span>
            <span className="text-xs text-hubsom-mint">Active</span>
          </li>
        ))}
      </ul>
      <div className="mt-4 space-y-2 text-sm">
        <button
          type="button"
          className="flex w-full items-center gap-2 rounded-xl bg-white/10 px-3 py-2 text-left"
        >
          <Sparkles className="h-4 w-4 text-hubsom-gold" />
          AI moderation: auto-hide spam & toxic chat
        </button>
        <button type="button" className="w-full rounded-xl bg-white/10 px-3 py-2 text-left">
          Slow mode · 5s
        </button>
        <button type="button" className="w-full rounded-xl bg-white/10 px-3 py-2 text-left">
          Mute chat for 60s
        </button>
        <button type="button" className="w-full rounded-xl bg-hubsom-live/80 px-3 py-2 text-left font-semibold">
          Remove abusive viewer
        </button>
      </div>
    </div>
  );
}
