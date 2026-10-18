// Renders cleaned, fictional-data versions of the canvas artboards (only built features left in).
const fs=require('fs'),path=require('path');
const {chromium}=require(process.env.HOME+'/.claude/plugins/marketplaces/marketing-skill/scripts/video/node_modules/playwright');
const [src,out]=process.argv.slice(2); fs.mkdirSync(out,{recursive:true});
const GLOBAL=[['University of East Anglia’s boat club.','Wexmoor University’s boat club.'],['UEA Boat Club','Wexmoor UBC'],['Norwich','Wexmoor'],
 ['Piero Ciobanu','Rory Ellison'],['Tom Ashworth','Kit Mallory'],['Ollie Hart','Sam Adeyemi'],['Dan Okafor','Josh Penrose'],['Ben Carter','Theo Lindqvist'],
 ['Alice Whitfield','Hannah Brooke'],['Joe Fenwick','Ewan Doyle'],['Nina Bergström','Freya Lund'],['Marcus Reilly','Owen Pryce']];
const INIT={PC:'RE',TA:'KM',OH:'SA',DO:'JP',BC:'TL',AW:'HB',JF:'ED',NB:'FL',MR:'OP',SL:'MG'};
const CAL={removeText:[['Calendar','a,button']]};
const BOX={
 ReviewSession:{dist:['#dist'],time:['#time'],avg:['#avg'],rate:['#rate'],confirm:['button','Confirm'],check:['h2','Check the numbers'],total:['div','Workout total',1]},
 Main:{photo:['div','rear camera photo',1],photo2:['div','rear camera photo',1,1],caption:['p','New 2k PB'],react:['button','🎉'],comments:['button','3'],metrics:['dl']},
 LogWorkout:{rear:['div[style*="aspect-ratio:3/4"]'],front:['div[style*="width:27%"]'],shutter:['[aria-label="Take photo"]']},
 PostDetail:{comments:['h2','Comments']},
 PBHistoryLine:{chart:['svg[aria-label="PB progression chart"]'],pbcard:['div','Current personal best',1],faster:['span','49.7 faster'],history:['h2','Personal best history']},
 PBHistory:{chart:['svg[aria-label="PB progression chart"]'],pbcard:['div','Current personal best',1],faster:['span','49.7 faster']},
 Profile:{pred2k:['div','2K · PREDICTED TODAY',1],pred5k:['div','5K · PREDICTED TODAY',1],tops:['h2','Top personal bests']},
 VolBefore:{hero:['div','to move into',1],heroNum:['div','61,400',0],gap:['div','to move into',0],row1:['div[style*="min-height:72px"]',null,0],row2:['div[style*="min-height:72px"]',null,1]},
 VolAfter:{hero:['div','lead this group',1],gap:['div','lead this group',0],row1:['div[style*="min-height:72px"]',null,0],row2:['div[style*="min-height:72px"]',null,1]},
};
const S={
 Main:{...CAL,pre:[['Alice Whitfield','Rory Ellison'],['Sub-7 at last. New 2k PB.','New 2k PB. Finally under 6:45.'],['6:58.7','6:42.9'],['1:44.6','1:40.7'],['🎉 19','🎉 12'],['🔥 6','🔥 5']],
       init:{AW:'RE',PC:'KM'},post:[['Piero Ciobanu','Kit Mallory']],removeText:[['Calendar','a,button'],['with Sam and Joe','div,p']],exact:[['4','3']]},
 LogWorkout:{pre:[['REAR CAMERA',''],['FRONT','']]},
 ReviewSession:{removeText:[['Pieces','h2'],['Main workout label','div'],['Warm-up','div'],['Trained with','h2'],['Sam Cole','button'],['Clubmates who row','p']],
   exact:[['Training','2k test']],brandSwitch:true,
   pre:[['Steady state + rate ladder. Felt smooth until the last 2k.','New 2k PB. Finally under 6:45.'],['16,000','2,000'],['1:04:50 · 2:01.6 /500m · 19 spm','6:42.9 · 1:40.7 /500m · 30 spm']],values:[['12000','2000'],['47:28.8','6:42.9'],['1:58.7','1:40.7'],['19 spm','30 spm']]},
 PostDetail:{seq:[['6:58.7','6:42.9'],['#1 of 9 senior women · #2 of 31 overall','2nd overall, 2nd senior men'],['6:58.7','6:42.9'],['1:44.6','1:40.7'],['1:43.2','1:39.8'],['1:43.2','1:39.8'],['34 spm','33 spm'],['3:28.9','3:21.6'],['1:45.7','1:41.8'],['32 spm','31 spm'],['5:14.3','5:03.8'],['1:45.4','1:42.2'],['33 spm','31 spm'],['6:58.7','6:42.9'],['1:44.4','1:39.1'],['36 spm','35 spm']],
   pre:[['🎉 19','🎉 12'],['🔥 6','🔥 5'],['Alice Whitfield','Rory Ellison'],['Piero Ciobanu','Kit Mallory'],['Unreal. Sub-7!','Told you 6:45 was going.'],['4 total','3 total']],init:{AW:'RE',PC:'KM'},removeText:[['with Nina','p']]},
 PBHistoryLine:{file:'PBHistory',hideLine:true,pre:[['6:18.9','6:42.9'],['6:30.7','6:54.7'],['6:48.6','7:12.6'],['7:08.6','7:32.6'],['14 Aug 2026','22 Aug 2026'],['2 Jun 2026','6 Jun 2026'],['21 Mar 2026','18 Mar 2026'],['9 Jan 2026','12 Jan 2026']],chart:true},
 PBHistory:{pre:[['6:18.9','6:42.9'],['6:30.7','6:54.7'],['6:48.6','7:12.6'],['7:08.6','7:32.6'],['14 Aug 2026','22 Aug 2026'],['2 Jun 2026','6 Jun 2026'],['21 Mar 2026','18 Mar 2026'],['9 Jan 2026','12 Jan 2026']],chart:true},
 Profile:{...CAL,pre:[['@piero.ciobanu',''],['58.3k','61.4k'],['58.25','61.40'],['6:18.9','6:42.9'],['17:12.4','17:48.3'],['6:16.0','6:40.6'],['1:34.0 /500m','1:40.2 /500m'],['17:03.8','17:31.5'],['1:42.4 /500m','1:45.2 /500m']],
       removeText:[['Calendar','a,button'],['A 2k test in the next fortnight','__self'],['A long all-out piece','__self'],['@piero','__self']]},
 VolBefore:{file:'RankingsVolume',...CAL,pre:[['13,150m to move into #1','3,501m to move into #1'],['71,400','64,900'],['58,250','61,400'],['55,900','55,200'],['47,300','48,600'],['39,800','41,300']]},
 VolAfter:{file:'RankingsVolume',...CAL,swapRows:true,pre:[['You · #2','You · #1'],['13,150m to move into #1','You lead this group'],['Group leader · Tom Ashworth · 71,400m','Group leader · You · 66,400m'],['55,900','55,200'],['47,300','48,600'],['39,800','41,300']]},
 RankingsTests:{...CAL,pre:[['6:12.4','6:31.2'],['You’re 6.5s behind','You’re 11.7s behind'],['17:12.4','17:48.3'],['6:18.9','6:42.9'],['1:28.4','1:33.1'],['3:02.6','3:14.0'],['35:48.0','37:02.5'],['1,214m','1,148m'],['8,410m','7,960m'],['16,220m','15,410m']]},
 YourCrew:{},
 ClubTestBoard:{pre:[['Alice Whitfield','Kit Mallory'],['Tom Ashworth','Sam Adeyemi']],init:{AW:'KM',TA:'SA'}},
 CoachRowers:{pre:[['58.3','61.4'],['6:18.9','6:42.9'],['6:16 ±4s','6:40 ±4s'],['6:12.4','6:31.2'],['6:10 ±3s','6:29 ±3s']],removeText:[['attendance','__attend']],removeNav:true},
};
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:393,height:3000},deviceScaleFactor:3});
for(const [name,o] of Object.entries(S)){
  await p.goto('file://'+path.resolve(src,(o.file||name)+'.html'));
  await p.evaluate(({o,GLOBAL,INIT})=>{
    const root=document.querySelector('[data-screen-label]');
    const texts=()=>{const w=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);const a=[];while(w.nextNode())a.push(w.currentNode);return a;};
    const rep=(list)=>{for(const t of texts())for(const [a,z] of list) if(t.nodeValue.includes(a)) t.nodeValue=t.nodeValue.split(a).join(z);};
    // removals by text
    for(const [txt,sel] of (o.removeText||[])){
      const hits=[...root.querySelectorAll('*')].filter(e=>e.textContent.includes(txt)&&![...e.children].some(c=>c.textContent.includes(txt)));
      for(const h of hits){ let el=h;
        if(sel==='__self'){} else if(sel==='__attend'){ el=h.parentElement; if(/^\d+%/.test(el.textContent.trim())===false && el.parentElement) el=el; }
        else if(sel==='nav'){ el=h.closest('nav')||h; } else { el=h.closest(sel)||h; }
        el.remove(); }
    }
    if(o.removeNav) root.querySelectorAll('nav').forEach(n=>n.remove());
    if(o.swapRows){ // VolAfter: you take #1
      rep([['Tom Ashworth','@@1'],['71,400','66,400'],['Piero Ciobanu','Kit Mallory'],['58,250','64,900'],['@@1','Rory Ellison']]);
      for(const t of texts()){ if(t.nodeValue==='TA') t.nodeValue='RE'; else if(t.nodeValue==='PC') t.nodeValue='KM'; }
      // hero number (first 64,900 is the row; hero shows own total)
      const hero=[...root.querySelectorAll('*')].find(e=>e.childNodes[0]&&e.childNodes[0].nodeValue==='64,900'&&parseFloat(getComputedStyle(e).fontSize)>25);
      if(hero) hero.childNodes[0].nodeValue='66,400';
      [...root.querySelectorAll('div')].filter(d=>d.getAttribute('style')?.includes('background:var(--brandSoft)')&&d.textContent.includes('Kit Mallory')).forEach(d=>d.style.background='');
    }
    if(o.seq){ let j=0; for(const t of texts()){ if(j<o.seq.length && t.nodeValue.trim()===o.seq[j][0]){ t.nodeValue=t.nodeValue.replace(o.seq[j][0],o.seq[j][1]); j++; } } if(j<o.seq.length) console.log('SEQ STOPPED AT',j); }
    rep(o.pre||[]);
    for(const t of texts()){ const v=t.nodeValue.trim(); const m=(o.init&&o.init[v])||INIT[v]; if(m) t.nodeValue=t.nodeValue.replace(v,m); for(const [a,z] of (o.exact||[])) if(v===a && t.parentElement.closest('button,a,span')) t.nodeValue=t.nodeValue.replace(a,z); }
    rep(o.post||[]); rep(GLOBAL);
    for(const [a,z] of (o.values||[])) root.querySelectorAll('input').forEach(i=>{ if(i.getAttribute('value')===a){i.setAttribute('value',z);i.value=z;} });
    if(o.chart){ const svg=root.querySelector('svg[aria-label="PB progression chart"]');
      const pts=[[64,38.5],[145.4,70.1],[245.6,98.5],[342,117.2]]; const d=pts.map((q,i)=>(i?'L':'M')+q[0]+' '+q[1]).join(' ');
      const paths=svg.querySelectorAll('path'); paths[0].setAttribute('d',d+' L342 212 L64 212 Z'); paths[1].setAttribute('d',d);
      svg.querySelectorAll('circle').forEach(c=>c.remove());
      for(const [i,q] of pts.entries()){ const c=document.createElementNS('http://www.w3.org/2000/svg','circle'); c.setAttribute('cx',q[0]);c.setAttribute('cy',q[1]);
        c.setAttribute('r',i===3?6:4); c.setAttribute('fill',i===3?'var(--brand)':'var(--card)'); c.setAttribute('stroke','var(--brand)'); c.setAttribute('stroke-width',2); svg.appendChild(c); }
      const labs=['7:43','7:13','6:43','6:13','5:43']; [...svg.querySelectorAll('text')].filter(t=>/^\d:\d\d$/.test(t.textContent)).forEach((t,i)=>t.textContent=labs[i]); }
    if(o.brandSwitch){ root.querySelectorAll('span').forEach(x=>{ if((x.getAttribute('style')||'').includes('background:var(--good)')) x.style.background='var(--brand)'; }); }
    if(o.hideLine){ const svg=root.querySelector('svg[aria-label="PB progression chart"]'); const ps=svg.querySelectorAll('path'); ps[0].style.display='none'; ps[1].style.display='none'; svg.querySelectorAll('circle').forEach(c=>c.style.display='none'); }
    root.style.height='auto';
    for(const e of root.querySelectorAll('*')){const cs=getComputedStyle(e); if(cs.overflowY==='auto'){e.style.overflow='visible';e.style.flex='none';}}
  },{o,GLOBAL,INIT});
  const boxes=await p.evaluate((spec)=>{ const root=document.querySelector('[data-screen-label]'); const R=root.getBoundingClientRect(); const out={};
    for(const [k,[sel,txt,nth,occ]] of Object.entries(spec||{})){
      let e;
      if(txt){ const all=[...root.querySelectorAll('*')].filter(x=>x.textContent.toLowerCase().includes(txt.toLowerCase()));
        const deep=all.filter(x=>![...x.children].some(c=>c.textContent.toLowerCase().includes(txt.toLowerCase())))[occ||0];
        e=deep&&(deep.closest(sel)||deep); for(let i=0;i<(nth||0)&&e;i++) e=e.parentElement; }
      else e=[...root.querySelectorAll(sel)][nth||0];
      if(!e){out[k]=null;continue;} const r=e.getBoundingClientRect(); out[k]=[r.left-R.left,r.top-R.top,r.width,r.height].map(v=>Math.round(v*3)); }
    return out; }, BOX[name]);
  fs.writeFileSync(path.join(out,name+'.boxes.json'),JSON.stringify(boxes));
  const el=await p.$('[data-screen-label]'); await el.screenshot({path:path.join(out,name+'.png')});
  fs.writeFileSync(path.join(out,name+'.txt'),await el.innerText());
}
await b.close();})();
