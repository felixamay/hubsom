"use client";

import { FormEvent, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Camera, ImageIcon, Loader2, Store } from "lucide-react";
import type { Seller } from "@/types";

async function uploadStoreImage(kind: "avatar" | "cover", file: File) {
  const form = new FormData();
  form.append("file", file);
  form.append("kind", kind);
  const res = await fetch("/api/uploads/store", {
    method: "POST",
    body: form,
    credentials: "same-origin",
  });
  const data = (await res.json()) as {
    url?: string;
    seller?: Seller;
    error?: string;
  };
  if (!res.ok || !data.url) {
    throw new Error(data.error ?? "Upload failed");
  }
  return data;
}

export function StorefrontEditor({ initialSeller }: { initialSeller: Seller }) {
  const router = useRouter();
  const avatarInputRef = useRef<HTMLInputElement>(null);
  const coverInputRef = useRef<HTMLInputElement>(null);

  const [seller, setSeller] = useState(initialSeller);
  const [name, setName] = useState(initialSeller.name);
  const [bio, setBio] = useState(initialSeller.bio);
  const [city, setCity] = useState(initialSeller.city);
  const [region, setRegion] = useState(initialSeller.region);
  const [avatar, setAvatar] = useState(initialSeller.avatar);
  const [cover, setCover] = useState(initialSeller.cover);
  const [busy, setBusy] = useState(false);
  const [uploading, setUploading] = useState<"avatar" | "cover" | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setSeller(initialSeller);
    setName(initialSeller.name);
    setBio(initialSeller.bio);
    setCity(initialSeller.city);
    setRegion(initialSeller.region);
    setAvatar(initialSeller.avatar);
    setCover(initialSeller.cover);
  }, [initialSeller]);

  async function onUpload(kind: "avatar" | "cover", file: File) {
    setUploading(kind);
    setError(null);
    setMessage(null);
    try {
      const data = await uploadStoreImage(kind, file);
      if (kind === "avatar") setAvatar(data.url!);
      else setCover(data.url!);
      if (data.seller) setSeller(data.seller);
      setMessage(kind === "cover" ? "Cover photo updated" : "Store photo updated");
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Upload failed");
    } finally {
      setUploading(null);
      if (kind === "avatar" && avatarInputRef.current) {
        avatarInputRef.current.value = "";
      }
      if (kind === "cover" && coverInputRef.current) {
        coverInputRef.current.value = "";
      }
    }
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    setMessage(null);
    try {
      const res = await fetch("/api/seller/store", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        credentials: "same-origin",
        body: JSON.stringify({ name, bio, city, region, avatar, cover }),
      });
      const data = (await res.json()) as { seller?: Seller; error?: string };
      if (!res.ok || !data.seller) {
        setError(data.error ?? "Could not save storefront");
        return;
      }
      setSeller(data.seller);
      setName(data.seller.name);
      setMessage("Storefront saved");
      router.refresh();
    } catch {
      setError("Network error");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <div className="flex items-end justify-between gap-3">
        <div>
          <p className="text-xs font-bold uppercase tracking-[0.16em] text-hubsom-ink/45">
            Seller hub
          </p>
          <h1 className="mt-1 font-display text-3xl font-extrabold text-hubsom-forest">
            Edit storefront
          </h1>
          <p className="mt-2 text-sm text-hubsom-ink/65">
            Update your store name, profile photo, and cover image.
          </p>
        </div>
        <Link
          href={`/stores/${seller.slug}`}
          className="shrink-0 rounded-xl border border-hubsom-forest/12 px-3 py-2 text-xs font-bold text-hubsom-forest"
        >
          View store
        </Link>
      </div>

      <form
        onSubmit={onSubmit}
        className="mt-5 space-y-4 rounded-3xl border border-hubsom-forest/10 bg-white/80 p-4"
      >
        <div className="overflow-hidden rounded-2xl border border-hubsom-forest/10">
          <button
            type="button"
            disabled={uploading === "cover"}
            onClick={() => coverInputRef.current?.click()}
            className="relative block h-36 w-full overflow-hidden bg-hubsom-night disabled:opacity-60"
            aria-label="Change cover photo"
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={cover}
              alt=""
              className="h-full w-full object-cover opacity-80"
            />
            <span className="absolute inset-0 bg-gradient-to-t from-black/50 to-transparent" />
            <span className="absolute bottom-3 left-3 inline-flex items-center gap-1.5 rounded-full bg-black/55 px-3 py-1.5 text-[11px] font-bold text-white">
              {uploading === "cover" ? (
                <Loader2 className="h-3.5 w-3.5 animate-spin" />
              ) : (
                <ImageIcon className="h-3.5 w-3.5" />
              )}
              {uploading === "cover" ? "Uploading…" : "Change cover"}
            </span>
          </button>

          <div className="relative -mt-8 flex items-end gap-3 px-4 pb-4">
            <button
              type="button"
              disabled={uploading === "avatar"}
              onClick={() => avatarInputRef.current?.click()}
              className="relative h-20 w-20 shrink-0 overflow-hidden rounded-2xl border-2 border-white bg-hubsom-mist shadow-md disabled:opacity-60"
              aria-label="Change store profile photo"
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={avatar}
                alt=""
                className="h-full w-full object-cover"
              />
              <span className="absolute inset-x-0 bottom-0 flex items-center justify-center gap-1 bg-black/55 py-1 text-[10px] font-bold text-white">
                {uploading === "avatar" ? (
                  <Loader2 className="h-3 w-3 animate-spin" />
                ) : (
                  <Camera className="h-3 w-3" />
                )}
                Edit
              </span>
            </button>
            <div className="min-w-0 flex-1 pb-1">
              <p className="truncate font-display text-lg font-bold text-hubsom-forest">
                {name || "Your store"}
              </p>
              <p className="truncate text-xs text-hubsom-ink/55">
                /stores/{seller.slug}
              </p>
            </div>
          </div>
        </div>

        <input
          ref={coverInputRef}
          type="file"
          accept="image/jpeg,image/png,image/webp,image/gif"
          className="hidden"
          onChange={(e) => {
            const file = e.target.files?.[0];
            if (file) void onUpload("cover", file);
          }}
        />
        <input
          ref={avatarInputRef}
          type="file"
          accept="image/jpeg,image/png,image/webp,image/gif"
          className="hidden"
          onChange={(e) => {
            const file = e.target.files?.[0];
            if (file) void onUpload("avatar", file);
          }}
        />

        <label className="block">
          <span className="text-sm font-semibold text-hubsom-forest">
            Store name
          </span>
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            required
            placeholder="e.g. Ama’s Market"
            className="mt-2 w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5 outline-none focus:border-hubsom-leaf"
          />
        </label>

        <label className="block">
          <span className="text-sm font-semibold text-hubsom-forest">Bio</span>
          <textarea
            value={bio}
            onChange={(e) => setBio(e.target.value)}
            rows={3}
            placeholder="What do you sell on Hubsom?"
            className="mt-2 w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5 outline-none focus:border-hubsom-leaf"
          />
        </label>

        <div className="grid grid-cols-2 gap-3">
          <label className="block">
            <span className="text-sm font-semibold text-hubsom-forest">City</span>
            <input
              value={city}
              onChange={(e) => setCity(e.target.value)}
              className="mt-2 w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5 outline-none focus:border-hubsom-leaf"
            />
          </label>
          <label className="block">
            <span className="text-sm font-semibold text-hubsom-forest">
              Region
            </span>
            <input
              value={region}
              onChange={(e) => setRegion(e.target.value)}
              className="mt-2 w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5 outline-none focus:border-hubsom-leaf"
            />
          </label>
        </div>

        {error ? <p className="text-sm text-hubsom-live">{error}</p> : null}
        {message ? <p className="text-sm text-hubsom-leaf">{message}</p> : null}

        <button
          type="submit"
          disabled={busy || !name.trim()}
          className="inline-flex w-full items-center justify-center gap-2 rounded-xl bg-hubsom-forest py-3 text-sm font-bold text-white disabled:opacity-50"
        >
          <Store className="h-4 w-4" />
          {busy ? "Saving…" : "Save storefront"}
        </button>
      </form>
    </div>
  );
}
