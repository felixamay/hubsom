"use client";

import Image from "next/image";
import Link from "next/link";
import { useCallback, useMemo, useRef, useState } from "react";
import {
  ArrowLeft,
  Bell,
  Heart,
  MessageCircle,
  Mic,
  MicOff,
  MoreHorizontal,
  Package,
  PictureInPicture2,
  Shield,
  ShoppingBag,
  Video,
  VideoOff,
  Volume2,
  VolumeX,
} from "lucide-react";
import {
  AgoraPlayer,
  type AgoraPlayerHandle,
  type LiveConnectionState,
} from "@/components/live/AgoraPlayer";
import { AuctionPanel } from "@/components/live/AuctionPanel";
import { FloatingReactions } from "@/components/live/FloatingReactions";
import { LiveCartDrawer } from "@/components/live/LiveCartDrawer";
import { LiveChat } from "@/components/live/LiveChat";
import { ModeratorPanel } from "@/components/live/ModeratorPanel";
import { PinnedProduct } from "@/components/live/PinnedProduct";
import { ProductCarousel } from "@/components/live/ProductCarousel";
import { useCartStore } from "@/lib/stores/cart";
import { useLiveStore } from "@/lib/stores/live";
import type { ChatMessage, LiveStream, Product, Seller } from "@/types";

