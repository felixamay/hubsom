"use client";

import { useRef, useState } from "react";
import { ImagePlus, Loader2, Star, Trash2, Upload } from "lucide-react";

type Props = {
  images: string[];
  onChange: (images: string[]) => void;
};

export function ProductImageUploader({ images, onChange }: Props) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [dragOver, setDragOver] = useState(false);

  async function uploadFiles(fileList: FileList | File[]) {
    const files = Array.from(fileList).filter((f) => f.type.startsWith("image/"));
    if (!files.length) {
      setError("Choose image files (JPG, PNG, WEBP, or GIF)");
      return;
    }
    if (images.length + files.length > 8) {
      setError("You can add up to 8 product images");
      return;
    }

    setBusy(true);
    setError(null);
    try {
      const form = new FormData();
      for (const file of files.slice(0, 6)) form.append("files", file);
      const res = await fetch("/api/uploads/products", {
        method: "POST",
        body: form,
      });
      const data = (await res.json()) as { urls?: string[]; error?: string };
      if (!res.ok || !data.urls?.length) {
        setError(data.error ?? "Upload failed");
        return;
      }
      onChange([...images, ...data.urls]);
    } catch {
      setError("Network error while uploading");
    } finally {
      setBusy(false);
      if (inputRef.current) inputRef.current.value = "";
    }
  }

  function removeAt(index: number) {
    onChange(images.filter((_, i) => i !== index));
  }

  function makeCover(index: number) {
    if (index === 0) return;
    const next = [...images];
    const [picked] = next.splice(index, 1);
    next.unshift(picked);
    onChange(next);
  }

  return (
    <div className="space-y-3">
      <div className="flex items-end justify-between gap-3">
        <div>
          <p className="text-sm font-semibold text-hubsom-forest">Product images</p>
          <p className="mt-0.5 text-xs text-hubsom-ink/55">
            Upload photos of the item. First image is the cover.
          </p>
        </div>
        <span className="text-[11px] font-semibold text-hubsom-ink/45">
          {images.length}/8
        </span>
      </div>

      <div
        onDragOver={(e) => {
          e.preventDefault();
          setDragOver(true);
        }}
        onDragLeave={() => setDragOver(false)}
        onDrop={(e) => {
          e.preventDefault();
          setDragOver(false);
          if (e.dataTransfer.files?.length) {
            void uploadFiles(e.dataTransfer.files);
          }
        }}
        className={`rounded-2xl border border-dashed px-4 py-6 text-center transition ${
          dragOver
            ? "border-hubsom-gold bg-hubsom-gold/10"
            : "border-hubsom-forest/20 bg-hubsom-mist/50"
        }`}
      >
        <input
          ref={inputRef}
          type="file"
          accept="image/jpeg,image/png,image/webp,image/gif"
          multiple
          className="hidden"
          onChange={(e) => {
            if (e.target.files?.length) void uploadFiles(e.target.files);
          }}
        />
        <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-2xl bg-white text-hubsom-forest shadow-sm">
          {busy ? (
            <Loader2 className="h-5 w-5 animate-spin" />
          ) : (
            <ImagePlus className="h-5 w-5" />
          )}
        </div>
        <p className="mt-3 text-sm font-semibold text-hubsom-ink">
          {busy ? "Uploading…" : "Drag & drop product photos"}
        </p>
        <p className="mt-1 text-xs text-hubsom-ink/55">
          JPG, PNG, WEBP, or GIF · up to 5MB each
        </p>
        <button
          type="button"
          disabled={busy || images.length >= 8}
          onClick={() => inputRef.current?.click()}
          className="mt-4 inline-flex items-center gap-2 rounded-xl bg-hubsom-forest px-3.5 py-2.5 text-xs font-bold text-white disabled:opacity-50"
        >
          <Upload className="h-3.5 w-3.5" />
          {images.length ? "Add more images" : "Upload images"}
        </button>
      </div>

      {images.length > 0 ? (
        <div className="grid grid-cols-3 gap-2 sm:grid-cols-4">
          {images.map((src, index) => (
            <div
              key={`${src}-${index}`}
              className="group relative aspect-square overflow-hidden rounded-2xl border border-hubsom-forest/10 bg-white"
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={src}
                alt=""
                className="h-full w-full object-cover"
              />
              {index === 0 ? (
                <span className="absolute left-1.5 top-1.5 inline-flex items-center gap-1 rounded-md bg-hubsom-gold px-1.5 py-0.5 text-[9px] font-bold text-hubsom-ink">
                  <Star className="h-2.5 w-2.5 fill-current" />
                  Cover
                </span>
              ) : (
                <button
                  type="button"
                  onClick={() => makeCover(index)}
                  className="absolute left-1.5 top-1.5 rounded-md bg-black/55 px-1.5 py-0.5 text-[9px] font-bold text-white opacity-0 transition group-hover:opacity-100"
                >
                  Set cover
                </button>
              )}
              <button
                type="button"
                onClick={() => removeAt(index)}
                className="absolute right-1.5 top-1.5 inline-flex h-7 w-7 items-center justify-center rounded-full bg-black/60 text-white"
                aria-label="Remove image"
              >
                <Trash2 className="h-3.5 w-3.5" />
              </button>
            </div>
          ))}
        </div>
      ) : (
        <p className="rounded-xl bg-hubsom-mist px-3 py-2 text-xs text-hubsom-ink/55">
          No photos yet — Hubsom will use a placeholder until you upload.
        </p>
      )}

      {error ? <p className="text-sm text-hubsom-live">{error}</p> : null}
    </div>
  );
}
