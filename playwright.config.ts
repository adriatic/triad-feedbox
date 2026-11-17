import { defineConfig, devices } from "@playwright/test";
import { localSupabase } from "./e2e/local-supabase";

// End-to-end tests (F1 section 10). F4: against the app built and started
// locally, with LOCAL Supabase in Docker (npm run e2e:supabase), never a
// hosted project. A runner against the hosted Preview is not built (F5
// report, decision F5-D2).
const PORT = 3000;
const baseURL = `http://127.0.0.1:${PORT}`;
const supabase = localSupabase();

export default defineConfig({
  testDir: "e2e",
  // Waits until local Supabase sends the Feedbox email templates (task F4b).
  globalSetup: "./e2e/global-setup.ts",
  fullyParallel: false,
  workers: 1,
  forbidOnly: !!process.env.CI,
  retries: 0,
  reporter: process.env.CI ? [["list"], ["html", { open: "never" }]] : "list",
  use: { baseURL, trace: "retain-on-failure" },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  webServer: {
    command: `npm run build && npx next start -H 127.0.0.1 -p ${PORT}`,
    url: baseURL,
    reuseExistingServer: !process.env.CI,
    timeout: 240_000,
    env: {
      NEXT_PUBLIC_SUPABASE_URL: supabase.apiUrl,
      NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: supabase.publishableKey,
      FEEDBOX_BOARD_SLUG: "lumen",
    },
  },
});
