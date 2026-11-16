// Before the end-to-end tests: wait until LOCAL Supabase sends the Feedbox
// email templates (supabase/templates/), not Supabase's built-in ones.
//
// Why (task F4b): in a freshly started local stack, the auth service tries to
// load the template files before the gateway that serves them is up. That
// first try fails ("connection refused" in its log), and until it reloads them
// it sends Supabase's default "Confirm your email address" email. CI always
// starts a fresh stack, so without this wait the first test would fail by luck.
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { localSupabase } from "./local-supabase";

const FIRST = "Your first Feedbox sign-in link";
const LATER = "Your Feedbox sign-in link";

export default async function globalSetup() {
  const sb = localSupabase();
  const anon = createClient(sb.apiUrl, sb.publishableKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const admin = createClient(sb.apiUrl, sb.secretKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const deadline = Date.now() + 120_000;
  let last = "";
  try {
    for (let n = 0; Date.now() < deadline; n++) {
      // A new person gets "Confirm signup"; a confirmed one gets "Magic Link".
      const fresh = `e2e+warmup-new-${Date.now()}-${n}@feedbox.test`;
      const known = `e2e+warmup-known-${Date.now()}-${n}@feedbox.test`;
      const { error } = await admin.auth.admin.createUser({ email: known, email_confirm: true });
      if (error) throw error;
      const subjects = await Promise.all([send(anon, sb.mailpitUrl, fresh), send(anon, sb.mailpitUrl, known)]);
      last = subjects.join(" / ");
      if (subjects[0] === FIRST && subjects[1] === LATER) return;
      await new Promise((r) => setTimeout(r, 3_000));
    }
    throw new Error(`Local Supabase still sends the wrong email templates after 2 minutes (got: ${last}).`);
  } finally {
    const { data } = await admin.auth.admin.listUsers({ perPage: 1000 });
    for (const u of data?.users ?? []) if (u.email?.startsWith("e2e+warmup-")) await admin.auth.admin.deleteUser(u.id);
  }
}

async function send(anon: SupabaseClient, mailpitUrl: string, email: string): Promise<string> {
  const { error } = await anon.auth.signInWithOtp({
    email,
    options: { emailRedirectTo: "http://127.0.0.1:3000/auth/confirm?next=%2F", shouldCreateUser: true },
  });
  if (error) throw error;
  for (let i = 0; i < 30; i++) {
    const res = await fetch(`${mailpitUrl}/api/v1/search?query=${encodeURIComponent(`to:"${email}"`)}`);
    const subject = ((await res.json()) as { messages?: { Subject: string }[] }).messages?.[0]?.Subject;
    if (subject) return subject;
    await new Promise((r) => setTimeout(r, 500));
  }
  return "no email";
}
