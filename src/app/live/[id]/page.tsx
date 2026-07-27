import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { LiveRoom } from "@/components/live/LiveRoom";
import { listChatMessages } from "@/lib/data/chat";
import { getProduct } from "@/lib/data/products";
import { getSeller } from "@/lib/data/sellers";
import { getStreamById } from "@/lib/data/stream-registry";

export const dynamic = "force-dynamic";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  const { id } = await params;
  const stream = await getStreamById(id);
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
  const stream = await getStreamById(id);
  if (!stream) notFound();

  const seller = await getSeller(stream.sellerId);
  const products = (
    await Promise.all(stream.productIds.map((pid) => getProduct(pid)))
  ).filter((p): p is NonNullable<typeof p> => Boolean(p));
  const chat = await listChatMessages(stream.id);

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
