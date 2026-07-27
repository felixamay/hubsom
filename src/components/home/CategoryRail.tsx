import Link from "next/link";
import { CATEGORIES } from "@/lib/categories";

export function CategoryRail() {
  return (
    <section className="mx-auto max-w-7xl px-4 py-8 sm:px-6">
      <div className="mb-5">
        <h2 className="font-display text-3xl font-bold text-hubsom-forest">
          Every category. Same playbook.
        </h2>
        <p className="mt-2 max-w-2xl text-hubsom-ink/70">
          Groceries are not a separate marketplace — they Buy Now, go live, auction,
          flash, bundle, and sit in seller stores like everything else.
        </p>
      </div>
      <div className="scrollbar-thin flex gap-2 overflow-x-auto pb-2">
        {CATEGORIES.map((category) => (
          <Link
            key={category.slug}
            href={`/categories/${category.slug}`}
            className="shrink-0 rounded-xl border border-hubsom-forest/10 bg-white/70 px-4 py-3 text-sm font-semibold text-hubsom-forest transition hover:border-hubsom-leaf hover:bg-hubsom-mint"
          >
            {category.name}
          </Link>
        ))}
      </div>
    </section>
  );
}
