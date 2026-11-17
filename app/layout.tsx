import type { Metadata, Viewport } from "next";
import { Inter } from "next/font/google";
import Link from "next/link";
import { Suspense, type ReactNode } from "react";
import { Header } from "@/components/Header";
import { getBoard, getViewer } from "@/lib/supabase/data";
import "./globals.css";

export const metadata: Metadata = {
  title: "Feedbox",
  description: "A free, open-source feedback and roadmap board.",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#ffffff" },
    { media: "(prefers-color-scheme: dark)", color: "#171a21" },
  ],
};

// Inter, as in the designs. next/font serves it from this site (no request to Google from the browser).
const inter = Inter({ subsets: ["latin"], weight: ["400", "500", "600", "700"], variable: "--font-inter", display: "swap" });

export default async function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  const board = await getBoard();
  const viewer = await getViewer(board?.id ?? null);
  return (
    <html lang="en" className={inter.variable}>
      <body>
        <Suspense>
          <Header board={board} viewer={viewer} />
        </Suspense>
        {children}
        <footer className="site-footer">
          {board?.name ?? "Feedbox"} runs on Feedbox, a free, open-source feedback board. <Link href="/changelog">See what shipped</Link>
        </footer>
      </body>
    </html>
  );
}
