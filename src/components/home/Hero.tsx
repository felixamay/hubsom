"use client";

import Image from "next/image";
import Link from "next/link";
import { motion } from "framer-motion";
import { Play, Store } from "lucide-react";
import { BrandLogo } from "@/components/brand/BrandLogo";

export function Hero() {
  return (
    <section className="relative min-h-[100svh] overflow-hidden text-white">
      <Image
        src="https://images.unsplash.com/photo-1604719312566-8912e9227c6a?auto=format&fit=crop&w=2000&q=80"
        alt="Busy Ghana market aisle with fresh goods and shoppers"
        fill
        priority
        className="object-cover"
        sizes="100vw"
      />
      <div className="absolute inset-0 bg-gradient-to-r from-black/92 via-[#0a3d5c]/75 to-black/40" />
      <div className="absolute inset-0 hubsom-noise" />

      <div className="relative mx-auto flex min-h-[100svh] max-w-7xl flex-col justify-end px-4 pb-16 pt-28 sm:px-6 sm:pb-24">
        <motion.div
          initial={{ opacity: 0, y: 18 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          <BrandLogo
            href="/brand"
            heightClassName="h-16 sm:h-24 md:h-28"
            priority
            className="drop-shadow-[0_12px_40px_rgba(0,0,0,0.45)]"
          />
        </motion.div>

        <motion.h1
          initial={{ opacity: 0, y: 18 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.12 }}
          className="mt-5 max-w-2xl font-display text-2xl font-semibold leading-tight text-white/95 sm:text-4xl"
        >
          Live commerce from Ghana — shop every category in one stream.
        </motion.h1>

        <motion.p
          initial={{ opacity: 0, y: 18 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.22 }}
          className="mt-4 max-w-xl text-base leading-relaxed text-white/80 sm:text-lg"
        >
          Fresh produce, pantry staples, phones, sneakers, watches — Buy Now,
          pin live, or bid. No grocery silo. Just Hubsom.
        </motion.p>

        <motion.div
          initial={{ opacity: 0, y: 18 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.32 }}
          className="mt-8 flex flex-wrap gap-3"
        >
          <Link
            href="/live/stream-ama-mix"
            className="inline-flex items-center gap-2 rounded-xl bg-hubsom-gold px-5 py-3 text-sm font-bold text-hubsom-ink transition hover:bg-hubsom-sun"
          >
            <Play className="h-4 w-4 fill-current" />
            Enter live show
          </Link>
          <Link
            href="/marketplace"
            className="inline-flex items-center gap-2 rounded-xl border border-white/30 bg-white/10 px-5 py-3 text-sm font-semibold text-white backdrop-blur transition hover:bg-white/20"
          >
            <Store className="h-4 w-4" />
            Browse marketplace
          </Link>
        </motion.div>
      </div>
    </section>
  );
}
