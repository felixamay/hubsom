"use client";

import Image from "next/image";
import Link from "next/link";
import { motion } from "framer-motion";
import { Flame, Radio } from "lucide-react";
import { CATEGORIES, categoryName } from "@/lib/categories";
import { categoryImage } from "@/lib/category-images";
import { categoryTone } from "@/lib/category-tones";

export type LiveNowPreview = {
  id: string;
  title: string;
  cover: string;
  viewerCount: number;
  sellerName: string;
  categories: string[];
};

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

function PrimaryCategoryBox({
  slug,
  name,
  href,
  priority = false,
  compact = false,
}: {
  slug: string;
  name: string;
  href: string;
  priority?: boolean;
  compact?: boolean;
}) {
  const tone = categoryTone(slug);

  return (
    <Link
      href={href}
      className="group block outline-none transition active:scale-[0.98]"
    >
      <div
        className={
          compact
            ? "relative flex h-[3.85rem] items-center justify-center overflow-hidden rounded-xl ring-1 ring-black/[0.04] shadow-[0_10px_22px_-18px_rgba(6,18,31,0.45)]"
            : "relative flex aspect-[5/3.4] items-center justify-center overflow-hidden rounded-[1.15rem] ring-1 ring-black/[0.04] shadow-[0_12px_26px_-18px_rgba(6,18,31,0.45)]"
        }
        style={{
          background: `linear-gradient(165deg, ${tone.bgSoft} 0%, ${tone.bg} 78%)`,
        }}
      >
        <Image
          src={categoryImage(slug)}
          alt=""
          width={compact ? 56 : 88}
          height={compact ? 56 : 88}
          sizes={compact ? "56px" : "88px"}
          quality={100}
          priority={priority}
          className={
            compact
              ? "h-8 w-8 object-contain drop-shadow-[0_6px_10px_rgba(6,18,31,0.18)] transition duration-300 group-hover:scale-110"
              : "h-12 w-12 object-contain drop-shadow-[0_8px_14px_rgba(6,18,31,0.2)] transition duration-300 group-hover:scale-110"
          }
        />
      </div>
      <p
        className={
          compact
            ? "mt-1.5 line-clamp-2 text-center text-[10px] font-bold leading-tight"
            : "mt-2 line-clamp-2 text-center text-xs font-bold leading-tight"
        }
        style={{ color: tone.ink }}
      >
        {name}
      </p>
    </Link>
  );
}

export function CategoriesBrowse({
  liveNow = [],
}: {
  liveNow?: LiveNowPreview[];
}) {
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
          <div className="flex min-w-0 items-center gap-2">
            <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-xl bg-hubsom-live/12 text-hubsom-live">
              <Flame className="h-3.5 w-3.5" strokeWidth={2.4} />
            </span>
            <div className="min-w-0">
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
              <PrimaryCategoryBox
                slug={category.slug}
                name={category.name}
                href={`/categories/${category.slug}`}
                priority={index < 4}
                compact
              />
            </motion.div>
          ))}
        </div>
      </section>

      <section className="mt-7">
        <div className="mb-3 flex items-start justify-between gap-3">
          <div className="flex min-w-0 items-center gap-2">
            <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-xl bg-hubsom-live text-white">
              <Radio className="h-3.5 w-3.5" strokeWidth={2.4} />
            </span>
            <div className="min-w-0">
              <h2 className="font-display text-lg font-bold text-hubsom-forest">
                Live now
              </h2>
              <p className="text-[11px] text-hubsom-ink/55">
                Shows by category — watch and shop
              </p>
            </div>
          </div>
          <Link
            href="/live"
            className="shrink-0 pt-1 text-xs font-bold text-hubsom-cyan"
          >
            See all
          </Link>
        </div>

        {liveNow.length ? (
          <div className="scrollbar-thin -mx-1 flex gap-2.5 overflow-x-auto px-1 pb-1">
            {liveNow.map((stream, index) => {
              const cat = stream.categories[0];
              const cover =
                stream.cover?.startsWith("http") || stream.cover?.startsWith("/")
                  ? stream.cover
                  : cat
                    ? categoryImage(cat)
                    : "/brand/hubsom-logo.png";

              return (
                <motion.div
                  key={stream.id}
                  initial={{ opacity: 0, y: 8 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ duration: 0.28, delay: index * 0.04 }}
                  className="w-[7.25rem] shrink-0"
                >
                  <Link
                    href={`/live/${stream.id}`}
                    className="group block outline-none transition active:scale-[0.98]"
                  >
                    <div className="relative aspect-[3/4] overflow-hidden rounded-[1.1rem] bg-hubsom-night ring-1 ring-black/10 shadow-[0_14px_28px_-18px_rgba(6,18,31,0.55)]">
                      <Image
                        src={cover}
                        alt=""
                        fill
                        sizes="116px"
                        quality={90}
                        priority={index < 3}
                        className="object-cover transition duration-500 group-hover:scale-105"
                      />
                      <div className="absolute inset-0 bg-gradient-to-t from-black/85 via-black/15 to-black/10" />
                      <span className="absolute left-2 top-2 inline-flex items-center gap-1 rounded-md bg-hubsom-live px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wide text-white">
                        <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-white" />
                        Live
                      </span>
                      {cat ? (
                        <span className="absolute right-2 top-2 max-w-[55%] truncate rounded-md bg-black/45 px-1.5 py-0.5 text-[9px] font-semibold text-white backdrop-blur-sm">
                          {categoryName(cat)}
                        </span>
                      ) : null}
                      <div className="absolute inset-x-0 bottom-0 p-2.5 text-white">
                        <p className="line-clamp-2 font-display text-[12px] font-bold leading-snug">
                          {stream.title}
                        </p>
                        <p className="mt-0.5 truncate text-[10px] text-white/75">
                          {stream.sellerName} ·{" "}
                          {stream.viewerCount.toLocaleString()}
                        </p>
                      </div>
                    </div>
                  </Link>
                </motion.div>
              );
            })}
          </div>
        ) : (
          <div className="rounded-[1.15rem] border border-dashed border-hubsom-forest/20 bg-white/60 px-4 py-6 text-center">
            <p className="text-sm font-semibold text-hubsom-forest">
              No live shows right now
            </p>
            <p className="mt-1 text-xs text-hubsom-ink/55">
              When sellers go live, they’ll appear here by category.
            </p>
            <Link
              href="/seller/go-live"
              className="mt-3 inline-flex rounded-xl bg-hubsom-live px-3 py-2 text-xs font-bold text-white"
            >
              Go live
            </Link>
          </div>
        )}
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
            See all
          </Link>
        </div>

        <div className="grid grid-cols-3 gap-x-2.5 gap-y-4">
          {CATEGORIES.map((category, index) => (
            <motion.div
              key={category.slug}
              initial={{ opacity: 0, y: 10 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, amount: 0.15 }}
              transition={{ duration: 0.28, delay: (index % 6) * 0.03 }}
            >
              <PrimaryCategoryBox
                slug={category.slug}
                name={category.name}
                href={`/categories/${category.slug}`}
                priority={index < 6}
              />
            </motion.div>
          ))}
        </div>
      </section>
    </div>
  );
}
