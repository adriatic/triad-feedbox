// F5 screenshots: one per screen and state, light and dark, 1280 and 390 px,
// into screenshots/F5/ (F1 section 10, "Visual check by Nik"). Runs only when
// asked for, so `npm run test:e2e` and CI do not rewrite the committed images:
//
//   npm run screenshots
//
// With SIDE_BY_SIDE_DIR=<folder> it also saves, for each of the six designs,
// one image with the design on the left and the built screen (same Lumen
// data) on the right, named after the design (Main.png, Idea.png, ...). The
// designs are drawn with e2e/design-support.js. LOCAL Supabase only.
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { expect, test, type Browser, type BrowserContext, type Page } from "@playwright/test";
import { ideaId, people, signIn, signInLink, viewerState } from "./helpers";

test.skip(!process.env.F5_SCREENSHOTS, "Screenshots are made only by `npm run screenshots`.");
test.setTimeout(600_000);

const OUT = path.join(process.cwd(), "screenshots", "F5");
const SIDE_BY_SIDE_DIR = process.env.SIDE_BY_SIDE_DIR;
const who = people("shots");
test.afterAll(() => who.cleanUp());

type Scheme = "light" | "dark";
type Width = 1280 | 390;
type As = "visitor" | "sam" | "ana";

interface State {
  name: string;
  as: As;
  /** Opens the page and brings it into the state. */
  open: (page: Page, baseURL: string, tag: string) => Promise<void>;
  /** The address (path and query) the capture must be on. */
  at: RegExp;
  /** The header's sign-in state the capture must show (default: the person's, from HEADER). */
  header?: string;
}

const HEADER: Record<As, string> = { visitor: "Viewing as visitor", sam: "Signed in as Sam P.", ana: "Signed in as owner" };

const dark = async () => `/ideas/${await ideaId("Dark mode for the editor")}`;

const STATES: State[] = [
  { name: "board-visitor", as: "visitor", at: /^\/$/, open: (p) => go(p, "/") },
  { name: "board-planned-visitor", as: "visitor", at: /^\/\?tab=planned$/, open: (p) => go(p, "/?tab=planned") },
  { name: "board-sort-new-visitor", as: "visitor", at: /^\/\?sort=new$/, open: (p) => go(p, "/?sort=new") },
  { name: "board-search-visitor", as: "visitor", at: /^\/\?q=laptop$/, open: (p) => go(p, "/?q=laptop") },
  { name: "board-signed-in", as: "sam", at: /^\/$/, open: (p) => go(p, "/") },
  { name: "board-owner", as: "ana", at: /^\/\?tab=planned$/, open: (p) => go(p, "/?tab=planned") },
  { name: "idea-visitor", as: "visitor", at: /^\/ideas\/\d+$/, open: async (p) => go(p, await dark()) },
  { name: "idea-signed-in", as: "sam", at: /^\/ideas\/\d+$/, open: async (p) => go(p, await dark()) },
  { name: "idea-owner", as: "ana", at: /^\/ideas\/\d+$/, open: async (p) => go(p, await dark()) },
  { name: "post-idea-empty", as: "sam", at: /^\/ideas\/new$/, open: (p) => go(p, "/ideas/new") },
  {
    name: "post-idea-similar",
    as: "sam", at: /^\/ideas\/new$/,
    open: async (p) => {
      await go(p, "/ideas/new");
      await p.getByLabel("Title").fill("Sync notes");
      await expect(p.getByTestId("similar-idea").first()).toBeVisible();
    },
  },
  { name: "sign-in", as: "visitor", at: /^\/sign-in$/, open: (p) => go(p, "/sign-in") },
  {
    name: "sign-in-check-email",
    as: "visitor", at: /^\/sign-in$/,
    open: async (p, _b, tag) => {
      await go(p, "/sign-in");
      await p.getByLabel("Email address").fill(who.email(`check-${tag}`));
      await p.getByRole("button", { name: "Send me a link" }).click();
      await expect(p.getByRole("heading", { name: "Check your email" })).toBeVisible();
    },
  },
  {
    name: "confirm",
    as: "visitor", at: /^\/auth\/confirm\?/,
    open: async (p, baseURL, tag) => {
      const { href } = await signInLink(who.email(`confirm-${tag}`), baseURL, "/");
      await go(p, href);
    },
  },
  {
    name: "welcome",
    as: "visitor", at: /^\/welcome\?next=/, header: "Signed in",
    open: async (p, baseURL, tag) => {
      const { href } = await signInLink(who.email(`welcome-${tag}`), baseURL, "/");
      await go(p, href);
      await p.getByRole("button", { name: "Finish signing in" }).click();
      await expect(p.getByRole("heading", { name: /^Welcome to / })).toBeVisible();
    },
  },
  { name: "changelog", as: "visitor", at: /^\/changelog$/, open: (p) => go(p, "/changelog") },
];

