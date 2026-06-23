---
name: fetch-js-page
description: Use when WebFetch returns 403/blocked or only the Cloudflare/Just-a-moment challenge HTML, when a page requires JavaScript to render its content (SPA, React/Vue/Angular), or when curl/WebFetch returns less content than a real browser would see. Triggers Playwright via a local Node.js script to fetch fully-rendered HTML and extracted text.
---

# fetch-js-page

## Overview

Fetch a URL with a real Chromium browser via Playwright, bypassing Cloudflare JS challenges and rendering SPA content that WebFetch / curl cannot see.

**Core principle:** Use only when WebFetch fails or returns incomplete content. Never as a default — Playwright startup is 10-30× slower than WebFetch.

## When to Use

Symptoms that mean "switch to this skill":
- WebFetch returns 403 / "Just a moment..." / "Enable JavaScript"
- curl with browser User-Agent still returns Cloudflare challenge HTML
- Page is a SPA (React/Vue/Angular) and WebFetch only returns the empty shell
- Suspected client-side rendering (search results, dashboards, knowledge bases)
- Need post-JS DOM (e.g., dynamically loaded comments, AJAX content)

Do NOT use when:
- WebFetch already worked
- The URL is a plain static HTML/Markdown/JSON file
- A specialized MCP exists (GitHub URLs → use `gh` CLI; Google Docs → Drive MCP)
- The site requires login (this skill does not handle auth state)

## Quick Reference

| Mode | Output |
|------|--------|
| `text` *(default)* | Plain text from `body.innerText` (scripts/styles stripped) — best for Claude consumption |
| `html` | Full rendered HTML (`document.documentElement.outerHTML`) |
| `both` | Both, with delimiter markers |

| Argument | Default | Notes |
|----------|---------|-------|
| `<url>` | required | Must include `https://` |
| `[mode]` | `text` | `text` / `html` / `both` |
| `[timeout_ms]` | `30000` | Per-step (goto + wait). Cloudflare-heavy sites: try `60000` |

## Setup (一度だけ)

Playwright とブラウザを導入する（場所はスキルディレクトリ内でよい。スクリプトが自動解決する）:

```bash
cd ~/.claude/skills/fetch-js-page && npm i playwright && npx playwright install chromium
```

> グローバル導入（`npm i -g playwright`）でも動く。`fetch.mjs` はローカル→playwright-core→グローバルの順に解決する。

## Usage

Run via Bash:

```bash
node ~/.claude/skills/fetch-js-page/fetch.mjs <url> [mode] [timeout_ms]
```

Output is delimited so you can parse it:

```
===TITLE===
<page title>
===URL===
<final url after redirects>
===TEXT_START===
<body innerText>
===TEXT_END===
```

If `html` mode is used, `===HTML_START===` / `===HTML_END===` delimiters are also emitted.

## How It Works

1. Launches headless Chromium via `playwright` (resolved from local node_modules / playwright-core / global — see Setup)
2. Sets a realistic User-Agent + `ja-JP` locale + Tokyo timezone
3. `page.goto(url, { waitUntil: 'domcontentloaded' })`
4. Waits until `document.title` no longer matches Cloudflare/challenge patterns
5. Waits for `networkidle` (best-effort, ignored if it times out)
6. Strips `<script>`/`<style>`/`<iframe>` and outputs `innerText`

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Calling without `https://` | Always include scheme; relative URLs fail |
| Default 30s timeout on hard Cloudflare sites | Pass `60000` or higher as 3rd arg |
| Using this when WebFetch would work | Slower & more tokens. Try WebFetch first. |
| Trusting `text` mode for code-heavy pages | `innerText` flattens layout; for tables/code use `html` and parse |
| Capturing the entire HTML and dumping into context | Pipe through `head -N` or grep first |

## Example

```bash
# JS-protected support page (Cafe24 / Zendesk Help Center)
node ~/.claude/skills/fetch-js-page/fetch.mjs \
  "https://support.cafe24.co.jp/hc/ja/articles/900005248923" text 60000 \
  | head -200

# SPA dashboard, want full HTML
node ~/.claude/skills/fetch-js-page/fetch.mjs "https://example.com/dashboard" html 45000
```

## Limitations

- No login / cookie state (every fetch is a fresh incognito context)
- No interaction (clicks, form fills) — use a Playwright agent for that
- ~5-15s per fetch; not for high-volume crawling
- Some sites require headful mode or fingerprint randomization that this script does not provide. If the title still says "Just a moment..." after 60s, the site is using harder anti-bot defenses.
