"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Radio, ShoppingBag, UserRound } from "lucide-react";
import { BrandLogo } from "@/components/brand/BrandLogo";
import { useCartStore } from "@/lib/stores/cart";

export function AppHeader() {
  const pathname = usePathname();
  const count = useCartStore((s) => s.items.reduce((n, i) => n + i.quantity, 0));
  const hide =
    (pathname?.startsWith("/live/") && pathname !== "/live") ||
    pathname?.startsWith("/brand") ||
    pathname?.startsWith("/auth/");

  if (hide) return null;

  return (
    <header
      className="sticky top-0 z-50 border-b border-hubsom-forest/10 bg-white/90 backdrop-blur-xl"
      style={{ paddingTop: "env(safe-area-inset-top, 0px)" }}
    >
      <div className="mx-auto flex h-14 max-w-lg items-center justify-between gap-3 px-4">
        <BrandLogo priority heightClassName="h-8" />
        <div className="flex items-center gap-2">
          <Link
            href="/live"
            className="inline-flex h-9 items-center gap-1.5 rounded-xl bg-hubsom-live px-2.5 text-xs font-bold text-white"
            aria-label="Watch live"
          >
            <Radio className="h-3.5 w-3.5" />
            Live
          </Link>
          <Link
            href="/account"
            className="inline-flex h-9 w-9 items-center justify-center rounded-xl border border-hubsom-forest/10 bg-hubsom-mist text-hubsom-forest"
            aria-label="Account"
          >
            <UserRound className="h-4 w-4" />
          </Link>
          <Link
            href="/cart"
            className="relative inline-flex h-9 w-9 items-center justify-center rounded-xl border border-hubsom-forest/10 bg-hubsom-mist text-hubsom-forest"
            aria-label="Cart"
          >
            <ShoppingBag className="h-4 w-4" />
            {count > 0 && (
              <span className="absolute -right-1 -top-1 flex h-4 min-w-4 items-center justify-center rounded-md bg-hubsom-gold px-1 text-[10px] font-bold text-hubsom-ink">
                {count}
              </span>
            )}
          </Link>
        </div>
      </div>
    </header>
  );
}
