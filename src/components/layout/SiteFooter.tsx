"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

export function SiteFooter() {
  const pathname = usePathname();
  if (pathname?.startsWith("/live/") && pathname !== "/live") return null;

  return (
    <footer className="mt-20 border-t border-hubsom-forest/10 bg-hubsom-forest text-hubsom-mint">
      <div className="mx-auto grid max-w-7xl gap-10 px-4 py-14 sm:px-6 md:grid-cols-[1.4fr_1fr_1fr]">
        <div>
          <p className="font-display text-3xl font-bold text-white">Hubsom</p>
          <p className="mt-3 max-w-md text-sm leading-relaxed text-hubsom-mint/85">
            Social commerce built in Ghana. Live shopping, auctions, Buy Now,
            flash sales, and seller stores — every product category, one platform.
          </p>
        </div>
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.18em] text-hubsom-gold">
            Explore
          </p>
          <ul className="mt-4 space-y-2 text-sm">
            <li>
              <Link href="/live" className="hover:text-white">
                Live shows
              </Link>
            </li>
            <li>
              <Link href="/marketplace" className="hover:text-white">
                Marketplace
              </Link>
            </li>
            <li>
              <Link href="/auctions" className="hover:text-white">
                Auctions
              </Link>
            </li>
            <li>
              <Link href="/flash-sales" className="hover:text-white">
                Flash sales
              </Link>
            </li>
          </ul>
        </div>
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.18em] text-hubsom-gold">
            Sellers
          </p>
          <ul className="mt-4 space-y-2 text-sm">
            <li>
              <Link href="/seller/go-live" className="hover:text-white">
                Go live
              </Link>
            </li>
            <li>
              <Link href="/seller/analytics" className="hover:text-white">
                Analytics
              </Link>
            </li>
            <li>
              <Link href="/stores/ama-market-live" className="hover:text-white">
                Example store
              </Link>
            </li>
          </ul>
        </div>
      </div>
      <div className="border-t border-white/10 px-4 py-4 text-center text-xs text-hubsom-mint/70">
        © {new Date().getFullYear()} Hubsom · Accra, Ghana
      </div>
    </footer>
  );
}
