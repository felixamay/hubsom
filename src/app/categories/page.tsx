import type { Metadata } from "next";
import { CategoriesBrowse } from "@/components/categories/CategoriesBrowse";
import { PromoSpace } from "@/components/promotions/PromoSpace";
import { getSeller } from "@/lib/data/sellers";
import { listAllStreams } from "@/lib/data/stream-registry";
import { listPromotions } from "@/lib/data/promotions";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Categories",
  description:
    "Browse every Hubsom product category — Buy Now, live, auction, flash.",
};

export default async function CategoriesPage() {
  const [streams, promotions] = await Promise.all([
    listAllStreams(),
    listPromotions({ placement: "category", limit: 4 }),
  ]);
  const live = streams.filter((s) => s.status === "live");

  const liveNow = await Promise.all(
    live.slice(0, 16).map(async (stream) => {
      const seller = await getSeller(stream.sellerId);
      return {
        id: stream.id,
        title: stream.title,
        cover: stream.cover,
        viewerCount: stream.viewerCount,
        sellerName: seller?.name ?? "Hubsom seller",
        categories: stream.categories,
      };
    }),
  );

  return (
    <div>
      <div className="mx-auto max-w-lg px-4 pt-5">
        <PromoSpace
          promotions={promotions}
          title="Category promotions"
          subtitle="Deals across Hubsom categories."
          compact
        />
      </div>
      <CategoriesBrowse liveNow={liveNow} />
    </div>
  );
}