/** The six designs and the built screen in the same state (light, the design's own width). */
const DESIGNS: { file: string; state: string; width: Width; height: number }[] = [
  { file: "Main.dc.html", state: "board-visitor", width: 1280, height: 900 },
  { file: "Idea.dc.html", state: "idea-owner", width: 1280, height: 980 },
  { file: "PostIdea.dc.html", state: "post-idea-similar", width: 1280, height: 820 },
  { file: "SignIn.dc.html", state: "sign-in", width: 1280, height: 640 },
  { file: "Changelog.dc.html", state: "changelog", width: 1280, height: 800 },
  { file: "BoardPhone.dc.html", state: "board-planned-visitor", width: 390, height: 844 },
];

async function go(page: Page, url: string) {
  await page.goto(url);
  await page.evaluate(() => document.fonts.ready);
}

const EMAILS: Record<Exclude<As, "visitor">, string> = { sam: "sam@lumen.example", ana: "ana@lumen.example" };

async function contextFor(browser: Browser, baseURL: string, as: As, scheme: Scheme, width: Width): Promise<BrowserContext> {
  const context = await browser.newContext({ baseURL, viewport: { width, height: width === 390 ? 844 : 900 }, colorScheme: scheme });
  if (as !== "visitor") {
    const page = await context.newPage();
    // The seeded Lumen people (supabase/seed.sql) already have a name.
    await signIn(page, baseURL, EMAILS[as], null);
    await page.close();
  }
  return context;
}

test("screenshots of every screen and state, and the side-by-side images", async ({ browser, baseURL }) => {
  mkdirSync(OUT, { recursive: true });
  const built = new Map<string, Buffer>();

  for (const scheme of ["light", "dark"] as const) {
    for (const width of [1280, 390] as const) {
      for (const state of STATES) {
        // A fresh browser for every capture (task F5a): no session is carried
        // over from an earlier capture. Before F5a, "welcome" left a person
        // without a name signed in, and "changelog" then showed /welcome.
        const context = await contextFor(browser, baseURL!, state.as, scheme, width);
        const page = await context.newPage();
        await state.open(page, baseURL!, `${scheme}-${width}`);
        // The capture must be the screen and state its file name says.
        const url = new URL(page.url());
        expect(url.pathname + url.search, `${state.name}: address`).toMatch(state.at);
        await expect(viewerState(page), `${state.name}: header`).toHaveText(state.header ?? HEADER[state.as]);
        const file = path.join(OUT, `${state.name}-${scheme}-${width}.png`);
        const png = await page.screenshot({ path: file, fullPage: true, animations: "disabled", caret: "hide" });
        built.set(`${state.name}-${scheme}-${width}`, png);
        await context.close();
      }
    }
  }

  if (!SIDE_BY_SIDE_DIR) return;
  mkdirSync(SIDE_BY_SIDE_DIR, { recursive: true });
  for (const d of DESIGNS) {
    const design = await drawDesign(browser, d.file, d.width, d.height);
    const screen = built.get(`${d.state}-light-${d.width}`)!;
    const name = d.file.replace(/\.dc\.html$/, "");
    writeFileSync(path.join(SIDE_BY_SIDE_DIR, `${name}.png`), await sideBySide(browser, d.file, design, d.state, screen));
  }
});

/** Draws one design file as the design tool would, from design/ and e2e/design-support.js. */
async function drawDesign(browser: Browser, file: string, width: number, height: number): Promise<Buffer> {
  const context = await browser.newContext({ viewport: { width, height }, colorScheme: "light" });
  const page = await context.newPage();
  await page.route("http://design.local/**", (route) => {
    const name = new URL(route.request().url()).pathname.slice(1);
    const source = name === "support.js" ? path.join("e2e", "design-support.js") : path.join("design", path.basename(name));
    route.fulfill({ body: readFileSync(source), contentType: name.endsWith(".js") ? "text/javascript" : "text/html" });
  });
  await page.goto(`http://design.local/${file}`);
  await expect(page.locator("html[data-rendered='1']")).toHaveCount(1);
  await page.evaluate(() => document.fonts.ready);
  const png = await page.screenshot({ fullPage: true, animations: "disabled" });
  await context.close();
  return png;
}

async function sideBySide(browser: Browser, file: string, design: Buffer, state: string, screen: Buffer): Promise<Buffer> {
  const context = await browser.newContext({ viewport: { width: 1200, height: 800 }, colorScheme: "light" });
  const page = await context.newPage();
  const img = (b: Buffer) => `data:image/png;base64,${b.toString("base64")}`;
  await page.setContent(`<!doctype html><html><body style="margin:0;background:#d9dce3;font:15px system-ui,sans-serif;color:#16181d">
    <div style="display:flex;gap:24px;align-items:flex-start;padding:24px;width:max-content">
      <figure style="margin:0"><figcaption style="font-weight:600;margin-bottom:8px">Design: design/${file}</figcaption>
        <img src="${img(design)}" style="display:block;border:1px solid #9aa0ab"></figure>
      <figure style="margin:0"><figcaption style="font-weight:600;margin-bottom:8px">Built (F5): ${state}, light, Lumen data</figcaption>
        <img src="${img(screen)}" style="display:block;border:1px solid #9aa0ab"></figure>
    </div></body></html>`);
  await page.waitForFunction(() => [...document.images].every((i) => i.complete));
  const png = await page.screenshot({ fullPage: true });
  await context.close();
  return png;
}
