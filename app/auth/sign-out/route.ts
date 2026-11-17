import { NextResponse, type NextRequest } from "next/server";
import { createClient } from "@/lib/supabase/server";

/** Sign out on this device only (F1 section 4), then back to the board. POST only. */
export async function POST(request: NextRequest) {
  const supabase = await createClient();
  await supabase.auth.signOut({ scope: "local" });
  return NextResponse.redirect(new URL("/", request.url), { status: 303 });
}

export function GET() {
  return new NextResponse("Sign out with the Sign out button (POST).", { status: 405, headers: { Allow: "POST" } });
}
