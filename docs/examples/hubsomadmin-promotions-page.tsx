/**
 * Reference UI for https://github.com/felixamay/hubsomadmin
 * Copy into the admin app and point env at Hubsom.
 *
 * Env:
 *   HUBSOM_API_BASE_URL=http://localhost:3000
 *   HUBSOM_ADMIN_API_KEY=shared-secret
 */
"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";

type Placement = "landing" | "marketplace" | "category" | "product";

type Catalog = {
  placements: Array<{ id: Placement; label: string; description: string }>;
  categories: Array<{ slug: string; name: string }>;
  products: Array<{ id: string; name: string; category: string }>;
};

type Promotion = {
  id?: string;
  title: string;
  subtitle: string;
  ctaLabel: string;
  href: string;
  tone: "forest" | "gold" | "cyan" | "live";
  placements: Placement[];
  categorySlugs: string[];
  productIds: string[];
  imageUrl?: string;
  sortOrder: number;
  active: boolean;
};

const empty: Promotion = {
  title: "",
  subtitle: "",
  ctaLabel: "Shop now",
  href: "/marketplace",
  tone: "forest",
  placements: ["landing"],
  categorySlugs: [],
  productIds: [],
  sortOrder: 100,
  active: true,
};

function adminHeaders() {
  const key = process.env.NEXT_PUBLIC_HUBSOM_ADMIN_API_KEY || "";
  return {
    "Content-Type": "application/json",
    ...(key ? { "X-Hubsom-Admin-Key": key } : {}),
  };
}

function apiBase() {
  return (process.env.NEXT_PUBLIC_HUBSOM_API_BASE_URL || "").replace(/\/$/, "");
}

export default function PromotionsAdminPage() {
  const base = apiBase();
  const [catalog, setCatalog] = useState<Catalog | null>(null);
  const [items, setItems] = useState<Promotion[]>([]);
  const [form, setForm] = useState<Promotion>(empty);
  const [status, setStatus] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const needsCategories = form.placements.includes("category");
  const needsProducts = form.placements.includes("product");

  const sortedProducts = useMemo(
    () => catalog?.products ?? [],
    [catalog],
  );

  async function refresh() {
    setError(null);
    const [catRes, listRes] = await Promise.all([
      fetch(`${base}/api/admin/catalog`, { headers: adminHeaders() }),
      fetch(`${base}/api/admin/promotions`, { headers: adminHeaders() }),
    ]);
    if (!catRes.ok || !listRes.ok) {
      setError("Could not load Hubsom admin APIs — check base URL + API key");
      return;
    }
    setCatalog(await catRes.json());
    const data = await listRes.json();
    setItems(data.promotions ?? []);
  }

  useEffect(() => {
    if (!base) {
      setError("Set NEXT_PUBLIC_HUBSOM_API_BASE_URL");
      return;
    }
    void refresh();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [base]);

  function togglePlacement(id: Placement) {
    setForm((prev) => {
      const has = prev.placements.includes(id);
      return {
        ...prev,
        placements: has
          ? prev.placements.filter((p) => p !== id)
          : [...prev.placements, id],
      };
    });
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setStatus(null);
    setError(null);
    const res = await fetch(`${base}/api/admin/promotions`, {
      method: "POST",
      headers: adminHeaders(),
      body: JSON.stringify({ promotion: form }),
    });
    const data = await res.json();
    if (!res.ok) {
      setError(data.error ?? "Save failed");
      return;
    }
    setStatus(`Saved ${data.promotion.id}`);
    setForm(empty);
    await refresh();
  }

  async function remove(id: string) {
    const res = await fetch(
      `${base}/api/admin/promotions?id=${encodeURIComponent(id)}`,
      { method: "DELETE", headers: adminHeaders() },
    );
    if (!res.ok) {
      const data = await res.json();
      setError(data.error ?? "Delete failed");
      return;
    }
    await refresh();
  }

  return (
    <div style={{ maxWidth: 880, margin: "0 auto", padding: 24 }}>
      <h1>Hubsom promotions</h1>
      <p>
        Select where each promo appears: landing, marketplace, category, and/or
        product. Optional category/product targeting controls which pages show
        it.
      </p>
      {error ? <p style={{ color: "crimson" }}>{error}</p> : null}
      {status ? <p style={{ color: "green" }}>{status}</p> : null}

      <form onSubmit={onSubmit} style={{ display: "grid", gap: 12 }}>
        <input
          required
          placeholder="Title"
          value={form.title}
          onChange={(e) => setForm({ ...form, title: e.target.value })}
        />
        <input
          placeholder="Subtitle"
          value={form.subtitle}
          onChange={(e) => setForm({ ...form, subtitle: e.target.value })}
        />
        <input
          required
          placeholder="Href (/live, /flash-sales, …)"
          value={form.href}
          onChange={(e) => setForm({ ...form, href: e.target.value })}
        />
        <input
          placeholder="CTA label"
          value={form.ctaLabel}
          onChange={(e) => setForm({ ...form, ctaLabel: e.target.value })}
        />

        <fieldset>
          <legend>Placements</legend>
          {(catalog?.placements ?? []).map((p) => (
            <label key={p.id} style={{ display: "block" }}>
              <input
                type="checkbox"
                checked={form.placements.includes(p.id)}
                onChange={() => togglePlacement(p.id)}
              />{" "}
              {p.label}
            </label>
          ))}
        </fieldset>

        {needsCategories ? (
          <fieldset>
            <legend>Categories (empty = all)</legend>
            {(catalog?.categories ?? []).map((c) => (
              <label key={c.slug} style={{ display: "block" }}>
                <input
                  type="checkbox"
                  checked={form.categorySlugs.includes(c.slug)}
                  onChange={() =>
                    setForm((prev) => ({
                      ...prev,
                      categorySlugs: prev.categorySlugs.includes(c.slug)
                        ? prev.categorySlugs.filter((s) => s !== c.slug)
                        : [...prev.categorySlugs, c.slug],
                    }))
                  }
                />{" "}
                {c.name}
              </label>
            ))}
          </fieldset>
        ) : null}

        {needsProducts ? (
          <fieldset>
            <legend>Products (empty = all)</legend>
            <div style={{ maxHeight: 180, overflow: "auto" }}>
              {sortedProducts.map((p) => (
                <label key={p.id} style={{ display: "block" }}>
                  <input
                    type="checkbox"
                    checked={form.productIds.includes(p.id)}
                    onChange={() =>
                      setForm((prev) => ({
                        ...prev,
                        productIds: prev.productIds.includes(p.id)
                          ? prev.productIds.filter((id) => id !== p.id)
                          : [...prev.productIds, p.id],
                      }))
                    }
                  />{" "}
                  {p.name}{" "}
                  <small>({p.category})</small>
                </label>
              ))}
            </div>
          </fieldset>
        ) : null}

        <button type="submit">Save promotion to Hubsom</button>
      </form>

      <h2>Live on Hubsom</h2>
      <ul>
        {items.map((item) => (
          <li key={item.id}>
            <strong>{item.title}</strong> · {(item.placements || []).join(", ")}
            <button type="button" onClick={() => item.id && void remove(item.id)}>
              Delete
            </button>
            <button type="button" onClick={() => setForm({ ...empty, ...item, categorySlugs: item.categorySlugs || [], productIds: item.productIds || [] })}>
              Edit
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}
