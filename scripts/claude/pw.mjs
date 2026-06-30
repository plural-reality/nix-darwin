#!/usr/bin/env node
/**
 * pw.mjs - Playwright CLI helper for Claude Code
 *
 * Usage:
 *   node ~/.claude/scripts/pw.mjs <command> [options]
 *
 * Commands:
 *   screenshot <url> [output]       - Take a screenshot (default: /tmp/pw-screenshot.png)
 *   shot <url> [output]             - Verify screenshot: --section "<text>" clips
 *                                     an element, --routes /a,/b shoots many (NDJSON)
 *   text <url>                      - Extract visible text content (compact)
 *   html <url> [selector]           - Get HTML (optionally filtered by selector)
 *   eval <url> <js-expression>      - Evaluate JS and return result
 *   click <url> <selector>          - Click an element and return resulting page text
 *   fill <url> <selector> <value>   - Fill an input and return page text
 *   pdf <url> [output]              - Save page as PDF
 *   wait <url> <selector>           - Wait for selector, then return text
 *
 * Options:
 *   --timeout <ms>        Navigation timeout (default: 30000)
 *   --wait <ms>           Extra wait after load (default: 0)
 *   --viewport <WxH>      Viewport size (default: 1280x720)
 *   --full-page           Full page screenshot
 *   --user-data-dir <p>   Chrome user data dir for sessions
 *   --cookie-file <p>     Load cookies from JSON file
 *   --no-headless          Run with visible browser (default: headless)
 *   --max-chars <n>       Max characters in text output (default: 8000)
 */

import { chromium } from 'playwright-core';
import { readFileSync, existsSync } from 'fs';
import { resolve, join } from 'path';
import { homedir } from 'os';

// Auto-detect Playwright browser path
function findChromiumPath() {
  const cacheDir = join(homedir(), 'Library', 'Caches', 'ms-playwright');
  if (!existsSync(cacheDir)) return undefined;

  // Find latest chromium directory
  const entries = readFileSync('/dev/null', 'utf8').length; // just a trick
  // Hardcode known path pattern for macOS
  const candidates = [
    join(cacheDir, 'chromium-1148', 'chrome-mac', 'Chromium.app', 'Contents', 'MacOS', 'Chromium'),
    join(cacheDir, 'chromium-1200', 'chrome-mac', 'Chromium.app', 'Contents', 'MacOS', 'Chromium'),
  ];
  for (const p of candidates) {
    if (existsSync(p)) return p;
  }
  return undefined;
}

const args = process.argv.slice(2);
const command = args[0];

function getFlag(name, defaultValue = undefined) {
  const idx = args.indexOf(`--${name}`);
  if (idx === -1) return defaultValue;
  if (typeof defaultValue === 'boolean') return true;
  return args[idx + 1];
}

function hasFlag(name) {
  return args.indexOf(`--${name}`) !== -1;
}

function getPositional(index) {
  const positionals = [];
  const boolFlags = ['--full-page', '--headless', '--no-headless'];
  for (let i = 1; i < args.length; i++) {
    if (args[i].startsWith('--')) {
      if (!boolFlags.includes(args[i])) i++;
      continue;
    }
    positionals.push(args[i]);
  }
  return positionals[index];
}

const timeout = parseInt(getFlag('timeout', '30000'));
const extraWait = parseInt(getFlag('wait', '0'));
const viewportStr = getFlag('viewport', '1280x720');
const [vw, vh] = viewportStr.split('x').map(Number);
const fullPage = hasFlag('full-page');
const userDataDir = getFlag('user-data-dir');
const cookieFile = getFlag('cookie-file');
const headless = !hasFlag('no-headless');
const maxChars = parseInt(getFlag('max-chars', '8000'));

const executablePath = findChromiumPath();

