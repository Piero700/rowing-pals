/* rowingpals.com — "Try it": the app's screens, tappable, with sample data.
   Screens come from ui.js (the same mockups as the rest of the site and the App Store art);
   this file only keeps the demo's state and decides which screen to draw. Nothing is saved. */
(function () {
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const phone = $('#demoPhone');
  if (!phone || !window.RPUI) return;
  const S = RPUI.screens;
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const fmt = (n) => n.toLocaleString('en-GB');
  const ord = (n) => n + (['th', 'st', 'nd', 'rd'][(n % 100 - 20) % 10] || ['th', 'st', 'nd', 'rd'][n % 100] || 'th');
  phone.classList.add('on'); // lets the boat's seat names animate in, as elsewhere on the site

  /* ---------- sample data ---------- */
  const PIECE_M = 7000; // warmup 3,000 + main 2,000 + cooldown 2,000, as on the Review screen
  const people = {
    'Tom Ashworth': { club: 'Newcastle University BC', c: 'a' },
    'Jack Fenwick': { club: 'Durham University BC', c: 'b' },
    'Piero Ciobanu': { club: 'UEA Boat Club', c: '', me: 1 },
    'Marcus Reilly': { club: 'UEA Boat Club', c: 's' },
    'Ollie Grant': { club: 'UEA Boat Club', c: 'g' },
    'Sam Okonkwo': { club: 'UEA Boat Club', c: 'b' }
  };
  const volume = {
    week: { 'Tom Ashworth': 128400, 'Jack Fenwick': 121900, 'Piero Ciobanu': 116250, 'Marcus Reilly': 104800, 'Ollie Grant': 88300, 'Sam Okonkwo': 41300 },
    month: { 'Jack Fenwick': 512300, 'Piero Ciobanu': 498100, 'Tom Ashworth': 470900, 'Ollie Grant': 401200, 'Marcus Reilly': 388000, 'Sam Okonkwo': 210400 },
    year: { 'Piero Ciobanu': 4812000, 'Tom Ashworth': 4700500, 'Jack Fenwick': 4522900, 'Marcus Reilly': 3980100, 'Ollie Grant': 2904800, 'Sam Okonkwo': 1260000 }
  };
  const womenTests = [
    ['Alice Whitfield', 'Durham Uni BC', '7:04.1', '1:46.0', 'b', 'senior'],
    ['Hannah Cole', 'Newcastle Uni BC', '7:09.8', '1:47.4', 'a', 'senior'],
    ['Nina Patel', 'UEA Boat Club', '7:18.6', '1:49.7', 's', 'senior'],
    ['Grace Byrne', 'UEA Boat Club', '7:52.3', '1:58.1', 'g', 'novice']
  ];
  const COMPOSE = {
    session: { title: 'New session', fields: [['Title', 'Evening ergs'], ['When', 'Thursday · 18:00–19:30'], ['Where', 'Erg room'], ['Who', 'Senior men']],
      button: 'Add to calendar', card: ['Evening ergs · Senior men', 'Thursday · 18:00–19:30 · Erg room'], toast: 'Added to the calendar' },
    announcement: { title: 'New announcement', fields: [['Title', 'Kit order closes Friday'], ['Message', 'Splash tops and AIOs. Sizes to the captain by 5pm.'], ['To', 'UEA Boat Club']],
      button: 'Send', card: ['Kit order closes Friday', 'Announcement · sent to UEA Boat Club'], toast: 'Sent to the club' }
  };

  const TODO = [
    ['log', 'Tap + and snap the monitor'],
    ['post', 'Check the numbers, then post'],
    ['rank', 'Find yourself on Rankings'],
    ['reply', 'Tell your coach if you can make practice'],
    ['register', 'Switch to Coach and take the register'],
    ['boat', 'Look at the 1st VIII in Boats'],
    ['news', 'Send the club an announcement']
  ];

  /* ---------- state ---------- */
  let st, timers = [];
  function reset() {
    timers.forEach(clearTimeout); timers = [];
    st = {
      mode: 'rower', tab: 'feed', coachTab: 'rowers',
      view: null,            // capture | reading | review | new | compose — drawn over the tabs
      feedSeg: 'following', rankSeg: 'volume', period: 'week', sex: 'men', level: 'all',
      test: null, include: true,
      post: null,            // { test, include } once posted
      postReacts: [0, 0, 0], mine: {},
      reply: '', register: false, compose: null, coachTop: [],
      done: new Set(), note: '', toast: '', fresh: false
    };
  }

  const done = (k) => { if (!st.done.has(k)) { st.done.add(k); drawTodo(); } };
  const note = (t) => { st.note = t; $('#demoNote').textContent = t; };
  const later = (ms, fn) => timers.push(setTimeout(fn, reduce ? Math.min(ms, 150) : ms));

  function drawTodo() {
    const next = TODO.find(([k]) => !st.done.has(k));
    $('#demoTodo').innerHTML = TODO.map(([k, t]) =>
      `<li class="${st.done.has(k) ? 'done' : next && next[0] === k ? 'next' : ''}"><span>${t}</span></li>`).join('');
  }

  /* ---------- drawing ---------- */
  function volumeBoard() {
    const data = { ...volume[st.period] };
    const added = st.post && st.post.include;
    if (added) data['Piero Ciobanu'] += PIECE_M;
    const order = Object.keys(data).sort((a, b) => data[b] - data[a]);
    const before = Object.keys(volume[st.period]).sort((a, b) => volume[st.period][b] - volume[st.period][a]).indexOf('Piero Ciobanu');
    const pos = order.indexOf('Piero Ciobanu');
    const rows = order.map((n) => {
      let mv = '';
      if (st.period === 'week') {                       // movement on last week, as in the app
        if (n === 'Tom Ashworth') mv = '▲2';
        if (n === 'Piero Ciobanu') mv = '▲' + (1 + (before - pos));
      }
      return { n, ...people[n], m: fmt(data[n]), mv };
    });
    const mine = data['Piero Ciobanu'];
    const line = pos === 0
      ? `${fmt(mine)}m · ${fmt(mine - data[order[1]])}m clear`
      : `${fmt(mine)}m · ${fmt(data[order[pos - 1]] - mine)}m to ${ord(pos)}`;
    return S.rankings({ period: st.period, rows, hero: { pos: ord(pos + 1), label: `You this ${st.period}`, line } });
  }

  function myPost() {
    if (!st.post) return '';
    const pb = st.post.test === 'yes' && st.post.include;
    const card = RPUI.feedCard({
      name: 'Piero Ciobanu', club: 'UEA Boat Club', ago: 'just now', chip: 'Senior · M',
      total: fmt(PIECE_M), time: '28:14.6', split: '2:01.0', rate: '24', pb,
      segs: ['Warmup 3,000m', 'Main 2,000m', 'Cooldown 2,000m'].concat(pb ? ['2k test'] : []),
      reacts: ['🔥', '👏', '💪'].map((e, i) => `${e} ${st.postReacts[i]}`), comments: 0, pm5: RPUI.testPm5
    });
    return `<div class="my-post ${st.fresh ? 'new-post' : ''}">${card}</div>`;
  }

  function screen() {
    if (st.view === 'capture' || st.view === 'reading') {
      return S.capture({ pm5: RPUI.testPm5, hint: st.view === 'reading' ? 'Reading photo…' : 'Both cameras fire at once' });
    }
    if (st.view === 'review') return S.review({ test: st.test, include: st.include });
    if (st.mode === 'coach') {
      const t = st.coachTab;
      if (t === 'work') return S.coachWorkout();
      if (t === 'boat') return S.coachBoat();
      if (t === 'cal') return S.coachCal({ registerDone: st.register, top: st.coachTop.join('') });
      return S.coachRowers();
    }
    if (st.tab === 'rank') {
      if (st.rankSeg === 'tests') return S.tests({ back: true, sex: st.sex, level: st.level, rows: st.sex === 'women' ? womenTests : RPUI.testRows });
      return volumeBoard();
    }
    if (st.tab === 'cal') return S.rowerCal({ reply: st.reply });
    if (st.tab === 'prof') return S.profile();
    return st.feedSeg === 'club' ? S.pb({ top: myPost() }) : S.feed({ top: myPost() });
  }

  function overlay() {
    let h = '';
    if (st.view === 'new') {
      h += `<div class="demo-dim" data-act="dismiss"></div><div class="rp-sheet short"><div class="rp-grabber"></div><h3>New</h3>
        <div class="demo-choice" data-act="new-session"><i>📅</i><div><b>Session</b><span>A practice, an erg session or a race</span></div></div>
        <div class="demo-choice" data-act="new-announcement"><i>📣</i><div><b>Announcement</b><span>A message to the club or a squad</span></div></div></div>`;
    }
    if (st.view === 'compose') {
      const c = COMPOSE[st.compose];
      h += `<div class="demo-dim" data-act="dismiss"></div><div class="rp-sheet short"><div class="rp-grabber"></div><h3>${c.title}</h3>
        ${c.fields.map(([k, v]) => `<div class="demo-field num"><i>${k}</i>${v}</div>`).join('')}
        <div class="rp-btn primary" style="display:block;margin-top:14px" data-act="compose-send">${c.button}</div></div>`;
    }
    if (st.toast) h += `<div class="demo-toast rp-glass"><b>✓</b>${st.toast}</div>`;
    return h;
  }

  function render(anim = 'enter') {
    phone.innerHTML = `<div class="rp-screen ${anim}">${screen()}${overlay()}</div>`;
    st.toast = ''; st.fresh = false;
    const log = $('.rp-log', phone);
    if (log) log.setAttribute('aria-label', st.mode === 'coach' ? 'New: session or announcement' : 'Log a session');
    if (log && st.mode === 'rower' && !st.done.has('log')) log.classList.add('pulse');
    // Reactions you tapped stay tapped while you move around.
    $$('.rp-card', phone).forEach(card => {
      const name = $('.name', card).textContent;
      $$('.rp-react span:not(.cm)', card).forEach((sp, i) => {
        sp.dataset.react = card.closest('.my-post') ? `post|${i}` : `${name}|${i}`;
        if (st.mine[sp.dataset.react]) bump(sp, 1);
      });
    });
    // Everything tappable is reachable with the keyboard too.
    $$('[data-tab],[data-act],[data-seg],[data-period],[data-sex],[data-level],[data-react]', phone).forEach(el => {
      if (el.classList.contains('demo-dim')) return;
      el.setAttribute('role', 'button'); el.tabIndex = 0;
    });
  }

  function bump(sp, d) {
    const [e, n] = sp.textContent.split(' ');
    sp.textContent = `${e} ${+n + d}`;
    sp.classList.toggle('mine', d > 0);
  }

  /* ---------- the log flow ---------- */
  function startLog() {
    st.view = 'capture'; st.test = null; st.include = true;
    done('log');
    render();
  }

  function shutter() {
    st.view = 'reading';
    render('');
    const vf = $('.rp-viewfinder', phone);
    phone.firstElementChild.insertAdjacentHTML('beforeend', '<div class="flash"></div>');
    vf.insertAdjacentHTML('beforeend', '<div class="scan"></div>');
    vf.classList.add('scanning');
    later(650, () => vf.classList.add('ocr-on'));
    later(1900, () => { if (st.view === 'reading') { st.view = 'review'; render('up'); } });
  }

  function post() {
    st.post = { test: st.test, include: st.include };
    st.view = null; st.tab = 'feed'; st.feedSeg = 'following'; st.fresh = true;
    st.postReacts = [0, 0, 0];
    st.toast = 'Posted';
    done('post');
    if (!st.include) note('Posted. It stays off the leaderboards, so it only counts toward your own totals.');
    else if (st.test === 'yes') note('A new 2k PB, so the post is marked PB for your club. Your 7,000m count toward this week too.');
    else note('Posted. Your 7,000m count toward this week on the leaderboard.');
    render();
    // Your crew reacts.
    [[1200, 0], [2000, 1], [2700, 0], [3400, 2], [4300, 0]].forEach(([ms, i]) => later(ms, () => {
      st.postReacts[i]++;
      const sp = $(`[data-react="post|${i}"]`, phone);
      if (sp) { const [e, n] = sp.textContent.split(' '); sp.textContent = `${e} ${+n + 1}`; }
    }));
  }

  /* ---------- taps ---------- */
  function act(el) {
    const d = el.dataset;
    if (d.react) {
      const on = !st.mine[d.react];
      st.mine[d.react] = on;
      bump(el, on ? 1 : -1);
      return;
    }
    if (d.tab) {
      st.view = null;
      if (st.mode === 'coach') {
        st.coachTab = d.tab;
        if (d.tab === 'boat') { done('boat'); note('When the coach sends the crew, each rower is told their boat and seat.'); }
      } else {
        st.tab = d.tab;
        if (d.tab === 'rank') visitRankings();
      }
      return render();
    }
    if (d.seg) {
      if (d.seg === 'following' || d.seg === 'club') st.feedSeg = d.seg;
      else { st.rankSeg = d.seg; if (d.seg === 'volume') visitRankings(); }
      return render('');
    }
    if (d.period) { st.period = d.period; return render(''); }
    if (d.sex) { st.sex = d.sex; return render(''); }
    if (d.level) { st.level = d.level; return render(''); }

    switch (d.act) {
      case 'log':
        if (st.mode === 'coach') { st.view = 'new'; return render(''); }
        return startLog();
      case 'close': st.view = null; return render();
      case 'shutter': return shutter();
      case 'test-yes': st.test = 'yes'; return render('');
      case 'test-no': st.test = 'no'; return render('');
      case 'include': st.include = !st.include; return render('');
      case 'post': return post();
      case 'reply-yes': case 'reply-no':
        st.reply = d.act === 'reply-yes' ? 'yes' : 'no';
        done('reply');
        note(st.reply === 'yes' ? 'Your coach sees you’re going, and the register fills itself in.' : 'Your coach sees you can’t make it.');
        return render('');
      case 'register':
        st.register = true; st.toast = 'Register saved';
        done('register');
        note('Present, excused and absent go into the term’s attendance.');
        return render('');
      case 'dismiss': st.view = null; return render('');
      case 'new-session': case 'new-announcement':
        st.compose = d.act.slice(4); st.view = 'compose'; return render('');
      case 'compose-send': {
        const c = COMPOSE[st.compose];
        st.coachTop.unshift(`<div class="demo-news"><div class="t">${c.card[0]}</div><div class="m num">${c.card[1]}</div></div>`);
        st.view = null; st.coachTab = 'cal'; st.toast = c.toast;
        if (st.compose === 'announcement') { done('news'); note('Every rower in the club gets it on their phone.'); }
        else note('Rowers in the squad see it in their Calendar and say if they can make it.');
        return render();
      }
    }
  }

  function visitRankings() {
    if (!st.post) { note('Post a piece first, then come back and watch your rank move.'); return; }
    done('rank');
    if (st.post.include) note('Those 7,000m took you from 3rd to 2nd this week. Try Month and Year too.');
    else note('You left this one off the leaderboards, so the board hasn’t moved.');
  }

  phone.addEventListener('click', (e) => {
    const el = e.target.closest('[data-react],[data-tab],[data-act],[data-seg],[data-period],[data-sex],[data-level]');
    if (el && phone.contains(el)) act(el);
  });
  phone.addEventListener('keydown', (e) => {
    if ((e.key === 'Enter' || e.key === ' ') && e.target.getAttribute('role') === 'button') { e.preventDefault(); act(e.target); }
  });

  /* ---------- Rower | Coach ---------- */
  const modeSeg = $('#demoMode'), thumb = $('.thumb', modeSeg);
  const place = () => { const b = $('button.on', modeSeg); thumb.style.left = b.offsetLeft + 'px'; thumb.style.width = b.offsetWidth + 'px'; };
  function setMode(m) {
    st.mode = m; st.view = null;
    $$('button', modeSeg).forEach(b => b.classList.toggle('on', b.dataset.m === m));
    place();
    note(m === 'coach' ? 'This is the coach’s app: the same squad, from the coach’s side.' : '');
    render();
  }
  $$('button', modeSeg).forEach(b => b.addEventListener('click', () => setMode(b.dataset.m)));
  addEventListener('resize', place);
  document.fonts && document.fonts.ready.then(place);

  $('#demoRestart').addEventListener('click', () => { reset(); drawTodo(); setMode('rower'); });

  reset(); drawTodo(); place(); render('');
})();
