"use client";

import { ProfileAvatarEditor } from "@/components/account/ProfileAvatarEditor";

export function AccountAvatarCard({
  name,
  email,
  image,
  meta,
}: {
  name: string;
  email: string;
  image?: string | null;
  meta: string;
}) {
  return (
    <div className="mt-5 flex items-center gap-3 rounded-2xl border border-hubsom-forest/10 bg-white/80 p-4">
      <ProfileAvatarEditor image={image} name={name} size="md" />
      <div className="min-w-0 flex-1">
        <p className="truncate font-display text-xl font-bold text-hubsom-ink">
          {name}
        </p>
        <p className="truncate text-sm text-hubsom-ink/60">{email}</p>
        <p className="mt-1 text-xs text-hubsom-ink/50">{meta}</p>
      </div>
    </div>
  );
}
