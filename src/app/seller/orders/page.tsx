import type { Metadata } from "next";
import Link from "next/link";
import { requireUser } from "@/lib/auth/session";
import { listOrdersBySeller } from "@/lib/data/orders";
import {
  listActiveShippedOrderIds,
  listShipmentsBySeller,
} from "@/lib/data/shipments";
import { ensureSellerForUser } from "@/lib/data/sellers";
import { getUserById, updateUserProfile } from "@/lib/data/users";
import { EmptyState } from "@/components/ui/EmptyState";
import { SellerOrdersBoard } from "@/components/seller/SellerOrdersBoard";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Orders",
  description: "Consolidate purchases and dispatch with Hubers.",
};

export default async function SellerOrdersPage() {
  const session = await requireUser("/seller/orders");
  const user = await getUserById(session.user.id);
  if (!user) {
    return (
      <div className="mx-auto max-w-3xl px-4 py-12">
        <EmptyState
          title="Account required"
          body="Sign in again to view seller orders."
          actionHref="/auth/sign-in"
          actionLabel="Sign in"
        />
      </div>
    );
  }

  const seller = await ensureSellerForUser({
    userId: user.id,
    name: user.name,
    city: user.city,
    region: user.region,
    bio: user.bio,
    avatar: user.image,
  });

  if (user.sellerId !== seller.id) {
    await updateUserProfile(user.id, {
      sellerId: seller.id,
      role: user.role === "buyer" ? "both" : user.role,
    });
  }

  const [orders, shipments, shippedIds] = await Promise.all([
    listOrdersBySeller(seller.id),
    listShipmentsBySeller(seller.id),
    listActiveShippedOrderIds(seller.id),
  ]);

  return (
    <div className="mx-auto max-w-3xl px-4 py-10 sm:px-6">
      <div className="flex items-end justify-between gap-3">
        <div>
          <p className="text-xs font-bold uppercase tracking-[0.16em] text-hubsom-ink/45">
            Seller hub
          </p>
          <h1 className="mt-1 font-display text-4xl font-extrabold text-hubsom-forest">
            Orders & shipments
          </h1>
          <p className="mt-2 text-sm text-hubsom-ink/65">
            Consolidate purchases, pin buyer location, Locate on maps, then
            send offers to approved Hubers riders.
          </p>
        </div>
        <Link
          href="/seller"
          className="rounded-xl border border-hubsom-forest/12 px-3 py-2 text-xs font-bold text-hubsom-forest"
        >
          Hub
        </Link>
      </div>

      <div className="mt-8">
        {!orders.length && !shipments.length ? (
          <EmptyState
            title="No orders yet"
            body="When buyers purchase your products, consolidate them into shipments and dispatch with Hubers."
            actionHref="/seller/go-live"
            actionLabel="Go live"
          />
        ) : (
          <SellerOrdersBoard
            sellerId={seller.id}
            orders={orders}
            initialShipments={shipments}
            shippedOrderIds={Array.from(shippedIds)}
          />
        )}
      </div>
    </div>
  );
}
