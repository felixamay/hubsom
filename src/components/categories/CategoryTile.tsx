"use client";

import Image from "next/image";
import Link from "next/link";
import { cn } from "@/lib/utils";
import { categoryImage } from "@/lib/category-images";
import { categoryTone } from "@/lib/category-tones";

export function CategoryTile({
  slug,
  name,
  description,
  href,
  size = "md",
  badge,
  priority = false,
  className,
}: {
  slug: string;
  name: string;
  description?: string;
  href: string;
  size?: "sm" | "md" | "lg";
  badge?: string;
  priority?: boolean;
  className?: string;
}) {
  const tone = categoryTone(slug);

  const shell =
    size === "sm"
      ? "w-[5.5rem]"
      : size === "lg"
        ? "w-[11.75rem] shrink-0"
        : "w-full";

  const box =
    size === "sm"
      ? "aspect-[4/5] rounded-2xl p-2.5"
      : size === "lg"
        ? "aspect-[5/3.35] rounded-[1.35rem] p-4"
        : "aspect-[4/3.15] rounded-[1.25rem] p-4";

  const imgPx = size === "sm" ? 112 : size === "lg" ? 200 : 180;

  return (
    <Link
      href={href}
      className={cn(
        "group block outline-none transition duration-200 active:scale-[0.985]",
        shell,
        className,
      )}
    >
      <div
        className={cn(
          "relative flex items-center justify-center overflow-hidden ring-1 ring-black/[0.04] shadow-[0_14px_30px_-22px_rgba(6,18,31,0.5)]",
          box,
        )}
        style={{
          background: `linear-gradient(165deg, ${tone.bgSoft} 0%, ${tone.bg} 78%)`,
        }}
      >
        {badge ? (
          <span
            className="absolute left-2.5 top-2.5 z-10 rounded-full bg-white/90 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide shadow-sm"
            style={{ color: tone.ink }}
          >
            {badge}
          </span>
        ) : null}

        <Image
          src={categoryImage(slug)}
          alt=""
          width={imgPx}
          height={imgPx}
          sizes={`${imgPx}px`}
          quality={100}
          priority={priority}
          className="relative z-[1] h-[78%] w-[78%] object-contain drop-shadow-[0_12px_20px_rgba(6,18,31,0.16)] transition duration-300 group-hover:scale-[1.06]"
        />
      </div>

      <div className={cn(size === "sm" ? "mt-1.5" : "mt-2")}>
        <p
          className={cn(
            "font-display font-bold leading-tight",
            size === "sm"
              ? "line-clamp-2 text-center text-[10px] text-hubsom-forest"
              : "text-sm text-hubsom-forest",
          )}
          style={size !== "sm" ? { color: tone.ink } : undefined}
        >
          {name}
        </p>
        {description && size === "md" ? (
          <p className="mt-0.5 line-clamp-2 text-[11px] leading-relaxed text-hubsom-ink/55">
            {description}
          </p>
        ) : null}
      </div>
    </Link>
  );
}
