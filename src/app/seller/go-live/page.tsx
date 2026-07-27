"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { PRODUCTS } from "@/lib/data/products";
import { categoryName } from "@/lib/categories";

export default function GoLivePage() {
  const [title, setTitle] = useState("Makola Mix Live — Produce, Pantry & Gadgets");
  const [selected, setSelected] = useState<string[]>([
    "prod-tomatoes",
    "prod-rice",
    "prod-oil",
    "prod-phone",
    "prod-sneakers",
    "prod-watch",
  ]);
  const [multiHost, setMultiHost] = useState(true);
  const [auctionProduct, setAuctionProduct] = useState("prod-phone");

  const selectedProducts = useMemo(
    () => PRODUCTS.filter((p) => selected.includes(p.id)),
    [selected],
  );

  function toggle(id: string) {
    setSelected((prev) =>
      prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id],
    );
  }

  return (
    <div className="mx-auto max-w-4xl px-4 py-10 sm:px-6">
      <h1 className="font-display text-4xl font-extrabold text-hubsom-forest">
        Go live
      </h1>
      <p className="mt-3 text-hubsom-ink/70">
        Build a mixed-category show. There is no grocery-only mode — every SKU uses
        the same live commerce stack.
      </p>

      <div className="mt-8 space-y-6 rounded-3xl border border-hubsom-forest/10 bg-white/70 p-6">
        <label className="block">
          <span className="text-sm font-semibold text-hubsom-forest">Show title</span>
          <input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className="mt-2 w-full rounded-xl border border-hubsom-forest/15 bg-white px-4 py-3 outline-none focus:border-hubsom-leaf"
          />
        </label>

        <div>
          <p className="text-sm font-semibold text-hubsom-forest">
            Products for this show
          </p>
          <div className="mt-3 grid gap-2 sm:grid-cols-2">
            {PRODUCTS.map((product) => (
              <label
                key={product.id}
                className="flex cursor-pointer items-start gap-3 rounded-xl border border-hubsom-forest/10 px-3 py-3"
              >
                <input
                  type="checkbox"
                  checked={selected.includes(product.id)}
                  onChange={() => toggle(product.id)}
                  className="mt-1"
                />
                <span>
                  <span className="block font-medium text-hubsom-ink">
                    {product.name}
                  </span>
                  <span className="text-xs text-hubsom-ink/55">
                    {categoryName(product.category)}
                  </span>
                </span>
              </label>
            ))}
          </div>
        </div>

        <label className="flex items-center gap-3 text-sm font-medium text-hubsom-ink">
          <input
            type="checkbox"
            checked={multiHost}
            onChange={(e) => setMultiHost(e.target.checked)}
          />
          Enable multi-host / guest sellers
        </label>

        <label className="block">
          <span className="text-sm font-semibold text-hubsom-forest">
            Open auction on
          </span>
          <select
            value={auctionProduct}
            onChange={(e) => setAuctionProduct(e.target.value)}
            className="mt-2 w-full rounded-xl border border-hubsom-forest/15 bg-white px-4 py-3"
          >
            {selectedProducts.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </select>
        </label>

        <div className="rounded-2xl bg-hubsom-mint/60 p-4 text-sm text-hubsom-ink/80">
          <p className="font-semibold text-hubsom-forest">Ready stack</p>
          <ul className="mt-2 list-disc space-y-1 pl-5">
            <li>Agora ultra-low latency + adaptive bitrate (HD/FHD)</li>
            <li>Realtime chat, reactions, AI moderation</li>
            <li>Product pinning, live cart, one-tap checkout</li>
            <li>Auction countdown + inventory sync</li>
            <li>Recording / replay + viewer & seller analytics</li>
            <li>
              {selectedProducts.length} products across{" "}
              {new Set(selectedProducts.map((p) => p.category)).size} categories
              {multiHost ? " · multi-host on" : ""}
            </li>
          </ul>
        </div>

        <Link
          href="/live/stream-ama-mix?host=1"
          className="inline-flex rounded-xl bg-hubsom-live px-5 py-3 text-sm font-bold text-white"
        >
          Start show as host
        </Link>
      </div>
    </div>
  );
}
