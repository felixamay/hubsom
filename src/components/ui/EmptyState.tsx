import Link from "next/link";

export function EmptyState({
  title,
  body,
  actionHref,
  actionLabel,
}: {
  title: string;
  body: string;
  actionHref?: string;
  actionLabel?: string;
}) {
  return (
    <div className="rounded-2xl border border-dashed border-hubsom-forest/20 bg-white/50 px-6 py-12 text-center">
      <p className="font-display text-lg font-bold text-hubsom-forest">{title}</p>
      <p className="mt-2 text-sm text-hubsom-ink/60">{body}</p>
      {actionHref && actionLabel ? (
        <Link
          href={actionHref}
          className="mt-4 inline-flex rounded-xl bg-hubsom-forest px-4 py-2 text-sm font-bold text-white"
        >
          {actionLabel}
        </Link>
      ) : null}
    </div>
  );
}
