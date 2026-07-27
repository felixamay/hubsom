import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { FollowButton } from "@/components/sellers/FollowButton";
import { EmptyState } from "@/components/ui/EmptyState";
import { requireUser } from "@/lib/auth/session";
import { listFollowedSellers } from "@/lib/data/follows";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Following",
};

export default async function FollowingPage() {
  const session = await requireUser("/account/following");
  const sellers = await listFollowedSellers(session.user.id);

  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
        Following
      </h1>
      <p className="mt-2 text-sm text-hubsom-ink/65">
        Sellers you follow — catch their lives and drops first.
      </p>

      <div className="mt-5 space-y-3">
        {!sellers.length ? (
          <EmptyState
            title="You’re not following anyone yet"
            body="Follow stores from live shows, products, or store pages."
            actionHref="/categories"
            actionLabel="Browse categories"
          />
        ) : null}

        {sellers.map((seller) => (
          <div
            key={seller.id}
            className="flex items-center gap-3 rounded-2xl border border-hubsom-forest/10 bg-white/80 p-3"
          >
            <Link href={`/stores/${seller.slug}`} className="shrink-0">
              <Image
                src={seller.avatar}
                alt={seller.name}
                width={48}
                height={48}
                className="h-12 w-12 rounded-2xl object-cover ring-1 ring-hubsom-forest/10"
              />
            </Link>
            <Link href={`/stores/${seller.slug}`} className="min-w-0 flex-1">
              <p className="truncate font-display text-base font-bold text-hubsom-forest">
                {seller.name}
              </p>
              <p className="truncate text-xs text-hubsom-ink/55">
                {seller.city}, {seller.region} ·{" "}
                {seller.followers.toLocaleString()} followers
              </p>
            </Link>
            <FollowButton
              sellerId={seller.id}
              initialFollowing
              initialFollowers={seller.followers}
              size="sm"
              className="shrink-0"
            />
          </div>
        ))}
      </div>
    </div>
  );
}
