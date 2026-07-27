import type { Metadata } from "next";
import Link from "next/link";
import { BarChart3, Package, PackagePlus, Pencil, Radio, Store, Users } from "lucide-react";
import { auth } from "@/auth";
import { getFollowCounts } from "@/lib/data/follows";
import { getProductsBySeller } from "@/lib/data/products";
import { ensureSellerForUser, getSeller } from "@/lib/data/sellers";
import { getStreamsBySeller } from "@/lib/data/streams";
import { getUserById, updateUserProfile } from "@/lib/data/users";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Seller hub",
  description: "Go live, manage inventory, and track Hubsom commerce analytics.",
};

export default async function SellerHubPage() {
  const session = await auth();
  const user = session?.user?.id ? await getUserById(session.user.id) : null;
  const seller = user
    ? await ensureSellerForUser({
        userId: user.id,
        name: user.name,
        city: user.city,
        region: user.region,
        bio: user.bio,
        avatar: user.image,
      })
    : null;

  if (user && seller && user.sellerId !== seller.id) {
    await updateUserProfile(user.id, {
      sellerId: seller.id,
      role: user.role === "buyer" ? "both" : user.role,
    });
  }

  const [products, streams, counts] = await Promise.all([
    seller ? getProductsBySeller(seller.id) : Promise.resolve([]),
    seller ? getStreamsBySeller(seller.id) : Promise.resolve([]),
    user
      ? getFollowCounts(user.id)
      : Promise.resolve({ followingCount: 0, followersCount: 0 }),
  ]);

  const store = seller ? await getSeller(seller.id) : null;

  return (
    <div className="mx-auto max-w-5xl px-4 py-12 sm:px-6">
      <h1 className="font-display text-4xl font-extrabold text-hubsom-forest">
        Seller hub
      </h1>
      <p className="mt-3 max-w-2xl text-hubsom-ink/70">
        Signed in as {user?.name}. Store:{" "}
        {store ? (
          <Link
            href={`/stores/${store.slug}`}
            className="font-semibold text-hubsom-cyan"
          >
            {store.name}
          </Link>
        ) : (
          "—"
        )}
      </p>

      <div className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div className="rounded-2xl border border-hubsom-forest/10 bg-white/70 p-4">
          <p className="text-[10px] font-bold uppercase text-hubsom-ink/45">
            Products
          </p>
          <p className="mt-1 font-display text-2xl font-bold">{products.length}</p>
        </div>
        <div className="rounded-2xl border border-hubsom-forest/10 bg-white/70 p-4">
          <p className="text-[10px] font-bold uppercase text-hubsom-ink/45">
            Shows
          </p>
          <p className="mt-1 font-display text-2xl font-bold">{streams.length}</p>
        </div>
        <Link
          href="/account/following?tab=followers"
          className="rounded-2xl border border-hubsom-forest/10 bg-white/70 p-4 transition hover:border-hubsom-cyan"
        >
          <p className="text-[10px] font-bold uppercase text-hubsom-ink/45">
            Followers
          </p>
          <p className="mt-1 font-display text-2xl font-bold">
            {counts.followersCount}
          </p>
        </Link>
        <Link
          href="/account/following?tab=following"
          className="rounded-2xl border border-hubsom-forest/10 bg-white/70 p-4 transition hover:border-hubsom-cyan"
        >
          <p className="text-[10px] font-bold uppercase text-hubsom-ink/45">
            Following
          </p>
          <p className="mt-1 font-display text-2xl font-bold">
            {counts.followingCount}
          </p>
        </Link>
      </div>

      <div className="mt-10 grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Link
          href="/seller/store"
          className="rounded-3xl border border-hubsom-forest/10 bg-white/70 p-6 transition hover:border-hubsom-leaf"
        >
          <Pencil className="h-6 w-6 text-hubsom-forest" />
          <h2 className="mt-4 font-display text-2xl font-bold text-hubsom-forest">
            Edit storefront
          </h2>
          <p className="mt-2 text-sm text-hubsom-ink/65">
            Change store name, profile photo, and cover image.
          </p>
        </Link>
        <Link
          href="/seller/orders"
          className="rounded-3xl border border-hubsom-forest/10 bg-white/70 p-6 transition hover:border-hubsom-leaf"
        >
          <Package className="h-6 w-6 text-hubsom-orange" />
          <h2 className="mt-4 font-display text-2xl font-bold text-hubsom-forest">
            Orders
          </h2>
          <p className="mt-2 text-sm text-hubsom-ink/65">
            See purchases, product lines, and buyer shipping details.
          </p>
        </Link>
        <Link
          href="/seller/go-live"
          className="rounded-3xl border border-hubsom-forest/10 bg-white/70 p-6 transition hover:border-hubsom-leaf"
        >
          <Radio className="h-6 w-6 text-hubsom-live" />
          <h2 className="mt-4 font-display text-2xl font-bold text-hubsom-forest">
            Go live
          </h2>
          <p className="mt-2 text-sm text-hubsom-ink/65">
            Launch Agora live commerce with pinning and checkout.
          </p>
        </Link>
        <Link
          href="/seller/products/new"
          className="rounded-3xl border border-hubsom-forest/10 bg-white/70 p-6 transition hover:border-hubsom-leaf"
        >
          <PackagePlus className="h-6 w-6 text-hubsom-gold" />
          <h2 className="mt-4 font-display text-2xl font-bold text-hubsom-forest">
            Add product
          </h2>
          <p className="mt-2 text-sm text-hubsom-ink/65">
            Publish catalog items for Buy Now and live shows.
          </p>
        </Link>
        <Link
          href="/seller/analytics"
          className="rounded-3xl border border-hubsom-forest/10 bg-white/70 p-6 transition hover:border-hubsom-leaf"
        >
          <BarChart3 className="h-6 w-6 text-hubsom-leaf" />
          <h2 className="mt-4 font-display text-2xl font-bold text-hubsom-forest">
            Analytics
          </h2>
          <p className="mt-2 text-sm text-hubsom-ink/65">
            Revenue, conversion, latency, and inventory sync.
          </p>
        </Link>
        <Link
          href="/account/following?tab=followers"
          className="rounded-3xl border border-hubsom-forest/10 bg-white/70 p-6 transition hover:border-hubsom-leaf"
        >
          <Users className="h-6 w-6 text-hubsom-cyan" />
          <h2 className="mt-4 font-display text-2xl font-bold text-hubsom-forest">
            Connections
          </h2>
          <p className="mt-2 text-sm text-hubsom-ink/65">
            See your followers and stores you follow.
          </p>
        </Link>
        <Link
          href={store ? `/stores/${store.slug}` : "/seller/store"}
          className="rounded-3xl border border-hubsom-forest/10 bg-white/70 p-6 transition hover:border-hubsom-leaf md:col-span-2 lg:col-span-3"
        >
          <Store className="h-6 w-6 text-hubsom-forest" />
          <h2 className="mt-4 font-display text-2xl font-bold text-hubsom-forest">
            View storefront
          </h2>
          <p className="mt-2 text-sm text-hubsom-ink/65">
            Preview your public store with live + Buy Now inventory.
          </p>
        </Link>
      </div>
    </div>
  );
}
