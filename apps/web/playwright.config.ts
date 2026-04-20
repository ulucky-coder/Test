import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  timeout: 30_000,
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  reporter: [
    ["html", { open: "never" }],
    ["json", { outputFile: "playwright-report.json" }],
  ],
  use: {
    baseURL: process.env.PREVIEW_URL ?? "http://localhost:3000",
    trace: "retain-on-failure",
  },
  projects: [
    {
      name: "a11y",
      testMatch: /.*\.a11y\.spec\.ts/,
      use: { ...devices["Desktop Chrome"] },
    },
    {
      name: "visual-regression",
      testMatch: /.*\.vis\.spec\.ts/,
      use: { ...devices["Desktop Chrome"] },
      expect: { toHaveScreenshot: { maxDiffPixels: 100 } },
    },
    {
      name: "smoke",
      testMatch: /.*\.smoke\.spec\.ts/,
      use: { ...devices["Desktop Chrome"] },
    },
    {
      name: "mobile",
      testMatch: /.*\.vis\.spec\.ts/,
      use: { ...devices["Pixel 5"] },
    },
  ],
});
