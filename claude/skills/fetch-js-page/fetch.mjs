#!/usr/bin/env node
// playwright を移植可能に解決する（環境ごとにインストール場所が違うため複数パスへフォールバック）:
//  1) スキルディレクトリ等のローカル node_modules（bare import）
//  2) playwright-core
//  3) グローバル npm（npm root -g）
async function loadChromium() {
  for (const spec of ['playwright', 'playwright-core']) {
    try { return (await import(spec)).chromium; } catch {}
  }
  try {
    const { execSync } = await import('node:child_process');
    const { pathToFileURL } = await import('node:url');
    const { join } = await import('node:path');
    const root = execSync('npm root -g', { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
    return (await import(pathToFileURL(join(root, 'playwright/index.mjs')).href)).chromium;
  } catch {}
  console.error(
    'playwright が見つかりません。インストール:\n' +
    '  cd ~/.claude/skills/fetch-js-page && npm i playwright && npx playwright install chromium'
  );
  process.exit(1);
}
const chromium = await loadChromium();

const url = process.argv[2];
const mode = process.argv[3] || 'text';
const timeoutMs = Number(process.argv[4] || 30000);

if (!url) {
  console.error('Usage: fetch.mjs <url> [text|html|both] [timeout_ms]');
  process.exit(1);
}

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({
  userAgent:
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  locale: 'ja-JP',
  timezoneId: 'Asia/Tokyo',
  viewport: { width: 1280, height: 800 },
});
const page = await context.newPage();

try {
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: timeoutMs });

  await page.waitForFunction(
    () => {
      const t = document.title || '';
      return !/just a moment|checking your browser|attention required/i.test(t);
    },
    { timeout: timeoutMs }
  ).catch(() => {});

  await page.waitForLoadState('networkidle', { timeout: timeoutMs }).catch(() => {});

  const finalUrl = page.url();
  const title = await page.title();

  if (mode === 'html' || mode === 'both') {
    const html = await page.content();
    console.log('===HTML_START===');
    console.log(html);
    console.log('===HTML_END===');
  }

  if (mode === 'text' || mode === 'both') {
    const text = await page.evaluate(() => {
      const clone = document.body.cloneNode(true);
      clone.querySelectorAll('script, style, noscript, iframe').forEach((el) => el.remove());
      return clone.innerText.replace(/\n{3,}/g, '\n\n').trim();
    });
    console.log('===TITLE===');
    console.log(title);
    console.log('===URL===');
    console.log(finalUrl);
    console.log('===TEXT_START===');
    console.log(text);
    console.log('===TEXT_END===');
  }
} finally {
  await browser.close();
}
