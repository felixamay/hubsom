"use client";

import Image from "next/image";
import Link from "next/link";
import { motion } from "framer-motion";
import { Flame } from "lucide-react";
import { CategoryTile } from "@/components/categories/CategoryTile";
import { CATEGORIES } from "@/lib/categories";
import { categoryImage } from "@/lib/category-images";

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
        <div className="mb-3 flex items-start justify-between gap-3">
          <div className="flex items-center gap-2">
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
          <Link
            href="/marketplace"
            className="shrink-0 pt-1 text-xs font-bold text-hubsom-cyan"
          >
            See all
          </Link>
        </div>

        <div className="scrollbar-thin -mx-1 flex gap-2.5 overflow-x-auto px-1 pb-1">
          {trendingItems.map((category, index) => (
            <motion.div
              key={category.slug}
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.28, delay: index * 0.03 }}
              className="w-[4.75rem] shrink-0"
            >
              <Link
                href={`/categories/${category.slug}`}
                className="group block outline-none transition active:scale-[0.98]"
              >
                <div
                  className="relative flex h-[3.85rem] items-center justify-center overflow-hidden rounded-xl ring-1 ring-white/10 shadow-[0_10px_22px_-16px_rgba(0,0,0,0.65)]"
                  style={{
                    background:
                      "linear-gradient(155deg, #0a3d5c 0%, #06121f 52%, #000000 100%)",
                  }}
                >
                  <Image
                    src={categoryImage(category.slug)}
                    alt=""
                    width={56}
                    height={56}
                    sizes="56px"
                    quality={100}
                    priority={index < 4}
                    className="h-8 w-8 object-contain drop-shadow-[0_6px_10px_rgba(0,0,0,0.35)] transition duration-300 group-hover:scale-110"
                  />
                </div>
                <p className="mt-1.5 line-clamp-2 text-center text-[10px] font-bold leading-tight text-hubsom-forest">
                  {category.name}
                </p>
              </Link>
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
