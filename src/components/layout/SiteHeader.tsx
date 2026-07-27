"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Menu, Radio, ShoppingBag, X } from "lucide-react";
import { useState } from "react";
import { useCartStore } from "@/lib/stores/cart";
import { cn } from "@/lib/utils";

const links = [
  { href: "/live", label: "Live" },
  { href: "/marketplace", label: "Marketplace" },
  { href: "/auctions", label: "Auctions" },
  { href: "/flash-sales", label: "Flash Sales" },
  { href: "/seller", label: "Sell" },
];

export function SiteHeader() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const count = useCartStore((s) => s.items.reduce((n, i) => n + i.quantity, 0));
  const hideChrome = pathname?.startsWith("/live/") && pathname !== "/live";

  if (hideChrome) return null;

  return (
    <header className="sticky top-0 z-50 border-b border-hubsom-forest/10 bg-[#eef5f0]/85 backdrop-blur-xl">
      <div className="mx-auto flex h-16 max-w-7xl items-center justify-between gap-4 px-4 sm:px-6">
        <Link href="/" className="font-display text-2xl font-extrabold tracking-tight text-hubsom-forest">
          Hubsom
        </Link>

        <nav className="hidden items-center gap-1 md:flex">
          {links.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className={cn(
                "rounded-lg px-3 py-2 text-sm font-medium transition-colors",
                pathname === link.href || pathname?.startsWith(`${link.href}/`)
                  ? "bg-hubsom-forest text-white"
                  : "text-hubsom-ink/75 hover:bg-hubsom-mint hover:text-hubsom-forest",
              )}
            >
              {link.label}
            </Link>
          ))}
        </nav>

        <div className="flex items-center gap-2">
          <Link
            href="/live/stream-ama-mix"
            className="hidden items-center gap-2 rounded-lg bg-hubsom-live px-3 py-2 text-sm font-semibold text-white shadow-sm transition hover:brightness-110 sm:inline-flex"
          >
            <Radio className="h-4 w-4" />
            Watch Live
          </Link>
          <Link
            href="/cart"
            className="relative inline-flex h-10 w-10 items-center justify-center rounded-lg border border-hubsom-forest/15 bg-white/70 text-hubsom-forest"
            aria-label="Cart"
          >
            <ShoppingBag className="h-5 w-5" />
            {count > 0 && (
              <span className="absolute -right-1 -top-1 flex h-5 min-w-5 items-center justify-center rounded-md bg-hubsom-gold px-1 text-[11px] font-bold text-hubsom-ink">
                {count}
              </span>
            )}
          </Link>
          <button
            type="button"
            className="inline-flex h-10 w-10 items-center justify-center rounded-lg border border-hubsom-forest/15 bg-white/70 text-hubsom-forest md:hidden"
            onClick={() => setOpen((v) => !v)}
            aria-label="Menu"
          >
            {open ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
          </button>
        </div>
      </div>

      {open && (
        <div className="border-t border-hubsom-forest/10 bg-[#eef5f0] px-4 py-3 md:hidden">
          <div className="flex flex-col gap-1">
            {links.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                onClick={() => setOpen(false)}
                className="rounded-lg px-3 py-2 text-sm font-medium text-hubsom-ink hover:bg-hubsom-mint"
              >
                {link.label}
              </Link>
            ))}
          </div>
        </div>
      )}
    </header>
  );
}
