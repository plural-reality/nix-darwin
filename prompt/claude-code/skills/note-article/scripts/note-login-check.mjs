import { chromium } from 'playwright-core';
import fs from 'fs';
import os from 'os';

const KEY = 'naba3aaebd80c';
const COOKIE = process.env.NOTE_COOKIE;
const udir = os.homedir() + '/tmp/hbl-note/pw-profile';

const ctx = await chromium.launchPersistentContext(udir, {
  channel: 'chrome', headless: false, viewport: null,
  args: ['--no-first-run','--no-default-browser-check'],
});
await ctx.addCookies([{ name:'_note_session_v5', value:COOKIE, domain:'.note.com', path:'/', httpOnly:true, secure:true, sameSite:'Lax' }]);
const page = ctx.pages()[0] || await ctx.newPage();
await page.goto(`https://editor.note.com/notes/${KEY}/edit/`, { waitUntil:'domcontentloaded', timeout:60000 });
await page.waitForTimeout(6000);
const url = page.url();
let info = { url };
try {
  info.hasEditor = await page.locator('.ProseMirror').count();
  if (info.hasEditor) {
    info.h = await page.locator('.ProseMirror h1, .ProseMirror h2, .ProseMirror h3').count();
    info.imgs = await page.locator('.ProseMirror img').count();
    info.bodyLen = (await page.locator('.ProseMirror').innerText()).length;
  }
  info.loginRedirect = /login|signin/i.test(url);
} catch(e){ info.err = ''+e; }
console.log('RESULT ' + JSON.stringify(info));
await ctx.close();
