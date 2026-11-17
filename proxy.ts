import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import type { Database } from "@/lib/supabase/database.types";
import { supabasePublishableKey, supabaseUrl } from "@/lib/supabase/env";

/**
 * Next.js 16 calls middleware "proxy" (proxy.ts). On every page request it:
 * 1. refreshes the Supabase session cookies (F1 section 4), and
 * 2. sends a signed-in person who has no display name yet to /welcome, so the
 *    name is asked once, before anything else can be done.
 */
const NAME_NOT_NEEDED = ["/welcome", "/auth/"];

export async function proxy(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient<Database>(
    supabaseUrl(),
    supabasePublishableKey(),
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          for (const { name, value } of cookiesToSet) request.cookies.set(name, value);
          response = NextResponse.next({ request });
          for (const { name, value, options } of cookiesToSet) response.cookies.set(name, value, options);
        },
      },
    },
  );

  // Do not put code between createServerClient and getUser(): getUser() is
  // what refreshes an expired session.
  const { data } = await supabase.auth.getUser();
  const user = data.user;

  const path = request.nextUrl.pathname;
  if (user && !NAME_NOT_NEEDED.some((p) => path === p || path.startsWith(p))) {
    const { data: profile } = await supabase.from("profiles").select("display_name").eq("id", user.id).maybeSingle();
    if (!profile?.display_name) {
      const url = request.nextUrl.clone();
      url.pathname = "/welcome";
      url.search = "";
      url.searchParams.set("next", path + request.nextUrl.search);
      const redirect = NextResponse.redirect(url);
      for (const c of response.cookies.getAll()) redirect.cookies.set(c);
      return redirect;
    }
  }
  return response;
}

export const config = {
  // Every page, but not Next's own files or images.
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)"],
};
