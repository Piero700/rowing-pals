/* Rowing Pals — phone screen mockups as HTML strings, drawn to match the app as of 2026-11-06.
   Usage: <div class="phone" data-screen="feed"></div>, then RPUI.mount().
   Set RPUI.base to the folder holding icon-256.png before mounting.
   Names, clubs and numbers are sample data. */
(function () {
  const RPUI = { base: 'assets/' };

  // The app's own icons, from docs/design/tools/rp_icons.py (decision 80).
  const ICONS = {
    home: '<path d="m3 11 9-7 9 7v9h-6v-6H9v6H3z"/>',
    rankings: '<path d="M5 20v-7h4v7M10 20V7h4v13M15 20v-10h4v10"/>',
    calendar: '<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M3 10h18M8 3v4M16 3v4"/>',
    profile: '<path d="M4.5 21a7.5 7.5 0 0 1 15 0"/><circle cx="12" cy="8" r="4"/>',
    people: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.9M16 3.1a4 4 0 0 1 0 7.8"/>',
    stopwatch: '<circle cx="12" cy="13" r="8"/><path d="M12 9v4l2.5 2.5M9.5 2.5h5"/>',
    boat: '<path d="M12 2c2 3 2.6 6 2.6 10S14 19 12 22c-2-3-2.6-6-2.6-10S10 5 12 2z"/><path d="M9.6 8 4 6.5M14.4 11 20 9.5M9.6 14 4 12.5M14.4 17 20 15.5"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    comment: '<path d="M21 15a4 4 0 0 1-4 4H8l-5 3V7a4 4 0 0 1 4-4h10a4 4 0 0 1 4 4z"/>',
    share: '<path d="M12 16V3M7 8l5-5 5 5M5 13v7h14v-7"/>',
    chevronRight: '<path d="m9 18 6-6-6-6"/>',
    chevronLeft: '<path d="m15 18-6-6 6-6"/>',
    close: '<path d="M18 6 6 18M6 6l12 12"/>',
    flipCamera: '<path d="M7 7h11l-3-3M17 17H6l3 3"/>',
    clipboard: '<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4V3h6v1M9 10h6M9 14h6M9 18h3"/>',
    camera: '<path d="M4 8.5A2.5 2.5 0 0 1 6.5 6H8l1.5-2h5L16 6h1.5A2.5 2.5 0 0 1 20 8.5v9a2.5 2.5 0 0 1-2.5 2.5h-11A2.5 2.5 0 0 1 4 17.5z"/><circle cx="12" cy="13" r="3.5"/>',
    scan: '<path d="M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2M8 10h8M8 14h5"/>',
    megaphone: '<path d="M3 10v4a1 1 0 0 0 1 1h3l6 4V5L7 9H4a1 1 0 0 0-1 1z"/><path d="M16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12"/>',
    water: '<path d="M2 15c2.5 0 2.5-2 5-2s2.5 2 5 2 2.5-2 5-2 2.5 2 5 2M2 20c2.5 0 2.5-2 5-2s2.5 2 5 2 2.5-2 5-2 2.5 2 5 2M2 10c2.5 0 2.5-2 5-2s2.5 2 5 2 2.5-2 5-2 2.5 2 5 2"/>',
    pencil: '<path d="M4 20h4L19 9a2.8 2.8 0 0 0-4-4L4 16z"/><path d="m13.5 6.5 4 4"/>',
    check: '<path d="M5 12.5 10 17l9-10"/>',
    flag: '<path d="M5 21V4M5 4h11l-2 4 2 4H5"/>',
    lock: '<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>',
    star: '<path d="m12 3.5 2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.8l-5.2 2.8 1-5.8-4.3-4.1 5.9-.9z"/>',
    shield: '<path d="M12 3 5 6v5.5c0 4.3 2.9 7.6 7 9.5 4.1-1.9 7-5.2 7-9.5V6z"/><path d="m9 12 2.2 2.2L15 10"/>'
  };
  const ico = (name, size = 20) => `<svg class="ico" width="${size}" height="${size}" viewBox="0 0 24 24" aria-hidden="true">${ICONS[name]}</svg>`;
  RPUI.ico = ico;

  const CLUB = 'Riverside BC';
  const tick = `<span class="rp-tick">${ico('shield', 13)}</span>`;
  const initials = (n) => n.split(' ').map(w => w[0]).join('');

  const statusBar = () => `
    <div class="rp-island"></div>
    <div class="rp-sb"><span class="num">9:41</span><span class="rp-sb-r">
      <svg viewBox="0 0 18 12"><rect x="0" y="8" width="3" height="4" rx="1"/><rect x="5" y="5.5" width="3" height="6.5" rx="1"/><rect x="10" y="3" width="3" height="9" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/></svg>
      <svg viewBox="0 0 16 12"><path d="M8 2.5c2.3 0 4.4.9 6 2.4l1.3-1.4A10.4 10.4 0 0 0 8 .6 10.4 10.4 0 0 0 .7 3.5L2 4.9a8.5 8.5 0 0 1 6-2.4zm0 3.8c1.3 0 2.5.5 3.4 1.3l1.3-1.4A6.6 6.6 0 0 0 8 4.4c-1.8 0-3.4.7-4.7 1.8l1.3 1.4c.9-.8 2.1-1.3 3.4-1.3zM8 12l2.3-2.4a3.3 3.3 0 0 0-4.6 0z"/></svg>
      <svg viewBox="0 0 27 12"><rect x=".5" y=".5" width="23" height="11" rx="3.5" fill="none" stroke="currentColor" opacity=".5"/><rect x="2" y="2" width="18" height="8" rx="2"/><rect x="25" y="4" width="2" height="4" rx="1" opacity=".5"/></svg>
    </span></div>`;

  const tabBar = (set, active) => `<div class="rp-tabs"><div class="rp-tabpill rp-glass">${set.map(([k, l]) =>
    `<div class="rp-tab ${k === active ? 'on' : ''}">${ico(k, 20)}${l}</div>`).join('')}</div>
    <div class="rp-log">${ico('plus', 24)}</div></div>`;
  const tabs = (a) => tabBar([['home', 'Feed'], ['rankings', 'Rankings'], ['calendar', 'Calendar'], ['profile', 'Profile']], a);
  const coachTabs = (a) => tabBar([['people', 'Rowers'], ['stopwatch', 'Workouts'], ['boat', 'Boats'], ['calendar', 'Calendar']], a);

  const seg = (opts, on, cls = '') => `<div class="rp-seg ${cls}">${opts.map((o, i) => `<span class="${i === on ? 'on' : ''}">${o}</span>`).join('')}</div>`;
  const row = (l, v) => `<div class="rp-row"><span>${l}</span><span class="val num">${v}</span></div>`;
  const linkRow = (icon, title) => `<div class="rp-row"><span class="rp-link">${ico(icon, 16)}${title}</span></div>`;

  // The erg monitor as it appears in the rear-camera photo.
  RPUI.pm5 = (o = {}) => {
    const d = Object.assign({ time: '47:28.8', metres: '12000', split: '1:58.7', rate: '20',
      rows: [['3000', '2:00.1', '19'], ['6000', '1:59.0', '20'], ['9000', '1:58.4', '20'], ['12000', '1:57.3', '21']] }, o);
    return `<div class="pm5"><div class="pm5-brand">CONCEPT2 · PM5</div><div class="pm5-lcd">
      <div class="pm5-row"><span>time</span><span>meters</span></div>
      <div class="pm5-row pm5-big"><b data-ocr style="--d:.0s">${d.time}</b><b data-ocr style="--d:.15s">${d.metres}</b></div>
      <div class="pm5-row"><span>/500m</span><span>s/m</span></div>
      <div class="pm5-row pm5-mid"><b data-ocr style="--d:.3s">${d.split}</b><b data-ocr style="--d:.45s">${d.rate}</b></div>
      <div class="pm5-table">${d.rows.map(r => `<div><span>${r[0]}</span><span>${r[1]}</span><span>${r[2]}</span></div>`).join('')}</div>
    </div><div class="pm5-btns"><i></i><i></i><i></i><i></i><i></i></div></div>`;
  };

  const selfie = () => `<div class="rp-selfie" style="background-image:url(${RPUI.base}icon-256.png)"></div>`;

  const TEST_PM5 = { time: '7:04.1', metres: '2000', split: '1:46.0', rate: '34',
    rows: [['500', '1:44.2', '36'], ['1000', '1:46.9', '33'], ['1500', '1:47.3', '33'], ['2000', '1:45.6', '35']] };

  // A post, as FeedCardView draws it: head, 4:3 photo, the lead piece's numbers, the workout link, actions.
  RPUI.feedCard = (o = {}) => {
    const d = Object.assign({
      name: 'Sam Cole', ago: '3 min', distance: '12,000m', time: '47:28.8', split: '1:58.7', pb: false,
      withWho: 'Joe and Priya', label: 'UT2', meta: '16,000m · 1:04:50 · 3 pieces', reacts: ['🔥 8', '💪 4'], comments: 3, pm5: {}
    }, o);
    return `<div class="rp-card ${d.pb ? 'pb' : ''}">
      <div class="rp-card-head"><div class="rp-av lg">${initials(d.name)}</div>
        <div class="who"><div class="name">${d.name}</div><div class="sub">${CLUB}${tick}</div></div>
        <span class="when num">${d.ago}</span></div>
      <div class="rp-media">${RPUI.pm5(d.pm5)}${selfie()}${d.pb ? '<div class="rp-pbflag">PB</div>' : ''}</div>
      <div class="rp-metrics num">
        <div><i>Distance</i><b data-hero-metres>${d.distance}</b></div>
        <div><i>Time</i><b>${d.time}</b></div>
        <div><i>/500m</i><b>${d.split}</b></div>
      </div>
      ${d.withWho ? `<div class="rp-with">with <b>${d.withWho}</b></div>` : ''}
      <div class="rp-worklink"><div><b class="num">${d.label} · Main workout</b><span class="num">${d.meta}</span></div>${ico('chevronRight', 16)}</div>
      <div class="rp-actions"><span class="rp-pill num">${ico('comment', 16)}${d.comments}</span>${d.reacts.map(r => `<span class="rp-pill num">${r}</span>`).join('')}<span class="grow"></span><span class="rp-round rp-glass">${ico('share', 18)}</span></div>
    </div>`;
  };

  /* ---------- Boats on their side, stern left (decisions 82, 86, 88; SidewaysBoatParts.swift) ---------- */
  const B = { hh: 9, reach: 13, spread: 11, lead: 4, angle: 38, outb: 40, inb: 13, blade: 17, bladeW: 6.5, ball: 2.8, seat: 10.5, cox: 16, y: 74, nameY: 140, h: 174 };
  const TYPES = { '8+': { seats: 8, cox: true }, '4+': { seats: 4, cox: true }, '4x': { seats: 4, sculls: true }, '2x': { seats: 2, sculls: true } };

  function oar(x, up) {
    const s = up ? -1 : 1, edge = B.y + s * B.hh * .85;
    const px = x + B.lead, py = B.y + s * (B.hh + B.reach);
    const a = B.angle * Math.PI / 180, dx = Math.sin(a), dy = s * Math.cos(a);
    const bx = px + dx * B.outb, by = py + dy * B.outb, hx = px - dx * B.inb, hy = py - dy * B.inb;
    // The spoon's face widens from the neck and squares off at the tip, towards the stern.
    let nx = -dy, ny = dx;
    if (nx > 0) { nx = -nx; ny = -ny; }
    const pt = (al, ac) => `${(bx + dx * B.blade * al + nx * ac).toFixed(1)} ${(by + dy * B.blade * al + ny * ac).toFixed(1)}`;
    const face = [[0, .18], [.18, .78], [.55, 1], [.88, .92], [1, .45]];
    const spoon = 'M' + face.map(([al, sh]) => pt(al, B.bladeW * sh * .85)).join('L') + 'L' + [1, .5, 0].map(al => pt(al, -B.bladeW * .22)).join('L') + 'Z';
    return `<path d="M${px - B.spread} ${edge}L${px} ${py}L${px + B.spread} ${edge}M${px} ${edge}L${px} ${py}" fill="none" stroke="#BBC0CE" stroke-width="1.3" stroke-linejoin="round"/>
      <line x1="${hx.toFixed(1)}" y1="${hy.toFixed(1)}" x2="${bx.toFixed(1)}" y2="${by.toFixed(1)}" stroke="#F7F8FC" stroke-width="1.9" stroke-linecap="round"/>
      <circle cx="${px}" cy="${py}" r="1.8" fill="#BBC0CE"/><path d="${spoon}" fill="#F7F8FC"/>`;
  }

  // names: { 0: cox, 8, 7, … 1 } first names by seat. opts: { type, mine (seat), colour, deck }.
  RPUI.boat = (names, opts = {}) => {
    const type = opts.type || '4+', t = TYPES[type], order = [];
    if (t.cox) order.push(0);
    for (let s = t.seats; s >= 1; s--) order.push(s);
    const xs = {};
    let x = 38;
    order.forEach((s, i) => { xs[s] = x; if (i < order.length - 1) x += (s === 0) ? 46 : 64; });
    const W = x + 50, L = 3, R = W - 3, len = R - L, hh = B.hh, y = B.y;
    const hull = `M${L} ${y}C${L + len * .07} ${y - hh * .4} ${L + len * .28} ${y - hh} ${L + len * .5} ${y - hh}C${L + len * .72} ${y - hh} ${R - len * .07} ${y - hh * .4} ${R} ${y}C${R - len * .07} ${y + hh * .4} ${L + len * .72} ${y + hh} ${L + len * .5} ${y + hh}C${L + len * .28} ${y + hh} ${L + len * .07} ${y + hh * .4} ${L} ${y}Z`;
    const seated = order.filter(s => s !== 0);
    const dl = xs[seated[0]] - 26, dh = xs[seated[seated.length - 1]] + 26;
    let g = `<svg class="rp-boat-svg" style="max-width:${W}px" viewBox="0 0 ${W} ${B.h}" role="img" aria-label="A ${type} on its side, stern on the left">
      <path d="${hull}" fill="${opts.colour || '#4C505B'}" stroke="#BBC0CE" stroke-width="1.2"/>
      <rect x="${dl}" y="${y - hh * .55}" width="${dh - dl}" height="${hh * 1.1}" rx="${hh * .55}" fill="${opts.deck || '#292C34'}"/>
      <circle cx="${R - 1.5 - B.ball}" cy="${y}" r="${B.ball}" fill="#BBC0CE"/>`;
    seated.forEach(s => {
      if (t.sculls) g += oar(xs[s], true) + oar(xs[s], false);
      else g += oar(xs[s], s % 2 === 0);   // stroke side up: the crew faces the stern
    });
    order.forEach((s, i) => {
      const mine = s === opts.mine, cx = xs[s];
      const mark = s === 0 ? 'C' : s === 1 ? 'B' : s === t.seats ? 'S' : s;
      const fill = mine ? '#91B8FF' : '#1B1C21', stroke = mine ? '#91B8FF' : '#F7F8FC', txt = mine ? '#0B1A35' : '#F7F8FC';
      g += s === 0
        ? `<rect x="${cx - B.cox / 2}" y="${y - B.cox / 2}" width="${B.cox}" height="${B.cox}" rx="5" fill="${fill}" stroke="${stroke}" stroke-width="1.3"/>`
        : `<circle cx="${cx}" cy="${y}" r="${B.seat}" fill="${fill}" stroke="${stroke}" stroke-width="1.3"/>`;
      g += `<text class="rp-bm" x="${cx}" y="${y}" fill="${txt}">${mark}</text>`;
      const role = s === 0 ? 'Cox' : s === t.seats ? 'Stroke' : s === 1 ? 'Bow' : '';
      g += `<g class="bn-in" style="--d:${(.15 + i * .1).toFixed(2)}s"><text class="rp-bn ${mine ? 'mine' : ''}" x="${cx}" y="${B.nameY}">${names[s] || ''}</text>${role ? `<text class="rp-br" x="${cx}" y="${B.nameY + 16}">${role}</text>` : ''}</g>`;
    });
    return g + '</svg>';
  };
  RPUI.crew = { 0: 'Freya', 8: 'Sam', 7: 'Marcus', 6: 'Joe', 5: 'Tom', 4: 'Ella', 3: 'Ollie', 2: 'Nina', 1: 'Priya' };
  const FOUR = { 0: 'Freya', 4: 'Sam', 3: 'Tom', 2: 'Joe', 1: 'Marcus' };
  const ORANGE = { colour: '#C4622D', deck: '#7A4A2E' };

  RPUI.feedBoatCard = () => `<div class="rp-fc">
    <div style="display:flex;justify-content:space-between;align-items:center"><span class="rp-kicker up num">Your boat · Sat 07:00</span><span class="rp-chip brand">${ico('water', 13)}4+</span></div>
    <h4>You’re in seat 2 in M1 four</h4><p>From Sarah Lin · stroke-rigged · meet at Boathouse</p>
    <div class="rp-ends"><span>‹ STERN</span><span>BOW ›</span></div>
    ${RPUI.boat(FOUR, Object.assign({ type: '4+', mine: 2 }, ORANGE))}</div>`;

  RPUI.challengeCard = (kicker, title, line, pct, done) => `<div class="rp-fc"><span class="rp-kicker num">${kicker}</span><h4>${title}</h4>
    <p class="num" style="color:var(--ink);font-weight:600">${line}</p><div class="rp-track"><i class="${done ? 'done' : ''}" style="width:${pct}%"></i></div></div>`;

  const screens = {};

  screens.feed = () => `${statusBar()}<div class="rp-body">
    ${seg(['Following', 'Club'], 0, 'feed')}
    <p class="rp-hint" style="text-align:left;margin:10px 2px">You and people you follow</p>
    ${RPUI.feedCard()}
    ${RPUI.feedCard({ name: 'Alice Whitfield', ago: '1h', distance: '2,000m', time: '7:04.1', split: '1:46.0', pb: true, withWho: '', label: 'AN', meta: '2,000m · 7:04.1 · 1 piece', pm5: TEST_PM5 })}
  </div>${tabs('home')}`;

  screens.pb = () => `${statusBar()}<div class="rp-body">
    ${seg(['Following', 'Club'], 1, 'feed')}
    <p class="rp-hint" style="text-align:left;margin:10px 2px">${CLUB}</p>
    ${RPUI.feedCard({ name: 'Alice Whitfield', ago: 'just now', distance: '2,000m', time: '7:04.1', split: '1:46.0', pb: true, withWho: '', label: 'AN', meta: '2,000m · 7:04.1 · 1 piece', reacts: ['🔥 24', '👏 17'], comments: 11, pm5: TEST_PM5 })}
    ${RPUI.challengeCard('Challenge · 12 days left', '100km in November', '62.4 / 100km', 62)}
  </div>${tabs('home')}`;

  screens.yourBoat = () => `${statusBar()}<div class="rp-body">
    ${seg(['Following', 'Club'], 1, 'feed')}
    <p class="rp-hint" style="text-align:left;margin:10px 2px">${CLUB}</p>
    <div class="rp-ann">${ico('megaphone', 20)}<div><b>Boathouse closed on Sunday</b><span>Sarah Lin · 2h ago</span></div></div>
    ${RPUI.feedBoatCard()}
    ${RPUI.challengeCard('Challenge · 12 days left', '100km in November', '62.4 / 100km', 62)}
    <div class="rp-fc" style="padding-bottom:4px"><span class="rp-kicker num">Your coach noted your scores</span><h4>4 × 500m</h4><p class="num">Split 1:44.6 · 1:45.2 · 1:45.9 · 1:44.1</p>
      <div style="margin:8px -14px 0;border-top:.5px solid var(--line)"><div class="rp-row" style="padding-left:14px"><span class="rp-link">${ico('plus', 16)}Log your session</span></div></div></div>
  </div>${tabs('home')}`;

  screens.capture = () => `${statusBar()}<div class="rp-body">
    <div class="rp-nav"><span class="back">${ico('close', 20)}</span><b>Log workout</b><span></span></div>
    <div class="rp-frame">${RPUI.pm5()}<div class="rp-corners"><i></i><i></i><i></i><i></i></div>${selfie()}</div>
    <div class="rp-group" style="margin-top:10px"><div class="rp-row"><span>Selfie</span><span class="rp-switch"></span></div></div>
    <p class="rp-hint" style="margin-top:8px">Front + rear · No time limit</p>
    <div class="rp-shutter rp-glass"><i></i></div>
    <p class="rp-hint" style="color:var(--brand);font-weight:600">Enter session manually</p>
  </div>`;

  screens.review = () => {
    const seg1 = (tag, nums, cls = '') => `<div class="rp-row rp-piece-row"><span class="tag ${tag === 'Main' ? 'main' : ''}">${tag}</span><span class="nums num">${nums.map((n, i) => `<span class="${cls && i === 1 ? cls : ''}">${n}</span>`).join('')}</span></div>`;
    return `${statusBar()}<div class="rp-body">
      <div class="rp-nav"><span class="back">${ico('chevronLeft', 20)}</span><b>Review session</b><span>Post</span></div>
      <div class="rp-section" style="margin-top:0">Splits</div>
      <div class="rp-group">${seg1('Warmup', ['3,000m', '12:41.0', '2:06.8', '20'])}${seg1('Main', ['2,000m', '7:04.1', '1:46.0', '34'], 'low')}${seg1('Cooldown', ['2,000m', '9:14.7', '2:18.7', '18'])}</div>
      <div class="rp-detect"><b>This looks like a 2k test.</b><p>Post it as a 2k test and add it to the leaderboard?</p>
        <div class="btns"><span class="rp-btn">No</span><span class="rp-btn primary">Yes</span></div></div>
      <div class="rp-group">
        <div class="rp-row"><span>Include on leaderboards</span><span class="rp-switch"></span></div>
        <div class="rp-row"><span>Count for Club 2k day</span><span class="rp-switch"></span></div>
        ${row('Trained with', 'Joe and Priya')}
        ${row('Visible to', 'My Club')}
        ${row('Effort', 'Maximal')}
      </div>
      <div class="rp-group"><div class="rp-row" style="color:var(--ink3)"><span>Caption</span></div></div>
    </div>`;
  };

  const lbRow = (r, i) => `<div class="rp-row rp-lb ${i === 0 ? 'first' : ''}"><span class="pos num">${i + 1}</span><span class="rp-av">${initials(r.n)}</span>
    <span class="who"><b>${r.n}${r.me ? ' · You' : ''}</b><span>${CLUB}</span></span><span class="m num">${r.m}${r.mv ? `<span class="rp-move">${r.mv}</span>` : ''}${r.s ? `<span>${r.s}</span>` : ''}</span></div>`;

  RPUI.volumeRows = [
    { n: 'Tom Ashworth', m: '128,400m' },
    { n: 'Joe Fenwick', m: '121,900m' },
    { n: 'Sam Cole', m: '116,250m', me: 1 },
    { n: 'Marcus Reilly', m: '104,800m' },
    { n: 'Ollie Grant', m: '88,300m' }
  ];

  screens.rankings = () => `${statusBar()}<div class="rp-body">
    <div class="rp-title">Rankings</div>
    ${seg(['Volume', 'Test results', 'Challenges'], 0)}
    <div class="rp-filter"><span>Senior men · My club</span><span class="rp-chip brand">Filters</span></div>
    ${seg(['Week', 'Month', 'Year'], 0)}
    <div class="rp-hero"><div class="ov num">Weekly volume · You · #3</div><div class="big num">116,250 <small>m</small></div><div class="sen num">5,650m to move into #2</div><div class="lead num">Group leader · Tom Ashworth · 128,400m</div></div>
    <div class="rp-group">${RPUI.volumeRows.map(lbRow).join('')}</div>
  </div>${tabs('rankings')}`;

  screens.tests = () => `${statusBar()}<div class="rp-body">
    <div class="rp-nav"><span class="back">${ico('chevronLeft', 20)}</span><b>2k test</b><span></span></div>
    <div class="rp-filter" style="margin-top:0"><span>Senior men · My club</span><span class="rp-chip brand">Filters</span></div>
    <div class="rp-hero"><div class="ov">Best in your group</div><div class="big num">6:04.2</div><div class="sen num">You’re 14.7s behind</div></div>
    <div class="rp-group">${[['Tom Ashworth', '6:04.2', '1:31.0'], ['Joe Fenwick', '6:11.7', '1:32.9'], ['Sam Cole', '6:18.9', '1:34.7'], ['Marcus Reilly', '6:31.5', '1:37.9'], ['Ollie Grant', '7:05.2', '1:46.3']]
      .map((r, i) => lbRow({ n: r[0], m: r[1], s: `${r[2]} /500m`, me: r[0] === 'Sam Cole' }, i)).join('')}</div>
  </div>${tabs('rankings')}`;

  screens.challenges = () => `${statusBar()}<div class="rp-body">
    <div class="rp-title">Rankings</div>
    ${seg(['Volume', 'Test results', 'Challenges'], 2)}
    <div class="rp-section">On now</div>
    <div class="rp-group rp-wk"><div class="kick"><span class="rp-chip brand">Personal target</span><span class="num">12 days left</span></div><div class="t">100km in November</div><div class="m num">12 of 30 done</div>
      <div class="rp-row" style="padding:8px 0 0;min-height:0;font-size:13px;font-weight:600"><span class="num">You · 62.4 / 100km</span></div><div class="rp-track"><i style="width:62%"></i></div></div>
    <div class="rp-group rp-wk"><div class="kick"><span class="rp-chip brand">Squad vs squad</span><span class="num">5 days left</span></div><div class="t">Seniors v Novices</div><div class="m">Metres per rower, so size doesn’t win it</div>
      <div class="rp-row" style="padding:8px 0 0;min-height:0;font-size:13px"><span>Seniors</span><span class="val num">41.2km</span></div><div class="rp-track"><i style="width:82%"></i></div>
      <div class="rp-row" style="padding:8px 0 0;min-height:0;font-size:13px"><span>Novices</span><span class="val num">36.8km</span></div><div class="rp-track"><i style="width:73%"></i></div></div>
    <div class="rp-group"><div class="rp-wk" style="padding-bottom:8px"><div class="kick"><span class="rp-chip brand">Erg event · 2k</span><span class="num">Until Sunday</span></div><div class="t">Club 2k day</div><div class="m num">18 rowers on the board</div></div>
      ${linkRow('plus', 'Log your 2k')}</div>
  </div>${tabs('rankings')}`;

  screens.profile = () => `${statusBar()}<div class="rp-body">
    <div class="rp-prof"><div class="rp-av">SC</div><b>Sam Cole</b><span>@samcole · ${CLUB}${tick} · Senior</span></div>
    ${seg(['Overview', 'PBs', 'Posts'], 0)}
    <div class="rp-group" style="margin-top:10px"><div class="rp-stats num"><div><b>116km</b><span>this week</span></div><div><b>9</b><span>sessions</span></div><div><b>6</b><span>PBs</span></div><div><b>23</b><span>streak days</span></div></div></div>
    <div class="rp-group rp-pred"><div class="t">2k · Predicted today</div><div class="n num">6:17.0 <small>±3s</small></div><div class="s num">1:34.2 /500m</div></div>
    <div class="rp-section">Personal bests</div>
    <div class="rp-pbgrid num">${[['500m', '1:27.4'], ['2k', '6:18.9', 1], ['5k', '17:02.0'], ['6k', '20:41.3'], ['10k', '35:12.8'], ['30 min', '8,102m']].map(p =>
      `<div class="rp-pbtile ${p[2] ? 'new' : ''}"><div class="d">${p[0]}</div><div class="t">${p[1]}</div></div>`).join('')}</div>
    <div class="rp-group" style="margin-top:10px"><div class="rp-row"><span class="rp-link">${ico('star', 16)}Season Wrapped</span>${ico('chevronRight', 16)}</div></div>
  </div>${tabs('profile')}`;

  const rower = (name, sub, km, target, pct, sess, pb, pred, att, flags = [], behind) => `<div class="rp-rower">
    <div class="top"><span class="rp-av">${initials(name)}</span><span class="who"><b>${name}</b><span>${sub}</span></span><span class="att num">${att}</span></div>
    <div class="line num"><span><b>${km}</b> / ${target} km this week</span><span>${sess}</span></div>
    <div class="rp-track ${behind ? 'behind' : ''}" style="margin-top:4px"><i style="width:${pct}%"></i></div>
    <div class="line num"><span>2k PB <b>${pb}</b></span><span class="pre">Predicted <b>${pred}</b></span></div>
    ${flags.length ? `<div class="flags">${flags.map(f => `<span class="rp-chip warn">${f}</span>`).join('')}</div>` : ''}</div>`;

  screens.coachRowers = () => `${statusBar()}<div class="rp-body">
    <div class="rp-title-row"><div class="rp-title">Rowers</div><span class="rp-av">SL</span></div>
    <div style="margin-bottom:10px"><span class="rp-pill">All squads · Behind target ${ico('chevronRight', 14)}</span></div>
    ${rower('Ollie Grant', 'Novices · bow side', '4.0', '50', 8, '1 session', '7:05.2', '7:04 ±7s', '62% attendance', ['10+ days without a session'], true)}
    ${rower('Marcus Reilly', 'Senior men · stroke side', '40.6', '75', 54, '4 sessions', '6:31.5', '6:29 ±5s', '84% attendance', ['Effort up 22% this week'], true)}
    ${rower('Sam Cole', 'Senior men · stroke side', '68.4', '75', 92, '6 sessions', '6:18.9', '6:17 ±3s', '96% attendance')}
    ${rower('Alice Whitfield', 'Senior women · bow side', '81.2', '75', 100, '7 sessions', '7:04.1', '7:02 ±4s', '100% attendance')}
  </div>${coachTabs('people')}`;

  screens.coachWorkout = () => `${statusBar()}<div class="rp-body">
    <div class="rp-title-row"><div class="rp-title">Workouts</div><span class="rp-av">SL</span></div>
    <div class="rp-section" style="margin-top:0">Today</div>
    <div class="rp-group"><div class="rp-wk"><div class="kick"><span class="rp-chip brand">AT</span><span class="num">06:30 · Senior men</span></div><div class="t num">4 × 500m</div>
      <div class="rp-row" style="padding:6px 0 0;min-height:0;font-size:13px"><span>Completed</span><span class="val num">7 of 12</span></div><div class="rp-track"><i style="width:58%"></i></div></div>
      ${linkRow('pencil', 'Open notepad')}</div>
    <div class="rp-section">Upcoming</div>
    <div class="rp-group rp-wk"><div class="kick"><span class="rp-chip brand">Test</span><span class="num">Sat 07:00 · Whole club</span></div><div class="t">2k test</div></div>
    <div class="rp-group rp-wk"><div class="kick"><span class="rp-chip">UT2</span><span class="num">Sun · Novices</span></div><div class="t num">60 min steady</div><div class="m num">Rate 18–20 · each rower’s own target split</div></div>
    <div class="rp-section">Past</div>
    <div class="rp-group"><div class="rp-row"><span class="rp-link">${ico('clipboard', 16)}Notebook</span>${ico('chevronRight', 16)}</div>${row('3 × 2k @ r24', 'Thu · 12 of 12')}</div>
  </div>${coachTabs('stopwatch')}`;

  screens.coachNotepad = () => {
    const rows = [['Sam', ['1:44.6', '1:45.2', '1:45.9', '1:44.1'], 'post'], ['Tom', ['1:42.3', '1:43.0', '1:43.8', '1:42.2'], 'post'], ['Joe', ['1:46.1', '1:46.4', '1:47.0', '1:45.5'], 'scan'], ['Marcus', ['1:47.2', '1:48.0', '1:48.3', '–'], 'scan'], ['Ollie', ['out', '–', '–', '–'], '']];
    let d = .2;
    const cells = rows.map((r, i) => `<div class="c n num">${i + 1}</div><div class="c who">${r[0]}</div><div class="c cam">${ico('camera', 18)}</div>` + r[1].map((v, j) => {
      const empty = v === '–' || v === 'out', selected = i === 3 && j === 3;
      const cls = empty ? 'empty' : r[2];
      const st = r[2] === 'scan' && !empty ? `style="--d:${(d += .14).toFixed(2)}s"` : '';
      return `<div class="c sc"><span class="rp-score ${cls} ${selected ? 'sel' : ''} num" ${st}>${v}</span></div>`;
    }).join('')).join('');
    return `${statusBar()}<div class="rp-body">
      <div class="rp-nav"><span class="back">${ico('chevronLeft', 20)}</span><b>Notepad</b><span></span></div>
      <p class="rp-hint num" style="margin:-6px 0 10px">4 × 500m · Today 06:30</p>
      <div class="rp-group"><div class="rp-row" style="min-height:36px;padding-bottom:0"><b style="font-weight:600">Scores</b><span class="val" style="font-size:12px">split /500m</span></div>
        <div class="rp-np"><div class="hd">#</div><div class="hd l">Rower</div><div class="hd"></div>${[1, 2, 3, 4].map(n => `<div class="hd num">${n}</div>`).join('')}${cells}</div>
        <div class="rp-legend"><i></i>From the rower’s own post</div></div>
      <div class="rp-group" style="padding:12px 16px"><b style="font-weight:600;font-size:15px">Technique</b><p style="margin:4px 0 0;font-size:13px;color:var(--ink2)">Sam rushing the slide in piece 3. Tom strong finish.</p></div>
      <div style="display:flex;gap:8px;margin-top:10px"><span class="rp-btn" style="flex:1">Add text</span><span class="rp-btn" style="flex:1">Add table</span></div>
      <div class="rp-section">Notes</div>
      <div class="rp-group" style="padding:12px 16px;font-size:13px;color:var(--ink2)">Wind picked up. Move the 2k test to Saturday.</div>
    </div>`;
  };

  screens.coachBoat = () => `${statusBar()}<div class="rp-body">
    <div class="rp-title-row"><div class="rp-title">Boats</div><span class="rp-av">SL</span></div>
    ${seg(['Sessions', 'Saved boats'], 0)}
    <div class="rp-section">Today · 2 boats · 7 rowers</div>
    <div class="rp-group rp-boatcard"><div class="h"><b>M1 four</b><span class="rp-chip ok">Sent</span></div><div class="m">4+ · stroke-rigged</div>${RPUI.boat(FOUR, Object.assign({ type: '4+' }, ORANGE))}</div>
    <div class="rp-group rp-boatcard"><div class="h"><b>Double</b><span class="rp-chip">Not sent</span></div><div class="m">2x · sculls</div>${RPUI.boat({ 2: 'Priya', 1: 'Nina' }, { type: '2x', colour: '#2C5F8A', deck: '#20405C' })}</div>
    <div class="rp-section">Not in a boat yet</div>
    <div class="rp-group">${row('Ollie', 'Usually bow side')}</div>
  </div>${coachTabs('boat')}`;

  screens.coachCal = () => {
    const days = [];
    const dots = { 2: 'p', 4: 'pp', 6: 'p', 9: 'pr', 11: 'p', 13: 'p', 16: 'pp', 18: 'p', 21: 'r', 23: 'p', 25: 'pp', 27: 'p', 30: 'p' };
    [26, 27, 28, 29, 30, 31].forEach(n => days.push(`<div class="d mute num">${n}</div>`));
    for (let d = 1; d <= 30; d++) {
      const k = dots[d] || '';
      days.push(`<div class="d num ${d === 11 ? 'today' : ''}">${d}<span class="dots">${[...k].map(c => `<i class="${c === 'r' ? 'r' : ''}"></i>`).join('')}</span></div>`);
    }
    for (let n = 1; n <= 6; n++) days.push(`<div class="d mute num">${n}</div>`);
    return `${statusBar()}<div class="rp-body">
      <div class="rp-title-row"><div class="rp-title">Calendar</div><span class="rp-av">SL</span></div>
      <div class="rp-group rp-cal"><div style="display:flex;justify-content:space-between;font-weight:600;margin-bottom:8px"><span>November</span><span style="color:var(--brand);font-size:13px">Who’s available</span></div>
        <div class="rp-cal-grid">${['M', 'T', 'W', 'T', 'F', 'S', 'S'].map(h => `<div class="h">${h}</div>`).join('')}${days.join('')}</div></div>
      <div class="rp-group"><div class="rp-wk"><div class="t" style="font-size:16px">Morning outing</div><div class="m num">Today · 06:30–08:30 · Boathouse</div>
        <div class="rp-counts num"><div><b style="color:var(--success)">14</b><span>Present</span></div><div><b>2</b><span>Excused</span></div><div><b style="color:var(--error)">1</b><span>Absent</span></div></div></div>
        ${linkRow('check', 'Take register')}</div>
      <div class="rp-group">${row('Announcements', '1 on rowers’ Feeds')}${row('Head of the River', '28 Nov · 16 can race')}</div>
    </div>${coachTabs('calendar')}`;
  };

  RPUI.screens = screens;
  RPUI.render = (name) => `<div class="rp-screen">${screens[name]()}</div>`;
  RPUI.mount = (root = document) => {
    root.querySelectorAll('[data-screen]').forEach(el => {
      el.innerHTML = RPUI.render(el.dataset.screen);
      el.setAttribute('role', 'img');
      el.setAttribute('aria-label', el.dataset.label || 'The Rowing Pals app on an iPhone');
    });
  };
  window.RPUI = RPUI;
})();
