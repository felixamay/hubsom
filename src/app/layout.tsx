import type { Metadata, Viewport } from "next";
import { Plus_Jakarta_Sans } from "next/font/google";
import { AuthProvider } from "@/components/auth/AuthProvider";
import { AppShell } from "@/components/layout/AppShell";
import "./globals.css";

const plusJakarta = Plus_Jakarta_Sans({
  variable: "--font-plus-jakarta",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800"],
  display: "swap",
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
    <html lang="en-GH" className={`${plusJakarta.variable} h-full`}>
      <body className={`${plusJakarta.className} flex min-h-full flex-col antialiased`}>
        <AuthProvider>
          <AppShell>{children}</AppShell>
        </AuthProvider>
      </body>
    </html>
  );
}
