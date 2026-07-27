import Image from "next/image";
import Link from "next/link";
import { cn } from "@/lib/utils";

/** Official Hubsom mark — transparent PNG, always object-contain (never stretched). */
export const HUBSOM_LOGO = {
  src: "/brand/hubsom-logo.png",
  width: 1363,
  height: 462,
  alt: "Hubsom",
} as const;

type BrandLogoProps = {
  className?: string;
  /** Height utility classes; width follows intrinsic aspect ratio. */
  heightClassName?: string;
  href?: string | null;
  priority?: boolean;
};

export function BrandLogo({
  className,
  heightClassName = "h-9",
  href = "/",
  priority = false,
}: BrandLogoProps) {
  const mark = (
    <Image
      src={HUBSOM_LOGO.src}
      alt={HUBSOM_LOGO.alt}
      width={HUBSOM_LOGO.width}
      height={HUBSOM_LOGO.height}
      priority={priority}
      className={cn(
        "w-auto max-w-full object-contain object-center",
        heightClassName,
        className,
      )}
      sizes="(max-width:768px) 160px, 200px"
    />
  );

  if (href === null) return mark;

  return (
    <Link href={href} aria-label="Hubsom home" className="inline-flex shrink-0 items-center">
      {mark}
    </Link>
  );
}
