"use client";

import Image from "next/image";
import Link from "next/link";
import { useCallback, useMemo, useState } from "react";
import {
  ArrowLeft,
  Heart,
  MessageCircleHeart,
  PictureInPicture2,
  Shield,
  ShoppingBag,
  Volume2,
  VolumeX,
} from "lucide-react";
import { AgoraPlayer } from "@/components/live/AgoraPlayer";
import { AuctionPanel } from "@/components/live/AuctionPanel";
import { FloatingReactions } from "@/components/live/FloatingReactions";
import { HostControls } from "@/components/live/HostControls";
import { LiveCartDrawer } from "@/components/live/LiveCartDrawer";
import { LiveChat } from "@/components/live/LiveChat";
import { ModeratorPanel } from "@/components/live/ModeratorPanel";
import { PinnedProduct } from "@/components/live/PinnedProduct";
import { ProductCarousel } from "@/components/live/ProductCarousel";
import { useCartStore } from "@/lib/stores/cart";
import { useLiveStore } from "@/lib/stores/live";
import type { ChatMessage, LiveStream, Product, Seller } from "@/types";

function reactionX() {
  // Deterministic-enough spread for floating reactions without impure render paths.
  return 0.55 + ((Date.now() % 350) / 1000);
}

export function LiveRoom({
  stream,
  seller,
  products,
  initialChat,
  hostMode = false,
}: {
  stream: LiveStream;
  seller?: Seller;
  products: Product[];
  initialChat: ChatMessage[];
  hostMode?: boolean;
}) {
  const [pinnedId, setPinnedId] = useState(stream.pinnedProductId);
  const [latencyMs, setLatencyMs] = useState(stream.latencyMs || 1000);
  const [micOn, setMicOn] = useState(true);
  const [camOn, setCamOn] = useState(true);
  const [recording, setRecording] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);

  const muted = useLiveStore((s) => s.muted);
  const setMuted = useLiveStore((s) => s.setMuted);
  const pipEnabled = useLiveStore((s) => s.pipEnabled);
  const togglePip = useLiveStore((s) => s.togglePip);
  const cartOpen = useLiveStore((s) => s.cartOpen);
  const setCartOpen = useLiveStore((s) => s.setCartOpen);
  const moderatorOpen = useLiveStore((s) => s.moderatorOpen);
  const setModeratorOpen = useLiveStore((s) => s.setModeratorOpen);
  const addReaction = useLiveStore((s) => s.addReaction);
  const addItem = useCartStore((s) => s.addItem);
  const cartCount = useCartStore((s) =>
    s.items.reduce((n, i) => n + i.quantity, 0),
  );

  const pinned = useMemo(
    () => products.find((p) => p.id === pinnedId),
    [products, pinnedId],
  );
  const auctionProduct = products.find((p) => p.id === stream.auction?.productId);

  const onLatencySample = useCallback((ms: number) => setLatencyMs(ms), []);

  async function react(emoji: string) {
    const x = reactionX();
    addReaction({ streamId: stream.id, emoji, x });
    await fetch(`/api/streams/${stream.id}/reactions`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ emoji, x }),
    });
  }

  function buy(product: Product) {
    addItem({
      productId: product.id,
      quantity: 1,
      source: "live",
      streamId: stream.id,
    });
    setCartOpen(true);
    setNotice(`${product.name} added — checkout while watching`);
  }

  return (
    <div className="relative min-h-[100svh] bg-hubsom-night text-white">
      <div
        className={`relative ${
          pipEnabled
            ? "fixed bottom-4 right-4 z-[60] h-44 w-72 overflow-hidden rounded-2xl border border-white/20 shadow-2xl sm:h-52 sm:w-80"
            : "h-[56svh] sm:h-[100svh]"
        }`}
      >
        <AgoraPlayer
          channelName={stream.channelName}
          role={hostMode ? "publisher" : "subscriber"}
          muted={muted}
          className="h-full w-full"
          onLatencySample={onLatencySample}
        />
        {!pipEnabled && <FloatingReactions />}

        {!pipEnabled && (
          <>
            <div className="absolute left-0 right-0 top-0 z-10 flex items-start justify-between gap-3 bg-gradient-to-b from-black/70 to-transparent p-4">
              <div className="flex items-center gap-3">
                <Link
                  href="/live"
                  className="inline-flex h-9 w-9 items-center justify-center rounded-full bg-black/40"
                >
                  <ArrowLeft className="h-4 w-4" />
                </Link>
                <div className="flex items-center gap-2">
                  {seller && (
                    <Image
                      src={seller.avatar}
                      alt={seller.name}
                      width={36}
                      height={36}
                      className="rounded-full object-cover"
                    />
                  )}
                  <div>
                    <p className="text-sm font-semibold">{stream.title}</p>
                    <p className="text-xs text-white/70">
                      {seller?.name} · {stream.viewerCount.toLocaleString()} watching
                    </p>
                  </div>
                </div>
              </div>
              <div className="flex flex-wrap items-center justify-end gap-2">
                <span className="animate-pulse-live rounded-md bg-hubsom-live px-2 py-1 text-[11px] font-bold uppercase tracking-wide">
                  {stream.status === "replay" ? "Replay" : "Live"}
                </span>
                <span className="rounded-md bg-black/45 px-2 py-1 text-[11px] font-semibold text-hubsom-mint">
                  {latencyMs}ms
                </span>
              </div>
            </div>

            <div className="absolute bottom-0 left-0 right-0 z-10 space-y-3 bg-gradient-to-t from-black/85 via-black/45 to-transparent p-4 pb-5">
              {pinned && (
                <PinnedProduct product={pinned} onBuy={() => buy(pinned)} />
              )}
              <ProductCarousel
                products={products}
                pinnedProductId={pinnedId}
                onPin={setPinnedId}
                onBuy={buy}
              />
            </div>
          </>
        )}
      </div>

      {!pipEnabled && (
        <div className="relative z-20 mx-auto grid max-w-7xl gap-4 px-3 pb-8 pt-4 lg:grid-cols-[1.1fr_0.9fr] lg:-mt-[38vh] lg:px-6">
          <div className="space-y-4 lg:pt-[38vh]">
            <div className="flex flex-wrap gap-2">
              {stream.categories.map((c) => (
                <Link
                  key={c}
                  href={`/categories/${c}`}
                  className="rounded-lg border border-white/15 bg-white/5 px-2.5 py-1 text-xs capitalize text-white/80 hover:bg-white/10"
                >
                  {c.replace(/-/g, " ")}
                </Link>
              ))}
            </div>
            <p className="max-w-2xl text-sm leading-relaxed text-white/75">
              {stream.description}
            </p>
            <div className="flex flex-wrap gap-2">
              {(["❤️", "🔥", "😂", "👏", "🇬🇭"] as const).map((emoji) => (
                <button
                  key={emoji}
                  type="button"
                  onClick={() => react(emoji)}
                  className="rounded-xl bg-white/10 px-3 py-2 text-lg hover:bg-white/20"
                >
                  {emoji}
                </button>
              ))}
              <button
                type="button"
                onClick={() => react("❤️")}
                className="inline-flex items-center gap-1 rounded-xl bg-hubsom-live px-3 py-2 text-xs font-bold"
              >
                <Heart className="h-3.5 w-3.5 fill-current" />
                React
              </button>
            </div>

            {stream.auction && (
              <AuctionPanel auction={stream.auction} product={auctionProduct} />
            )}

            {(hostMode || stream.isMultiHost) && (
              <HostControls
                publishing={recording}
                micOn={micOn}
                camOn={camOn}
                onToggleMic={() => setMicOn((v) => !v)}
                onToggleCam={() => setCamOn((v) => !v)}
                onInviteGuest={() =>
                  setNotice("Guest seller invite sent — multi-host slot opened")
                }
                onStartRecording={() => {
                  setRecording(true);
                  setNotice("Cloud recording started · replay will be available");
                }}
              />
            )}

            {notice && (
              <p className="rounded-xl border border-hubsom-gold/30 bg-hubsom-gold/10 px-3 py-2 text-sm text-hubsom-sun">
                {notice}
              </p>
            )}
          </div>

          <div className="flex min-h-[420px] flex-col gap-3 lg:pt-[38vh]">
            <div className="flex flex-wrap gap-2">
              <button
                type="button"
                onClick={() => setMuted(!muted)}
                className="inline-flex items-center gap-1 rounded-xl bg-white/10 px-3 py-2 text-xs font-semibold"
              >
                {muted ? <VolumeX className="h-3.5 w-3.5" /> : <Volume2 className="h-3.5 w-3.5" />}
                {muted ? "Unmute" : "Mute"}
              </button>
              <button
                type="button"
                onClick={togglePip}
                className="inline-flex items-center gap-1 rounded-xl bg-white/10 px-3 py-2 text-xs font-semibold"
              >
                <PictureInPicture2 className="h-3.5 w-3.5" />
                PiP
              </button>
              <button
                type="button"
                onClick={() => setModeratorOpen(true)}
                className="inline-flex items-center gap-1 rounded-xl bg-white/10 px-3 py-2 text-xs font-semibold"
              >
                <Shield className="h-3.5 w-3.5" />
                Mods
              </button>
              <button
                type="button"
                onClick={() => setCartOpen(true)}
                className="inline-flex items-center gap-1 rounded-xl bg-hubsom-gold px-3 py-2 text-xs font-bold text-hubsom-ink"
              >
                <ShoppingBag className="h-3.5 w-3.5" />
                Cart {cartCount > 0 ? `(${cartCount})` : ""}
              </button>
            </div>

            <div className="min-h-0 flex-1">
              <LiveChat streamId={stream.id} initialMessages={initialChat} />
            </div>

            {moderatorOpen && (
              <ModeratorPanel
                hosts={stream.hosts}
                onClose={() => setModeratorOpen(false)}
              />
            )}

            <div className="rounded-2xl border border-white/10 bg-white/5 p-3 text-xs text-white/65">
              <p className="inline-flex items-center gap-1 font-semibold text-white/85">
                <MessageCircleHeart className="h-3.5 w-3.5 text-hubsom-gold" />
                Stream stack
              </p>
              <p className="mt-1">
                Agora RTC · adaptive bitrate · HD/FHD · AI chat moderation · realtime
                inventory sync · push-ready analytics hooks · auto-scale ready for
                10k+ viewers.
              </p>
            </div>
          </div>
        </div>
      )}

      {pipEnabled && (
        <div className="mx-auto max-w-3xl px-4 py-16 text-center">
          <p className="font-display text-3xl font-bold">Picture-in-picture on</p>
          <p className="mt-2 text-white/70">
            Keep shopping the marketplace while the show floats.
          </p>
          <div className="mt-6 flex justify-center gap-3">
            <button
              type="button"
              onClick={togglePip}
              className="rounded-xl bg-hubsom-gold px-4 py-2 text-sm font-bold text-hubsom-ink"
            >
              Expand show
            </button>
            <Link
              href="/marketplace"
              className="rounded-xl border border-white/20 px-4 py-2 text-sm font-semibold"
            >
              Open marketplace
            </Link>
          </div>
        </div>
      )}

      <LiveCartDrawer
        streamId={stream.id}
        open={cartOpen}
        onClose={() => setCartOpen(false)}
      />
    </div>
  );
}
