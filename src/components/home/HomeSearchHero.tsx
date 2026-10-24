"use client";

import Link from "next/link";
import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { Search, ShoppingBag } from "lucide-react";

export function HomeSearchHero() {
  const router = useRouter();
  const [query, setQuery] = useState("");

  function onSearch(e: FormEvent) {
    e.preventDefault();
    const q = query.trim();
    router.push(q ? `/marketplace?q=${encodeURIComponent(q)}` : "/marketplace");
  }

  return (
    <section className="relative overflow-hidden px-4 pb-5 pt-5">
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_top,rgba(0,174,239,0.16),transparent_58%),linear-gradient(180deg,rgba(215,241,251,0.55),transparent_70%)]" />

      <div className="relative">
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.35 }}
          className="flex items-center gap-2.5"
        >
          <Link
            href="/marketplace"
            className="group inline-flex h-12 shrink-0 items-center gap-2 rounded-2xl bg-hubsom-forest px-3.5 text-sm font-bold text-white shadow-[0_14px_28px_-16px_rgba(10,61,92,0.85)] transition hover:bg-[#0c4a6e] active:scale-[0.98]"
            aria-label="Buy Now marketplace"
          >
            <span className="flex h-7 w-7 items-center justify-center rounded-xl bg-white/15 ring-1 ring-white/20 transition group-hover:bg-white/20">
              <ShoppingBag className="h-3.5 w-3.5" strokeWidth={2.4} />
            </span>
            Buy Now
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
              className="h-12 w-full rounded-2xl border border-hubsom-forest/12 bg-white py-2 pl-11 pr-3.5 text-sm text-hubsom-ink shadow-[0_12px_28px_-20px_rgba(10,61,92,0.55)] outline-none transition placeholder:text-hubsom-ink/40 focus:border-hubsom-cyan focus:ring-4 focus:ring-hubsom-cyan/15"
            />
          </form>
        </motion.div>

        <motion.p
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.35, delay: 0.06 }}
          className="mt-3 text-xs leading-relaxed text-hubsom-ink/55"
        >
          Find anything across live, Buy Now, auctions, and flash sales.
        </motion.p>
      </div>
    </section>
  );
}
