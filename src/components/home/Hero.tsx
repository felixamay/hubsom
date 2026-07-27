"use client";

import Image from "next/image";
import Link from "next/link";
import { motion } from "framer-motion";
import { Play, Store } from "lucide-react";
import { BrandLogo } from "@/components/brand/BrandLogo";

export function Hero() {
  return (
    <section className="relative min-h-[68svh] overflow-hidden text-white">
      <Image
        src="https://images.unsplash.com/photo-1604719312566-8912e9227c6a?auto=format&fit=crop&w=1600&q=80"
        alt="Busy Ghana market aisle with fresh goods and shoppers"
        fill
        priority
        className="object-cover"
        sizes="(max-width:512px) 100vw, 512px"
      />
      <div className="absolute inset-0 bg-gradient-to-t from-black via-black/55 to-black/25" />

      <div className="relative flex min-h-[68svh] flex-col justify-end px-4 pb-8 pt-10">
        <motion.div
          initial={{ opacity: 0, y: 14 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.45 }}
        >
          <BrandLogo
            href="/"
            heightClassName="h-12"
            priority
            className="drop-shadow-[0_10px_24px_rgba(0,0,0,0.45)]"
          />
        </motion.div>

        <motion.h1
          initial={{ opacity: 0, y: 14 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.45, delay: 0.08 }}
          className="mt-4 max-w-sm font-display text-2xl font-bold leading-tight text-white"
        >
          Live commerce from Ghana — every category in one stream.
        </motion.h1>

        <motion.p
          initial={{ opacity: 0, y: 14 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.45, delay: 0.14 }}
          className="mt-2 max-w-sm text-sm leading-relaxed text-white/78"
        >
          Buy Now, pin live, or bid — groceries to gadgets, same cart.
        </motion.p>

        <motion.div
          initial={{ opacity: 0, y: 14 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.45, delay: 0.2 }}
          className="mt-5 flex flex-wrap gap-2"
        >
          <Link
            href="/live/stream-ama-mix"
            className="inline-flex items-center gap-2 rounded-xl bg-hubsom-gold px-4 py-2.5 text-sm font-bold text-hubsom-ink"
          >
            <Play className="h-4 w-4 fill-current" />
            Watch live
          </Link>
          <Link
            href="/marketplace"
            className="inline-flex items-center gap-2 rounded-xl border border-white/30 bg-white/10 px-4 py-2.5 text-sm font-semibold text-white backdrop-blur"
          >
            <Store className="h-4 w-4" />
            Shop
          </Link>
        </motion.div>
      </div>
    </section>
  );
}
