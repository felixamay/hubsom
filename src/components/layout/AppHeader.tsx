"use client";

import Link from "next/link";
import { FormEvent, useEffect, useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Grid2x2, Radio, Search, ShoppingBag, UserRound } from "lucide-react";
import { useCartStore } from "@/lib/stores/cart";
import { cn } from "@/lib/utils";

export function AppHeader() {
  const pathname = usePathname() || "/";
  const router = useRouter();
  const searchParams = useSearchParams();
  const count = useCartStore((s) => s.items.reduce((n, i) => n + i.quantity, 0));
  const [query, setQuery] = useState("");

  useEffect(() => {
    setQuery(searchParams.get("q") ?? "");
  }, [searchParams]);

  const hide =
    (pathname.startsWith("/live/") && pathname !== "/live") ||
    pathname.startsWith("/brand") ||
    pathname.startsWith("/auth/");

  if (hide) return null;

  function onSearch(e: FormEvent) {
    e.preventDefault();
    const q = query.trim();
    router.push(q ? `/marketplace?q=${encodeURIComponent(q)}` : "/marketplace");
  }

  return (
    <header
      className="sticky top-0 z-50 border-b border-hubsom-forest/10 bg-[linear-gradient(180deg,rgba(255,255,255,0.96),rgba(238,247,252,0.92))] backdrop-blur-xl"
      style={{ paddingTop: "env(safe-area-inset-top, 0px)" }}
    >
      <div className="mx-auto max-w-lg space-y-2 px-3 pb-3 pt-2.5">
        <div className="flex items-center gap-2">
          <Link
            href="/categories"
            className={cn(
              "inline-flex h-12 shrink-0 items-center gap-2 rounded-2xl border px-3.5 text-sm font-bold shadow-[0_10px_24px_-18px_rgba(10,61,92,0.55)] transition active:scale-[0.98]",
              pathname.startsWith("/categories")
                ? "border-hubsom-forest/25 bg-hubsom-forest text-white"
                : "border-hubsom-forest/12 bg-white text-hubsom-forest",
            )}
            aria-label="Browse categories"
          >
            <Grid2x2 className="h-4.5 w-4.5 h-[1.125rem] w-[1.125rem]" strokeWidth={2.25} />
            Categories
          </Link>

          <form onSubmit={onSearch} className="relative min-w-0 flex-1">
            <Search
              className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-hubsom-ink/40"
              aria-hidden
            />
            <input
              type="search"
              name="q"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search products, brands…"
              aria-label="Search Hubsom"
              className="h-12 w-full rounded-2xl border border-hubsom-forest/12 bg-white py-2 pl-11 pr-3.5 text-sm text-hubsom-ink shadow-[0_10px_24px_-18px_rgba(10,61,92,0.45)] outline-none transition placeholder:text-hubsom-ink/40 focus:border-hubsom-cyan focus:ring-4 focus:ring-hubsom-cyan/15"
            />
          </form>
        </div>

        <div className="flex items-center justify-between gap-2">
          <Link
            href="/live"
            className="inline-flex h-9 items-center gap-1.5 rounded-xl bg-hubsom-live px-3 text-xs font-bold text-white"
            aria-label="Watch live"
          >
            <Radio className="h-3.5 w-3.5" />
            Live
          </Link>
          <div className="flex items-center gap-1.5">
            <Link
              href="/account"
              className="inline-flex h-9 w-9 items-center justify-center rounded-xl border border-hubsom-forest/10 bg-white/80 text-hubsom-forest"
              aria-label="Account"
            >
              <UserRound className="h-4 w-4" />
            </Link>
            <Link
              href="/cart"
              className="relative inline-flex h-9 w-9 items-center justify-center rounded-xl border border-hubsom-forest/10 bg-white/80 text-hubsom-forest"
              aria-label="Cart"
            >
              <ShoppingBag className="h-4 w-4" />
              {count > 0 && (
                <span className="absolute -right-1 -top-1 flex h-4 min-w-4 items-center justify-center rounded-md bg-hubsom-gold px-1 text-[10px] font-bold text-hubsom-ink">
                  {count}
                </span>
              )}
            </Link>
          </div>
        </div>
      </div>
    </header>
  );
}
