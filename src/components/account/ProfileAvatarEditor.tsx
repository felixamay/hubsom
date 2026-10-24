"use client";

import { useEffect, useRef, useState } from "react";
import { useSession } from "next-auth/react";
import { Camera, Loader2, UserRound } from "lucide-react";
import { cn } from "@/lib/utils";

type Props = {
  image?: string | null;
  name?: string;
  onUploaded?: (url: string) => void;
  size?: "md" | "lg";
  className?: string;
  /** When true, show stronger CTA copy for post-signup onboarding. */
  emphasize?: boolean;
};

export function ProfileAvatarEditor({
  image,
  name = "You",
  onUploaded,
  size = "lg",
  className,
  emphasize = false,
}: Props) {
  const { update } = useSession();
  const inputRef = useRef<HTMLInputElement>(null);
  const [preview, setPreview] = useState(image || "");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Keep local preview in sync when parent loads profile data.
  useEffect(() => {
    setPreview(image || "");
  }, [image]);

  const initials = name
    .split(" ")
    .map((p) => p[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();

  const dim = size === "lg" ? "h-28 w-28" : "h-16 w-16";

  async function upload(file: File) {
    setBusy(true);
    setError(null);
    try {
      const form = new FormData();
      form.append("file", file);
      const res = await fetch("/api/uploads/avatar", {
        method: "POST",
        body: form,
        credentials: "same-origin",
      });
      const data = (await res.json()) as {
        url?: string;
        user?: { image?: string; name?: string };
        error?: string;
      };
      if (!res.ok || !data.url) {
        setError(data.error ?? "Could not upload photo");
        return;
      }
      setPreview(data.url);
      onUploaded?.(data.url);
      await update({
        user: {
          image: data.url,
          name: data.user?.name,
        },
      });
    } catch {
      setError("Network error uploading photo");
    } finally {
      setBusy(false);
      if (inputRef.current) inputRef.current.value = "";
    }
  }

  return (
    <div className={cn("flex flex-col items-center gap-3", className)}>
      <button
        type="button"
        disabled={busy}
        onClick={() => inputRef.current?.click()}
        className={cn(
          "group relative overflow-hidden rounded-3xl border-2 border-dashed bg-hubsom-mist transition disabled:opacity-60",
          emphasize
            ? "border-hubsom-gold ring-4 ring-hubsom-gold/20"
            : "border-hubsom-forest/20",
          dim,
        )}
        aria-label="Change profile photo"
      >
        {preview && preview !== "/brand/hubsom-logo.png" ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={preview}
            alt=""
            className="h-full w-full object-cover"
          />
        ) : (
          <span className="flex h-full w-full flex-col items-center justify-center gap-1 bg-gradient-to-br from-hubsom-cyan to-hubsom-blue text-white">
            {initials ? (
              <span
                className={cn(
                  "font-display font-bold",
                  size === "lg" ? "text-2xl" : "text-lg",
                )}
              >
                {initials}
              </span>
            ) : (
              <UserRound className={size === "lg" ? "h-8 w-8" : "h-6 w-6"} />
            )}
          </span>
        )}
        <span className="absolute inset-x-0 bottom-0 flex items-center justify-center gap-1 bg-black/55 py-1.5 text-[10px] font-bold text-white">
          {busy ? (
            <Loader2 className="h-3 w-3 animate-spin" />
          ) : (
            <Camera className="h-3 w-3" />
          )}
          {busy ? "…" : "Edit"}
        </span>
      </button>

      <input
        ref={inputRef}
        type="file"
        accept="image/jpeg,image/png,image/webp,image/gif"
        className="hidden"
        onChange={(e) => {
          const file = e.target.files?.[0];
          if (file) void upload(file);
        }}
      />

      {size === "lg" ? (
        <div className="text-center">
          <button
            type="button"
            disabled={busy}
            onClick={() => inputRef.current?.click()}
            className="text-sm font-bold text-hubsom-forest disabled:opacity-50"
          >
            {emphasize
              ? busy
                ? "Uploading photo…"
                : "Add a profile photo"
              : busy
                ? "Uploading…"
                : "Change photo"}
          </button>
          <p className="mt-1 text-[11px] text-hubsom-ink/50">
            JPG, PNG, WEBP, or GIF · up to 5MB
          </p>
          {error ? (
            <p className="mt-1 text-xs font-medium text-hubsom-live">{error}</p>
          ) : null}
        </div>
      ) : error ? (
        <p className="max-w-[9rem] text-[10px] font-medium text-hubsom-live">
          {error}
        </p>
      ) : null}
    </div>
  );
}
