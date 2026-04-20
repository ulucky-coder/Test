import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

test.describe("home a11y", () => {
  for (const scheme of ["light", "dark"] as const) {
    test(`home no violations @ ${scheme}`, async ({ page }) => {
      await page.emulateMedia({ colorScheme: scheme });
      await page.goto("/");
      const results = await new AxeBuilder({ page })
        .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
        .analyze();
      const critical = results.violations.filter(
        (v) => v.impact === "critical" || v.impact === "serious",
      );
      expect(critical).toEqual([]);
    });
  }
});
