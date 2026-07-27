import type { Metadata } from "next";
import Link from "next/link";
import { EmptyState } from "@/components/ui/EmptyState";
import { getSeller } from "@/lib/data/sellers";
import { listAllStreams } from "@/lib/data/stream-registry";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Live shows",
};

export default async function LiveIndexPage() {
  const streams = await listAllStreams();

  return (
    <div className="mx-auto max-w-lg px-4 pb-8 pt-5">
      <div className="flex items-end justify-between gap-3">
        <div>
          <h1 className="font-display text-3xl font-extrabold text-hubsom-forest">
            Live
          </h1>
          <p className="mt-2 text-sm text-hubsom-ink/65">
            Watch sellers pin, auction, and checkout in real time.
          </p>
        </div>
        <Link
          href="/seller/go-live"
          className="rounded-xl bg-hubsom-live px-3 py-2 text-xs font-bold text-white"
        >
          Go live
        </Link>
      </div>

      <div className="mt-5 space-y-3">
        {!streams.length && (
          <EmptyState
            title="No shows yet"
            body="Start the first Hubsom live commerce show."
            actionHref="/seller/go-live"
            actionLabel="Start a show"
          />
        )}
        {await Promise.all(
          streams.map(async (stream) => {
            const seller = await getSeller(stream.sellerId);
            return (
              <Link
                key={stream.id}
                href={`/live/${stream.id}`}
                className="block rounded-2xl border border-hubsom-forest/10 bg-white/80 p-4"
              >
                <div className="flex items-center justify-between gap-2">
                  <p className="font-display text-lg font-bold text-hubsom-ink">
                    {stream.title}
                  </p>
                  <span className="rounded-md bg-hubsom-live px-2 py-1 text-[10px] font-bold uppercase text-white">
                    {stream.status}
                  </span>
                </div>
                <p className="mt-1 text-xs text-hubsom-ink/55">
                  {seller?.name ?? "Seller"} · {stream.viewerCount.toLocaleString()}{" "}
                  viewers
                </p>
                <p className="mt-2 line-clamp-2 text-sm text-hubsom-ink/70">
                  {stream.description}
                </p>
              </Link>
            );
          }),
        )}
      </div>
    </div>
  );
}
