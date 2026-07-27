import Link from "next/link";
import { Megaphone } from "lucide-react";
import { cn } from "@/lib/utils";
import type { Promotion } from "@/types/promotions";

const TONE: Record<
  Promotion["tone"],
  { shell: string; eyebrow: string; cta: string }
> = {
  forest: {
    shell:
      "border-hubsom-forest/15 bg-gradient-to-br from-hubsom-forest to-[#0c4a6e] text-white",
    eyebrow: "text-white/65",
    cta: "bg-white text-hubsom-forest",
  },
  gold: {
    shell:
      "border-hubsom-gold/35 bg-gradient-to-br from-[#f7b733] to-hubsom-gold text-hubsom-ink",
    eyebrow: "text-hubsom-ink/55",
    cta: "bg-hubsom-ink text-white",
  },
  cyan: {
    shell:
      "border-hubsom-cyan/25 bg-gradient-to-br from-hubsom-cyan to-[#0284c7] text-white",
    eyebrow: "text-white/70",
    cta: "bg-white text-[#0369a1]",
  },
  live: {
    shell:
      "border-hubsom-live/30 bg-gradient-to-br from-hubsom-live to-[#b91c1c] text-white",
    eyebrow: "text-white/70",
    cta: "bg-white text-hubsom-live",
  },
};

export function PromoSpace({
  promotions,
  title = "Promotions",
  subtitle = "Offers, drops, and partner deals.",
  className,
  compact = false,
}: {
  promotions: Promotion[];
  title?: string;
  subtitle?: string;
  className?: string;
  compact?: boolean;
}) {
  return (
    <section
      aria-label="Promotions"
      className={cn(
        compact ? "space-y-2.5" : "space-y-3",
        className,
      )}
    >
      <div className="flex items-end justify-between gap-3">
        <div>
          <div className="inline-flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-[0.16em] text-hubsom-ink/45">
            <Megaphone className="h-3.5 w-3.5" />
            {title}
          </div>
          {!compact ? (
            <p className="mt-1 text-xs text-hubsom-ink/60">{subtitle}</p>
          ) : null}
        </div>
        <Link
          href="/flash-sales"
          className="text-[11px] font-bold text-hubsom-cyan"
        >
          All deals
        </Link>
      </div>

      {!promotions.length ? (
        <div className="rounded-2xl border border-dashed border-hubsom-forest/20 bg-white/50 px-4 py-5 text-center">
          <p className="text-sm font-semibold text-hubsom-ink/70">
            Promotion space
          </p>
          <p className="mt-1 text-xs text-hubsom-ink/50">
            Campaigns and partner offers will appear here.
          </p>
        </div>
      ) : (
        <div className="scrollbar-thin flex gap-3 overflow-x-auto pb-1">
          {promotions.map((promo) => {
            const tone = TONE[promo.tone];
            return (
              <Link
                key={promo.id}
                href={promo.href}
                className={cn(
                  "relative min-w-[78%] shrink-0 overflow-hidden rounded-2xl border p-4 shadow-[0_16px_32px_-24px_rgba(6,18,31,0.45)] transition active:scale-[0.99] sm:min-w-[52%] lg:min-w-[320px]",
                  tone.shell,
                )}
              >
                <p
                  className={cn(
                    "text-[10px] font-bold uppercase tracking-[0.14em]",
                    tone.eyebrow,
                  )}
                >
                  Promo
                </p>
                <h3 className="mt-2 font-display text-xl font-extrabold leading-tight">
                  {promo.title}
                </h3>
                <p className="mt-1.5 line-clamp-2 text-sm opacity-90">
                  {promo.subtitle}
                </p>
                <span
                  className={cn(
                    "mt-4 inline-flex rounded-xl px-3 py-2 text-[11px] font-bold",
                    tone.cta,
                  )}
                >
                  {promo.ctaLabel}
                </span>
              </Link>
            );
          })}
        </div>
      )}
    </section>
  );
}
