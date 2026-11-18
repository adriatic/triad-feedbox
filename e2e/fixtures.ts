// The browser never calls Supabase itself (task F5b; shared since task F6, A1
// finding 4). Every read and write goes through the app's server, the path
// that also works on the hosted Preview. Every test that imports `test` from
// this file runs with the local Supabase API blocked for the browser, and any
// attempt to reach it fails the test.
import { expect, test as base } from "@playwright/test";
import { localSupabase } from "./local-supabase";

const sb = localSupabase();

export const test = base.extend<{ noBrowserSupabase: void }>({
  noBrowserSupabase: [
    async ({ context }, use) => {
      const calls: string[] = [];
      await context.route(`${sb.apiUrl}/**`, (route) => {
        calls.push(route.request().url());
        return route.abort();
      });
      await use();
      expect(calls, "requests from the browser straight to Supabase").toEqual([]);
    },
    { auto: true },
  ],
});

export { expect };
export type { Page } from "@playwright/test";
