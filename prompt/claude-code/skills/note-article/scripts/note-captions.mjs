import { chromium } from 'playwright-core';
import fs from 'fs'; import os from 'os';
const KEY='naba3aaebd80c'; const COOKIE=process.env.NOTE_COOKIE;
const HOME=os.homedir(); const DIR=HOME+'/tmp/hbl-note';
const caps=JSON.parse(fs.readFileSync(DIR+'/captions.json','utf8'));
const udir=DIR+'/pw-profile';
const log=(...a)=>console.log('[c3]',...a);
const ctx=await chromium.launchPersistentContext(udir,{channel:'chrome',headless:false,viewport:null,args:['--no-first-run','--no-default-browser-check']});
await ctx.addCookies([{name:'_note_session_v5',value:COOKIE,domain:'.note.com',path:'/',httpOnly:true,secure:true,sameSite:'Lax'}]);
const page=ctx.pages()[0]||await ctx.newPage();
await page.goto(`https://editor.note.com/notes/${KEY}/edit/`,{waitUntil:'domcontentloaded',timeout:60000});
await page.waitForSelector('.ProseMirror figure',{timeout:40000});
await page.waitForTimeout(5000);
const imgFigs=page.locator('.ProseMirror figure').filter({has:page.locator('img')});
const n=await imgFigs.count();
log('image figures=',n);
for(let i=0;i<Math.min(n,caps.length);i++){
  const f=imgFigs.nth(i);
  await f.scrollIntoViewIfNeeded();
  const cap=f.locator('figcaption');
  await cap.click({clickCount:3});
  await page.waitForTimeout(90);
  await page.keyboard.insertText(caps[i].text);
  await page.waitForTimeout(120);
}
log('applied all, waiting for autosave...');
// keep typing a harmless edit to keep the editor "dirty", then wait long
await page.locator('.ProseMirror').click();
await page.keyboard.press('End'); await page.keyboard.type('  '); await page.waitForTimeout(500);
await page.keyboard.press('Backspace'); await page.keyboard.press('Backspace');
await page.waitForTimeout(45000);
log('done waiting');
console.log('RESULT done');
await ctx.close();
