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
    <div className="bg-hubsom-mist text-hubsom-ink">
      <section className="mx-auto flex min-h-[70svh] max-w-5xl flex-col items-center justify-center px-4 py-16 sm:px-6">
        <p className="text-xs font-bold uppercase tracking-[0.2em] text-hubsom-orange">
          Official mark · transparent PNG
        </p>
        <div
          className="mt-8 w-full max-w-3xl rounded-3xl border border-hubsom-forest/10 p-8 sm:p-12"
          style={{
            backgroundImage:
              "linear-gradient(45deg, #d7e3ec 25%, transparent 25%), linear-gradient(-45deg, #d7e3ec 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #d7e3ec 75%), linear-gradient(-45deg, transparent 75%, #d7e3ec 75%)",
            backgroundSize: "24px 24px",
            backgroundPosition: "0 0, 0 12px, 12px -12px, -12px 0",
            backgroundColor: "#ffffff",
          }}
        >
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
        <div className="mt-6 w-full max-w-3xl rounded-3xl bg-black p-8 sm:p-12">
          <Image
            src={HUBSOM_LOGO.src}
            alt="Hubsom on dark"
            width={HUBSOM_LOGO.width}
            height={HUBSOM_LOGO.height}
            className="h-auto w-full object-contain"
            sizes="(max-width:768px) 100vw, 768px"
          />
        </div>
        <p className="mt-6 max-w-xl text-center text-sm text-hubsom-ink/65">
          Transparent background · intrinsic aspect ratio ·{" "}
          <code className="text-hubsom-blue">object-contain</code> (never stretched).
          Asset:{" "}
          <a className="text-hubsom-cyan underline" href="/brand/hubsom-logo.png">
            /brand/hubsom-logo.png
          </a>
        </p>
      </section>

      <section className="border-t border-hubsom-forest/10 bg-hubsom-night px-4 py-14 text-white sm:px-6">
        <div className="mx-auto max-w-5xl">
          <h1 className="font-display text-3xl font-bold">Official colors</h1>
          <p className="mt-2 text-white/65">
            Extracted from the Hubsom logo — teal/cyan, lime, and orange/gold.
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
