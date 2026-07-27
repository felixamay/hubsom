"use client";

import Image from "next/image";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { motion } from "framer-motion";
import { CATEGORIES } from "@/lib/categories";
import { categoryImage } from "@/lib/category-images";
import { cn } from "@/lib/utils";

const PREVIEW = CATEGORIES.slice(0, 12);

export function CategoryRail() {
  const sectionRef = useRef<HTMLElement>(null);
  const [pinned, setPinned] = useState(false);

  useEffect(() => {
    const section = sectionRef.current;
    if (!section) return;

    const headerOffset = () => {
      const safe = Number.parseFloat(
        getComputedStyle(document.documentElement).getPropertyValue(
          "env(safe-area-inset-top)",
        ) || "0",
      );
      // Match sticky header: h-14 (56px) + safe area.
      return 56 + (Number.isFinite(safe) ? safe : 0);
    };

    let frame = 0;

    function update() {
      frame = 0;
      if (!section) return;
      const top = section.getBoundingClientRect().top;
      // Pin title chips only after the image rail has scrolled under the header.
      setPinned(top <= headerOffset() - 8);
    }

    function onScroll() {
      if (frame) return;
      frame = window.requestAnimationFrame(update);
    }

    update();
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll, { passive: true });
    return () => {
      window.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onScroll);
      if (frame) cancelAnimationFrame(frame);
    };
  }, []);

  return (
    <>
      {/* In-flow original rail — never resizes while sticky (avoids flicker). */}
      <section ref={sectionRef} className="px-4 py-6">
        <div className="mb-3 flex items-end justify-between gap-3">
          <div>
            <h2 className="font-display text-xl font-bold text-hubsom-forest">
              Categories
            </h2>
            <p className="mt-1 text-xs text-hubsom-ink/60">
              Browse every aisle with a tap.
            </p>
          </div>
          <Link href="/categories" className="text-xs font-bold text-hubsom-cyan">
            See all
          </Link>
        </div>

        <div className="scrollbar-thin -mx-1 flex gap-2.5 overflow-x-auto px-1 pb-1">
          {PREVIEW.map((category, index) => (
            <div key={category.slug} className="w-[5.5rem] shrink-0">
              <Link
                href={`/categories/${category.slug}`}
                className="group block outline-none"
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
      </section>

      {/* Compact title strip — fixed under header only while the rail is off-screen. */}
      <div
        className={cn(
          "pointer-events-none fixed inset-x-0 z-40 flex justify-center transition-opacity duration-200 ease-out",
          pinned ? "opacity-100" : "opacity-0",
        )}
        style={{ top: "calc(3.5rem + env(safe-area-inset-top, 0px))" }}
        aria-hidden={!pinned}
      >
        <div
          className={cn(
            "pointer-events-auto w-full max-w-lg border-b border-hubsom-forest/10 bg-white/95 py-2 shadow-[0_10px_30px_-22px_rgba(6,18,31,0.45)] backdrop-blur-xl",
            !pinned && "invisible",
          )}
        >
          <div className="scrollbar-thin flex gap-2 overflow-x-auto px-4">
            {PREVIEW.map((category) => (
              <Link
                key={`pin-${category.slug}`}
                href={`/categories/${category.slug}`}
                tabIndex={pinned ? undefined : -1}
                className="shrink-0 rounded-full border border-hubsom-forest/12 bg-hubsom-mist/90 px-3 py-1.5 text-[11px] font-bold text-hubsom-forest"
              >
                {category.name}
              </Link>
            ))}
          </div>
        </div>
      </div>
    </>
  );
}
