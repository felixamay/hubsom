import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { Package, Truck } from "lucide-react";
import { requireUser } from "@/lib/auth/session";
import { formatGhs } from "@/lib/currency";
import { listOrdersBySeller } from "@/lib/data/orders";
import { ensureSellerForUser } from "@/lib/data/sellers";
import { getUserById, updateUserProfile } from "@/lib/data/users";
import { EmptyState } from "@/components/ui/EmptyState";
import { SellerOrderActions } from "@/components/seller/SellerOrderActions";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Orders",
  description: "Incoming Hubsom orders with shipping details.",
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

  const orders = await listOrdersBySeller(seller.id);

  return (
    <div className="mx-auto max-w-3xl px-4 py-10 sm:px-6">
      <div className="flex items-end justify-between gap-3">
        <div>
          <p className="text-xs font-bold uppercase tracking-[0.16em] text-hubsom-ink/45">
            Seller hub
          </p>
          <h1 className="mt-1 font-display text-4xl font-extrabold text-hubsom-forest">
            Orders
          </h1>
          <p className="mt-2 text-sm text-hubsom-ink/65">
            Product details and buyer shipping for every purchase of your items.
          </p>
        </div>
        <Link
          href="/seller"
          className="rounded-xl border border-hubsom-forest/12 px-3 py-2 text-xs font-bold text-hubsom-forest"
        >
          Hub
        </Link>
      </div>

      <div className="mt-8 space-y-4">
        {!orders.length ? (
          <EmptyState
            title="No orders yet"
            body="When buyers purchase your products, shipping and line items show up here — and in Messages."
            actionHref="/seller/go-live"
            actionLabel="Go live"
          />
        ) : null}

        {orders.map((order) => {
          const myLines = order.lines.filter((l) => l.sellerId === seller.id);
          const myTotal = myLines.reduce((sum, l) => sum + l.lineTotalGhs, 0);
          return (
            <article
              key={order.id}
              className="overflow-hidden rounded-3xl border border-hubsom-forest/10 bg-white/80"
            >
              <div className="flex flex-wrap items-start justify-between gap-3 border-b border-hubsom-forest/8 px-4 py-3">
                <div>
                  <p className="font-display text-lg font-bold text-hubsom-forest">
                    {order.id}
                  </p>
                  <p className="text-xs text-hubsom-ink/55">
                    {new Date(order.createdAt).toLocaleString()} ·{" "}
                    {order.status.replace("_", " ")}
                    {order.oneTap ? " · live checkout" : ""}
                  </p>
                </div>
                <p className="font-display text-xl font-bold text-hubsom-ink">
                  {formatGhs(myTotal)}
                </p>
              </div>

              <div className="space-y-3 px-4 py-4">
                <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wide text-hubsom-ink/45">
                  <Package className="h-3.5 w-3.5" />
                  Products
                </div>
                {myLines.map((line) => (
                  <div
                    key={`${order.id}-${line.productId}`}
                    className="flex items-center gap-3 rounded-2xl bg-hubsom-mist/70 p-2.5"
                  >
                    <div className="relative h-14 w-14 shrink-0 overflow-hidden rounded-xl bg-white">
                      {line.image ? (
                        <Image
                          src={line.image}
                          alt=""
                          fill
                          sizes="56px"
                          className="object-cover"
                        />
                      ) : (
                        <span className="flex h-full items-center justify-center text-[10px] font-bold text-hubsom-forest/40">
                          Item
                        </span>
                      )}
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-bold text-hubsom-ink">
                        {line.name}
                      </p>
                      <p className="text-xs text-hubsom-ink/55">
                        Qty {line.quantity} · {line.category} ·{" "}
                        {formatGhs(line.unitPriceGhs)} each
                      </p>
                    </div>
                    <p className="shrink-0 text-sm font-bold text-hubsom-forest">
                      {formatGhs(line.lineTotalGhs)}
                    </p>
                  </div>
                ))}

                <div className="rounded-2xl border border-dashed border-hubsom-forest/15 bg-hubsom-mist/40 p-3.5">
                  <div className="mb-2 flex items-center gap-2 text-xs font-bold uppercase tracking-wide text-hubsom-ink/45">
                    <Truck className="h-3.5 w-3.5" />
                    Ship to
                  </div>
                  {order.shipping ? (
                    <div className="space-y-0.5 text-sm text-hubsom-ink/80">
                      <p className="font-semibold text-hubsom-ink">
                        {order.shipping.recipientName}
                      </p>
                      <p>{order.shipping.phone}</p>
                      <p>{order.shipping.line1}</p>
                      {order.shipping.line2 ? (
                        <p>{order.shipping.line2}</p>
                      ) : null}
                      <p>
                        {order.shipping.city}, {order.shipping.region}
                      </p>
                      {order.shipping.notes ? (
                        <p className="pt-1 text-xs text-hubsom-ink/55">
                          Note: {order.shipping.notes}
                        </p>
                      ) : null}
                    </div>
                  ) : (
                    <p className="text-sm text-hubsom-ink/55">
                      No shipping on this older order.
                    </p>
                  )}
                  {(order.buyerName || order.buyerEmail) && (
                    <p className="mt-2 text-xs text-hubsom-ink/50">
                      Buyer account: {order.buyerName}
                      {order.buyerEmail ? ` · ${order.buyerEmail}` : ""}
                    </p>
                  )}
                </div>

                <SellerOrderActions
                  orderId={order.id}
                  status={order.status}
                  buyerUserId={order.userId}
                />
              </div>
            </article>
          );
        })}
      </div>
    </div>
  );
}
