"use client";

import { useRouter } from "next/navigation";
import { useSession } from "next-auth/react";
import { useState, useTransition, type MouseEvent } from "react";
import { Heart } from "lucide-react";
import { cn } from "@/lib/utils";

export function SaveProductButton({
  productId,
  initialSaved = false,
  size = "md",
  variant = "default",
  className,
  label,
}: {
  productId: string;
  initialSaved?: boolean;
  size?: "sm" | "md" | "icon";
  variant?: "default" | "live" | "overlay";
  className?: string;
  /** Show text beside the heart (default / live only). */
  label?: boolean;
}) {
  const { data: session, status } = useSession();
  const router = useRouter();
  const [saved, setSaved] = useState(initialSaved);
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  function toggle(e?: MouseEvent) {
    e?.preventDefault();
    e?.stopPropagation();

    if (status === "unauthenticated" || !session?.user) {
      router.push(
        `/auth/sign-in?callbackUrl=${encodeURIComponent(window.location.pathname)}`,
      );
      return;
    }

    setError(null);
    const prev = saved;
    const next = !prev;
    setSaved(next);

    startTransition(async () => {
      try {
        const res = await fetch(`/api/products/${productId}/save`, {
          method: next ? "POST" : "DELETE",
        });
        const data = await res.json();
        if (!res.ok) {
          setSaved(prev);
          setError(data.error ?? "Could not update save");
          return;
        }
        setSaved(Boolean(data.saved));
        router.refresh();
      } catch {
        setSaved(prev);
        setError("Could not update save");
      }
    });
  }

  const showLabel = label && size !== "icon";

  return (
    <div className={cn("inline-flex flex-col items-stretch", className)}>
      <button
        type="button"
        onClick={toggle}
        disabled={pending || status === "loading"}
        aria-pressed={saved}
        aria-label={saved ? "Remove from saved" : "Save product"}
        className={cn(
          "inline-flex items-center justify-center gap-1.5 font-bold transition active:scale-[0.98] disabled:opacity-60",
          size === "sm" && "h-8 rounded-lg px-2.5 text-[11px]",
          size === "md" && "h-10 rounded-xl px-3.5 text-xs",
          size === "icon" && "h-9 w-9 rounded-full",
          variant === "overlay" &&
            (saved
              ? "bg-white/95 text-hubsom-live shadow-md"
              : "bg-black/45 text-white backdrop-blur-sm"),
          variant === "live" &&
            (saved
              ? "border border-white/25 bg-white/15 text-white"
              : "border border-white/20 bg-black/40 text-white"),
          variant === "default" &&
            (saved
              ? "border border-hubsom-live/25 bg-hubsom-live/10 text-hubsom-live"
              : "border border-hubsom-forest/15 bg-white text-hubsom-forest"),
        )}
      >
        <Heart
          className={cn(
            size === "sm" ? "h-3.5 w-3.5" : "h-4 w-4",
            saved && "fill-current",
          )}
        />
        {showLabel ? (saved ? "Saved" : "Save") : null}
      </button>
      {error ? (
        <p className="mt-1 text-[10px] font-medium text-hubsom-live">{error}</p>
      ) : null}
    </div>
  );
}
