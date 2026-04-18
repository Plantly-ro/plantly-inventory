import { test, expect, Page } from '@playwright/test';
import { waitForProtoReady, waitForFontsReady } from './helpers';

async function ready(page: Page) {
  await waitForProtoReady(page);
  // Google Fonts (Inter, Plus Jakarta Sans) are pulled via @import in the CSS.
  // Screenshots taken before fonts resolve lock FOUT glyphs into the baseline.
  await waitForFontsReady(page);
}

test.describe('visual baselines', () => {
  test('home — default layout (light)', async ({ page }) => {
    await ready(page);
    await expect(page).toHaveScreenshot('home-light.png', { fullPage: true });
  });

  test('plant detail', async ({ page }) => {
    await ready(page);
    await page.getByRole('button', { name: 'Plant detail', exact: true }).click();
    await expect(page.getByRole('heading', { name: 'Monstera "Bob"' })).toBeVisible();
    await expect(page).toHaveScreenshot('plant-detail.png', { fullPage: true });
  });

  test('calendar week view', async ({ page }) => {
    await ready(page);
    await page.getByRole('button', { name: 'Calendar', exact: true }).click();
    await expect(page.getByRole('heading', { name: 'This week' })).toBeVisible();
    await expect(page).toHaveScreenshot('calendar.png', { fullPage: true });
  });

  test('export dialog', async ({ page }) => {
    await ready(page);
    await page.getByRole('button', { name: 'Export dialog' }).click();
    await expect(page.getByRole('heading', { name: /Post "Monstera Bob"/ })).toBeVisible();
    await expect(page).toHaveScreenshot('export-dialog.png', { fullPage: true });
  });
});
