// Bookgist landing page. No dependencies: the scroll scenes are driven by one rAF loop reading each section's progress.
(() => {
  // Set this to the public TestFlight invite (https://testflight.apple.com/join/<code>) once the beta is public.
  const TESTFLIGHT_URL = 'https://testflight.apple.com/join/BOOKBITE';

  const BOOKS = window.BB_BOOKS || [];
  const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
  const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
  const range = (p, a, b) => clamp((p - a) / (b - a));
  const easeOut = (t) => 1 - Math.pow(1 - t, 3);

  $$('[data-testflight]').forEach((a) => { a.href = TESTFLIGHT_URL; a.rel = 'noopener'; });
  $$('[data-year]').forEach((el) => { el.textContent = new Date().getFullYear(); });

  /* ---------- Hero ---------- */
  const title = $('[data-split]');
  if (title) {
    const words = title.innerHTML.split(' ');
    title.setAttribute('aria-label', title.textContent);
    title.innerHTML = words.map((w, i) => `<span class="w" aria-hidden="true"><span style="--i:${i}">${w}</span></span>`).join(' ');
  }
  requestAnimationFrame(() => requestAnimationFrame(() => document.body.classList.add('is-loaded')));

  /* ---------- The walkthrough ---------- */
  const tour = $('[data-tour]');
  const tourDevice = $('[data-tour-device]');
  const tourScreens = $$('[data-tour-screen]');
  const tourSteps = $$('[data-tour-step]');
  const tourJumps = $$('[data-tour-jump]');
  const INTRO_END = 0.05;
  // How much scroll each part of the app gets: the screens that scroll inside the phone need more
  const WEIGHTS = [2.2, 2.2, 1.2, 1.6];
  const TOTAL = WEIGHTS.reduce((a, b) => a + b, 0);
  const STARTS = WEIGHTS.map((_, i) => WEIGHTS.slice(0, i).reduce((a, b) => a + b, 0) / TOTAL);
  let tourIdx = -1;

  function updateTour(p) {
    const rise = easeOut(range(p, 0, INTRO_END));
    const small = innerWidth <= 900;
    tourDevice.style.setProperty('--dev-y', `${(1 - rise) * innerHeight * (small ? 0.06 : 0.16)}px`);
    tourDevice.style.setProperty('--dev-s', 1 - (1 - rise) * 0.06);

    const f = range(p, INTRO_END, 1);
    let idx = STARTS.length - 1;
    while (idx > 0 && f < STARTS[idx]) idx--;
    const lp = clamp((f - STARTS[idx]) / (WEIGHTS[idx] / TOTAL));
    if (idx !== tourIdx) {
      tourIdx = idx;
      tourScreens.forEach((s, i) => { s.classList.toggle('is-active', i === idx); s.classList.toggle('is-past', i < idx); });
      tourSteps.forEach((s, i) => { s.classList.toggle('is-active', i === idx); });
      tourJumps.forEach((b, i) => { if (i === idx) b.setAttribute('aria-current', 'step'); else b.removeAttribute('aria-current'); });
    }
    // The screen on stage scrolls, or steps through its shots
    const screen = tourScreens[idx];
    const tall = $('[data-tall]', screen);
    if (tall) {
      const travel = Math.max(0, tall.offsetHeight - screen.offsetHeight);
      tall.style.setProperty('--scroll', `${-range(lp, 0.08, 0.94) * travel}px`);
    }
    const shots = $$('.shot-layer', screen);
    if (shots.length > 1) {
      const n = Math.min(shots.length - 1, Math.floor(lp * shots.length));
      shots.forEach((s, i) => s.classList.toggle('is-on', i === n));
    }
  }

  tourJumps.forEach((b, i) => b.addEventListener('click', () => {
    const r = tour.getBoundingClientRect();
    const f = STARTS[i] + 0.04;
    scrollTo({ top: scrollY + r.top + (INTRO_END + f * (1 - INTRO_END)) * (r.height - innerHeight), behavior: reduceMotion ? 'auto' : 'smooth' });
  }));

  /* ---------- The collection: real covers ---------- */
  const SHELF = ['Atomic Habits', 'Sapiens', 'The Psychology of Money', 'Deep Work', 'Thinking, Fast and Slow', 'Never Split the Difference', 'The Power of Habit', 'Zero to One', 'Meditations', 'The Laws of Human Nature', 'Ikigai', 'Influence', 'Rich Dad Poor Dad', 'Mindset', 'The Body Keeps the Score', 'Steve Jobs', 'The Lean Startup', 'The 48 Laws of Power', 'The Intelligent Investor', 'The Power of Now', 'Emotional Intelligence', 'A Brief History of Time', 'The Prince', 'Ego Is the Enemy'];
  const fillShelf = (el, titles) => titles.map((t) => BOOKS.find((b) => b.title === t)).filter(Boolean).forEach((b) => {
    const img = new Image();
    img.alt = b.title;
    img.decoding = 'async';
    img.src = b.cover.replace('fife=w1200-h1800', 'fife=w300-h450').replace('1600x1600bb', '300x300bb');
    el.append(img);
  });
  fillShelf($('[data-shelfline]'), SHELF);

  /* ---------- Ask: the answer arrives once, when the card comes on screen ---------- */
  const thread = $('[data-thread]');
  const cited = [
    'https://books.google.com/books/publisher/content/images/frontcover/H6x-DwAAQBAJ?fife=w300-h450&source=gbs_api',
    'https://books.google.com/books/publisher/content/images/frontcover/Yq35BY5Fk3gC?fife=w300-h450&source=gbs_api',
    'https://covers.openlibrary.org/b/id/14632659-M.jpg',
  ];
  const addCover = (el, src, angle) => {
    const img = new Image();
    img.alt = '';
    img.src = src;
    if (angle !== undefined) img.style.setProperty('--a', `${angle}deg`);
    el.append(img);
  };
  cited.forEach((src) => addCover($('[data-read-covers]'), src));
  [cited[2], cited[1], cited[0]].forEach((src, i) => addCover($('[data-fan]'), src, [-13, 13, 0][i]));
  if (!reduceMotion) {
    thread.classList.add('pre');
    new IntersectionObserver(([e], io) => {
      if (!e.isIntersecting) return;
      io.disconnect();
      thread.classList.remove('pre');
    }, { threshold: 0.3 }).observe(thread);
  }
  const task = $('[data-task]');
  task.addEventListener('click', () => task.setAttribute('aria-pressed', String(task.getAttribute('aria-pressed') !== 'true')));

  /* ---------- Reader themes ---------- */
  const swatches = $$('[data-swatch]');
  swatches.forEach((b) => b.addEventListener('click', () => {
    b.closest('[data-page-theme]').dataset.pageTheme = b.dataset.swatch;
    swatches.forEach((x) => x.setAttribute('aria-checked', String(x === b)));
  }));

  /* ---------- Audio: the waveform plays while it's on screen ---------- */
  const wave = $('[data-wave]');
  const waveAt = $('[data-wave-at]');
  const BARS = 44, LENGTH = 300;
  const bars = Array.from({ length: BARS }, (_, i) => {
    const b = document.createElement('i');
    b.style.setProperty('--h', `${Math.round(22 + Math.abs(Math.sin(i * 1.7) * 48 + Math.sin(i * 0.43) * 30))}%`);
    wave.append(b);
    return b;
  });
  let played = 42;
  const showPlayed = () => {
    bars.forEach((b, i) => b.classList.toggle('on', i / BARS < played / LENGTH));
    waveAt.textContent = `${Math.floor(played / 60)}:${String(Math.floor(played % 60)).padStart(2, '0')}`;
  };
  showPlayed();
  if (!reduceMotion) {
    let timer = null;
    new IntersectionObserver(([e]) => {
      if (e.isIntersecting && !timer) timer = setInterval(() => { played = (played + 1) % LENGTH; showPlayed(); }, 1000);
      else if (!e.isIntersecting && timer) { clearInterval(timer); timer = null; }
    }).observe(wave);
  }

  /* ---------- CTA icon tilt ---------- */
  const cta = $('[data-cta]');
  const ctaIcon = $('[data-cta-icon]');
  if (cta && !reduceMotion && matchMedia('(pointer: fine)').matches) {
    cta.addEventListener('pointermove', (e) => {
      const r = ctaIcon.getBoundingClientRect();
      const x = (e.clientX - (r.left + r.width / 2)) / innerWidth;
      const y = (e.clientY - (r.top + r.height / 2)) / innerHeight;
      ctaIcon.style.setProperty('--ry', `${x * 40}deg`);
      ctaIcon.style.setProperty('--rx', `${-y * 40}deg`);
      ctaIcon.style.setProperty('--gx', `${50 + x * 120}%`);
      ctaIcon.style.setProperty('--gy', `${50 + y * 120}%`);
    });
    cta.addEventListener('pointerleave', () => { ['--rx', '--ry'].forEach((v) => ctaIcon.style.setProperty(v, '0deg')); });
  }

  /* ---------- Loop ---------- */
  const nav = $('[data-nav]');
  const darks = $$('[data-dark]');
  const progressOf = (el) => {
    const r = el.getBoundingClientRect();
    return clamp(-r.top / (r.height - innerHeight));
  };
  const visible = (el) => { const r = el.getBoundingClientRect(); return r.bottom > 0 && r.top < innerHeight; };

  function frame() {
    nav.classList.toggle('is-stuck', scrollY > 40);
    const navY = 40;
    nav.classList.toggle('on-dark', darks.some((d) => { const r = d.getBoundingClientRect(); return r.top <= navY && r.bottom > navY; }));

    if (visible(tour)) updateTour(progressOf(tour));
    requestAnimationFrame(frame);
  }
  updateTour(0);
  requestAnimationFrame(frame);
})();
