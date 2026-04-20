import { test, expect } from "@playwright/test";

test.describe("home visual regression", () => {
  for (const width of [375, 768, 1024, 1440]) {
    test(`home @ ${width}`, async ({ page }) => {
      await page.setViewportSize({ width, height: 900 });
      await page.goto("/");
      await page.emulateMedia({ reducedMotion: "reduce" });
      await expect(page).toHaveScreenshot(`home-${width}.png`, {
        fullPage: true,
      });
    });
  }
});
