"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { CategoryTile } from "@/components/categories/CategoryTile";
import { CATEGORIES } from "@/lib/categories";
import { cn } from "@/lib/utils";

const PREVIEW = CATEGORIES.slice(0, 12);

export function CategoryRail() {
  const sectionRef = useRef<HTMLElement>(null);
  const [pinned, setPinned] = useState(false);

  useEffect(() => {
    const section = sectionRef.current;
    if (!section) return;

    let frame = 0;
    function update() {
      frame = 0;
      if (!section) return;
      const top = section.getBoundingClientRect().top;
      setPinned(top <= 56 - 8);
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
            <CategoryTile
              key={category.slug}
              slug={category.slug}
              name={category.name}
              href={`/categories/${category.slug}`}
              size="sm"
              priority={index < 4}
            />
          ))}
        </div>
      </section>

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
