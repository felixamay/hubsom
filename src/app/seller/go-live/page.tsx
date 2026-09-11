"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { categoryName } from "@/lib/categories";
import type { AgoraStatusResponse } from "@/lib/streaming/agora";
import type { Product } from "@/types";

export default function GoLivePage() {
  const router = useRouter();
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [products, setProducts] = useState<Product[]>([]);
  const [selected, setSelected] = useState<string[]>([]);
  const [multiHost, setMultiHost] = useState(false);
  const [enableRecording, setEnableRecording] = useState(true);
  const [enableAuction, setEnableAuction] = useState(false);
  const [auctionProduct, setAuctionProduct] = useState("");
  const [startingBid, setStartingBid] = useState(50);
  const [status, setStatus] = useState<AgoraStatusResponse | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loadingProducts, setLoadingProducts] = useState(true);

  useEffect(() => {
    void fetch("/api/agora/status")
      .then((r) => r.json())
      .then((data: AgoraStatusResponse) => setStatus(data))
      .catch(() => undefined);

    void fetch("/api/products?mine=1")
      .then((r) => r.json())
      .then((data: { products: Product[] }) => {
        setProducts(data.products ?? []);
        setLoadingProducts(false);
      })
      .catch(() => setLoadingProducts(false));
  }, []);

  const selectedProducts = useMemo(
    () => products.filter((p) => selected.includes(p.id)),
    [products, selected],
  );

  useEffect(() => {
    if (
      enableAuction &&
      selectedProducts.length &&
      !selectedProducts.some((p) => p.id === auctionProduct)
    ) {
      setAuctionProduct(selectedProducts[0].id);
    }
  }, [enableAuction, selectedProducts, auctionProduct]);

  function toggle(id: string) {
    setSelected((prev) =>
      prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id],
    );
  }

  async function startShow() {
    setBusy(true);
    setError(null);
    try {
      const res = await fetch("/api/streams", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          title: title.trim() || "Hubsom Live Show",
          description,
          productIds: selected,
          pinnedProductId: selected[0],
          auctionProductId: enableAuction ? auctionProduct : null,
          multiHost,
          enableRecording,
          startingBidGhs: startingBid,
        }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error ?? "Could not create show");
        return;
      }
      router.push(`/live/${data.stream.id}?host=1`);
    } catch {
      setError("Network error creating show");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
        Go live
      </h1>
      <p className="mt-2 text-sm text-hubsom-ink/65">
        Launch a live commerce show with your catalog — camera, chat, pins,
        auctions, and checkout.
      </p>

      <div
        className={`mt-4 rounded-2xl border p-4 text-sm ${
          status?.configured
            ? "border-hubsom-cyan/30 bg-hubsom-mint/50 text-hubsom-ink"
            : "border-hubsom-live/30 bg-hubsom-live/10 text-hubsom-ink"
        }`}
      >
        <p className="font-bold text-hubsom-forest">
          Agora: {status?.mode ?? "checking…"}
        </p>
        <p className="mt-1 text-hubsom-ink/70">
          {status?.message ?? "Checking streaming credentials…"}
        </p>
        {!status?.configured && (
          <ul className="mt-3 space-y-1 text-xs text-hubsom-ink/65">
            <li>
              Set <code className="text-hubsom-blue">NEXT_PUBLIC_AGORA_APP_ID</code>
            </li>
            <li>
              Set <code className="text-hubsom-blue">AGORA_APP_CERTIFICATE</code>
            </li>
          </ul>
        )}
      </div>

      <div className="mt-5 space-y-5 rounded-3xl border border-hubsom-forest/10 bg-white/80 p-4">
        <label className="block">
          <span className="text-sm font-semibold text-hubsom-forest">Show title</span>
          <input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Evening market live"
            className="mt-2 w-full rounded-xl border border-hubsom-forest/15 bg-white px-3 py-2.5 outline-none focus:border-hubsom-leaf"
          />
        </label>

        <label className="block">
          <span className="text-sm font-semibold text-hubsom-forest">Description</span>
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            rows={3}
            placeholder="What are you selling tonight?"
            className="mt-2 w-full rounded-xl border border-hubsom-forest/15 bg-white px-3 py-2.5 outline-none focus:border-hubsom-leaf"
          />
        </label>

        <div>
          <div className="flex items-center justify-between gap-2">
            <p className="text-sm font-semibold text-hubsom-forest">
              Products for this show
            </p>
            <Link
              href="/seller/products/new"
              className="text-xs font-bold text-hubsom-cyan"
            >
              Add product
            </Link>
          </div>
          <div className="mt-2 max-h-56 space-y-2 overflow-y-auto">
            {loadingProducts && (
              <p className="text-sm text-hubsom-ink/55">Loading catalog…</p>
            )}
            {!loadingProducts && !products.length && (
              <p className="rounded-xl border border-dashed border-hubsom-forest/20 px-3 py-6 text-center text-sm text-hubsom-ink/60">
                No products yet.{" "}
                <Link href="/seller/products/new" className="font-bold text-hubsom-cyan">
                  Create one
                </Link>{" "}
                before going live.
              </p>
            )}
            {products.map((product) => (
              <label
                key={product.id}
                className="flex cursor-pointer items-start gap-3 rounded-xl border border-hubsom-forest/10 px-3 py-2.5"
              >
                <input
                  type="checkbox"
                  checked={selected.includes(product.id)}
                  onChange={() => toggle(product.id)}
                  className="mt-1"
                />
                <span>
                  <span className="block text-sm font-medium text-hubsom-ink">
                    {product.name}
                  </span>
                  <span className="text-[11px] text-hubsom-ink/55">
                    {categoryName(product.category)} · stock {product.stock}
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
          Multi-host / guest sellers
        </label>

        <label className="flex items-center gap-3 text-sm font-medium text-hubsom-ink">
          <input
            type="checkbox"
            checked={enableRecording}
            onChange={(e) => setEnableRecording(e.target.checked)}
          />
          Enable recording / replay
        </label>

        <label className="flex items-center gap-3 text-sm font-medium text-hubsom-ink">
          <input
            type="checkbox"
            checked={enableAuction}
            onChange={(e) => setEnableAuction(e.target.checked)}
          />
          Open live auction
        </label>

        {enableAuction && (
          <div className="grid gap-3">
            <label className="block">
              <span className="text-sm font-semibold text-hubsom-forest">
                Auction product
              </span>
              <select
                value={auctionProduct}
                onChange={(e) => setAuctionProduct(e.target.value)}
                className="mt-2 w-full rounded-xl border border-hubsom-forest/15 bg-white px-3 py-2.5"
              >
                {selectedProducts.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.name}
                  </option>
                ))}
              </select>
            </label>
            <label className="block">
              <span className="text-sm font-semibold text-hubsom-forest">
                Starting bid (GHS)
              </span>
              <input
                type="number"
                min={1}
                value={startingBid}
                onChange={(e) => setStartingBid(Number(e.target.value) || 1)}
                className="mt-2 w-full rounded-xl border border-hubsom-forest/15 bg-white px-3 py-2.5"
              />
            </label>
          </div>
        )}

        {error && <p className="text-sm text-hubsom-live">{error}</p>}

        <button
          type="button"
          disabled={busy || selected.length === 0}
          onClick={() => void startShow()}
          className="w-full rounded-xl bg-hubsom-live py-3 text-sm font-bold text-white disabled:opacity-50"
        >
          {busy ? "Starting…" : "Start show as host"}
        </button>
      </div>
    </div>
  );
}
