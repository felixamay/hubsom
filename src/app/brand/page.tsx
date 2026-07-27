import type { Metadata } from "next";
import Image from "next/image";
import { HUBSOM_LOGO } from "@/components/brand/BrandLogo";

export const metadata: Metadata = {
  title: "Brand",
  description: "Official Hubsom logo and color system.",
};

const colors = [
  { name: "Night", token: "--hubsom-night", value: "#000000" },
  { name: "Ink", token: "--hubsom-ink", value: "#06121F" },
  { name: "Deep Teal", token: "--hubsom-forest", value: "#0A3D5C" },
  { name: "Blue", token: "--hubsom-blue", value: "#0054A6" },
  { name: "Cyan", token: "--hubsom-cyan", value: "#00AEEF" },
  { name: "Lime", token: "--hubsom-lime", value: "#7CBF2C" },
  { name: "Orange", token: "--hubsom-orange", value: "#F36F21" },
  { name: "Gold", token: "--hubsom-gold", value: "#F7941D" },
  { name: "Sun", token: "--hubsom-sun", value: "#FFC107" },
];

export default function BrandPage() {
  return (
    <div className="bg-black text-white">
      <section className="mx-auto flex min-h-[70svh] max-w-5xl flex-col items-center justify-center px-4 py-16 sm:px-6">
        <p className="text-xs font-bold uppercase tracking-[0.2em] text-hubsom-gold">
          Official mark
        </p>
        <div className="mt-8 w-full max-w-3xl">
          <Image
            src={HUBSOM_LOGO.src}
            alt={HUBSOM_LOGO.alt}
            width={HUBSOM_LOGO.width}
            height={HUBSOM_LOGO.height}
            priority
            className="h-auto w-full object-contain"
            sizes="(max-width:768px) 100vw, 768px"
          />
        </div>
        <p className="mt-6 max-w-xl text-center text-sm text-white/65">
          Displayed with intrinsic aspect ratio and <code>object-contain</code> —
          never stretched. Direct asset:{" "}
          <a className="text-hubsom-cyan underline" href="/brand/hubsom-logo.png">
            /brand/hubsom-logo.png
          </a>
        </p>
      </section>

      <section className="border-t border-white/10 bg-[#06121f] px-4 py-14 sm:px-6">
        <div className="mx-auto max-w-5xl">
          <h1 className="font-display text-3xl font-bold">Official colors</h1>
          <p className="mt-2 text-white/65">
            Extracted from the Hubsom logo — teal/cyan, lime, and orange/gold on
            black.
          </p>
          <div className="mt-8 grid gap-3 sm:grid-cols-2 md:grid-cols-3">
            {colors.map((c) => (
              <div
                key={c.token}
                className="overflow-hidden rounded-2xl border border-white/10 bg-white/5"
              >
                <div className="h-20" style={{ background: c.value }} />
                <div className="px-4 py-3 text-sm">
                  <p className="font-semibold">{c.name}</p>
                  <p className="text-white/55">{c.value}</p>
                  <p className="text-xs text-hubsom-cyan">{c.token}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>
    </div>
  );
}
