import type { Metadata } from "next";
import Link from "next/link";
import { CATEGORIES } from "@/lib/categories";

export const metadata: Metadata = {
  title: "Categories",
  description: "Browse every Hubsom product category — Buy Now, live, auction, flash.",
};

const accents = [
  "from-[#7cbf2c]/20 to-[#00aeef]/15",
  "from-[#00aeef]/20 to-[#0054a6]/15",
  "from-[#f7941d]/20 to-[#f36f21]/15",
  "from-[#0054a6]/15 to-[#7cbf2c]/15",
];

export default function CategoriesPage() {
  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
        Categories
      </h1>
      <p className="mt-2 text-sm text-hubsom-ink/65">
        Groceries to gadgets — same Buy Now, live, auction, and flash tools.
      </p>

      <div className="mt-6 grid grid-cols-2 gap-3">
        {CATEGORIES.map((category, index) => (
          <Link
            key={category.slug}
            href={`/categories/${category.slug}`}
            className={`rounded-2xl border border-hubsom-forest/10 bg-gradient-to-br ${accents[index % accents.length]} p-4 transition active:scale-[0.98]`}
          >
            <p className="font-display text-base font-bold leading-snug text-hubsom-ink">
              {category.name}
            </p>
            <p className="mt-1 line-clamp-2 text-[11px] leading-relaxed text-hubsom-ink/60">
              {category.description}
            </p>
          </Link>
        ))}
      </div>
    </div>
  );
}
