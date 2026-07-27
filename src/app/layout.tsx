import type { Metadata } from "next";
import { Syne, Figtree } from "next/font/google";
import { SiteFooter } from "@/components/layout/SiteFooter";
import { SiteHeader } from "@/components/layout/SiteHeader";
import "./globals.css";

const display = Syne({
  variable: "--font-display",
  subsets: ["latin"],
  weight: ["500", "600", "700", "800"],
});

const body = Figtree({
  variable: "--font-body",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
});

export const metadata: Metadata = {
  title: {
    default: "Hubsom — Live commerce from Ghana",
    template: "%s · Hubsom",
  },
  description:
    "Hubsom is Ghana’s social-commerce platform for live shopping, live auctions, Buy Now marketplace, flash sales, and seller stores — every category, one experience.",
  keywords: [
    "Hubsom",
    "Ghana marketplace",
    "live shopping",
    "live auction",
    "social commerce",
    "Accra",
  ],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en-GH" className={`${display.variable} ${body.variable} h-full`}>
      <body className="min-h-full flex flex-col antialiased">
        <SiteHeader />
        <main className="flex-1">{children}</main>
        <SiteFooter />
      </body>
    </html>
  );
}
