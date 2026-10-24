"use client";

import { useRouter } from "next/navigation";
import { useSession } from "next-auth/react";
import { useState, useTransition } from "react";
import { Star } from "lucide-react";
import { cn } from "@/lib/utils";
import type { ProductReview } from "@/lib/data/product-reviews";

export function ProductReviewsSection({
  productId,
  initialReviews,
  initialRating,
  initialReviewCount,
  canReview,
  myReview,
}: {
  productId: string;
  initialReviews: ProductReview[];
  initialRating: number;
  initialReviewCount: number;
  canReview: boolean;
  myReview?: ProductReview | null;
}) {
  const { status } = useSession();
  const router = useRouter();
  const [reviews, setReviews] = useState(initialReviews);
  const [rating, setRating] = useState(initialRating);
  const [reviewCount, setReviewCount] = useState(initialReviewCount);
  const [my, setMy] = useState(myReview ?? null);
  const [stars, setStars] = useState(myReview?.rating ?? 5);
  const [text, setText] = useState(myReview?.text ?? "");
  const [error, setError] = useState<string | null>(null);
  const [statusMsg, setStatusMsg] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  function submit() {
    if (status === "unauthenticated") {
      router.push(
        `/auth/sign-in?callbackUrl=${encodeURIComponent(window.location.pathname)}`,
      );
      return;
    }
    setError(null);
    setStatusMsg(null);
    startTransition(async () => {
      try {
        const res = await fetch(`/api/products/${productId}/reviews`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ rating: stars, text }),
        });
        const data = await res.json();
        if (!res.ok) {
          setError(data.error ?? "Could not save review");
          return;
        }
        const review = data.review as ProductReview;
        setMy(review);
        setReviews((prev) => {
          const without = prev.filter((r) => r.userId !== review.userId);
          return [review, ...without];
        });
        if (typeof data.rating === "number") setRating(data.rating);
        if (typeof data.reviewCount === "number") setReviewCount(data.reviewCount);
        setStatusMsg(my ? "Review updated" : "Thanks — review saved");
        router.refresh();
      } catch {
        setError("Could not save review");
      }
    });
  }

  return (
    <section className="mt-10 space-y-5">
      <div>
        <h2 className="font-display text-2xl font-bold text-hubsom-forest">
          Reviews
        </h2>
        <p className="mt-1 text-sm text-hubsom-ink/60">
          {reviewCount > 0
            ? `${rating.toFixed(1)} · ${reviewCount} review${reviewCount === 1 ? "" : "s"}`
            : "No reviews yet"}
        </p>
      </div>

      {canReview ? (
        <div className="rounded-2xl border border-hubsom-forest/10 bg-white/80 p-4">
          <p className="text-sm font-semibold text-hubsom-ink">
            {my ? "Update your review" : "Review this product"}
          </p>
          <p className="mt-1 text-xs text-hubsom-ink/55">
            You bought this item — share how it went.
          </p>
          <div className="mt-3 flex items-center gap-1">
            {[1, 2, 3, 4, 5].map((n) => (
              <button
                key={n}
                type="button"
                onClick={() => setStars(n)}
                aria-label={`${n} stars`}
                className="rounded-md p-1 text-hubsom-gold transition hover:scale-105"
              >
                <Star
                  className={cn(
                    "h-6 w-6",
                    n <= stars ? "fill-current" : "text-hubsom-ink/25",
                  )}
                />
              </button>
            ))}
          </div>
          <textarea
            value={text}
            onChange={(e) => setText(e.target.value)}
            rows={3}
            placeholder="Quality, delivery, would you buy again…"
            className="mt-3 w-full rounded-xl border border-hubsom-forest/15 bg-white px-3 py-2 text-sm text-hubsom-ink outline-none focus:border-hubsom-forest/40"
          />
          {error ? (
            <p className="mt-2 text-xs font-medium text-hubsom-live">{error}</p>
          ) : null}
          {statusMsg ? (
            <p className="mt-2 text-xs font-medium text-hubsom-leaf">{statusMsg}</p>
          ) : null}
          <button
            type="button"
            onClick={submit}
            disabled={pending || !text.trim()}
            className="mt-3 inline-flex h-10 items-center justify-center rounded-xl bg-hubsom-forest px-4 text-xs font-bold text-white disabled:opacity-60"
          >
            {pending ? "Saving…" : my ? "Update review" : "Submit review"}
          </button>
        </div>
      ) : (
        <p className="rounded-2xl border border-dashed border-hubsom-forest/20 bg-white/50 px-4 py-3 text-sm text-hubsom-ink/60">
          Buy this product to leave a review.
        </p>
      )}

      <div className="space-y-3">
        {!reviews.length ? null : (
          reviews.map((review) => (
            <article
              key={review.id}
              className="rounded-2xl border border-hubsom-forest/10 bg-white/70 px-4 py-3"
            >
              <div className="flex items-center justify-between gap-2">
                <p className="text-sm font-semibold text-hubsom-ink">
                  {review.userName}
                </p>
                <div className="inline-flex items-center gap-0.5 text-hubsom-gold">
                  {Array.from({ length: 5 }).map((_, i) => (
                    <Star
                      key={i}
                      className={cn(
                        "h-3.5 w-3.5",
                        i < review.rating ? "fill-current" : "text-hubsom-ink/20",
                      )}
                    />
                  ))}
                </div>
              </div>
              <p className="mt-2 text-sm text-hubsom-ink/75">{review.text}</p>
              <p className="mt-2 text-[11px] text-hubsom-ink/45">
                {new Date(review.createdAt).toLocaleDateString()}
              </p>
            </article>
          ))
        )}
      </div>
    </section>
  );
}