async function run() {
  if (!command || command === '--help' || command === '-h') {
    console.log(`pw.mjs - Playwright CLI helper for Claude Code

Commands:
  screenshot <url> [output]     Take a screenshot
  shot <url> [output]           Verify screenshot: --section "<text>" (element
                                clip), --routes /a,/b (multi-page, NDJSON out),
                                --scroll <px>, --full-page
  text <url>                    Extract visible text
  html <url> [selector]         Get HTML content
  eval <url> <expression>       Evaluate JS on page
  click <url> <selector>        Click element, return text
  fill <url> <selector> <val>   Fill input, return text
  pdf <url> [output]            Save as PDF
  wait <url> <selector>         Wait for element, return text

Options: --timeout --wait --viewport --full-page --section --routes --scroll
         --user-data-dir --cookie-file --no-headless --max-chars`);
    process.exit(0);
  }

  let browser, context, page;

  try {
    const launchOpts = { headless };
    if (executablePath) launchOpts.executablePath = executablePath;

    if (userDataDir) {
      context = await chromium.launchPersistentContext(userDataDir, {
        ...launchOpts,
        viewport: { width: vw, height: vh },
      });
      page = context.pages()[0] || await context.newPage();
      browser = null;
    } else {
      browser = await chromium.launch(launchOpts);
      context = await browser.newContext({
        viewport: { width: vw, height: vh },
        userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      });
      page = await context.newPage();
    }

    if (cookieFile && existsSync(cookieFile)) {
      const cookies = JSON.parse(readFileSync(cookieFile, 'utf8'));
      await context.addCookies(cookies);
    }

    const url = getPositional(0);
    if (!url) {
      console.error('Error: URL is required');
      process.exit(1);
    }

    await page.goto(url, { waitUntil: 'domcontentloaded', timeout });
    if (extraWait > 0) await page.waitForTimeout(extraWait);

    switch (command) {
      case 'screenshot': {
        const output = getPositional(1) || '/tmp/pw-screenshot.png';
        await page.screenshot({ path: resolve(output), fullPage });
        console.log(resolve(output));
        break;
      }

      // Section-targeted / multi-route verify screenshots. Replaces the
      // hand-rolled inline scrollIntoView + element-clip + sips-crop loop with
      // one deterministic call that emits NDJSON {path, mode, ...} per shot.
      case 'shot': {
        const sectionText = getFlag('section');
        const routesStr = getFlag('routes');
        const scrollPx = getFlag('scroll');
        const baseOutput = getPositional(1) || '/tmp/pw-shot.png';

        const shoot = async (outPath) => {
          if (sectionText) {
            const loc = page.getByText(sectionText, { exact: false }).first();
            if (await loc.count() > 0) {
              await loc.scrollIntoViewIfNeeded({ timeout }).catch(() => {});
              await page.waitForTimeout(extraWait || 150);
              await loc.screenshot({ path: resolve(outPath) });
              return { mode: 'section' };
            }
            await page.screenshot({ path: resolve(outPath), fullPage: true });
            return { mode: 'full-page', note: `section "${sectionText}" not found` };
          }
          if (scrollPx) {
            await page.evaluate((y) => window.scrollTo(0, y), parseInt(scrollPx));
            await page.waitForTimeout(extraWait || 150);
          }
          await page.screenshot({ path: resolve(outPath), fullPage });
          return { mode: fullPage ? 'full-page' : 'viewport' };
        };

        if (routesStr) {
          const base = url.replace(/\/+$/, '');
          const routes = routesStr.split(',').map((r) => r.trim()).filter(Boolean);
          for (const route of routes) {
            const path = route.startsWith('/') ? route : `/${route}`;
            const slug = path.replace(/[^a-zA-Z0-9]+/g, '_').replace(/^_|_$/g, '') || 'root';
            const outPath = baseOutput.replace(/\.png$/, '') + `-${slug}.png`;
            await page.goto(base + path, { waitUntil: 'domcontentloaded', timeout });
            if (extraWait > 0) await page.waitForTimeout(extraWait);
            const r = await shoot(outPath);
            console.log(JSON.stringify({ route: path, path: resolve(outPath), ...r }));
          }
        } else {
          const r = await shoot(baseOutput);
          console.log(JSON.stringify({ url, path: resolve(baseOutput), ...r }));
        }
        break;
      }

      case 'text': {
        const text = await page.evaluate(() => {
          document.querySelectorAll('script, style, noscript, svg, [aria-hidden="true"]')
            .forEach(el => el.remove());
          return document.body.innerText.trim();
        });
        const truncated = text.length > maxChars
          ? text.slice(0, maxChars) + `\n...[truncated at ${maxChars} chars, total ${text.length}]`
          : text;
        console.log(truncated);
        break;
      }

      case 'html': {
        const selector = getPositional(1);
        if (selector) {
          const html = await page.$eval(selector, el => el.innerHTML);
          console.log(html);
        } else {
          const html = await page.content();
          console.log(html);
        }
        break;
      }

      case 'eval': {
        const expr = getPositional(1);
        if (!expr) { console.error('Error: JS expression required'); process.exit(1); }
        const result = await page.evaluate(expr);
        console.log(typeof result === 'object' ? JSON.stringify(result, null, 2) : result);
        break;
      }

      case 'click': {
        const selector = getPositional(1);
        if (!selector) { console.error('Error: selector required'); process.exit(1); }
        await page.click(selector, { timeout });
        await page.waitForLoadState('domcontentloaded').catch(() => {});
        if (extraWait > 0) await page.waitForTimeout(extraWait);
        const text = await page.evaluate(() => document.body.innerText.trim());
        console.log(text.slice(0, maxChars));
        break;
      }

      case 'fill': {
        const selector = getPositional(1);
        const value = getPositional(2);
        if (!selector || !value) { console.error('Error: selector and value required'); process.exit(1); }
        await page.fill(selector, value, { timeout });
        const text = await page.evaluate(() => document.body.innerText.trim());
        console.log(text.slice(0, maxChars));
        break;
      }

      case 'pdf': {
        const output = getPositional(1) || '/tmp/pw-output.pdf';
        await page.pdf({ path: resolve(output), format: 'A4' });
        console.log(resolve(output));
        break;
      }

      case 'wait': {
        const selector = getPositional(1);
        if (!selector) { console.error('Error: selector required'); process.exit(1); }
        await page.waitForSelector(selector, { timeout });
        const text = await page.evaluate(() => document.body.innerText.trim());
        console.log(text.slice(0, maxChars));
        break;
      }

      default:
        console.error(`Unknown command: ${command}`);
        process.exit(1);
    }
  } catch (err) {
    console.error(`Error: ${err.message}`);
    process.exit(1);
  } finally {
    if (browser) await browser.close();
    else if (context) await context.close();
  }
}

run();
