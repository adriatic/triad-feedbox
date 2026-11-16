import type { Metadata } from "next";
import { Suspense, type ReactNode } from "react";
import { Header } from "@/components/Header";
import { getBoard, getViewer } from "@/lib/supabase/data";

export const metadata: Metadata = {
  title: "Feedbox",
  description: "A free, open-source feedback and roadmap board.",
};

const baseStyles = `
:root { color-scheme: light dark; --bg: #F6F7F9; --card: #FFFFFF; --ink: #16181D; --muted: #5B6270; --line: #E3E5EA; --accent: #4338CA; }
@media (prefers-color-scheme: dark) {
  :root { --bg: #0F1115; --card: #171A21; --ink: #ECEEF3; --muted: #A3ABBA; --line: #2A2F3A; --accent: #8B93FF; }
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--ink); font-family: ui-sans-serif, system-ui, -apple-system, "Segoe UI", sans-serif; line-height: 1.5; }
`;

export default async function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  const board = await getBoard();
  const viewer = await getViewer(board?.id ?? null);
  return (
    <html lang="en">
      <head>
        <style>{baseStyles}</style>
      </head>
      <body>
        <div style={{ maxWidth: 720, margin: "0 auto", padding: "16px" }}>
          <Suspense>
            <Header board={board} viewer={viewer} />
          </Suspense>
          <main>{children}</main>
        </div>
      </body>
    </html>
  );
}
