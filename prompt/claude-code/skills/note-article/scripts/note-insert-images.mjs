import { chromium } from 'playwright-core';
import fs from 'fs'; import os from 'os';
const KEY='naba3aaebd80c'; const COOKIE=process.env.NOTE_COOKIE;
const HOME=os.homedir(); const DIR=HOME+'/tmp/hbl-note';
const imgs=JSON.parse(fs.readFileSync(DIR+'/note-images2.json','utf8'));
const udir=DIR+'/pw-profile';
const log=(...a)=>console.log('[pw]',...a);

const ctx=await chromium.launchPersistentContext(udir,{channel:'chrome',headless:false,viewport:null,args:['--no-first-run','--no-default-browser-check']});
await ctx.addCookies([{name:'_note_session_v5',value:COOKIE,domain:'.note.com',path:'/',httpOnly:true,secure:true,sameSite:'Lax'}]);
const page=ctx.pages()[0]||await ctx.newPage();
await page.goto(`https://editor.note.com/notes/${KEY}/edit/`,{waitUntil:'domcontentloaded',timeout:60000});
await page.waitForSelector('.ProseMirror',{timeout:30000});
await page.waitForTimeout(4000);

const base=await page.evaluate(()=>{const e=document.querySelector('.ProseMirror');return {h:e.querySelectorAll('h1,h2,h3').length,imgs:e.querySelectorAll('img').length,len:e.innerText.length};});
log('base',JSON.stringify(base));

// clear existing images (real select+delete)
let guard=0;
while(await page.locator('.ProseMirror img').count()>0 && guard<80){
  const im=page.locator('.ProseMirror img').first();
  await im.scrollIntoViewIfNeeded().catch(()=>{});
  await im.click().catch(()=>{});
  await page.keyboard.press('Backspace').catch(()=>{});
  await page.waitForTimeout(200);
  guard++;
}
log('cleared, imgs now', await page.locator('.ProseMirror img').count());

const fails=[];
for(let idx=0; idx<imgs.length; idx++){
  const im=imgs[idx];
  const fn=im.file.replace(/\.(gif|jpg|jpeg|png)$/i,'.jpg');
  const b64=fs.readFileSync(DIR+'/img/small/'+fn).toString('base64');
  const bidx=await page.evaluate((a)=>{const norm=s=>s.replace(/\s+/g,' ').trim();const ed=document.querySelector('.ProseMirror');const nodes=[...ed.children];return nodes.findIndex(n=>norm(n.innerText).indexOf(a)>=0);}, im.anchor);
  if(bidx<0){ fails.push({idx,file:fn,reason:'no_anchor'}); log(idx,fn,'NO_ANCHOR'); continue; }
  const before=await page.locator('.ProseMirror img').count();
  const para=page.locator('.ProseMirror > *').nth(bidx);
  await para.scrollIntoViewIfNeeded();
  await para.click();
  await page.keyboard.press('End');
  await page.waitForTimeout(200);
  await page.evaluate((b64)=>{function bin(B){var s=atob(B);var a=new Uint8Array(s.length);for(var i=0;i<s.length;i++)a[i]=s.charCodeAt(i);return a;}var file=new File([bin(b64)],'fig.jpg',{type:'image/jpeg'});var ed=document.querySelector('.ProseMirror');ed.focus();var dt=new DataTransfer();dt.items.add(file);ed.dispatchEvent(new ClipboardEvent('paste',{clipboardData:dt,bubbles:true,cancelable:true}));},b64);
  // wait for upload (img count increments)
  let ok=false;
  for(let t=0;t<20;t++){ await page.waitForTimeout(600); if(await page.locator('.ProseMirror img').count()>before){ok=true;break;} }
  if(!ok){ fails.push({idx,file:fn,reason:'no_upload'}); log(idx,fn,'NO_UPLOAD'); }
  else log(idx,fn,'ok @block',bidx);
}

// trigger save: real edit at end
await page.locator('.ProseMirror').click();
await page.keyboard.press('End');
await page.keyboard.type(' ');
await page.waitForTimeout(300);
await page.keyboard.press('Backspace');
await page.waitForTimeout(12000);

const mid=await page.evaluate(()=>document.querySelector('.ProseMirror').querySelectorAll('img').length);
log('after inserts imgs=',mid,'fails=',fails.length);

// reload to verify persistence
await page.reload({waitUntil:'domcontentloaded'});
await page.waitForSelector('.ProseMirror',{timeout:30000});
await page.waitForTimeout(6000);
const persisted=await page.evaluate(()=>{const e=document.querySelector('.ProseMirror');return {imgs:e.querySelectorAll('img').length,h:e.querySelectorAll('h1,h2,h3').length};});
console.log('RESULT '+JSON.stringify({inserted:mid, fails, persistedAfterReload:persisted}));
await ctx.close();
