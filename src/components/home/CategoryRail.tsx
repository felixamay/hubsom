"use client";

import Image from "next/image";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { motion } from "framer-motion";
import { CATEGORIES } from "@/lib/categories";
import { categoryImage } from "@/lib/category-images";
import { cn } from "@/lib/utils";

const PREVIEW = CATEGORIES.slice(0, 12);
const NEAR_TOP = 64;
const DIRECTION_DELTA = 10;

export function CategoryRail() {
  const [collapsed, setCollapsed] = useState(false);
  const lastY = useRef(0);
  const frame = useRef(0);

  useEffect(() => {
    lastY.current = window.scrollY;

    function onScroll() {
      if (frame.current) return;
      frame.current = window.requestAnimationFrame(() => {
        frame.current = 0;
        const y = Math.max(0, window.scrollY);
        const delta = y - lastY.current;

        if (y <= NEAR_TOP) {
          setCollapsed(false);
          lastY.current = y;
          return;
        }

        // Ignore tiny jitter so direction flips don't flash the layout.
        if (Math.abs(delta) < DIRECTION_DELTA) {
          return;
        }

        setCollapsed(delta > 0);
        lastY.current = y;
      });
    }

    window.addEventListener("scroll", onScroll, { passive: true });
    return () => {
      window.removeEventListener("scroll", onScroll);
      if (frame.current) cancelAnimationFrame(frame.current);
    };
  }, []);

  return (
    <section
      className={cn(
        "sticky z-40 border-b bg-white/95 backdrop-blur-xl transition-[box-shadow,padding] duration-300 ease-out",
        collapsed
          ? "border-hubsom-forest/10 py-2 shadow-[0_10px_30px_-22px_rgba(6,18,31,0.45)]"
          : "border-transparent py-5 shadow-none",
      )}
      style={{ top: "calc(3.5rem + env(safe-area-inset-top, 0px))" }}
    >
      <div className="px-4">
        <div
          className={cn(
            "grid transition-[grid-template-rows,opacity,margin] duration-300 ease-out",
            collapsed
              ? "mb-0 grid-rows-[0fr] opacity-0"
              : "mb-3 grid-rows-[1fr] opacity-100",
          )}
          aria-hidden={collapsed}
        >
          <div className="overflow-hidden">
            <div className="flex items-end justify-between gap-3">
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
                tabIndex={collapsed ? -1 : undefined}
              >
                See all
              </Link>
            </div>
          </div>
        </div>

        {/* Title chips — shown when collapsed */}
        <div
          className={cn(
            "grid transition-[grid-template-rows,opacity] duration-300 ease-out",
            collapsed
              ? "grid-rows-[1fr] opacity-100"
              : "pointer-events-none grid-rows-[0fr] opacity-0",
          )}
        >
          <div className="overflow-hidden">
            <div className="scrollbar-thin -mx-1 flex gap-2 overflow-x-auto px-1 pb-0.5">
              {PREVIEW.map((category) => (
                <Link
                  key={`chip-${category.slug}`}
                  href={`/categories/${category.slug}`}
                  className="shrink-0 rounded-full border border-hubsom-forest/12 bg-hubsom-mist/90 px-3 py-1.5 text-[11px] font-bold text-hubsom-forest"
                  tabIndex={collapsed ? undefined : -1}
                >
                  {category.name}
                </Link>
              ))}
            </div>
          </div>
        </div>

        {/* Image tiles — stay mounted so scroll-up never reloads/flickers */}
        <div
          className={cn(
            "grid transition-[grid-template-rows,opacity] duration-300 ease-out",
            collapsed
              ? "pointer-events-none grid-rows-[0fr] opacity-0"
              : "mt-0 grid-rows-[1fr] opacity-100",
          )}
        >
          <div className="overflow-hidden">
            <div className="scrollbar-thin -mx-1 flex gap-2.5 overflow-x-auto px-1 pb-1">
              {PREVIEW.map((category, index) => (
                <div key={category.slug} className="w-[5.5rem] shrink-0">
                  <Link
                    href={`/categories/${category.slug}`}
                    className="group block outline-none"
                    tabIndex={collapsed ? -1 : undefined}
                  >
                    <div className="relative aspect-[4/5] overflow-hidden rounded-2xl bg-hubsom-mist ring-1 ring-hubsom-forest/10 shadow-[0_12px_24px_-18px_rgba(10,61,92,0.55)] transition duration-300 group-hover:-translate-y-0.5 group-hover:shadow-[0_16px_28px_-16px_rgba(10,61,92,0.65)] group-active:scale-[0.98]">
                      <motion.div
                        className="absolute inset-[-16%] will-change-transform"
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
                          priority={index < 4}
                        />
                      </motion.div>
                      <div className="absolute inset-0 bg-gradient-to-t from-hubsom-ink/75 via-hubsom-ink/15 to-transparent" />
                      <p className="absolute inset-x-0 bottom-0 line-clamp-2 px-1.5 pb-1.5 text-center text-[10px] font-bold leading-tight text-white">
                        {category.name}
                      </p>
                    </div>
                  </Link>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
