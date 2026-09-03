"use client";

import { useRouter } from "next/navigation";
import { useSession } from "next-auth/react";
import { useState, useTransition } from "react";
import { UserPlus, UserCheck } from "lucide-react";
import { cn } from "@/lib/utils";

export function FollowButton({
  sellerId,
  initialFollowing = false,
  initialFollowers,
  isOwnStore = false,
  size = "md",
  variant = "default",
  className,
  onFollowersChange,
}: {
  sellerId: string;
  initialFollowing?: boolean;
  initialFollowers?: number;
  isOwnStore?: boolean;
  size?: "sm" | "md";
  variant?: "default" | "live";
  className?: string;
  onFollowersChange?: (count: number) => void;
}) {
  const { data: session, status } = useSession();
  const router = useRouter();
  const [following, setFollowing] = useState(initialFollowing);
  const [followers, setFollowers] = useState(initialFollowers);
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const ownStore =
    isOwnStore ||
    Boolean(session?.user?.sellerId && session.user.sellerId === sellerId);

  if (ownStore) return null;

  function toggle() {
    if (status === "unauthenticated" || !session?.user) {
      router.push(
        `/auth/sign-in?callbackUrl=${encodeURIComponent(window.location.pathname)}`,
      );
      return;
    }

    if (session.user.sellerId && session.user.sellerId === sellerId) {
      setError("You can’t follow yourself");
      return;
    }

    setError(null);
    const prevFollowing = following;
    const prevFollowers = followers;
    const nextFollowing = !prevFollowing;

    setFollowing(nextFollowing);
    if (typeof prevFollowers === "number") {
      const count = Math.max(0, prevFollowers + (nextFollowing ? 1 : -1));
      setFollowers(count);
      onFollowersChange?.(count);
    }

    startTransition(async () => {
      try {
        const res = await fetch(`/api/sellers/${sellerId}/follow`, {
          method: nextFollowing ? "POST" : "DELETE",
        });
        const data = await res.json();
        if (!res.ok) {
          setFollowing(prevFollowing);
          if (typeof prevFollowers === "number") {
            setFollowers(prevFollowers);
            onFollowersChange?.(prevFollowers);
          }
          setError(data.error ?? "Could not update follow");
          return;
        }
        setFollowing(Boolean(data.following));
        if (typeof data.followers === "number") {
          setFollowers(data.followers);
          onFollowersChange?.(data.followers);
        }
        router.refresh();
      } catch {
        setFollowing(prevFollowing);
        if (typeof prevFollowers === "number") {
          setFollowers(prevFollowers);
          onFollowersChange?.(prevFollowers);
        }
        setError("Could not update follow");
      }
    });
  }

  return (
    <div className={cn("inline-flex flex-col items-stretch", className)}>
      <button
        type="button"
        onClick={toggle}
        disabled={pending || status === "loading"}
        aria-pressed={following}
        className={cn(
          "inline-flex items-center justify-center gap-1.5 font-bold transition active:scale-[0.98] disabled:opacity-60",
          size === "sm"
            ? "h-8 rounded-lg px-2.5 text-[11px]"
            : "h-10 rounded-xl px-3.5 text-xs",
          variant === "live"
            ? following
              ? "border border-white/25 bg-white/15 text-white"
              : "bg-hubsom-gold text-hubsom-ink shadow-[0_10px_20px_-14px_rgba(247,148,29,0.85)]"
            : following
              ? "border border-hubsom-forest/15 bg-white text-hubsom-forest"
              : "bg-hubsom-forest text-white shadow-[0_10px_20px_-14px_rgba(10,61,92,0.85)]",
        )}
      >
        {following ? (
          <UserCheck className={size === "sm" ? "h-3.5 w-3.5" : "h-4 w-4"} />
        ) : (
          <UserPlus className={size === "sm" ? "h-3.5 w-3.5" : "h-4 w-4"} />
        )}
        {following ? "Following" : "Follow"}
      </button>
      {error ? (
        <p className="mt-1 text-[10px] font-medium text-hubsom-live">{error}</p>
      ) : null}
    </div>
  );
}
