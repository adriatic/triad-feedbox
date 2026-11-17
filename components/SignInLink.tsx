"use client";
import Link from "next/link";
import { usePathname, useSearchParams } from "next/navigation";

/** "Sign in", remembering the page the visitor is on (?next=, checked again on the server). */
export function SignInLink() {
  const path = usePathname();
  const search = useSearchParams().toString();
  const here = search ? `${path}?${search}` : path;
  const href = here === "/" || here.startsWith("/sign-in") ? "/sign-in" : `/sign-in?next=${encodeURIComponent(here)}`;
  return <Link href={href}>Sign in</Link>;
}
