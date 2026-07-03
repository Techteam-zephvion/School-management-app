import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    // Integration tests hit the local Supabase stack; run serially and give
    // network calls room to breathe.
    include: ["tests/**/*.test.ts"],
    environment: "node",
    testTimeout: 20000,
    hookTimeout: 30000,
    fileParallelism: false,
  },
});
