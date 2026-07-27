"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Grid2x2,
  Home,
  LayoutDashboard,
  PlusCircle,
  UserRound,
} from "lucide-react";
import { cn } from "@/lib/utils";

const tabs = [
  { href: "/", label: "Home", icon: Home, match: (p: string) => p === "/" },
  {
    href: "/categories",
    label: "Categories",
    icon: Grid2x2,
    match: (p: string) => p.startsWith("/categories"),
  },
  {
    href: "/sell",
    label: "Sell",
    icon: PlusCircle,
    match: (p: string) => p.startsWith("/sell") || p.startsWith("/seller"),
    emphasize: true,
  },
  {
    href: "/account",
    label: "Account",
    icon: UserRound,
    match: (p: string) => p.startsWith("/account"),
  },
  {
    href: "/dashboard",
    label: "Dashboard",
    icon: LayoutDashboard,
    match: (p: string) => p.startsWith("/dashboard"),
  },
] as const;

export function MobileTabBar() {
  const pathname = usePathname() || "/";
  const hide =
    (pathname.startsWith("/live/") && pathname !== "/live") ||
    pathname.startsWith("/brand");

  if (hide) return null;

  return (
    <nav
      aria-label="Primary"
      className="fixed inset-x-0 bottom-0 z-[60] border-t border-hubsom-forest/10 bg-white/95 shadow-[0_-8px_30px_-18px_rgba(6,18,31,0.35)] backdrop-blur-xl"
      style={{ paddingBottom: "env(safe-area-inset-bottom, 0px)" }}
    >
      <div className="mx-auto grid h-[4.25rem] max-w-lg grid-cols-5 items-stretch px-1">
        {tabs.map((tab) => {
          const active = tab.match(pathname);
          const Icon = tab.icon;
          const emphasize = "emphasize" in tab && tab.emphasize;

          return (
            <Link
              key={tab.href}
              href={tab.href}
              className={cn(
                "group relative flex flex-col items-center justify-center gap-1 rounded-xl px-1 text-[10px] font-semibold tracking-wide transition-colors",
                active ? "text-hubsom-forest" : "text-hubsom-ink/45 hover:text-hubsom-forest",
              )}
            >
              <span
                className={cn(
                  "flex h-8 w-8 items-center justify-center rounded-xl transition-all",
                  emphasize &&
                    "h-11 w-11 -mt-3 rounded-2xl bg-hubsom-live text-white shadow-[0_10px_20px_-10px_rgba(243,111,33,0.9)]",
                  emphasize && active && "ring-2 ring-hubsom-orange/40",
                  !emphasize && active && "bg-hubsom-mint text-hubsom-forest",
                )}
              >
                <Icon
                  className={cn(
                    emphasize ? "h-6 w-6" : "h-[1.35rem] w-[1.35rem]",
                    !emphasize && active && "stroke-[2.4px]",
                  )}
                  strokeWidth={active ? 2.4 : 2}
                />
              </span>
              <span className={cn(emphasize && "mt-0.5", active && "text-hubsom-forest")}>
                {tab.label}
              </span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
