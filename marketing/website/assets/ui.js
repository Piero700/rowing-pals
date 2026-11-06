/* Rowing Pals — phone screen mockups as HTML strings.
   Usage: <div class="phone" data-screen="feed"></div>, then RPUI.mount().
   Set RPUI.base to the folder holding icon-256.png before mounting. */
(function () {
  const RPUI = { base: 'assets/' };

  const icon = {
    feed: '<svg viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="16" rx="4"/><path d="M4 10h16"/></svg>',
    rank: '<svg viewBox="0 0 24 24"><path d="M5 20V12M12 20V5M19 20v-5"/></svg>',
    cal: '<svg viewBox="0 0 24 24"><rect x="4" y="5" width="16" height="15" rx="3"/><path d="M4 10h16M9 3v4M15 3v4"/></svg>',
    prof: '<svg viewBox="0 0 24 24"><circle cx="12" cy="9" r="4"/><path d="M5 20c1.5-3.5 4-5 7-5s5.5 1.5 7 5"/></svg>',
    rowers: '<svg viewBox="0 0 24 24"><circle cx="9" cy="9" r="3.5"/><circle cx="17" cy="10" r="2.5"/><path d="M3 19c1-3 3.3-4.5 6-4.5s5 1.5 6 4.5M15 15.5c2.6-.3 4.6.9 5.5 3.5"/></svg>',
    work: '<svg viewBox="0 0 24 24"><rect x="5" y="4" width="14" height="17" rx="3"/><path d="M9 9h6M9 13h6M9 17h3"/></svg>',
    boat: '<svg viewBox="0 0 24 24"><path d="M12 2c2 4 2 16 0 20-2-4-2-16 0-20zM5 8l14 2M5 14l14 2"/></svg>',
    plus: '<svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>',
    x: '<svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg>'
  };

  const statusBar = () => `
    <div class="rp-island"></div>
    <div class="rp-sb"><span class="num">9:41</span><span class="rp-sb-r">
      <svg viewBox="0 0 18 12"><rect x="0" y="8" width="3" height="4" rx="1"/><rect x="5" y="5.5" width="3" height="6.5" rx="1"/><rect x="10" y="3" width="3" height="9" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/></svg>
      <svg viewBox="0 0 16 12"><path d="M8 2.5c2.3 0 4.4.9 6 2.4l1.3-1.4A10.4 10.4 0 0 0 8 .6 10.4 10.4 0 0 0 .7 3.5L2 4.9a8.5 8.5 0 0 1 6-2.4zm0 3.8c1.3 0 2.5.5 3.4 1.3l1.3-1.4A6.6 6.6 0 0 0 8 4.4c-1.8 0-3.4.7-4.7 1.8l1.3 1.4c.9-.8 2.1-1.3 3.4-1.3zM8 12l2.3-2.4a3.3 3.3 0 0 0-4.6 0z"/></svg>
      <svg viewBox="0 0 27 12"><rect x=".5" y=".5" width="23" height="11" rx="3.5" fill="none" stroke="currentColor" opacity=".5"/><rect x="2" y="2" width="18" height="8" rx="2"/><rect x="25" y="4" width="2" height="4" rx="1" opacity=".5"/></svg>
    </span></div>`;

  const tabBar = (set, active) => `<div class="rp-tabs"><div class="rp-tabpill rp-glass">${set.map(([k, l]) =>
    `<div class="rp-tab ${k === active ? 'on' : ''}" data-tab="${k}">${icon[k]}${l}</div>`).join('')}</div>
    <div class="rp-log" data-act="log">${icon.plus}</div></div>`;
  const tabs = (a) => tabBar([['feed', 'Feed'], ['rank', 'Rankings'], ['cal', 'Calendar'], ['prof', 'Profile']], a);
  const coachTabs = (a) => tabBar([['rowers', 'Rowers'], ['work', 'Workouts'], ['boat', 'Boats'], ['cal', 'Calendar']], a);

  const initials = (n) => n.split(' ').map(w => w[0]).join('');

  // The erg monitor as it appears in the rear-camera photo.
  RPUI.pm5 = (o = {}) => {
    const d = Object.assign({ time: '1:04:50', metres: '16000', split: '2:01.6', rate: '19',
      rows: [['4000', '2:03.1', '18'], ['8000', '2:01.0', '19'], ['12000', '2:00.4', '20'], ['16000', '2:01.9', '19']] }, o);
    return `<div class="pm5"><div class="pm5-brand">CONCEPT2 · PM5</div><div class="pm5-lcd">
      <div class="pm5-row"><span>time</span><span>meters</span></div>
      <div class="pm5-row pm5-big"><b data-ocr style="--d:.0s">${d.time}</b><b data-ocr style="--d:.15s">${d.metres}</b></div>
      <div class="pm5-row"><span>/500m</span><span>s/m</span></div>
      <div class="pm5-row pm5-mid"><b data-ocr style="--d:.3s">${d.split}</b><b data-ocr style="--d:.45s">${d.rate}</b></div>
      <div class="pm5-table">${d.rows.map(r => `<div><span>${r[0]}</span><span>${r[1]}</span><span>${r[2]}</span></div>`).join('')}</div>
    </div><div class="pm5-btns"><i></i><i></i><i></i><i></i><i></i></div></div>`;
  };

  const selfie = () => `<div class="rp-selfie" style="background-image:url(${RPUI.base}icon-256.png)"></div>`;

  const ALICE_PM5 = RPUI.alicePm5 = { time: '7:04.1', metres: '2000', split: '1:46.0', rate: '34',
    rows: [['500', '1:44.2', '36'], ['1000', '1:46.9', '33'], ['1500', '1:47.3', '33'], ['2000', '1:45.6', '35']] };

  RPUI.feedCard = (o = {}) => {
    const d = Object.assign({
      name: 'Piero Ciobanu', avc: '', club: 'UEA Boat Club', ago: '3 min', chip: 'Senior · M',
      total: '16,000', time: '1:04:50', split: '2:01.6', rate: '19', pb: false,
      segs: ['Warmup 2,000m', 'Main 12,000m', 'Cooldown 2,000m'], reacts: ['🔥 8', '💪 4'], comments: 3, pm5: {}
    }, o);
    return `<div class="rp-card ${d.pb ? 'pb' : ''}">
      <div class="rp-card-head"><div class="rp-av ${d.avc}">${initials(d.name)}</div>
        <div class="who"><div class="name">${d.name}</div><div class="sub">${d.club} · ${d.ago}</div></div>
        <span class="rp-chip">${d.chip}</span></div>
      <div class="rp-media"><div class="gym"></div>${RPUI.pm5(d.pm5)}${selfie()}
        ${d.pb ? '<div class="rp-pbflag">PB</div>' : ''}
        <div class="rp-strip rp-glass num">
          <div class="total">${d.total}<small>m</small></div><div class="spacer"></div>
          <div class="stat"><b>${d.time}</b><i>Time</i></div>
          <div class="stat"><b>${d.split}</b><i>Split</i></div>
          <div class="stat"><b>${d.rate}</b><i>Rate</i></div>
        </div></div>
      <div class="rp-card-foot"><div class="rp-segs">${d.segs.map(s =>
        `<span class="rp-chip ${s.startsWith('Main') ? 'brand' : ''} num">${s}</span>`).join('')}</div>
        <div class="rp-react">${d.reacts.map(r => `<span class="num">${r}</span>`).join('')}<span class="cm num">💬 ${d.comments}</span></div>
      </div></div>`;
  };

  const screens = {};

  screens.feed = (o = {}) => `${statusBar()}<div class="rp-body">
    <div class="rp-large-title">Feed</div>
    <div class="rp-pill-seg" style="margin-bottom:14px"><span class="on" data-seg="following">Following</span><span data-seg="club">My club</span></div>
    ${o.top || ''}${RPUI.feedCard()}
    ${RPUI.feedCard({ name: 'Alice Whitfield', avc: 'b', club: 'Durham University BC', ago: '1h', chip: 'Senior · W', total: '2,000', time: '7:04.1', split: '1:46.0', rate: '34', pb: true, segs: ['Main 2,000m', '2k test'], pm5: ALICE_PM5 })}
  </div>${tabs('feed')}`;

  screens.pb = (o = {}) => `${statusBar()}<div class="rp-body">
    <div class="rp-large-title">Feed</div>
    <div class="rp-pill-seg" style="margin-bottom:14px"><span data-seg="following">Following</span><span class="on" data-seg="club">My club</span></div>
    ${o.top || ''}${RPUI.feedCard({ name: 'Alice Whitfield', avc: 'b', club: 'Durham University BC', ago: 'just now', chip: 'Senior · W', total: '2,000', time: '7:04.1', split: '1:46.0', rate: '34', pb: true, segs: ['Main 2,000m', '2k test'], reacts: ['🔥 24', '👏 17', '💪 9'], comments: 11, pm5: ALICE_PM5 })}
    ${RPUI.feedCard({ name: 'Sam Okonkwo', avc: 'g', club: 'UEA Boat Club', ago: '2h', chip: 'Novice · M', total: '6,000', time: '22:41.6', split: '1:53.4', rate: '24', segs: ['Main 6,000m'], pm5: { time: '22:41.6', metres: '6000', split: '1:53.4', rate: '24' } })}
  </div>${tabs('feed')}`;

  screens.capture = (o = {}) => `<div class="rp-capture">${statusBar()}
    <div class="rp-viewfinder"><div class="gym"></div>${RPUI.pm5(o.pm5)}
      <div class="rp-corners"><i></i><i></i><i></i><i></i></div></div>
    <div class="rp-close rp-glass" data-act="close">${icon.x}</div>
    ${selfie()}
    <div class="rp-shutter-wrap"><div class="rp-shutter rp-glass" data-act="shutter"><i></i></div><div class="hint">${o.hint || 'Both cameras fire at once'}</div></div>
  </div>`;

  const TEST_PM5 = RPUI.testPm5 = { time: '6:18.9', metres: '2000', split: '1:34.7', rate: '35',
    rows: [['500', '1:33.1', '37'], ['1000', '1:35.4', '34'], ['1500', '1:35.9', '34'], ['2000', '1:34.4', '36']] };

  screens.review = (o = {}) => `<div class="rp-capture"><div class="rp-viewfinder" style="opacity:.35"><div class="gym"></div>${RPUI.pm5(TEST_PM5)}</div>
    ${statusBar()}
    <div class="rp-sheet"><div class="rp-grabber"></div>
      <h3>Check your numbers</h3>
      <div class="rp-total num"><b>7,000m</b>28:14.6 · 2:01.0 /500m · r24</div>
      ${[['Warmup', '3,000', '12:41.0', '2:06.8', '20', false, {}], ['Main', '2,000', '6:18.9', '1:34.7', '35', true, TEST_PM5], ['Cooldown', '2,000', '9:14.7', '2:18.7', '18', false, {}]].map(s => `
      <div class="rp-segrow"><div class="rp-thumb">${RPUI.pm5(s[6])}</div><div style="flex:1">
        <div style="margin-bottom:6px"><span class="rp-chip ${s[0] === 'Main' ? 'brand' : ''}">${s[0]}</span></div>
        <div class="rp-fields num">
          <div class="rp-field"><i>Metres</i>${s[1]}</div>
          <div class="rp-field ${s[5] ? 'low' : ''}"><i>Time</i>${s[2]}</div>
          <div class="rp-field"><i>Split</i>${s[3]}</div>
          <div class="rp-field"><i>Rate</i>${s[4]}</div>
        </div></div></div>`).join('')}
      <div class="rp-detect">${o.test === 'yes' ? '<p style="margin:0"><b>Added to the 2k leaderboard.</b></p>'
        : o.test === 'no' ? '<p style="margin:0"><b>Not a test.</b> It counts for your metres only.</p>'
        : '<p><b>This looks like a 2k test.</b> Add it to the 2k leaderboard?</p><div class="btns"><div class="rp-btn" data-act="test-no">No</div><div class="rp-btn primary" data-act="test-yes">Yes</div></div>'}</div>
      <div class="rp-switch-row">Include on leaderboards<span class="rp-switch ${o.include === false ? 'off' : ''}" data-act="include"></span></div>
      <div class="rp-btn primary" style="display:block;margin-top:6px" data-act="post">Post</div>
    </div></div>`;

  const rankRow = (r, i, val, sub) => `<div class="rp-row ${i === 0 ? 'first' : ''}" ${r.me ? 'style="background:var(--card)"' : ''}>
    <div class="pos num">${i + 1}</div><div class="rp-av ${r.c}">${initials(r.n)}</div>
    <div class="who"><b>${r.n}</b><span>${r.club}</span></div><div class="val num">${val}<span>${sub}</span></div></div>`;

  RPUI.volumeRows = [
    { n: 'Tom Ashworth', club: 'Newcastle University BC', c: 'a', m: '128,400', mv: '▲2' },
    { n: 'Jack Fenwick', club: 'Durham University BC', c: 'b', m: '121,900' },
    { n: 'Piero Ciobanu', club: 'UEA Boat Club', c: '', m: '116,250', mv: '▲1', me: 1 },
    { n: 'Marcus Reilly', club: 'UEA Boat Club', c: 's', m: '104,800' },
    { n: 'Ollie Grant', club: 'UEA Boat Club', c: 'g', m: '88,300' },
    { n: 'Sam Okonkwo', club: 'UEA Boat Club', c: 'b', m: '41,300' }
  ];

  screens.rankings = (o = {}) => {
    const period = o.period || 'week';
    const hero = o.hero || { pos: '3rd', label: 'You this week', line: '116,250m · 5,650m to 2nd' };
    return `${statusBar()}<div class="rp-body">
    <div class="rp-large-title">Rankings</div>
    <div class="rp-pill-seg"><span class="on" data-seg="volume">Volume</span><span data-seg="tests">Test results</span></div>
    <div class="rp-rank-hero"><div class="big num">${hero.pos}</div><div><div style="font-weight:600">${hero.label}</div>
      <div class="num" style="font-size:13px;color:var(--ink2)">${hero.line}</div></div></div>
    <div class="rp-pill-seg" style="margin-bottom:10px">${[['week', 'Week'], ['month', 'Month'], ['year', 'Year']].map(([k, l]) =>
      `<span class="${k === period ? 'on' : ''}" data-period="${k}">${l}</span>`).join('')}</div>
    ${(o.rows || RPUI.volumeRows).map((r, i) => rankRow(r, i, r.m, `${r.mv ? `<em class="rp-move">${r.mv}</em> ` : ''}metres`)).join('')}
  </div>${tabs('rank')}`;
  };

  RPUI.testRows = [['Tom Ashworth', 'Newcastle Uni BC', '6:04.2', '1:31.0', 'a', 'senior'], ['Jack Fenwick', 'Durham Uni BC', '6:11.7', '1:32.9', 'b', 'senior'], ['Piero Ciobanu', 'UEA Boat Club', '6:18.9', '1:34.7', '', 'senior'], ['Marcus Reilly', 'UEA Boat Club', '6:31.5', '1:37.9', 's', 'senior'], ['Sam Okonkwo', 'UEA Boat Club', '6:52.4', '1:43.1', 'g', 'novice'], ['Ollie Grant', 'UEA Boat Club', '7:05.2', '1:46.3', 'b', 'novice']];

  screens.tests = (o = {}) => {
    const sex = o.sex || 'men', level = o.level || 'all';
    const seg = (set, cur, attr) => set.map(([k, l]) => `<span class="${k === cur ? 'on' : ''}" ${attr}="${k}">${l}</span>`).join('');
    const rows = (o.rows || RPUI.testRows).filter(r => level === 'all' || r[5] === level);
    return `${statusBar()}<div class="rp-body">
    <div class="rp-large-title">2k test</div>
    ${o.back ? '<div class="rp-pill-seg" style="margin-bottom:8px"><span data-seg="volume">Volume</span><span class="on" data-seg="tests">Test results</span></div>' : ''}
    <div class="rp-pill-seg" style="margin-bottom:8px">${seg([['men', 'Men'], ['women', 'Women']], sex, 'data-sex')}</div>
    <div class="rp-pill-seg" style="margin-bottom:12px">${seg([['all', 'All'], ['novice', 'Novice'], ['senior', 'Senior']], level, 'data-level')}</div>
    ${rows
      .map((r, i) => rankRow({ n: r[0], club: r[1], c: r[4] }, i, r[2], `${r[3]} /500m`)).join('')}
  </div>${tabs('rank')}`;
  };

  screens.profile = () => `${statusBar()}<div class="rp-body">
    <div class="rp-prof-head"><div class="rp-av">PC</div><div><div style="font-size:22px;font-weight:700">Piero Ciobanu</div>
      <div style="color:var(--ink3);font-size:14px">UEA Boat Club · <span class="rp-chip">Senior · M</span></div></div></div>
    <div class="rp-streak"><div class="rp-streak-top"><div class="n num">23</div><div><div style="font-weight:600;font-size:17px">day streak</div>
      <div class="rp-pips"><i class="used"></i><i></i></div><div style="font-size:13px;color:var(--ink3)">1 rest day left this week</div></div></div>
      <div class="rp-week">${['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d, i) => `<div><b class="${i === 2 ? 'rest' : i < 5 ? 'done' : ''}"></b>${d}</div>`).join('')}</div></div>
    <div class="rp-section">Personal bests</div>
    <div class="rp-pbgrid num">${[['500m', '1:27.4'], ['2k', '6:18.9', 1], ['5k', '17:02.0'], ['6k', '20:41.3'], ['10k', '35:12.8'], ['30 min', '8,102m']].map(p =>
      `<div class="rp-pbtile ${p[2] ? 'new' : ''}"><div class="d">${p[0]}</div><div class="t">${p[1]}</div></div>`).join('')}</div>
    <div class="rp-chart"><div style="display:flex;justify-content:space-between;font-size:13px"><b>2k progression</b><span class="num" style="color:var(--records)">−14.6s this season</span></div>
      <svg viewBox="0 0 300 100" preserveAspectRatio="none"><defs><linearGradient id="pg" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#C6ADFF" stop-opacity=".45"/><stop offset="1" stop-color="#C6ADFF" stop-opacity="0"/></linearGradient></defs>
      <path d="M0 20 L50 32 L100 38 L150 55 L200 60 L250 74 L300 86 L300 100 L0 100Z" fill="url(#pg)"/>
      <path d="M0 20 L50 32 L100 38 L150 55 L200 60 L250 74 L300 86" fill="none" stroke="#C6ADFF" stroke-width="3" stroke-linejoin="round"/>
      <circle cx="296" cy="86" r="5" fill="#C6ADFF"/></svg></div>
  </div>${tabs('prof')}`;

  // The rower's Calendar: what the coach has set, and whether you can make it.
  screens.rowerCal = (o = {}) => {
    const reply = o.reply || '';
    const answer = reply === 'yes' ? '<span class="rp-chip success">Going</span>'
      : reply === 'no' ? '<span class="rp-chip">Can’t make it</span>' : '';
    return `${statusBar()}<div class="rp-body">
    <div class="rp-large-title">Calendar</div>
    <div class="rp-section">Next up</div>
    <div class="rp-practice" style="margin-top:0"><div style="display:flex;justify-content:space-between;align-items:center"><div class="t">Morning outing · 1st VIII</div>${answer}</div>
      <div class="m num">Tomorrow · 06:30–08:30 · Boathouse</div>
      <div style="display:flex;gap:6px;margin-bottom:12px"><span class="rp-chip brand num">Seat 8 · Stroke</span><span class="rp-chip">1st VIII</span></div>
      ${reply ? '<div style="font-size:13px;color:var(--ink3)">Your coach can see your answer.</div>'
        : '<div style="font-size:14px;margin-bottom:8px">Can you make it?</div><div style="display:flex;gap:8px"><div class="rp-btn" data-act="reply-no">No</div><div class="rp-btn primary" data-act="reply-yes">Yes</div></div>'}
    </div>
    <div class="rp-section">From your coach</div>
    <div class="rp-wk"><div style="display:flex;justify-content:space-between;align-items:center"><div class="t">3 × 2k @ r24</div><span class="rp-chip">UT1</span></div>
      <div class="m num">Thursday · Target split 1:52.0</div>
      <div class="rp-btn primary" data-act="log">Log it</div></div>
    <div class="rp-wk"><div style="display:flex;justify-content:space-between;align-items:center"><div class="t" style="font-size:16px">Head of the River Fours</div><span class="rp-chip">Race</span></div>
      <div class="m num" style="margin-bottom:0">Saturday · Race day</div></div>
  </div>${tabs('cal')}`;
  };

  screens.coachRowers = () => `${statusBar()}<div class="rp-body">
    <div class="rp-header-row"><div class="rp-large-title">Rowers</div><div class="rp-av a" style="margin-right:4px">JM</div></div>
    <div class="rp-pill-seg" style="margin-bottom:12px"><span class="on">All squads</span><span>Senior men</span><span>Novices</span></div>
    ${[['Piero Ciobanu', '', 92, '68,400 / 75,000m', '6:17', '±3s', 'Senior · stroke side', ''],
       ['Alice Whitfield', 'b', 100, '81,200 / 75,000m', '7:02', '±4s', 'Senior · bow side', ''],
       ['Marcus Reilly', 's', 54, '40,600 / 75,000m', '6:29', '±5s', 'Senior · stroke side', 'Effort up sharply this week'],
       ['Sam Okonkwo', 'g', 71, '35,400 / 50,000m', '6:49', '±6s', 'Novice · both sides', ''],
       ['Ollie Grant', 'a', 8, '4,000 / 50,000m', '7:04', '±7s', 'Novice · bow side', '10 days without a session']].map(r => `
      <div class="rp-crow"><div class="rp-av ${r[1]}">${initials(r[0])}</div><div class="who"><b>${r[0]}</b>
        <div class="meta">${r[6]}</div><div class="rp-bar"><i style="width:${r[2]}%;${r[2] >= 100 ? 'background:var(--success)' : ''}"></i></div>
        <div class="meta num">${r[3]}</div>${r[7] ? `<div class="rp-flag">${r[7]}</div>` : ''}</div>
        <div class="pred num"><b>${r[4]}</b><span>2k ${r[5]}</span></div></div>`).join('')}
  </div>${coachTabs('rowers')}`;

  // An eight drawn upright, stern (cox) at the top, oars alternating; the stroke seat rows stroke side.
  RPUI.boat = (names, o = {}) => {
    const W = o.w || 358, H = o.h || 560, cx = W / 2;
    const top = 24, bottom = H - 16, len = bottom - top;
    const seats = [];
    for (let i = 0; i < 8; i++) seats.push(top + 80 + i * ((len - 120) / 7));
    const hull = `M${cx} ${top} C${cx + 24} ${top + 90}, ${cx + 24} ${bottom - 90}, ${cx} ${bottom} C${cx - 24} ${bottom - 90}, ${cx - 24} ${top + 90}, ${cx} ${top}Z`;
    let g = `<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" class="rp-boat">
      <defs><linearGradient id="hull" x1="0" x2="1"><stop offset="0" stop-color="#cfd6e4"/><stop offset=".5" stop-color="#f4f6fb"/><stop offset="1" stop-color="#aab3c5"/></linearGradient></defs>
      <path d="${hull}" fill="url(#hull)"/>
      <circle cx="${cx}" cy="${top + 40}" r="9" fill="#C6ADFF"/>
      <text x="${cx + 24}" y="${top + 44}" class="rp-seat-name seat-label" data-seat="cox">${names.cox || ''}</text>
      <text x="${cx - 24}" y="${top + 44}" text-anchor="end" class="rp-seat-sub">Cox</text>`;
    seats.forEach((y, i) => {
      const seatNo = 8 - i;                  // 8 = stroke, nearest the stern
      const right = seatNo % 2 === 0;        // stroke side drawn to the right
      const dir = right ? 1 : -1;
      const ox = cx + dir * 122, oy = y + 10;
      g += `<line x1="${cx}" y1="${y}" x2="${ox}" y2="${oy}" stroke="#7d8597" stroke-width="3" stroke-linecap="round"/>
        <rect x="${right ? ox - 4 : ox - 26}" y="${oy - 7}" width="30" height="14" rx="5" fill="${right ? '#91B8FF' : '#C6ADFF'}"/>
        <rect x="${cx - 11}" y="${y - 9}" width="22" height="18" rx="6" fill="#91B8FF"/>
        <text x="${cx}" y="${y + 4}" text-anchor="middle" font-size="11" font-weight="700" fill="#0b1a35" font-family="-apple-system,Inter,sans-serif">${seatNo}</text>
        <text x="${right ? cx - 26 : cx + 26}" y="${y + 1}" text-anchor="${right ? 'end' : 'start'}" class="rp-seat-name seat-label" data-seat="${seatNo}">${names[seatNo] || ''}</text>
        <text x="${right ? cx - 26 : cx + 26}" y="${y + 15}" text-anchor="${right ? 'end' : 'start'}" class="rp-seat-sub">${seatNo === 8 ? 'Stroke' : seatNo === 1 ? 'Bow' : ''}</text>`;
    });
    return g + '</svg>';
  };
  RPUI.crew = { cox: 'Freya', 8: 'Piero', 7: 'Marcus', 6: 'Jack', 5: 'Tom', 4: 'Sam', 3: 'Ollie', 2: 'Nina', 1: 'Alice' };

  screens.coachBoat = () => `${statusBar()}<div class="rp-body">
    <div class="rp-large-title" style="font-size:28px;margin-bottom:6px">1st VIII</div>
    <div style="display:flex;gap:6px;margin:0 4px 12px"><span class="rp-chip brand">8+</span><span class="rp-chip num">Sat 07:00</span><span class="rp-chip success">Sent</span></div>
    <div class="rp-boat-wrap">${RPUI.boat(RPUI.crew, { h: 500 })}</div>
    <div style="text-align:center;font-size:13px;color:var(--ink3);margin-top:10px">Each rower is told their boat and seat</div>
  </div>${coachTabs('boat')}`;

  screens.coachCal = (o = {}) => {
    const days = [];
    const dots = { 1: 'p', 3: 'pp', 6: 'p', 8: 'pr', 10: 'p', 13: 'p', 15: 'pp', 16: 'p', 18: 'r', 20: 'p', 22: 'pp', 25: 'r', 27: 'p', 29: 'p' };
    days.push('<div class="d mute num">29</div><div class="d mute num">30</div>');
    for (let d = 1; d <= 31; d++) {
      const k = dots[d] || '';
      days.push(`<div class="d num ${d === 17 ? 'today' : ''}">${d}<span class="dots">${[...k].map(c => `<i class="${c === 'r' ? 'r' : ''}"></i>`).join('')}</span></div>`);
    }
    days.push('<div class="d mute num">1</div><div class="d mute num">2</div>');
    return `${statusBar()}<div class="rp-body">
      <div class="rp-header-row"><div class="rp-large-title">Calendar</div><span class="rp-chip brand" style="margin-right:4px">Who's available</span></div>
      <div class="rp-cal"><div style="display:flex;justify-content:space-between;font-weight:600;margin-bottom:10px"><span>October</span><span style="color:var(--ink3)">‹ ›</span></div>
        <div class="rp-cal-grid">${['M', 'T', 'W', 'T', 'F', 'S', 'S'].map(h => `<div class="h">${h}</div>`).join('')}${days.join('')}</div></div>
      ${o.top || ''}<div class="rp-practice"><div class="t">Morning outing · 1st VIII</div><div class="m num">Today · 06:30–08:30 · Boathouse</div>
        <div class="rp-counts num"><div><b style="color:var(--success)">14</b><span>Present</span></div><div><b>2</b><span>Excused</span></div><div><b style="color:var(--error)">1</b><span>Absent</span></div></div>
        ${o.registerDone ? '<div class="rp-btn" style="margin-top:10px;color:var(--success)">Register saved</div>' : '<div class="rp-btn primary" style="margin-top:10px" data-act="register">Take register</div>'}</div>
      <div class="rp-practice" style="padding:4px 14px">
        ${[['Piero Ciobanu', 'Checked in', 'Present', 'success'], ['Ollie Grant', 'Can’t make it — exam', 'Excused', '']].map(r =>
          `<div class="rp-reg"><div class="who">${r[0]}<span>${r[1]}</span></div><span class="rp-chip ${r[3]}">${r[2]}</span></div>`).join('')}
      </div>
    </div>${coachTabs('cal')}`;
  };

  screens.coachWorkout = () => `${statusBar()}<div class="rp-body">
    <div class="rp-large-title">Workouts</div>
    <div class="rp-wk"><div class="t">3 × 2k @ r24</div><div class="m">Tomorrow · Senior men · UT1</div>
      <div class="rp-donut"><svg viewBox="0 0 36 36"><circle cx="18" cy="18" r="15.9" fill="none" stroke="#292C34" stroke-width="4"/>
        <circle cx="18" cy="18" r="15.9" fill="none" stroke="#78D7AC" stroke-width="4" stroke-dasharray="58 100" stroke-linecap="round"/>
        <circle cx="18" cy="18" r="15.9" fill="none" stroke="#91B8FF" stroke-width="4" stroke-dasharray="15 100" stroke-dashoffset="-61" stroke-linecap="round"/></svg>
        <div class="rp-legend num"><div><i style="background:var(--success)"></i>7 done</div><div><i style="background:var(--brand)"></i>2 partly</div><div><i style="background:var(--raised)"></i>3 not yet</div></div></div></div>
    <div class="rp-section">Splits against target · 1:52.0</div>
    <div class="rp-wk" style="padding:4px 14px">
      ${[['Piero Ciobanu', '1:50.8', 1], ['Alice Whitfield', '1:51.6', 1], ['Marcus Reilly', '1:53.4', 0], ['Jack Fenwick', '1:49.9', 1], ['Sam Okonkwo', '1:54.1', 0], ['Tom Ashworth', '1:48.7', 1]].map((r, i) =>
        `<div class="rp-piece" style="${i === 0 ? 'border-top:0' : ''}"><b>${r[0]}</b><span class="rp-split num ${r[2] ? 'ok' : ''}">${r[1]}</span></div>`).join('')}
    </div>
    <div class="rp-wk"><div style="display:flex;justify-content:space-between;align-items:center"><div class="t" style="font-size:16px">60 min steady state</div><span class="rp-chip">UT2</span></div>
      <div class="m" style="margin-bottom:0">Saturday · Novices · rate 18–20</div></div>
  </div>${coachTabs('work')}`;

  RPUI.screens = screens;
  RPUI.render = (name) => `<div class="rp-screen">${screens[name]()}</div>`;
  RPUI.mount = (root = document) => {
    root.querySelectorAll('[data-screen]').forEach(el => { el.innerHTML = RPUI.render(el.dataset.screen); });
  };
  window.RPUI = RPUI;
})();
