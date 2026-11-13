import { STATUSES, statusLabel } from "@/lib/feedbox";

// Placeholder home page (task F2). The real board screen arrives in F5.
export default function Home() {
  return (
    <main style={{ maxWidth: 640, margin: "0 auto", padding: "64px 16px" }}>
      <h1 style={{ fontSize: 32, margin: "0 0 8px" }}>Feedbox</h1>
      <p style={{ color: "var(--muted)", margin: "0 0 24px" }}>
        A free, open-source feedback and roadmap board. The board is being built; this page is a placeholder.
      </p>
      <p style={{ margin: "0 0 8px" }}>Ideas move through:</p>
      <ol style={{ margin: 0, paddingLeft: 20 }}>
        {STATUSES.map((s) => (
          <li key={s}>{statusLabel(s)}</li>
        ))}
      </ol>
    </main>
  );
}
