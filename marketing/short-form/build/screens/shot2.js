const fs=require('fs'),path=require('path');
const {chromium}=require(process.env.HOME+'/.claude/plugins/marketplaces/marketing-skill/scripts/video/node_modules/playwright');
const [src,out]=process.argv.slice(2);
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:393,height:1400},deviceScaleFactor:3});
for(const f of fs.readdirSync(src).filter(f=>f.endsWith('.html'))){
  await p.goto('file://'+path.resolve(src,f));
  const el=await p.$('[data-screen-label]'); const n=f.replace('.html','');
  await el.screenshot({path:path.join(out,n+'.png')}); fs.writeFileSync(path.join(out,n+'.txt'),await el.innerText());}
await b.close();})();
