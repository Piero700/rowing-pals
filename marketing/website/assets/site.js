/* rowingpals.com — interactions and effects. */

(function () {
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];

  RPUI.base = 'assets/';
  RPUI.mount();

  // The app's own icons wherever the page asks for one.
  $$('[data-icon]').forEach(el => { el.innerHTML = RPUI.ico(el.dataset.icon, el.dataset.icon === 'shield' ? 18 : 20); });

  // An eight on its side, seat 5 is yours.
  $('#boatDemo').innerHTML = RPUI.boat(RPUI.crew, { type: '8+', mine: 5 });

  /* ---------- segmented control with a sliding thumb ---------- */
  function segmented(root, onPick) {
    const thumb = $('.thumb', root);
    const place = (btn) => { thumb.style.left = btn.offsetLeft + 'px'; thumb.style.width = btn.offsetWidth + 'px'; };
    $$('button', root).forEach(btn => btn.addEventListener('click', () => {
      $$('button', root).forEach(b => b.classList.toggle('on', b === btn));
      place(btn); onPick(btn);
    }));
    const init = () => place($('button.on', root));
    init(); addEventListener('resize', init); document.fonts && document.fonts.ready.then(init);
  }

  /* ---------- nav shrinks on scroll, like the app's tab bar ---------- */
  const nav = $('#nav');
  addEventListener('scroll', () => nav.classList.toggle('small', scrollY > 80), { passive: true });

  /* ---------- hero phone tilts toward the cursor ---------- */
  const tilt = $('#heroTilt');
  if (!reduce && matchMedia('(pointer: fine)').matches) {
    addEventListener('pointermove', (e) => {
      const x = e.clientX / innerWidth - .5, y = e.clientY / innerHeight - .5;
      tilt.style.transform = `rotateY(${x * 14}deg) rotateX(${-y * 10}deg)`;
    }, { passive: true });
  } else if (!reduce) {
    tilt.style.transform = 'rotateY(-8deg) rotateX(4deg)';
  }

  /* ---------- counters ---------- */
  function countUp(el, to, ms, fmt) {
    if (reduce) return;
    const start = performance.now();
    const step = (t) => {
      const p = Math.max(0, Math.min(1, (t - start) / ms)), e = 1 - Math.pow(1 - p, 3);
      el.firstChild.nodeValue = fmt(to * e);
      if (p < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  }
  // Counts a time like 7:07.3 down to 7:04.1: a PB arriving.
  function countTime(el) {
    if (reduce) return;
    const toS = (s) => { const [m, r] = s.split(':'); return +m * 60 + +r; };
    const from = toS(el.dataset.from), to = toS(el.dataset.countTime);
    const fmt = (v) => { const m = Math.floor(v / 60), s = (v - m * 60).toFixed(1).padStart(4, '0'); return `${m}:${s}`; };
    const start = performance.now(), ms = 1600;
    const step = (t) => {
      const p = Math.max(0, Math.min(1, (t - start) / ms)), e = 1 - Math.pow(1 - p, 4);
      el.firstChild.nodeValue = fmt(from + (to - from) * e);
      if (p < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  }

  /* ---------- hero: scan the monitor, box each number, count the post up ---------- */
  const heroMedia = $('#heroPhone .rp-media');
  const heroMetres = $('#heroPhone [data-hero-metres]');
  heroMedia.insertAdjacentHTML('beforeend', '<div class="scan"></div>');
  function scanLoop() {
    heroMedia.classList.remove('scanning', 'ocr-on'); void heroMedia.offsetWidth;
    heroMedia.classList.add('scanning');
    setTimeout(() => heroMedia.classList.add('ocr-on'), 700);
    setTimeout(() => countUp(heroMetres, 12000, 1200, v => Math.round(v).toLocaleString('en-GB') + 'm'), 1300);
  }
  if (!reduce) { setTimeout(scanLoop, 900); setInterval(scanLoop, 7000); } else heroMedia.classList.add('ocr-on');

  /* ---------- marquee ---------- */
  const words = ['2K TEST', 'STEADY STATE', '6K', 'CLUB 2K DAY', '30 MIN', '100KM IN NOVEMBER', '5K', '3 × 2K', '10K', 'UT2'];
  const run = words.map((w, i) => `<span class="${i % 3 === 0 ? 'fill' : ''}">${w}</span><span class="dot">●</span>`).join('');
  $('#marquee').innerHTML = run + run;

  /* ---------- reveal on scroll ---------- */
  const io = new IntersectionObserver((entries) => entries.forEach(en => {
    if (!en.isIntersecting) return;
    en.target.classList.add('in');
    $$('[data-count]', en.target).forEach(c => countUp(c, +c.dataset.count, 1400, v => Math.round(v)));
    $$('[data-count-time]', en.target).forEach(countTime);
    io.unobserve(en.target);
  }), { threshold: .15 });
  $$('[data-reveal]').forEach(el => io.observe(el));

  /* PB sparks */
  const sparks = $('#sparks');
  for (let i = 0; i < 14; i++) {
    const a = Math.random() * Math.PI * 2, d = 60 + Math.random() * 110;
    sparks.insertAdjacentHTML('beforeend', `<i style="--tx:${(Math.cos(a) * d).toFixed(0)}px;--ty:${(Math.sin(a) * d).toFixed(0)}px;--dl:${(Math.random() * 2.4).toFixed(2)}s"></i>`);
  }

  /* ---------- how it works: sticky phone follows the step in view ---------- */
  const steps = $$('.step'), storyPhones = $$('.story-device .phone');
  const stepIO = new IntersectionObserver((entries) => entries.forEach(en => {
    if (!en.isIntersecting) return;
    const i = +en.target.dataset.step;
    steps.forEach((s, j) => s.classList.toggle('active', i === j));
    storyPhones.forEach((p, j) => p.classList.toggle('on', i === j));
  }), { rootMargin: '-45% 0px -45% 0px' });
  steps.forEach(s => stepIO.observe(s));
  steps[0].classList.add('active');

  /* ---------- leaderboard with FLIP re-ordering ---------- */
  const people = { 'Tom Ashworth': false, 'Joe Fenwick': false, 'Sam Cole': true, 'Marcus Reilly': false, 'Ollie Grant': false };
  const boards = {
    week: { 'Tom Ashworth': 128400, 'Joe Fenwick': 121900, 'Sam Cole': 116250, 'Marcus Reilly': 104800, 'Ollie Grant': 88300 },
    month: { 'Joe Fenwick': 512300, 'Sam Cole': 498100, 'Tom Ashworth': 470900, 'Ollie Grant': 401200, 'Marcus Reilly': 388000 },
    year: { 'Sam Cole': 4812000, 'Tom Ashworth': 4700500, 'Joe Fenwick': 4522900, 'Marcus Reilly': 3980100, 'Ollie Grant': 2904800 }
  };
  const rowsEl = $('#boardRows');
  rowsEl.innerHTML = Object.keys(people).map(n => `<div class="brow ${people[n] ? 'me' : ''}" data-n="${n}"><div class="pos"></div><div class="rp-av">${n.split(' ').map(w => w[0]).join('')}</div>
      <div class="who"><b>${n}</b><span>Riverside BC</span></div><div class="val"><span class="v">0</span><small>m</small></div></div>`).join('');
  const shown = {};
  function showBoard(period, animate) {
    const data = boards[period];
    const order = Object.keys(data).sort((a, b) => data[b] - data[a]);
    const rows = $$('.brow', rowsEl);
    const first = new Map(rows.map(r => [r, r.getBoundingClientRect().top]));
    order.forEach((n, i) => {
      const row = $(`.brow[data-n="${n}"]`, rowsEl);
      rowsEl.appendChild(row);
      $('.pos', row).textContent = i + 1;
      row.classList.toggle('first', i === 0);
      const v = $('.v', row), from = shown[n] || 0, to = data[n];
      shown[n] = to;
      if (reduce) { v.textContent = to.toLocaleString('en-GB'); return; }
      const start = performance.now();
      const tick = (t) => {
        const p = Math.max(0, Math.min(1, (t - start) / 900)), e = 1 - Math.pow(1 - p, 3);
        v.textContent = Math.round(from + (to - from) * e).toLocaleString('en-GB');
        if (p < 1) requestAnimationFrame(tick);
      };
      requestAnimationFrame(tick);
    });
    if (!animate || reduce) return;
    $$('.brow', rowsEl).forEach(r => {
      const dy = first.get(r) - r.getBoundingClientRect().top;
      if (!dy) return;
      r.animate([{ transform: `translateY(${dy}px)` }, { transform: 'none' }], { duration: 700, easing: 'cubic-bezier(.3,1.25,.5,1)' });
    });
  }
  segmented($('#periodSeg'), (btn) => showBoard(btn.dataset.p, true));
  showBoard('week', false);

  /* ---------- coach showcase: tabs auto-advance with a progress bar ---------- */
  const grid = $('#coachGrid'), ctabs = $$('.ctab'), cphones = $$('.coach-stage .phone');
  const DUR = 6000;
  let ci = 0, timer = null;
  grid.style.setProperty('--dur', DUR + 'ms');
  function showCoach(i) {
    ci = i;
    ctabs.forEach((t, j) => { t.classList.remove('on'); if (j === i) { void t.offsetWidth; t.classList.add('on'); } });
    cphones.forEach((p, j) => { p.classList.remove('on'); if (j === i) { void p.offsetWidth; p.classList.add('on'); } });
  }
  function startTimer() { clearInterval(timer); if (!reduce) timer = setInterval(() => showCoach((ci + 1) % ctabs.length), DUR); }
  ctabs.forEach((t, i) => t.addEventListener('click', () => { showCoach(i); startTimer(); }));
  grid.addEventListener('pointerenter', (e) => { if (e.pointerType === 'mouse') { grid.classList.add('paused'); clearInterval(timer); } });
  grid.addEventListener('pointerleave', (e) => { if (e.pointerType === 'mouse') { grid.classList.remove('paused'); startTimer(); } });
  const coachIO = new IntersectionObserver((en) => { if (en[0].isIntersecting) { showCoach(0); startTimer(); coachIO.disconnect(); } }, { threshold: .3 });
  coachIO.observe(grid);

  /* ---------- water: layered swells on a canvas, solid lines with a soft glow ---------- */
  $$('canvas[data-water]').forEach(cv => {
    const ctx = cv.getContext('2d');
    let w, h, visible = true;
    const size = () => { const dpr = Math.min(2, devicePixelRatio || 1); w = cv.clientWidth; h = cv.clientHeight; cv.width = w * dpr; cv.height = h * dpr; ctx.setTransform(dpr, 0, 0, dpr, 0, 0); };
    size(); addEventListener('resize', size);
    new IntersectionObserver((en) => { visible = en[0].isIntersecting; }).observe(cv);
    const layers = [
      { amp: 26, len: 520, speed: .00025, y: .38, a: .5, c: '145,184,255' },
      { amp: 20, len: 380, speed: -.0004, y: .5, a: .32, c: '145,184,255' },
      { amp: 32, len: 700, speed: .0002, y: .62, a: .24, c: '145,184,255' },
      { amp: 16, len: 300, speed: .0006, y: .74, a: .16, c: '145,184,255' },
      { amp: 22, len: 460, speed: -.0003, y: .86, a: .1, c: '145,184,255' }
    ];
    function draw(t) {
      ctx.clearRect(0, 0, w, h);
      layers.forEach((L, k) => {
        const base = h * L.y;
        ctx.beginPath();
        for (let x = 0; x <= w + 10; x += 10) {
          const y = base + Math.sin(x / L.len * Math.PI * 2 + t * L.speed * 6) * L.amp + Math.sin(x / (L.len * .37) + t * L.speed * 9 + k) * L.amp * .35;
          x ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
        }
        ctx.strokeStyle = `rgba(${L.c},${L.a})`; ctx.lineWidth = 1.6; ctx.shadowColor = `rgba(${L.c},.6)`; ctx.shadowBlur = 10;
        ctx.stroke();
      });
    }
    function frame(t) { if (visible) draw(t); requestAnimationFrame(frame); }
    if (reduce) draw(0); else requestAnimationFrame(frame);
  });
})();
