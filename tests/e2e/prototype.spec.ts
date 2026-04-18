import { test, expect } from '@playwright/test';
import { waitForProtoReady } from './helpers';

// Playwright isolates a fresh browser context per test by default, so
// localStorage always starts empty — no global beforeEach cleanup needed.

test.describe('PlantlyInventory prototype — structure', () => {
  test('renders intro, phone frame, and default widgets', async ({ page }) => {
    await waitForProtoReady(page);

    await expect(page.getByText('🌿 PlantlyInventory · clickable prototype')).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Good morning, Ana' })).toBeVisible();

    // "Overdue", "Due today", "Spaces" each appear in multiple places
    // (stats tile label, widget heading, tab bar) so anchor with .first().
    await expect(page.getByText('Overdue', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('Due today', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('Plants', { exact: true })).toBeVisible();
    await expect(page.getByText('Spaces', { exact: true }).first()).toBeVisible();
    // "24" renders both as the stats value and the grid header accent.
    await expect(page.getByText('24', { exact: true }).first()).toBeVisible();

    await expect(page.getByText('Monstera "Bob"').first()).toBeVisible();
    await expect(page.getByText('Pothos "Green"')).toBeVisible();
    await expect(page.getByText('Snake plant')).toBeVisible();
    await expect(page.getByText('Calathea').first()).toBeVisible();
    await expect(page.getByRole('heading', { name: 'All plants' })).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Recent activity' })).toBeVisible();
  });

  test('intro controls reach Plant detail, Calendar, Home, and the Export dialog', async ({ page }) => {
    await waitForProtoReady(page);

    await page.getByRole('button', { name: 'Plant detail', exact: true }).click();
    await expect(page.getByRole('heading', { name: 'Monstera "Bob"' })).toBeVisible();
    await expect(page.getByRole('button', { name: /Post on plantly\.ro/ })).toBeVisible();

    await page.getByRole('button', { name: 'Calendar', exact: true }).click();
    await expect(page.getByRole('heading', { name: 'This week' })).toBeVisible();
    await expect(page.getByText(/Rain expected/i)).toBeVisible();

    await page.getByRole('button', { name: 'Home', exact: true }).click();
    await expect(page.getByRole('heading', { name: 'Good morning, Ana' })).toBeVisible();

    await page.getByRole('button', { name: 'Export dialog' }).click();
    await expect(page.getByRole('heading', { name: /Post "Monstera Bob"/ })).toBeVisible();
  });
});

test.describe('PlantlyInventory prototype — widget customization', () => {
  test('Dashboard preset swaps the widget set and persists to localStorage', async ({ page }) => {
    await waitForProtoReady(page);

    await page.getByRole('button', { name: /Customize home/ }).click();
    await page.getByRole('button', { name: 'Dashboard', exact: true }).click();

    await expect(page.getByText(/Timișoara · 19°C/)).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Overdue' })).toHaveCount(0);

    await page.getByRole('button', { name: /✓ Done/ }).click();

    await page.reload();
    await expect(page.getByText('Assemble your home from widgets')).toBeVisible({ timeout: 20_000 });
    await expect(page.getByText(/Timișoara · 19°C/)).toBeVisible({ timeout: 20_000 });
  });

  test('Reset home from the Tweaks panel restores the default layout', async ({ page }) => {
    await page.addInitScript(() => {
      localStorage.setItem('plantly_layout', JSON.stringify(['greeting', 'quicklog']));
    });
    await waitForProtoReady(page);

    await expect(page.getByRole('heading', { name: 'Quick log' })).toBeVisible();
    await expect(page.getByRole('heading', { name: 'All plants' })).toHaveCount(0);

    await page.evaluate(() => window.postMessage({ type: '__activate_edit_mode' }, '*'));
    await page.getByRole('button', { name: 'Reset home' }).click();

    await expect(page.getByRole('heading', { name: 'All plants' })).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Recent activity' })).toBeVisible();
  });
});

test.describe('PlantlyInventory prototype — plant detail + export flow', () => {
  test('tapping an overdue plant opens Plant Detail with upcoming care + timeline', async ({ page }) => {
    await waitForProtoReady(page);

    await page.getByText('Monstera "Bob"').first().click();

    await expect(page.getByRole('heading', { name: 'Monstera "Bob"' })).toBeVisible();
    await expect(page.getByText('Monstera deliciosa')).toBeVisible();
    await expect(page.getByText('Upcoming care')).toBeVisible();
    await expect(page.getByText('2 days overdue')).toBeVisible();
    await expect(page.getByText('Timeline')).toBeVisible();
    await expect(page.getByText(/Repotted → 20cm terracotta/)).toBeVisible();
    await expect(page.getByRole('button', { name: /Post on plantly\.ro/ })).toBeVisible();
  });

  test('Export dialog → edit title → Save draft shows toast + closes', async ({ page }) => {
    await waitForProtoReady(page);

    await page.getByRole('button', { name: 'Plant detail', exact: true }).click();
    await page.getByRole('button', { name: /Post on plantly\.ro/ }).click();

    const title = page.getByRole('textbox').first();
    await expect(title).toHaveValue(/Monstera deliciosa variegata/);
    await title.fill('Monstera deliciosa — split leaf (rooted)');

    await page.getByRole('button', { name: 'Save draft' }).click();
    await expect(page.getByText('Draft saved')).toBeVisible();
    await expect(page.getByRole('heading', { name: /Post "Monstera Bob"/ })).toHaveCount(0);
  });

  test('Export dialog → Post now shows the posted toast', async ({ page }) => {
    await waitForProtoReady(page);

    await page.getByRole('button', { name: 'Export dialog' }).click();
    await page.getByRole('button', { name: 'Post now' }).click();
    await expect(page.getByText('Posted to plantly.ro ✓')).toBeVisible();
  });
});

test.describe('PlantlyInventory prototype — calendar + theme', () => {
  test('Calendar week view shows the rain suggestion and a skip row on Saturday', async ({ page }) => {
    await waitForProtoReady(page);

    await page.getByRole('button', { name: 'Calendar', exact: true }).click();
    await expect(page.getByRole('heading', { name: 'This week' })).toBeVisible();
    await expect(page.getByText(/Skip outdoor watering/)).toBeVisible();
    await expect(page.getByText('19', { exact: true })).toBeVisible();
    // DOM text is "Skip"; CSS text-transform renders it as "SKIP" visually.
    // The rain banner's "Skip outdoor watering…" matches by substring, so anchor exactly.
    await expect(page.getByText('Skip', { exact: true })).toBeVisible();
  });

  test('edit-mode theme toggle flips the <body> class', async ({ page }) => {
    await waitForProtoReady(page);

    await page.evaluate(() => window.postMessage({ type: '__activate_edit_mode' }, '*'));
    await expect(page.getByText('Tweaks', { exact: true })).toBeVisible();

    // Default theme is "light" — set in the /*EDITMODE-BEGIN*/ block in index.html.
    await expect(page.locator('body')).toHaveClass(/light/);

    await page.getByRole('button', { name: /☾ Dark/ }).click();
    await expect(page.locator('body')).not.toHaveClass(/light/);

    await page.getByRole('button', { name: /☀ Light/ }).click();
    await expect(page.locator('body')).toHaveClass(/light/);
  });
});
