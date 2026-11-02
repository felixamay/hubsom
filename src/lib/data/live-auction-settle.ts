import { createOrder, getOrder } from "./orders";
import { adjustProductStock, getProduct } from "./products";
import { auctionHasWinner } from "../live-auction-bid";
import type { LiveAuction, LiveStream, ProductCategory } from "../../types";

export function auctionWinnerOrderId(auctionId: string): string {
  return `ord_auc_${auctionId}`;
}

/**
 * Convert a finished winning lot into a paid seller order once.
 * Empty lots close as unsold. Already-settled lots are left alone.
 */
export async function settleLiveAuction(
  stream: LiveStream,
): Promise<LiveAuction | undefined> {
  const auction = stream.auction;
  if (!auction) return auction;
  if (auction.orderId) {
    return { ...auction, status: "sold" };
  }
  if (auction.status === "sold" || auction.status === "unsold") {
    return auction;
  }
  if (!auctionHasWinner(auction)) {
    return { ...auction, status: "unsold" };
  }

  const orderId = auctionWinnerOrderId(auction.id);
  const existing = await getOrder(orderId);
  const product = await getProduct(auction.productId);
  const price = auction.currentBidGhs;

  if (!existing) {
    await createOrder({
      id: orderId,
      currency: "GHS",
      subtotalGhs: price,
      status: "paid",
      userId: auction.highestBidderId,
      buyerName: auction.highestBidder,
      buyerEmail: auction.highestBidderEmail,
      streamId: stream.id,
      lines: [
        {
          productId: auction.productId,
          sellerId: stream.sellerId,
          name: product?.name ?? "Live auction win",
          image: product?.images[0],
          quantity: 1,
          unitPriceGhs: price,
          lineTotalGhs: price,
          category: (product?.category ?? "miscellaneous") as ProductCategory,
        },
      ],
      shipping: {
        recipientName: auction.highestBidder ?? "Winner",
        phone: "",
        line1: "Live auction win — confirm delivery with buyer",
        city: "Accra",
        region: "Greater Accra",
        notes: `Won on Hubsom live auction ${auction.id}`,
        label: "Live auction",
      },
      paymentMethods: ["live-auction"],
      deliveryEstimate: "Arrange with buyer",
    });
    if (product && product.stock > 0) {
      await adjustProductStock(product.id, -1);
    }
  }

  return { ...auction, status: "sold", orderId };
}