function reactionX() {
  return 0.62 + ((Date.now() % 280) / 1000);
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
  const playerRef = useRef<AgoraPlayerHandle>(null);
  const [pinnedId, setPinnedId] = useState(stream.pinnedProductId);
  const [latencyMs, setLatencyMs] = useState(stream.latencyMs || 1000);
  const [micOn, setMicOn] = useState(true);
  const [camOn, setCamOn] = useState(true);
  const [recording, setRecording] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [connState, setConnState] = useState<LiveConnectionState>("idle");
  const [shopOpen, setShopOpen] = useState(false);
  const [chatOpen, setChatOpen] = useState(false);
  const [hostTrayOpen, setHostTrayOpen] = useState(false);
  const [auctionOpen, setAuctionOpen] = useState(false);

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
    () => products.find((p) => p.id === pinnedId) ?? products[0],
    [products, pinnedId],
  );
  const auctionProduct = products.find((p) => p.id === stream.auction?.productId);

  const onLatencySample = useCallback((ms: number) => setLatencyMs(ms), []);

  async function react(emoji = "❤️") {
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
    setShopOpen(false);
    setNotice(null);
  }

  async function pinProduct(productId: string) {
    setPinnedId(productId);
    await fetch(`/api/streams/${stream.id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ pinnedProductId: productId }),
    });
  }

  async function toggleMic() {
    const next = !micOn;
    setMicOn(next);
    await playerRef.current?.setMicEnabled(next);
  }

  async function toggleCam() {
    const next = !camOn;
    setCamOn(next);
    await playerRef.current?.setCamEnabled(next);
  }

  async function startRecording() {
    setRecording(true);
    await fetch(`/api/streams/${stream.id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ recording: true }),
    });
  }

  if (pipEnabled) {
    return (
      <div className="min-h-[100svh] bg-hubsom-night px-4 py-16 text-center text-white">
        <div className="fixed bottom-4 right-4 z-[60] h-44 w-72 overflow-hidden rounded-2xl border border-white/20 shadow-2xl">
          <AgoraPlayer
            ref={playerRef}
            channelName={stream.channelName}
            role={hostMode ? "publisher" : "subscriber"}
            muted={muted}
            className="h-full w-full"
            onLatencySample={onLatencySample}
            onStateChange={setConnState}
          />
        </div>
        <p className="font-display text-2xl font-bold">Picture-in-picture on</p>
        <button
          type="button"
          onClick={togglePip}
          className="mt-5 rounded-xl bg-hubsom-gold px-4 py-2 text-sm font-bold text-hubsom-ink"
        >
          Expand show
        </button>
      </div>
    );
  }

  return (
    <div className="relative h-[100svh] max-h-[100svh] overflow-hidden bg-black text-white">
      {/* Full-bleed host video — face stays clear */}
      <AgoraPlayer
        ref={playerRef}
        channelName={stream.channelName}
        role={hostMode ? "publisher" : "subscriber"}
        muted={muted}
        className="absolute inset-0 h-full w-full"
        onLatencySample={onLatencySample}
        onStateChange={setConnState}
      />

      <FloatingReactions />

      {/* Soft top gradient only — keeps face readable */}
      <div className="pointer-events-none absolute inset-x-0 top-0 z-10 h-28 bg-gradient-to-b from-black/50 to-transparent" />
      <div className="pointer-events-none absolute inset-x-0 bottom-0 z-10 h-36 bg-gradient-to-t from-black/55 to-transparent" />

      {/* Top chrome */}
      <div
        className="absolute inset-x-0 top-0 z-20 flex items-start justify-between gap-2 px-3"
        style={{ paddingTop: "max(0.75rem, env(safe-area-inset-top))" }}
      >
        <div className="flex min-w-0 items-center gap-2">
          <Link
            href="/live"
            className="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-black/35 backdrop-blur"
          >
            <ArrowLeft className="h-4 w-4" />
          </Link>
          <div className="flex min-w-0 items-center gap-2 rounded-full bg-black/35 py-1 pl-1 pr-3 backdrop-blur">
            {seller && (
              <Image
                src={seller.avatar}
                alt={seller.name}
                width={28}
                height={28}
                className="rounded-full object-cover"
              />
            )}
            <div className="min-w-0">
              <p className="truncate text-xs font-bold leading-tight">
                {seller?.name ?? "Hubsom Live"}
              </p>
              <p className="text-[10px] text-white/70">
                {stream.viewerCount.toLocaleString()} watching
              </p>
            </div>
          </div>
        </div>
        <div className="flex items-center gap-1.5">
          <span className="animate-pulse-live rounded-md bg-hubsom-live px-2 py-1 text-[10px] font-bold uppercase">
            Live
          </span>
          {connState === "connected" && (
            <span className="rounded-md bg-black/35 px-1.5 py-1 text-[9px] font-semibold text-hubsom-mint backdrop-blur">
              {latencyMs}ms
            </span>
          )}
        </div>
      </div>

      {/* Right action rail — TikTok-style, lower so face stays clear */}
      <div
        className="absolute right-2 z-20 flex flex-col items-center gap-3"
        style={{ bottom: "max(6.5rem, calc(env(safe-area-inset-bottom) + 5.5rem))" }}
      >
        <button
          type="button"
          onClick={() => void react("❤️")}
          className="flex flex-col items-center gap-0.5"
        >
          <span className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-black/35 backdrop-blur">
            <Heart className="h-5 w-5 fill-hubsom-live text-hubsom-live" />
          </span>
          <span className="text-[9px] font-semibold">Love</span>
        </button>
        <button
          type="button"
          onClick={() => {
            setShopOpen(true);
            setChatOpen(false);
          }}
          className="flex flex-col items-center gap-0.5"
        >
          <span className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-black/35 backdrop-blur">
            <Package className="h-5 w-5" />
          </span>
          <span className="text-[9px] font-semibold">Bag</span>
        </button>
        <button
          type="button"
          onClick={() => setCartOpen(true)}
          className="relative flex flex-col items-center gap-0.5"
        >
          <span className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-black/35 backdrop-blur">
            <ShoppingBag className="h-5 w-5" />
          </span>
          {cartCount > 0 && (
            <span className="absolute -right-0.5 -top-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-hubsom-gold px-1 text-[9px] font-bold text-hubsom-ink">
              {cartCount}
            </span>
          )}
          <span className="text-[9px] font-semibold">Cart</span>
        </button>
        <button
          type="button"
          onClick={() => {
            setChatOpen((v) => !v);
            setShopOpen(false);
          }}
          className="flex flex-col items-center gap-0.5"
        >
          <span className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-black/35 backdrop-blur">
            <MessageCircle className="h-5 w-5" />
          </span>
          <span className="text-[9px] font-semibold">Chat</span>
        </button>
        <button
          type="button"
          onClick={() => {
            const next = !muted;
            setMuted(next);
            playerRef.current?.setMuted(next);
          }}
          className="flex flex-col items-center gap-0.5"
        >
          <span className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-black/35 backdrop-blur">
            {muted ? <VolumeX className="h-5 w-5" /> : <Volume2 className="h-5 w-5" />}
          </span>
          <span className="text-[9px] font-semibold">{muted ? "Unmute" : "Mute"}</span>
        </button>
        <button
          type="button"
          onClick={() => setHostTrayOpen((v) => !v)}
          className="flex flex-col items-center gap-0.5"
        >
          <span className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-black/35 backdrop-blur">
            <MoreHorizontal className="h-5 w-5" />
          </span>
          <span className="text-[9px] font-semibold">More</span>
        </button>
      </div>

      {/* Bottom: one compact bag pill only — face stays clear */}
      <div
        className="absolute inset-x-0 bottom-0 z-20 pr-14 pl-3"
        style={{ paddingBottom: "max(0.75rem, env(safe-area-inset-bottom))" }}
      >
        {stream.auction && auctionOpen && !shopOpen && !chatOpen && (
          <div className="mb-2 max-w-[min(100%,20rem)]">
            <AuctionPanel
              auction={stream.auction}
              product={auctionProduct}
            />
            <button
              type="button"
              onClick={() => setAuctionOpen(false)}
              className="mt-1 text-[10px] text-white/60"
            >
              Hide auction
            </button>
          </div>
        )}

        {pinned && !shopOpen && !chatOpen && (
          <PinnedProduct
            product={pinned}
            onBuy={() => buy(pinned)}
            onOpenShop={() => setShopOpen(true)}
          />
        )}

        {notice && (
          <p className="mt-2 max-w-[min(100%,20rem)] rounded-xl bg-black/50 px-3 py-1.5 text-[11px] text-hubsom-sun backdrop-blur">
            {notice}
          </p>
        )}
      </div>

      {/* Shop bottom sheet */}
      {shopOpen && (
        <div className="absolute inset-x-0 bottom-0 z-30">
          <button
            type="button"
            className="absolute inset-x-0 -top-[40svh] h-[40svh]"
            aria-label="Dismiss shop"
            onClick={() => setShopOpen(false)}
          />
          <ProductCarousel
            products={products}
            pinnedProductId={pinnedId}
            onPin={(id) => void pinProduct(id)}
            onBuy={buy}
            onClose={() => setShopOpen(false)}
          />
        </div>
      )}

      {/* Chat sheet */}
      {chatOpen && (
        <div className="absolute inset-x-0 bottom-0 z-30 h-[42svh] rounded-t-3xl border-t border-white/10 bg-hubsom-night/95 p-3 backdrop-blur-xl">
          <div className="mb-2 flex items-center justify-between">
            <p className="text-sm font-bold">Live chat</p>
            <button
              type="button"
              onClick={() => setChatOpen(false)}
              className="text-xs text-white/60"
            >
              Close
            </button>
          </div>
          <div className="h-[calc(42svh-3rem)]">
            <LiveChat streamId={stream.id} initialMessages={initialChat} />
          </div>
        </div>
      )}

      {/* More / host tray */}
      {hostTrayOpen && (
        <div className="absolute inset-x-3 bottom-24 z-30 rounded-2xl border border-white/15 bg-black/80 p-3 backdrop-blur-xl">
          <div className="mb-2 flex items-center justify-between">
            <p className="text-xs font-bold uppercase tracking-[0.14em] text-hubsom-gold">
              Controls
            </p>
            <button
              type="button"
              onClick={() => setHostTrayOpen(false)}
              className="text-xs text-white/60"
            >
              Close
            </button>
          </div>
          <div className="flex flex-wrap gap-2">
            {hostMode && (
              <>
                <button
                  type="button"
                  onClick={() => void toggleMic()}
                  className="inline-flex items-center gap-1 rounded-xl bg-white/10 px-3 py-2 text-xs font-semibold"
                >
                  {micOn ? <Mic className="h-3.5 w-3.5" /> : <MicOff className="h-3.5 w-3.5" />}
                  Mic
                </button>
                <button
                  type="button"
                  onClick={() => void toggleCam()}
                  className="inline-flex items-center gap-1 rounded-xl bg-white/10 px-3 py-2 text-xs font-semibold"
                >
                  {camOn ? <Video className="h-3.5 w-3.5" /> : <VideoOff className="h-3.5 w-3.5" />}
                  Cam
                </button>
                <button
                  type="button"
                  onClick={() => void startRecording()}
                  className="rounded-xl bg-hubsom-leaf px-3 py-2 text-xs font-semibold"
                >
                  {recording ? "Recording…" : "Record"}
                </button>
              </>
            )}
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
              onClick={() => {
                setNotice("Push notify armed");
                setHostTrayOpen(false);
              }}
              className="inline-flex items-center gap-1 rounded-xl bg-white/10 px-3 py-2 text-xs font-semibold"
            >
              <Bell className="h-3.5 w-3.5" />
              Notify
            </button>
            {stream.auction && (
              <button
                type="button"
                onClick={() => {
                  setAuctionOpen(true);
                  setHostTrayOpen(false);
                }}
                className="rounded-xl bg-white/10 px-3 py-2 text-xs font-semibold"
              >
                Auction
              </button>
            )}
          </div>
        </div>
      )}

      {moderatorOpen && (
        <div className="absolute inset-x-3 bottom-24 z-40">
          <ModeratorPanel
            hosts={stream.hosts}
            onClose={() => setModeratorOpen(false)}
          />
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
