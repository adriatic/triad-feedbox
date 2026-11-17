import Link from "next/link";

export default function NotFound() {
  return (
    <main className="page">
      <h1 className="page-title">This page could not be found.</h1>
      <p className="muted">The idea may have been removed, or the address is wrong.</p>
      <Link href="/" className="back-link">
        &larr; All ideas
      </Link>
    </main>
  );
}
