import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

export default defineConfig([
  ...nextVitals,
  ...nextTs,
  {
    // The core library stays pure TypeScript: no Supabase, no Next, no React.
    files: ["lib/feedbox/**/*.ts"],
    rules: {
      "no-restricted-imports": [
        "error",
        {
          patterns: [
            { group: ["@supabase/*", "next", "next/*", "react", "react-dom"], message: "lib/feedbox must stay pure TypeScript (no Supabase, Next or React imports)." },
          ],
        },
      ],
    },
  },
  globalIgnores([".next/**", "out/**", "build/**", "coverage/**", "next-env.d.ts"]),
]);
