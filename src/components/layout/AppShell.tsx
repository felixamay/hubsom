"use client";

import { Suspense } from "react";
import { usePathname } from "next/navigation";
import { AppHeader } from "@/components/layout/AppHeader";
import { MobileTabBar } from "@/components/layout/MobileTabBar";
import { cn } from "@/lib/utils";

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname() || "/";
  const immersive =
    (pathname.startsWith("/live/") && pathname !== "/live") ||
    pathname.startsWith("/brand");
  const authScreen = pathname.startsWith("/auth/");

  return (
    <div
      className={cn(
        "mx-auto flex min-h-full w-full flex-1 flex-col bg-transparent",
        immersive
          ? "max-w-none"
          : "max-w-lg shadow-[0_0_80px_-40px_rgba(6,18,31,0.35)] md:border-x md:border-hubsom-forest/10 md:bg-white/40",
      )}
    >
      <Suspense
        fallback={
          <div
            className="sticky top-0 z-50 h-[4.25rem] border-b border-hubsom-forest/10 bg-white/92"
            style={{ paddingTop: "env(safe-area-inset-top, 0px)" }}
          />
        }
      >
        <AppHeader />
      </Suspense>
      <main
        className={cn(
          "flex-1",
          !immersive &&
            !authScreen &&
            "pb-[calc(5.5rem+env(safe-area-inset-bottom,0px))]",
        )}
      >
        {children}
      </main>
      {!authScreen ? <MobileTabBar /> : null}
    </div>
  );
}
