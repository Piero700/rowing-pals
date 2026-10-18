const fs=require('fs'),path=require('path');
const {chromium}=require(process.env.HOME+'/.claude/plugins/marketplaces/marketing-skill/scripts/video/node_modules/playwright');
const [src,out,...names]=process.argv.slice(2);
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:393,height:3000},deviceScaleFactor:3});
for(const n of names){ await p.goto('file://'+path.resolve(src,n+'.html'));
  await p.evaluate(()=>{const s=document.querySelector('[data-screen-label]'); s.style.height='auto';
    for(const e of s.querySelectorAll('*')){const cs=getComputedStyle(e); if(cs.overflowY==='auto'){e.style.overflow='visible';e.style.flex='none';}}
    for(const e of s.querySelectorAll('nav')) e.remove();});
  const el=await p.$('[data-screen-label]'); await el.screenshot({path:path.join(out,n+'-tall.png')});}
await b.close();})();
