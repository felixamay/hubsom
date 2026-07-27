"use client";

import Image from "next/image";
import Link from "next/link";
import { useCallback, useMemo, useRef, useState } from "react";
import {
  ArrowLeft,
  Bell,
  Heart,
  PictureInPicture2,
  Shield,
  ShoppingBag,
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
import { HostControls } from "@/components/live/HostControls";
import { LiveCartDrawer } from "@/components/live/LiveCartDrawer";
import { LiveChat } from "@/components/live/LiveChat";
import { ModeratorPanel } from "@/components/live/ModeratorPanel";
import { PinnedProduct } from "@/components/live/PinnedProduct";
import { ProductCarousel } from "@/components/live/ProductCarousel";
import { useCartStore } from "@/lib/stores/cart";
import { useLiveStore } from "@/lib/stores/live";
import { categoryName } from "@/lib/categories";
import type { ChatMessage, LiveStream, Product, Seller } from "@/types";

function reactionX() {
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
  const playerRef = useRef<AgoraPlayerHandle>(null);
  const [pinnedId, setPinnedId] = useState(stream.pinnedProductId);
  const [latencyMs, setLatencyMs] = useState(stream.latencyMs || 1000);
  const [micOn, setMicOn] = useState(true);
  const [camOn, setCamOn] = useState(true);
  const [recording, setRecording] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [connState, setConnState] = useState<LiveConnectionState>("idle");
  const [pushArmed, setPushArmed] = useState(false);

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
    setNotice(`${product.name} added — one-tap checkout ready`);
  }

  async function pinProduct(productId: string) {
    setPinnedId(productId);
    await fetch(`/api/streams/${stream.id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ pinnedProductId: productId }),
    });
    setNotice("Product pinned for all viewers");
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
    setNotice("Cloud recording marked on — replay will be available after the show");
  }

  async function armPush() {
    setPushArmed(true);
    setNotice("Push notification hook armed for “show going live” + flash drops");
  }

  return (
    <div className="relative min-h-[100svh] bg-hubsom-night text-white">
      <div
        className={`relative ${
          pipEnabled
            ? "fixed bottom-4 right-4 z-[60] h-44 w-72 overflow-hidden rounded-2xl border border-white/20 shadow-2xl sm:h-52 sm:w-80"
            : "h-[58svh]"
        }`}
      >
        <AgoraPlayer
          ref={playerRef}
          channelName={stream.channelName}
          role={hostMode ? "publisher" : "subscriber"}
          muted={muted}
          className="h-full w-full"
          onLatencySample={onLatencySample}
          onStateChange={setConnState}
        />
        {!pipEnabled && <FloatingReactions />}

        {!pipEnabled && (
          <>
            <div className="absolute left-0 right-0 top-0 z-10 flex items-start justify-between gap-3 bg-gradient-to-b from-black/70 to-transparent p-3 pt-10">
              <div className="flex items-center gap-2">
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
                      width={32}
                      height={32}
                      className="rounded-full object-cover"
                    />
                  )}
                  <div>
                    <p className="line-clamp-1 text-sm font-semibold">{stream.title}</p>
                    <p className="text-[11px] text-white/70">
                      {seller?.name} · {stream.viewerCount.toLocaleString()} watching
                    </p>
                  </div>
                </div>
              </div>
              <div className="flex flex-wrap items-center justify-end gap-1.5">
                <span className="animate-pulse-live rounded-md bg-hubsom-live px-2 py-1 text-[10px] font-bold uppercase tracking-wide">
                  {stream.status === "replay" ? "Replay" : "Live"}
                </span>
                <span className="rounded-md bg-black/45 px-2 py-1 text-[10px] font-semibold text-hubsom-mint">
                  {latencyMs}ms
                </span>
                <span className="rounded-md bg-black/45 px-2 py-1 text-[10px] font-semibold capitalize text-white/80">
                  {connState}
                </span>
              </div>
            </div>

            <div className="absolute bottom-0 left-0 right-0 z-10 space-y-2 bg-gradient-to-t from-black/90 via-black/50 to-transparent p-3 pb-4">
              {pinned && (
                <PinnedProduct product={pinned} onBuy={() => buy(pinned)} />
              )}
              <ProductCarousel
                products={products}
                pinnedProductId={pinnedId}
                onPin={pinProduct}
                onBuy={buy}
              />
            </div>
          </>
        )}
      </div>

      {!pipEnabled && (
        <div className="space-y-3 px-3 pb-6 pt-3">
          <div className="flex flex-wrap gap-1.5">
            {stream.categories.map((c) => (
              <Link
                key={c}
                href={`/categories/${c}`}
                className="rounded-lg border border-white/15 bg-white/5 px-2.5 py-1 text-[11px] text-white/80"
              >
                {categoryName(c)}
              </Link>
            ))}
          </div>

          <p className="text-sm leading-relaxed text-white/75">{stream.description}</p>

          <div className="flex flex-wrap gap-2">
            {(["❤️", "🔥", "😂", "👏", "🇬🇭"] as const).map((emoji) => (
              <button
                key={emoji}
                type="button"
                onClick={() => react(emoji)}
                className="rounded-xl bg-white/10 px-3 py-2 text-lg"
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
              onToggleMic={() => void toggleMic()}
              onToggleCam={() => void toggleCam()}
              onInviteGuest={() =>
                setNotice(
                  "Guest seller invite ready — share /live/" +
                    stream.id +
                    "?host=1 for co-host publish",
                )
              }
              onStartRecording={() => void startRecording()}
            />
          )}

          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              onClick={() => {
                const next = !muted;
                setMuted(next);
                playerRef.current?.setMuted(next);
              }}
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
              onClick={() => void armPush()}
              className="inline-flex items-center gap-1 rounded-xl bg-white/10 px-3 py-2 text-xs font-semibold"
            >
              <Bell className="h-3.5 w-3.5" />
              {pushArmed ? "Push on" : "Notify"}
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

          {notice && (
            <p className="rounded-xl border border-hubsom-gold/30 bg-hubsom-gold/10 px-3 py-2 text-sm text-hubsom-sun">
              {notice}
            </p>
          )}

          {moderatorOpen && (
            <ModeratorPanel
              hosts={stream.hosts}
              onClose={() => setModeratorOpen(false)}
            />
          )}

          <div className="min-h-[320px]">
            <LiveChat streamId={stream.id} initialMessages={initialChat} />
          </div>

          <div className="rounded-2xl border border-white/10 bg-white/5 p-3 text-[11px] leading-relaxed text-white/65">
            Stack: Agora RTC · adaptive bitrate · HD/FHD · chat + AI moderation ·
            reactions · product pin · live cart · one-tap checkout · auctions ·
            multi-host · mods · PiP · recording/replay · inventory sync · analytics ·
            10k+ viewer scale target.
          </div>
        </div>
      )}

      {pipEnabled && (
        <div className="mx-auto max-w-lg px-4 py-12 text-center">
          <p className="font-display text-2xl font-bold">Picture-in-picture on</p>
          <p className="mt-2 text-sm text-white/70">
            Keep shopping while the show floats.
          </p>
          <button
            type="button"
            onClick={togglePip}
            className="mt-5 rounded-xl bg-hubsom-gold px-4 py-2 text-sm font-bold text-hubsom-ink"
          >
            Expand show
          </button>
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
