import { chromium } from 'playwright';
const b = await chromium.launch();
const ctx = await b.newContext({ viewport:{width:390,height:844}, deviceScaleFactor:2, isMobile:true, hasTouch:true });
const p = await ctx.newPage();
p.on('console', m => { if (m.type()==='error') console.log('ERR>', m.text().slice(0,160)); });
p.on('pageerror', e => console.log('PAGEERR>', String(e).slice(0,200)));
await p.goto('http://127.0.0.1:8799/', { waitUntil:'networkidle' });
await p.waitForTimeout(600);
console.log('title:', await p.title());
console.log('gate visible:', await p.locator('#ageGate').isVisible().catch(e=>'n/a'));
const info = await p.evaluate(() => {
  const scr = [...document.querySelectorAll('.screen')].map(s => s.id + (s.classList.contains('is-active')?'*':'') + ' hidden=' + s.hasAttribute('hidden'));
  return {
    screens: scr,
    GAMES: window.GAMES ? Object.keys(window.GAMES) : null,
    MODES: window.MODES ? Object.keys(window.MODES) : null,
    APP: window.APP ? Object.keys(window.APP) : null,
    docH: document.documentElement.scrollHeight,
    bodyW: document.body.clientWidth,
    appBox: (()=>{const a=document.getElementById('app');const r=a.getBoundingClientRect();return {w:r.width,h:r.height,top:r.top};})(),
    fonts: getComputedStyle(document.body).fontFamily,
  };
});
console.log(JSON.stringify(info, null, 2));
await b.close();
