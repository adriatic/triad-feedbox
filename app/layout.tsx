import type { Metadata, Viewport } from "next";
import { Inter } from "next/font/google";
import { Suspense, type ReactNode } from "react";
import { Footer } from "@/components/Footer";
import { Header } from "@/components/Header";
import { countUnread } from "@/lib/messages/data";
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
  // Owners see "Messages (2)" in the header while two messages are unread (task CT1).
  const unread = board && viewer.role === "owner" ? await countUnread(board.id) : 0;
  return (
    <html lang="en" className={inter.variable}>
      <body>
        <Suspense>
          <Header board={board} viewer={viewer} unreadMessages={unread} />
        </Suspense>
        {children}
        <Suspense>
          <Footer boardName={board?.name ?? "Feedbox"} />
        </Suspense>
      </body>
    </html>
  );
}
