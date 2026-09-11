"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { AnimatePresence, motion } from "framer-motion";
import {
  Ban,
  Flag,
  Gift,
  MessageCircle,
  AtSign,
  Star,
  Store,
  X,
} from "lucide-react";
import { FollowButton } from "@/components/sellers/FollowButton";

type Props = {
  open: boolean;
  onClose: () => void;
  sellerId: string;
  sellerName: string;
  sellerAvatar: string | null;
  initialFollowing: boolean;
  initialFollowers?: number;
  isOwnStore?: boolean;
  streamId?: string;
  onMention: (handle: string) => void;
};

type Panel = "menu" | "tip" | "report" | "review" | "done";

export function LiveSellerProfileSheet({
  open,
  onClose,
  sellerId,
  sellerName,
  sellerAvatar,
  initialFollowing,
  initialFollowers,
  isOwnStore = false,
  streamId,
  onMention,
}: Props) {
  const router = useRouter();
  const [panel, setPanel] = useState<Panel>("menu");
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<string | null>(null);
  const [tipAmount, setTipAmount] = useState("5");
  const [reportReason, setReportReason] = useState("Spam or misleading");
  const [reportDetails, setReportDetails] = useState("");
  const [rating, setRating] = useState(5);
  const [reviewText, setReviewText] = useState("");
  const [blocked, setBlocked] = useState(false);

  useEffect(() => {
    if (!open) {
      setPanel("menu");
      setStatus(null);
      setBusy(false);
      return;
    }

    let cancelled = false;
    void (async () => {
      try {
        const res = await fetch(`/api/sellers/${sellerId}/social`);
        if (!res.ok || cancelled) return;
        const data = (await res.json()) as { blocked?: boolean };
        if (!cancelled) setBlocked(Boolean(data.blocked));
      } catch {
        /* ignore */
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [open, sellerId]);

  async function postAction(body: Record<string, unknown>) {
    setBusy(true);
    setStatus(null);
    try {
      const res = await fetch(`/api/sellers/${sellerId}/social`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      const data = (await res.json().catch(() => ({}))) as {
        error?: string;
      };
      if (!res.ok) {
        setStatus(data.error ?? "Something went wrong");
        return false;
      }
      return true;
    } catch {
      setStatus("Network error. Try again.");
      return false;
    } finally {
      setBusy(false);
    }
  }

  async function handleBlock() {
    const ok = await postAction({
      action: blocked ? "unblock" : "block",
    });
    if (!ok) return;
    setBlocked((v) => !v);
    setStatus(blocked ? "Seller unblocked." : "Seller blocked.");
    setPanel("done");
  }

  async function handleTip() {
    const amountGhs = Number(tipAmount);
    if (!Number.isFinite(amountGhs) || amountGhs <= 0) {
      setStatus("Enter a valid tip amount");
      return;
    }
    const ok = await postAction({
      action: "tip",
      amountGhs,
      streamId,
    });
    if (!ok) return;
    setStatus(`GHS ${amountGhs.toFixed(2)} tip sent to ${sellerName}.`);
    setPanel("done");
  }

  async function handleReport() {
    const ok = await postAction({
      action: "report",
      reason: reportReason,
      details: reportDetails.trim() || undefined,
      streamId,
    });
    if (!ok) return;
    setStatus("Report submitted. Our team will review it.");
    setReportDetails("");
    setPanel("done");
  }

  async function handleReview() {
    if (!reviewText.trim()) {
      setStatus("Write a short review");
      return;
    }
    const ok = await postAction({
      action: "review",
      rating,
      text: reviewText.trim(),
    });
    if (!ok) return;
    setStatus("Thanks — your review was saved.");
    setReviewText("");
    setPanel("done");
  }

  async function handleMessage() {
    setBusy(true);
    setStatus(null);
    try {
      const res = await fetch(
        `/api/messages?sellerId=${encodeURIComponent(sellerId)}`,
      );
      const data = (await res.json().catch(() => ({}))) as {
        peerUserId?: string;
        error?: string;
      };
      if (!res.ok || !data.peerUserId) {
        setStatus(data.error ?? "Could not open chat");
        return;
      }
      onClose();
      router.push(`/messages/${data.peerUserId}`);
    } catch {
      setStatus("Network error. Try again.");
    } finally {
      setBusy(false);
    }
  }

  function mentionInChat() {
    onMention(sellerName);
    onClose();
  }

  const actions = [
    {
      id: "message",
      label: "Message",
      icon: MessageCircle,
      onClick: () => void handleMessage(),
    },
    {
      id: "mention",
      label: "Mention in chat",
      icon: AtSign,
      onClick: mentionInChat,
    },
    {
      id: "tip",
      label: "Tip",
      icon: Gift,
      onClick: () => {
        setStatus(null);
        setPanel("tip");
      },
    },
    {
      id: "review",
      label: "Review",
      icon: Star,
      onClick: () => {
        setStatus(null);
        setPanel("review");
      },
    },
    {
      id: "report",
      label: "Report",
      icon: Flag,
      onClick: () => {
        setStatus(null);
        setPanel("report");
      },
    },
    {
      id: "block",
      label: blocked ? "Unblock" : "Block",
      icon: Ban,
      onClick: () => void handleBlock(),
      danger: true,
    },
  ] as const;

  return (
    <AnimatePresence>
      {open ? (
        <>
          <motion.button
            type="button"
            aria-label="Close seller profile"
            className="fixed inset-0 z-[70] bg-black/55"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
          />
          <motion.div
            role="dialog"
            aria-modal="true"
            aria-label={`${sellerName} profile`}
            className="fixed inset-x-0 bottom-0 z-[71] mx-auto max-h-[88vh] w-full max-w-lg overflow-y-auto rounded-t-[1.6rem] bg-white text-hubsom-ink shadow-2xl"
            initial={{ y: "100%" }}
            animate={{ y: 0 }}
            exit={{ y: "100%" }}
            transition={{ type: "spring", stiffness: 380, damping: 34 }}
          >
            <div className="sticky top-0 z-10 flex items-center justify-between border-b border-hubsom-forest/10 bg-white px-4 py-3">
              <p className="font-display text-lg font-bold text-hubsom-ink">
                {panel === "menu"
                  ? "Seller"
                  : panel === "tip"
                    ? "Send a tip"
                    : panel === "report"
                      ? "Report seller"
                      : panel === "review"
                        ? "Leave a review"
                        : "Done"}
              </p>
              <button
                type="button"
                onClick={onClose}
                className="rounded-full p-2 text-hubsom-forest/55 hover:bg-hubsom-mist"
                aria-label="Close"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <div className="space-y-4 px-4 py-4 pb-[max(1.25rem,env(safe-area-inset-bottom))]">
              <div className="flex items-center gap-3">
                <div className="flex h-14 w-14 shrink-0 items-center justify-center overflow-hidden rounded-full bg-hubsom-mist ring-2 ring-hubsom-gold/30">
                  {sellerAvatar ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={sellerAvatar}
                      alt=""
                      className="h-full w-full object-cover"
                    />
                  ) : (
                    <span className="font-display text-xl font-bold text-hubsom-gold">
                      {sellerName.slice(0, 1)}
                    </span>
                  )}
                </div>
                <div className="min-w-0 flex-1">
                  <p className="truncate font-display text-xl font-bold text-hubsom-ink">
                    {sellerName}
                  </p>
                  <Link
                    href={`/store/${sellerId}`}
                    className="mt-0.5 inline-flex items-center gap-1 text-xs font-semibold text-hubsom-gold"
                    onClick={onClose}
                  >
                    <Store className="h-3.5 w-3.5" />
                    View store
                  </Link>
                </div>
                {!isOwnStore ? (
                  <FollowButton
                    sellerId={sellerId}
                    initialFollowing={initialFollowing}
                    initialFollowers={initialFollowers}
                    isOwnStore={isOwnStore}
                    size="sm"
                  />
                ) : null}
              </div>

              {status ? (
                <p
                  className={`rounded-xl px-3 py-2 text-sm ${
                    panel === "done"
                      ? "bg-emerald-50 text-emerald-800"
                      : "bg-hubsom-mist text-hubsom-forest/70"
                  }`}
                >
                  {status}
                </p>
              ) : null}

              {panel === "menu" && !isOwnStore ? (
                <div className="grid grid-cols-2 gap-2">
                  {actions.map((action) => {
                    const Icon = action.icon;
                    return (
                      <button
                        key={action.id}
                        type="button"
                        disabled={busy}
                        onClick={action.onClick}
                        className={`flex min-h-16 flex-col items-start justify-center gap-1.5 rounded-2xl border px-3.5 py-3 text-left transition disabled:opacity-50 ${
                          "danger" in action && action.danger
                            ? "border-red-200 bg-red-50 text-red-700"
                            : "border-hubsom-forest/10 bg-hubsom-mist/70 text-hubsom-ink hover:border-hubsom-gold/35"
                        }`}
                      >
                        <Icon className="h-4 w-4 opacity-80" />
                        <span className="text-sm font-semibold">
                          {action.label}
                        </span>
                      </button>
                    );
                  })}
                </div>
              ) : null}

              {panel === "menu" && isOwnStore ? (
                <p className="rounded-xl bg-hubsom-mist px-3 py-3 text-sm text-hubsom-forest/70">
                  This is your live profile. Viewers can follow, message, tip,
                  mention, review, report, or block from here.
                </p>
              ) : null}

              {panel === "tip" ? (
                <div className="space-y-3">
                  <div className="flex flex-wrap gap-2">
                    {["2", "5", "10", "20"].map((amt) => (
                      <button
                        key={amt}
                        type="button"
                        onClick={() => setTipAmount(amt)}
                        className={`min-h-10 rounded-full px-4 text-sm font-semibold ${
                          tipAmount === amt
                            ? "bg-hubsom-gold text-hubsom-ink"
                            : "bg-hubsom-mist text-hubsom-ink"
                        }`}
                      >
                        GHS {amt}
                      </button>
                    ))}
                  </div>
                  <label className="block space-y-1.5">
                    <span className="text-xs font-semibold text-hubsom-forest/55">
                      Custom amount (GHS)
                    </span>
                    <input
                      type="number"
                      min="1"
                      step="0.5"
                      value={tipAmount}
                      onChange={(e) => setTipAmount(e.target.value)}
                      className="w-full rounded-xl border border-hubsom-forest/12 bg-white px-3 py-2.5 text-sm outline-none focus:border-hubsom-gold"
                    />
                  </label>
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={() => setPanel("menu")}
                      className="min-h-11 flex-1 rounded-full border border-hubsom-forest/12 text-sm font-semibold"
                    >
                      Back
                    </button>
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => void handleTip()}
                      className="min-h-11 flex-1 rounded-full bg-hubsom-gold text-sm font-semibold text-hubsom-ink disabled:opacity-50"
                    >
                      {busy ? "Sending…" : "Send tip"}
                    </button>
                  </div>
                </div>
              ) : null}

              {panel === "report" ? (
                <div className="space-y-3">
                  <label className="block space-y-1.5">
                    <span className="text-xs font-semibold text-hubsom-forest/55">
                      Reason
                    </span>
                    <select
                      value={reportReason}
                      onChange={(e) => setReportReason(e.target.value)}
                      className="w-full rounded-xl border border-hubsom-forest/12 bg-white px-3 py-2.5 text-sm outline-none focus:border-hubsom-gold"
                    >
                      <option value="Spam or misleading">Spam or misleading</option>
                      <option value="Suspected scam">Suspected scam</option>
                      <option value="Harassment">Harassment</option>
                      <option value="Inappropriate content">
                        Inappropriate content
                      </option>
                      <option value="Other">Other</option>
                    </select>
                  </label>
                  <label className="block space-y-1.5">
                    <span className="text-xs font-semibold text-hubsom-forest/55">
                      Details
                    </span>
                    <textarea
                      value={reportDetails}
                      onChange={(e) => setReportDetails(e.target.value)}
                      rows={3}
                      placeholder="Tell us what happened…"
                      className="w-full resize-none rounded-xl border border-hubsom-forest/12 bg-white px-3 py-2.5 text-sm outline-none focus:border-hubsom-gold"
                    />
                  </label>
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={() => setPanel("menu")}
                      className="min-h-11 flex-1 rounded-full border border-hubsom-forest/12 text-sm font-semibold"
                    >
                      Back
                    </button>
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => void handleReport()}
                      className="min-h-11 flex-1 rounded-full bg-hubsom-forest text-sm font-semibold text-white disabled:opacity-50"
                    >
                      {busy ? "Sending…" : "Submit report"}
                    </button>
                  </div>
                </div>
              ) : null}

              {panel === "review" ? (
                <div className="space-y-3">
                  <div className="flex justify-center gap-1.5">
                    {[1, 2, 3, 4, 5].map((n) => (
                      <button
                        key={n}
                        type="button"
                        onClick={() => setRating(n)}
                        className="rounded-full p-1.5"
                        aria-label={`${n} stars`}
                      >
                        <Star
                          className={`h-7 w-7 ${
                            n <= rating
                              ? "fill-hubsom-gold text-hubsom-gold"
                              : "text-hubsom-forest/20"
                          }`}
                        />
                      </button>
                    ))}
                  </div>
                  <textarea
                    value={reviewText}
                    onChange={(e) => setReviewText(e.target.value)}
                    rows={3}
                    placeholder="How was this seller?"
                    className="w-full resize-none rounded-xl border border-hubsom-forest/12 bg-white px-3 py-2.5 text-sm outline-none focus:border-hubsom-gold"
                  />
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={() => setPanel("menu")}
                      className="min-h-11 flex-1 rounded-full border border-hubsom-forest/12 text-sm font-semibold"
                    >
                      Back
                    </button>
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => void handleReview()}
                      className="min-h-11 flex-1 rounded-full bg-hubsom-gold text-sm font-semibold text-hubsom-ink disabled:opacity-50"
                    >
                      {busy ? "Saving…" : "Submit review"}
                    </button>
                  </div>
                </div>
              ) : null}

              {panel === "done" ? (
                <button
                  type="button"
                  onClick={onClose}
                  className="flex min-h-11 w-full items-center justify-center rounded-full bg-hubsom-gold text-sm font-semibold text-hubsom-ink"
                >
                  Close
                </button>
              ) : null}
            </div>
          </motion.div>
        </>
      ) : null}
    </AnimatePresence>
  );
}
