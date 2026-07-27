import Link from "next/link";
import { CATEGORIES } from "@/lib/categories";

export function CategoryRail() {
  return (
    <section className="px-4 py-6">
      <div className="mb-3 flex items-end justify-between gap-3">
        <div>
          <h2 className="font-display text-xl font-bold text-hubsom-forest">
            Categories
          </h2>
          <p className="mt-1 text-xs text-hubsom-ink/60">
            Same playbook for every aisle.
          </p>
        </div>
        <Link href="/categories" className="text-xs font-bold text-hubsom-cyan">
          See all
        </Link>
      </div>
      <div className="scrollbar-thin flex gap-2 overflow-x-auto pb-1">
        {CATEGORIES.slice(0, 12).map((category) => (
          <Link
            key={category.slug}
            href={`/categories/${category.slug}`}
            className="shrink-0 rounded-xl border border-hubsom-forest/10 bg-white/80 px-3 py-2 text-xs font-semibold text-hubsom-forest"
          >
            {category.name}
          </Link>
        ))}
      </div>
    </section>
  );
}
