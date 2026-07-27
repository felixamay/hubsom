"use client";

import Image from "next/image";
import Link from "next/link";
import { motion } from "framer-motion";
import { Flame, TrendingUp } from "lucide-react";
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
        transition={{ duration: 0.35 }}
      >
        <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
          Categories
        </h1>
        <p className="mt-2 text-sm text-hubsom-ink/65">
          Explore every aisle — Buy Now, live, auction, and flash.
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
            <p className="text-[11px] text-hubsom-ink/55">What’s hot on Hubsom right now</p>
          </div>
        </div>

        <div className="scrollbar-thin -mx-1 flex gap-3 overflow-x-auto px-1 pb-1">
          {trendingItems.map((category, index) => (
            <motion.div
              key={category.slug}
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.35, delay: 0.04 * index }}
              className="shrink-0"
            >
              <Link
                href={`/categories/${category.slug}`}
                className="group relative block h-[7.5rem] w-[11.5rem] overflow-hidden rounded-[1.35rem] ring-1 ring-hubsom-forest/10 shadow-[0_16px_32px_-22px_rgba(10,61,92,0.65)] transition duration-300 active:scale-[0.98]"
              >
                <motion.div
                  className="absolute inset-[-12%] will-change-transform"
                  animate={{
                    scale: [1, 1.08, 1],
                    x: [0, index % 2 === 0 ? 6 : -6, 0],
                  }}
                  transition={{
                    duration: 9 + (index % 3),
                    repeat: Infinity,
                    ease: "easeInOut",
                    delay: index * 0.15,
                  }}
                >
                  <Image
                    src={categoryImage(category.slug)}
                    alt=""
                    fill
                    sizes="220px"
                    quality={95}
                    className="object-cover"
                    priority={index < 3}
                  />
                </motion.div>
                <div className="absolute inset-0 bg-gradient-to-t from-hubsom-ink/80 via-hubsom-ink/25 to-transparent" />
                <div className="absolute inset-x-0 bottom-0 p-3">
                  <span className="mb-1 inline-flex items-center gap-1 rounded-full bg-white/15 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-white/90 ring-1 ring-white/20 backdrop-blur-sm">
                    <TrendingUp className="h-3 w-3" />
                    Hot
                  </span>
                  <p className="font-display text-sm font-bold leading-tight text-white">
                    {category.name}
                  </p>
                </div>
              </Link>
            </motion.div>
          ))}
        </div>
      </section>

      <section className="mt-8">
        <div className="mb-3">
          <h2 className="font-display text-lg font-bold text-hubsom-forest">
            All categories
          </h2>
          <p className="mt-0.5 text-[11px] text-hubsom-ink/55">
            {CATEGORIES.length} aisles ready to shop
          </p>
        </div>

        <div className="grid grid-cols-2 gap-3">
          {CATEGORIES.map((category, index) => (
            <motion.div
              key={category.slug}
              initial={{ opacity: 0, y: 10 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, amount: 0.2 }}
              transition={{ duration: 0.3, delay: (index % 6) * 0.03 }}
            >
              <Link
                href={`/categories/${category.slug}`}
                className="group block overflow-hidden rounded-[1.25rem] bg-white ring-1 ring-hubsom-forest/10 shadow-[0_12px_28px_-22px_rgba(10,61,92,0.55)] transition duration-300 active:scale-[0.98]"
              >
                <div className="relative aspect-[5/4] overflow-hidden">
                  <motion.div
                    className="absolute inset-[-10%] will-change-transform"
                    whileHover={{ scale: 1.06 }}
                    transition={{ duration: 0.45 }}
                  >
                    <Image
                      src={categoryImage(category.slug)}
                      alt=""
                      fill
                      sizes="(max-width:512px) 50vw, 240px"
                      quality={95}
                      className="object-cover transition duration-500 group-hover:scale-105"
                    />
                  </motion.div>
                  <div className="absolute inset-0 bg-gradient-to-t from-hubsom-ink/55 via-transparent to-transparent" />
                </div>
                <div className="px-3 py-2.5">
                  <p className="font-display text-sm font-bold leading-snug text-hubsom-forest">
                    {category.name}
                  </p>
                  <p className="mt-0.5 line-clamp-2 text-[11px] leading-relaxed text-hubsom-ink/55">
                    {category.description}
                  </p>
                </div>
              </Link>
            </motion.div>
          ))}
        </div>
      </section>
    </div>
  );
}
