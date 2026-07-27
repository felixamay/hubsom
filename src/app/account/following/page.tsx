import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { FollowButton } from "@/components/sellers/FollowButton";
import { EmptyState } from "@/components/ui/EmptyState";
import { requireUser } from "@/lib/auth/session";
import { cn } from "@/lib/utils";
import {
  getFollowCounts,
  listFollowedSellers,
  listFollowersForSeller,
} from "@/lib/data/follows";
import { getUserById } from "@/lib/data/users";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Connections",
};

export default async function ConnectionsPage({
  searchParams,
}: {
  searchParams: Promise<{ tab?: string }>;
}) {
  const session = await requireUser("/account/following");
  const { tab: tabParam } = await searchParams;
  const user = await getUserById(session.user.id);
  const counts = await getFollowCounts(session.user.id);
  const hasStore = Boolean(counts.sellerId);

  const tab =
    tabParam === "followers" && hasStore
      ? "followers"
      : tabParam === "following" || !tabParam
        ? "following"
        : "following";

  const following = tab === "following" ? await listFollowedSellers(session.user.id) : [];
  const followers =
    tab === "followers" && counts.sellerId
      ? await listFollowersForSeller(counts.sellerId)
      : [];

  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
        Connections
      </h1>
      <p className="mt-2 text-sm text-hubsom-ink/65">
        See who you follow
        {hasStore ? " and who follows your store" : ""}.
      </p>

      <div className="mt-5 grid grid-cols-2 gap-2 rounded-2xl border border-hubsom-forest/10 bg-white/80 p-1.5">
        <Link
          href="/account/following?tab=following"
          className={cn(
            "rounded-xl px-3 py-2.5 text-center text-sm font-bold transition",
            tab === "following"
              ? "bg-hubsom-forest text-white"
              : "text-hubsom-forest hover:bg-hubsom-mist",
          )}
        >
          Following
          <span className="mt-0.5 block text-[11px] font-semibold opacity-80">
            {counts.followingCount}
          </span>
        </Link>
        <Link
          href={hasStore ? "/account/following?tab=followers" : "/seller"}
          className={cn(
            "rounded-xl px-3 py-2.5 text-center text-sm font-bold transition",
            tab === "followers"
              ? "bg-hubsom-forest text-white"
              : "text-hubsom-forest hover:bg-hubsom-mist",
          )}
        >
          Followers
          <span className="mt-0.5 block text-[11px] font-semibold opacity-80">
            {hasStore ? counts.followersCount : "Open store"}
          </span>
        </Link>
      </div>

      <div className="mt-5 space-y-3">
        {tab === "following" ? (
          <>
            {!following.length ? (
              <EmptyState
                title="You’re not following anyone yet"
                body="Follow stores from live shows, products, or store pages."
                actionHref="/categories"
                actionLabel="Browse categories"
              />
            ) : null}
            {following.map((seller) => (
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
          </>
        ) : (
          <>
            {!hasStore ? (
              <EmptyState
                title="Create a store to get followers"
                body="Open the seller hub to set up your storefront, then people can follow you."
                actionHref="/seller"
                actionLabel="Seller hub"
              />
            ) : null}
            {hasStore && !followers.length ? (
              <EmptyState
                title="No followers yet"
                body="Share your store and go live — followers will show up here."
                actionHref={user?.sellerId ? `/seller` : "/seller"}
                actionLabel="Go live tools"
              />
            ) : null}
            {followers.map((follower) => (
              <div
                key={follower.id}
                className="flex items-center gap-3 rounded-2xl border border-hubsom-forest/10 bg-white/80 p-3"
              >
                <div className="relative h-12 w-12 shrink-0 overflow-hidden rounded-2xl bg-hubsom-mist ring-1 ring-hubsom-forest/10">
                  {follower.image ? (
                    <Image
                      src={follower.image}
                      alt={follower.name}
                      fill
                      sizes="48px"
                      className="object-cover"
                    />
                  ) : (
                    <span className="flex h-full w-full items-center justify-center font-display text-sm font-bold text-hubsom-forest">
                      {follower.name
                        .split(" ")
                        .map((p) => p[0])
                        .join("")
                        .slice(0, 2)
                        .toUpperCase()}
                    </span>
                  )}
                </div>
                <div className="min-w-0 flex-1">
                  <p className="truncate font-display text-base font-bold text-hubsom-forest">
                    {follower.name}
                  </p>
                  <p className="truncate text-xs text-hubsom-ink/55">
                    {[follower.city, follower.region].filter(Boolean).join(", ") ||
                      "Hubsom member"}
                  </p>
                </div>
                <span className="shrink-0 rounded-lg bg-hubsom-mist px-2 py-1 text-[10px] font-bold uppercase tracking-wide text-hubsom-forest">
                  {follower.role === "buyer" ? "Buyer" : "Seller"}
                </span>
              </div>
            ))}
          </>
        )}
      </div>
    </div>
  );
}
