import { expect, Page } from '@playwright/test';

// The prototype loads React + ReactDOM + @babel/standalone from unpkg and then
// compiles three JSX files in the browser. First paint happens on Babel's onload;
// waiting for `networkidle` hangs because Google Fonts keeps the network busy,
// so we anchor on known DOM landmarks instead.
export async function waitForProtoReady(page: Page) {
  await page.goto('/');
  await expect(page.getByText('Assemble your home from widgets')).toBeVisible({ timeout: 20_000 });
  await expect(page.getByRole('heading', { name: /Good morning, Ana/ })).toBeVisible({ timeout: 20_000 });
}

export async function waitForFontsReady(page: Page) {
  await page.evaluate(() => document.fonts.ready);
}
