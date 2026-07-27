"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { CATEGORIES } from "@/lib/categories";
import type { ProductCategory } from "@/types";

export default function NewProductPage() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState<ProductCategory>("groceries");
  const [priceGhs, setPriceGhs] = useState(50);
  const [stock, setStock] = useState(10);
  const [imageUrl, setImageUrl] = useState("");
  const [flash, setFlash] = useState(false);
  const [discountPct, setDiscountPct] = useState(15);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      await fetch("/api/sellers", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ensureDefault: true }),
      });

      const res = await fetch("/api/products", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name,
          description,
          category,
          priceGhs,
          stock,
          images: imageUrl.trim() ? [imageUrl.trim()] : undefined,
          flashSale: flash
            ? {
                endsAt: new Date(Date.now() + 1000 * 60 * 60 * 6).toISOString(),
                discountPct,
              }
            : undefined,
        }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error ?? "Could not create product");
        return;
      }
      router.push(`/products/${data.product.slug}`);
      router.refresh();
    } catch {
      setError("Network error");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
        Add product
      </h1>
      <p className="mt-2 text-sm text-hubsom-ink/65">
        Create a real catalog listing for Buy Now, live shows, and auctions.
      </p>

      <div className="mt-5 space-y-4 rounded-3xl border border-hubsom-forest/10 bg-white/80 p-4">
        <label className="block">
          <span className="text-sm font-semibold text-hubsom-forest">Name</span>
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="mt-2 w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5 outline-none focus:border-hubsom-leaf"
            placeholder="Garden Fresh Tomatoes — 5kg"
          />
        </label>

        <label className="block">
          <span className="text-sm font-semibold text-hubsom-forest">
            Description
          </span>
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            rows={3}
            className="mt-2 w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5 outline-none focus:border-hubsom-leaf"
          />
        </label>

        <label className="block">
          <span className="text-sm font-semibold text-hubsom-forest">Category</span>
          <select
            value={category}
            onChange={(e) => setCategory(e.target.value as ProductCategory)}
            className="mt-2 w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5"
          >
            {CATEGORIES.map((c) => (
              <option key={c.slug} value={c.slug}>
                {c.name}
              </option>
            ))}
          </select>
        </label>

        <div className="grid grid-cols-2 gap-3">
          <label className="block">
            <span className="text-sm font-semibold text-hubsom-forest">
              Price (GHS)
            </span>
            <input
              type="number"
              min={0}
              value={priceGhs}
              onChange={(e) => setPriceGhs(Number(e.target.value) || 0)}
              className="mt-2 w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5"
            />
          </label>
          <label className="block">
            <span className="text-sm font-semibold text-hubsom-forest">Stock</span>
            <input
              type="number"
              min={0}
              value={stock}
              onChange={(e) => setStock(Number(e.target.value) || 0)}
              className="mt-2 w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5"
            />
          </label>
        </div>

        <label className="block">
          <span className="text-sm font-semibold text-hubsom-forest">
            Image URL (optional)
          </span>
          <input
            value={imageUrl}
            onChange={(e) => setImageUrl(e.target.value)}
            placeholder="https://…"
            className="mt-2 w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5"
          />
        </label>

        <label className="flex items-center gap-3 text-sm font-medium">
          <input
            type="checkbox"
            checked={flash}
            onChange={(e) => setFlash(e.target.checked)}
          />
          Enable 6-hour flash sale
        </label>

        {flash && (
          <label className="block">
            <span className="text-sm font-semibold text-hubsom-forest">
              Discount %
            </span>
            <input
              type="number"
              min={1}
              max={90}
              value={discountPct}
              onChange={(e) => setDiscountPct(Number(e.target.value) || 1)}
              className="mt-2 w-full rounded-xl border border-hubsom-forest/15 px-3 py-2.5"
            />
          </label>
        )}

        {error && <p className="text-sm text-hubsom-live">{error}</p>}

        <button
          type="button"
          disabled={busy || !name.trim()}
          onClick={() => void submit()}
          className="w-full rounded-xl bg-hubsom-forest py-3 text-sm font-bold text-white disabled:opacity-50"
        >
          {busy ? "Saving…" : "Publish product"}
        </button>

        <Link
          href="/seller/go-live"
          className="block text-center text-sm font-semibold text-hubsom-cyan"
        >
          Or go live with existing catalog
        </Link>
      </div>
    </div>
  );
}
