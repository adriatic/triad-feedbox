// F4b: the sign-in emails as code. A first sign-in gets "Confirm signup", a
// later one "Magic Link"; both must link to /auth/confirm the same way, and
// local Supabase must require email confirmation like the hosted projects.
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const root = join(__dirname, "..");
const read = (path: string) => readFileSync(join(root, path), "utf8");
const LINK = '<a href="{{ .RedirectTo }}&token_hash={{ .TokenHash }}&type=email">Sign in to Feedbox</a>';

describe("email templates", () => {
  it("local Mailpit sends as Feedbox <feedbox@pactresearch.net>, like the hosted projects", () => {
    const toml = read("supabase/config.toml");
    const smtp = toml.slice(toml.indexOf("[local_smtp]"), toml.indexOf("[storage]"));
    expect(smtp).toMatch(/^admin_email = "feedbox@pactresearch.net"$/m);
    expect(smtp).toMatch(/^sender_name = "Feedbox"$/m);
  });

  it.each(["confirmation.html", "magic_link.html"])("%s links to /auth/confirm with token_hash and type=email, nothing else", (file) => {
    const html = read(`supabase/templates/${file}`);
    expect(html).toContain(LINK);
    expect(html.match(/href=/g)).toHaveLength(1);
    expect(html).not.toContain("ConfirmationURL");
  });

  it("supabase/config.toml requires email confirmation and uses both templates", () => {
    const toml = read("supabase/config.toml");
    const email = toml.slice(toml.indexOf("[auth.email]"), toml.indexOf("[auth.sms]"));
    expect(email).toMatch(/^enable_confirmations = true$/m);
    expect(email).toMatch(/^otp_length = 8$/m);
    expect(email).toContain('[auth.email.template.confirmation]\nsubject = "Your first Feedbox sign-in link"\ncontent_path = "./supabase/templates/confirmation.html"');
    expect(email).toContain('[auth.email.template.magic_link]\nsubject = "Your Feedbox sign-in link"\ncontent_path = "./supabase/templates/magic_link.html"');
  });
});
