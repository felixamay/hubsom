import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { LiveRoom } from "@/components/live/LiveRoom";
import { getProduct } from "@/lib/data/products";
import { getSeller } from "@/lib/data/sellers";
import { getStreamById } from "@/lib/data/stream-registry";
import { SEED_CHAT } from "@/lib/data/streams";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  const { id } = await params;
  const stream = getStreamById(id);
  return {
    title: stream?.title ?? "Live show",
    description: stream?.description,
  };
}

export default async function LiveShowPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ host?: string }>;
}) {
  const { id } = await params;
  const { host } = await searchParams;
  const stream = getStreamById(id);
  if (!stream) notFound();

  const seller = getSeller(stream.sellerId);
  const products = stream.productIds
    .map((pid) => getProduct(pid))
    .filter((p): p is NonNullable<typeof p> => Boolean(p));
  const chat = SEED_CHAT.filter((m) => m.streamId === stream.id);

  return (
    <LiveRoom
      stream={stream}
      seller={seller}
      products={products}
      initialChat={chat}
      hostMode={host === "1"}
    />
  );
}
