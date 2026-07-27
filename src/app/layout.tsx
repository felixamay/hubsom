import type { Metadata, Viewport } from "next";
import { Syne, Figtree } from "next/font/google";
import { AppShell } from "@/components/layout/AppShell";
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
    "Hubsom is Ghana’s social-commerce mobile app for live shopping, live auctions, Buy Now marketplace, flash sales, and seller stores — every category, one experience.",
  keywords: [
    "Hubsom",
    "Ghana marketplace",
    "live shopping",
    "live auction",
    "social commerce",
    "Accra",
  ],
  icons: {
    icon: "/brand/hubsom-logo.png",
    apple: "/brand/hubsom-logo.png",
  },
  appleWebApp: {
    capable: true,
    title: "Hubsom",
    statusBarStyle: "default",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  viewportFit: "cover",
  themeColor: "#eef7fc",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en-GH" className={`${display.variable} ${body.variable} h-full`}>
      <body className="flex min-h-full flex-col antialiased">
        <AppShell>{children}</AppShell>
      </body>
    </html>
  );
}
