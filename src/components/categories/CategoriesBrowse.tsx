"use client";

import Link from "next/link";
import { motion } from "framer-motion";
import { Flame } from "lucide-react";
import { CategoryTile } from "@/components/categories/CategoryTile";
import { CATEGORIES } from "@/lib/categories";

const TRENDING = [
  "fashion",
  "phones-accessories",
  "groceries",
  "electronics",
  "beauty-personal-care",
  "shoes",
  "home-kitchen",
  "gaming",
] as const;

const trendingItems = TRENDING.map(
  (slug) => CATEGORIES.find((c) => c.slug === slug)!,
).filter(Boolean);

export function CategoriesBrowse() {
  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
      >
        <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
          Categories
        </h1>
        <p className="mt-2 text-sm text-hubsom-ink/65">
          Pick an aisle and start shopping.
        </p>
      </motion.div>

      <section className="mt-6">
        <div className="mb-3 flex items-center gap-2">
          <span className="flex h-7 w-7 items-center justify-center rounded-xl bg-hubsom-live/12 text-hubsom-live">
            <Flame className="h-3.5 w-3.5" strokeWidth={2.4} />
          </span>
          <div>
            <h2 className="font-display text-lg font-bold text-hubsom-forest">
              Trending today
            </h2>
            <p className="text-[11px] text-hubsom-ink/55">
              Popular picks across Hubsom
            </p>
          </div>
        </div>

        <div className="scrollbar-thin -mx-1 flex gap-3 overflow-x-auto px-1 pb-1">
          {trendingItems.map((category, index) => (
            <motion.div
              key={category.slug}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.3, delay: index * 0.04 }}
            >
              <CategoryTile
                slug={category.slug}
                name={category.name}
                href={`/categories/${category.slug}`}
                size="lg"
                badge="Hot"
                priority={index < 3}
              />
            </motion.div>
          ))}
        </div>
      </section>

      <section className="mt-8">
        <div className="mb-3 flex items-end justify-between gap-3">
          <div>
            <h2 className="font-display text-lg font-bold text-hubsom-forest">
              All categories
            </h2>
            <p className="mt-0.5 text-[11px] text-hubsom-ink/55">
              {CATEGORIES.length} aisles
            </p>
          </div>
          <Link href="/marketplace" className="text-xs font-bold text-hubsom-cyan">
            Marketplace
          </Link>
        </div>

        <div className="grid grid-cols-2 gap-x-3 gap-y-5">
          {CATEGORIES.map((category, index) => (
            <motion.div
              key={category.slug}
              initial={{ opacity: 0, y: 10 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, amount: 0.15 }}
              transition={{ duration: 0.28, delay: (index % 6) * 0.03 }}
            >
              <CategoryTile
                slug={category.slug}
                name={category.name}
                description={category.description}
                href={`/categories/${category.slug}`}
                size="md"
                priority={index < 4}
              />
            </motion.div>
          ))}
        </div>
      </section>
    </div>
  );
}
