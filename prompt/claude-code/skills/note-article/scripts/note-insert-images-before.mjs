import { chromium } from 'playwright-core';
import fs from 'fs'; import os from 'os';
const KEY='naba3aaebd80c'; const COOKIE=process.env.NOTE_COOKIE;
const HOME=os.homedir(); const DIR=HOME+'/tmp/hbl-note';
const udir=DIR+'/pw-profile';
const log=(...a)=>console.log('[fx2]',...a);
// insert BEFORE the following-paragraph anchor
const FIX=[
 {file:'book-chatsworth.jpg', after:'そのどちらでもない、時間との関係を拒否した建物'},
 {file:'book-monticello.jpg', after:'そのどちらでもない、時間との関係を拒否した建物'},
 {file:'marin-civic.jpg', after:'なぜこうなるのか'},
 {file:'ca-doro.jpg', after:'建物は我々より大きく堅固だから'},
];
const ctx=await chromium.launchPersistentContext(udir,{channel:'chrome',headless:false,viewport:null,args:['--no-first-run','--no-default-browser-check']});
await ctx.addCookies([{name:'_note_session_v5',value:COOKIE,domain:'.note.com',path:'/',httpOnly:true,secure:true,sameSite:'Lax'}]);
const page=ctx.pages()[0]||await ctx.newPage();
await page.goto(`https://editor.note.com/notes/${KEY}/edit/`,{waitUntil:'domcontentloaded',timeout:60000});
await page.waitForSelector('.ProseMirror',{timeout:30000});
await page.waitForTimeout(5000);
log('start imgs=', await page.locator('.ProseMirror img').count());
const done=[];
for(const f of FIX){
  const fn=f.file.replace(/\.(gif|jpg|jpeg|png)$/i,'.jpg');
  const b64=fs.readFileSync(DIR+'/img/small/'+fn).toString('base64');
  const bidx=await page.evaluate((a)=>{const norm=s=>s.replace(/\s+/g,' ').trim();const ed=document.querySelector('.ProseMirror');const nodes=[...ed.children];return nodes.findIndex(n=>norm(n.innerText).indexOf(a)>=0);}, f.after);
  if(bidx<0){ log('NO_ANCHOR',fn,f.after); done.push(fn+':no_anchor'); continue; }
  const before=await page.locator('.ProseMirror img').count();
  const para=page.locator('.ProseMirror > *').nth(bidx);
  await para.scrollIntoViewIfNeeded();
  await para.click();
  await page.keyboard.press('Home');
  await page.waitForTimeout(300);
  await page.evaluate((b64)=>{function bin(B){var s=atob(B);var a=new Uint8Array(s.length);for(var i=0;i<s.length;i++)a[i]=s.charCodeAt(i);return a;}var file=new File([bin(b64)],'fig.jpg',{type:'image/jpeg'});var ed=document.querySelector('.ProseMirror');ed.focus();var dt=new DataTransfer();dt.items.add(file);ed.dispatchEvent(new ClipboardEvent('paste',{clipboardData:dt,bubbles:true,cancelable:true}));},b64);
  let ok=false;
  for(let t=0;t<40;t++){ await page.waitForTimeout(700); if(await page.locator('.ProseMirror img').count()>before){ok=true;break;} }
  log(fn, ok?('ok before@'+bidx):'NO_UPLOAD');
  done.push(fn+':'+(ok?'ok':'no_upload'));
}
await page.locator('.ProseMirror').click();
await page.keyboard.press('End'); await page.keyboard.type(' '); await page.waitForTimeout(300); await page.keyboard.press('Backspace');
await page.waitForTimeout(12000);
await page.reload({waitUntil:'domcontentloaded'});
await page.waitForSelector('.ProseMirror',{timeout:30000});
await page.waitForTimeout(6000);
const fin=await page.evaluate(()=>{const e=document.querySelector('.ProseMirror');return {imgs:e.querySelectorAll('img').length,h:e.querySelectorAll('h1,h2,h3').length};});
console.log('RESULT '+JSON.stringify({done, persisted:fin}));
await ctx.close();
