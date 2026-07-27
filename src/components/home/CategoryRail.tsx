"use client";

import Image from "next/image";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { CATEGORIES } from "@/lib/categories";
import { categoryImage } from "@/lib/category-images";
import { cn } from "@/lib/utils";

const PREVIEW = CATEGORIES.slice(0, 12);
const COLLAPSE_AFTER = 72;

export function CategoryRail() {
  const [collapsed, setCollapsed] = useState(false);
  const lastY = useRef(0);
  const ticking = useRef(false);

  useEffect(() => {
    lastY.current = window.scrollY;

    function onScroll() {
      if (ticking.current) return;
      ticking.current = true;
      window.requestAnimationFrame(() => {
        const y = window.scrollY;
        const goingDown = y > lastY.current + 2;
        const goingUp = y < lastY.current - 2;

        if (y <= COLLAPSE_AFTER) {
          setCollapsed(false);
        } else if (goingDown) {
          setCollapsed(true);
        } else if (goingUp) {
          setCollapsed(false);
        }

        lastY.current = y;
        ticking.current = false;
      });
    }

    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <section
      className={cn(
        "sticky z-40 border-b transition-[padding,background-color,box-shadow,backdrop-filter] duration-300",
        collapsed
          ? "border-hubsom-forest/10 bg-white/95 py-2 shadow-[0_10px_30px_-22px_rgba(6,18,31,0.45)] backdrop-blur-xl"
          : "border-transparent bg-transparent py-6",
      )}
      style={{ top: "calc(3.5rem + env(safe-area-inset-top, 0px))" }}
    >
      <div className="px-4">
        <AnimatePresence initial={false}>
          {!collapsed ? (
            <motion.div
              key="heading"
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: "auto" }}
              exit={{ opacity: 0, height: 0 }}
              transition={{ duration: 0.22 }}
              className="overflow-hidden"
            >
              <div className="mb-3 flex items-end justify-between gap-3">
                <div>
                  <h2 className="font-display text-xl font-bold text-hubsom-forest">
                    Categories
                  </h2>
                  <p className="mt-1 text-xs text-hubsom-ink/60">
                    Browse every aisle with a tap.
                  </p>
                </div>
                <Link
                  href="/categories"
                  className="text-xs font-bold text-hubsom-cyan"
                >
                  See all
                </Link>
              </div>
            </motion.div>
          ) : null}
        </AnimatePresence>

        <div className="scrollbar-thin -mx-1 flex gap-2.5 overflow-x-auto px-1 pb-1">
          {PREVIEW.map((category, index) =>
            collapsed ? (
              <Link
                key={category.slug}
                href={`/categories/${category.slug}`}
                className="shrink-0 rounded-full border border-hubsom-forest/12 bg-hubsom-mist/90 px-3 py-1.5 text-[11px] font-bold text-hubsom-forest transition active:scale-[0.98]"
              >
                {category.name}
              </Link>
            ) : (
              <motion.div
                key={category.slug}
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.35, delay: index * 0.04 }}
                className="shrink-0"
              >
                <Link
                  href={`/categories/${category.slug}`}
                  className="group block w-[5.5rem] outline-none"
                >
                  <div className="relative aspect-[4/5] overflow-hidden rounded-2xl bg-hubsom-mist ring-1 ring-hubsom-forest/10 shadow-[0_12px_24px_-18px_rgba(10,61,92,0.55)] transition duration-300 group-hover:-translate-y-0.5 group-hover:shadow-[0_16px_28px_-16px_rgba(10,61,92,0.65)] group-active:scale-[0.98]">
                    <motion.div
                      className="absolute inset-[-16%]"
                      animate={{
                        scale: [1, 1.1, 1],
                        x: [0, index % 2 === 0 ? 8 : -8, 0],
                        y: [0, index % 3 === 0 ? -5 : 5, 0],
                      }}
                      transition={{
                        duration: 8 + (index % 5),
                        repeat: Infinity,
                        ease: "easeInOut",
                        delay: index * 0.25,
                      }}
                    >
                      <Image
                        src={categoryImage(category.slug)}
                        alt=""
                        fill
                        sizes="256px"
                        quality={95}
                        className="object-cover"
                      />
                    </motion.div>
                    <div className="absolute inset-0 bg-gradient-to-t from-hubsom-ink/75 via-hubsom-ink/15 to-transparent" />
                    <p className="absolute inset-x-0 bottom-0 line-clamp-2 px-1.5 pb-1.5 text-center text-[10px] font-bold leading-tight text-white">
                      {category.name}
                    </p>
                  </div>
                </Link>
              </motion.div>
            ),
          )}
        </div>
      </div>
    </section>
  );
}
