import type { Metadata } from "next";
import { CategoriesBrowse } from "@/components/categories/CategoriesBrowse";
import { getSeller } from "@/lib/data/sellers";
import { listAllStreams } from "@/lib/data/stream-registry";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Categories",
  description:
    "Browse every Hubsom product category — Buy Now, live, auction, flash.",
};

export default async function CategoriesPage() {
  const streams = await listAllStreams();
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

  return <CategoriesBrowse liveNow={liveNow} />;
}
