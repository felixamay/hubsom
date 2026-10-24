"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { ProductImageUploader } from "@/components/seller/ProductImageUploader";
import { CATEGORIES } from "@/lib/categories";
import type { ProductCategory } from "@/types";

const MIN_PRODUCT_IMAGES = 3;

export default function NewProductPage() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState<ProductCategory>("groceries");
  const [priceGhs, setPriceGhs] = useState(50);
  const [stock, setStock] = useState(10);
  const [images, setImages] = useState<string[]>([]);
  const [flash, setFlash] = useState(false);
  const [discountPct, setDiscountPct] = useState(15);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    if (images.length < MIN_PRODUCT_IMAGES) {
      setError(`Upload at least ${MIN_PRODUCT_IMAGES} product images before saving`);
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const res = await fetch("/api/products", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name,
          description,
          category,
          priceGhs,
          stock,
          images,
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

  const canPublish = Boolean(name.trim()) && images.length >= MIN_PRODUCT_IMAGES;

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
            placeholder="Product name"
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

        <div className="rounded-2xl border border-hubsom-forest/10 bg-hubsom-mist/30 p-3.5">
          <ProductImageUploader
            images={images}
            onChange={setImages}
            minImages={MIN_PRODUCT_IMAGES}
          />
        </div>

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
          disabled={busy || !canPublish}
          onClick={() => void submit()}
          className="w-full rounded-xl bg-hubsom-forest py-3 text-sm font-bold text-white disabled:opacity-50"
        >
          {busy
            ? "Saving…"
            : images.length < MIN_PRODUCT_IMAGES
              ? `Add ${MIN_PRODUCT_IMAGES - images.length} more photo${
                  MIN_PRODUCT_IMAGES - images.length === 1 ? "" : "s"
                }`
              : "Publish product"}
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
