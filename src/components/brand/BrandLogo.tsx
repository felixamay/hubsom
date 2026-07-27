import Image from "next/image";
import Link from "next/link";
import { cn } from "@/lib/utils";

/** Official Hubsom mark — always letterboxed with object-contain (never stretched). */
export const HUBSOM_LOGO = {
  src: "/brand/hubsom-logo.png",
  width: 1536,
  height: 1024,
  alt: "Hubsom",
} as const;

type BrandLogoProps = {
  className?: string;
  /** Height utility classes; width follows intrinsic aspect ratio. */
  heightClassName?: string;
  href?: string | null;
  priority?: boolean;
  /** Show black brand plate behind the mark (recommended on light surfaces). */
  plate?: boolean;
};

export function BrandLogo({
  className,
  heightClassName = "h-9",
  href = "/",
  priority = false,
  plate = true,
}: BrandLogoProps) {
  const mark = (
    <span
      className={cn(
        "inline-flex items-center justify-center overflow-hidden",
        plate && "rounded-lg bg-black px-2 py-1",
        className,
      )}
    >
      <Image
        src={HUBSOM_LOGO.src}
        alt={HUBSOM_LOGO.alt}
        width={HUBSOM_LOGO.width}
        height={HUBSOM_LOGO.height}
        priority={priority}
        className={cn(
          "w-auto max-w-full object-contain object-center",
          heightClassName,
        )}
        sizes="(max-width:768px) 140px, 180px"
      />
    </span>
  );

  if (href === null) return mark;

  return (
    <Link href={href} aria-label="Hubsom home" className="inline-flex shrink-0">
      {mark}
    </Link>
  );
}
