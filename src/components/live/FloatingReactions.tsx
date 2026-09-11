"use client";

import { useEffect } from "react";
import { useLiveStore } from "@/lib/stores/live";

export function FloatingReactions() {
  const reactions = useLiveStore((s) => s.reactions);
  const prune = useLiveStore((s) => s.pruneReactions);

  useEffect(() => {
    const id = window.setInterval(prune, 400);
    return () => window.clearInterval(id);
  }, [prune]);

  return (
    <div className="pointer-events-none absolute inset-x-0 bottom-28 top-24 overflow-hidden">
      {reactions.map((r) => (
        <span
          key={r.id}
          className="animate-float-heart absolute bottom-0 text-2xl"
          style={{ left: `${Math.min(92, Math.max(4, r.x * 100))}%` }}
        >
          {r.emoji}
        </span>
      ))}
    </div>
  );
}
