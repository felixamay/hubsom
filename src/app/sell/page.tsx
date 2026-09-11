import type { Metadata } from "next";
import Link from "next/link";
import { BarChart3, PackagePlus, Radio, Store } from "lucide-react";

export const metadata: Metadata = {
  title: "Sell",
  description: "Go live, list products, and grow your Hubsom store.",
};

const actions = [
  {
    href: "/seller/go-live",
    title: "Go live",
    body: "Start a mixed-category show with pinning, auctions, and one-tap checkout.",
    icon: Radio,
    tone: "bg-hubsom-live text-white",
  },
  {
    href: "/seller/products/new",
    title: "Add listing",
    body: "List any category for Buy Now, flash, bundles, and store shelves.",
    icon: PackagePlus,
    tone: "bg-hubsom-gold text-hubsom-ink",
  },
  {
    href: "/seller",
    title: "Seller hub",
    body: "Manage shows, inventory sync, and your storefront.",
    icon: Store,
    tone: "bg-hubsom-forest text-white",
  },
  {
    href: "/dashboard",
    title: "Performance",
    body: "Open your dashboard for revenue, viewers, and conversion.",
    icon: BarChart3,
    tone: "bg-hubsom-cyan text-white",
  },
];

export default function SellPage() {
  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">Sell</h1>
      <p className="mt-2 text-sm text-hubsom-ink/65">
        One tap to go live or list — produce beside phones in the same show.
      </p>

      <div className="mt-6 space-y-3">
        {actions.map((action) => {
          const Icon = action.icon;
          return (
            <Link
              key={action.href}
              href={action.href}
              className="flex items-start gap-3 rounded-2xl border border-hubsom-forest/10 bg-white/80 p-4 transition active:scale-[0.99]"
            >
              <span
                className={`inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl ${action.tone}`}
              >
                <Icon className="h-5 w-5" />
              </span>
              <span>
                <span className="block font-display text-lg font-bold text-hubsom-ink">
                  {action.title}
                </span>
                <span className="mt-1 block text-sm leading-relaxed text-hubsom-ink/65">
                  {action.body}
                </span>
              </span>
            </Link>
          );
        })}
      </div>
    </div>
  );
}
