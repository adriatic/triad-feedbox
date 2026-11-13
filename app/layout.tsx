import type { Metadata } from "next";
import type { ReactNode } from "react";

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

export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="en">
      <head>
        <style>{baseStyles}</style>
      </head>
      <body>{children}</body>
    </html>
  );
}
