"use client";

import { usePathname } from "next/navigation";
import { AppHeader } from "@/components/layout/AppHeader";
import { MobileTabBar } from "@/components/layout/MobileTabBar";
import { cn } from "@/lib/utils";

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname() || "/";
  const immersive =
    (pathname.startsWith("/live/") && pathname !== "/live") ||
    pathname.startsWith("/brand");

  return (
    <div
      className={cn(
        "mx-auto flex min-h-full w-full flex-1 flex-col bg-transparent",
        immersive
          ? "max-w-none"
          : "max-w-lg shadow-[0_0_80px_-40px_rgba(6,18,31,0.35)] md:border-x md:border-hubsom-forest/10 md:bg-white/40",
      )}
    >
      <AppHeader />
      <main
        className={cn(
          "flex-1",
          !immersive &&
            "pb-[calc(5.5rem+env(safe-area-inset-bottom,0px))]",
        )}
      >
        {children}
      </main>
      <MobileTabBar />
    </div>
  );
}
