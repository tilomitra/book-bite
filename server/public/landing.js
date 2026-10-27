// BookBite landing page. No dependencies: scroll scenes are driven by one rAF loop reading each section's progress.
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
  const backOut = (t) => 1 + 2.4 * Math.pow(t - 1, 3) + 1.4 * Math.pow(t - 1, 2);

  $$('[data-testflight]').forEach((a) => { a.href = TESTFLIGHT_URL; a.rel = 'noopener'; });
  $$('[data-year]').forEach((el) => { el.textContent = new Date().getFullYear(); });
  const today = $('[data-today]');
  if (today) today.textContent = new Date().toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long' });

  /* ---------- Covers ---------- */
  // Bookcloth colours, as in the app's TypographicCover: picked from the title so a book always gets the same one
  const CLOTHS = ['#732324', '#2f4a3a', '#24364f', '#5b4a2e', '#3d2c44', '#6a5a3c', '#2e3d3f', '#4a2a22'];
  const clothFor = (title) => CLOTHS[[...title].reduce((h, c) => (h * 31 + c.charCodeAt(0)) >>> 0, 7) % CLOTHS.length];

  function coverEl(book, { lazy = true } = {}) {
    const el = document.createElement('div');
    el.className = 'cover';
    el.style.setProperty('--cloth', clothFor(book.title));
    const t = document.createElement('span'); t.className = 't'; t.textContent = book.title;
    const a = document.createElement('span'); a.className = 'a'; a.textContent = book.author;
    el.append(t, a);
    if (book.cover) {
      const img = new Image();
      img.alt = '';
      img.decoding = 'async';
      if (lazy) img.loading = 'lazy';
      img.onload = () => img.classList.add('ok');
      img.src = book.cover;
      el.append(img);
    }
    return el;
  }
  const shuffled = (list, seed) => {
    const out = [...list];
    let s = seed;
    for (let i = out.length - 1; i > 0; i--) {
      s = (s * 9301 + 49297) % 233280;
      const j = Math.floor((s / 233280) * (i + 1));
      [out[i], out[j]] = [out[j], out[i]];
    }
    return out;
  };

  /* ---------- Hero ---------- */
  const title = $('[data-split]');
  if (title) {
    const words = title.innerHTML.split(' ');
    title.setAttribute('aria-label', title.textContent);
    title.innerHTML = words.map((w, i) => `<span class="w" aria-hidden="true"><span style="--i:${i}">${w}</span></span>`).join(' ');
  }

  // A few covers float around the hero phone; the pointer nudges them by depth
  const device = $('[data-tilt]');
  const floaters = [];
  if (device && BOOKS.length) {
    const box = document.createElement('div');
    box.className = 'floaters';
    box.setAttribute('aria-hidden', 'true');
    const picks = ['Atomic Habits', 'The Psychology of Money', 'Sapiens', 'The Power of Habit', 'Zero to One', 'Ikigai'];
    picks.map((t) => BOOKS.find((b) => b.title === t)).filter(Boolean).forEach((b, i) => {
      const c = coverEl(b, { lazy: false });
      c.style.setProperty('--dl', `${i * -1.3}s`);
      c.style.setProperty('--depth', `${18 + (i % 3) * 14}px`);
      box.append(c);
      floaters.push(c);
    });
    device.prepend(box);
  }

  $$('[data-shelf]').forEach((shelf, i) => {
    shuffled(BOOKS, 40 + i * 11).slice(0, 10).forEach((b) => shelf.append(coverEl(b, { lazy: false })));
  });

  requestAnimationFrame(() => requestAnimationFrame(() => document.body.classList.add('is-loaded')));

  // Pointer parallax: the phone leans toward the cursor and the covers drift
  const hero = $('[data-hero]');
  const tilt = $('[data-tilt] .phone');
  let pointer = { x: 0, y: 0 };
  if (hero && !reduceMotion && matchMedia('(pointer: fine)').matches) {
    hero.addEventListener('pointermove', (e) => {
      const r = hero.getBoundingClientRect();
      pointer = { x: (e.clientX - r.left) / r.width - 0.5, y: (e.clientY - r.top) / r.height - 0.5 };
      if (tilt) {
        tilt.style.setProperty('--ry', `${-10 + pointer.x * 16}deg`);
        tilt.style.setProperty('--rx', `${4 - pointer.y * 10}deg`);
      }
      floaters.forEach((c) => { c.style.setProperty('--px', -pointer.x * 2); c.style.setProperty('--py', -pointer.y * 2); });
    });
  }

  /* ---------- Nav ---------- */
  const nav = $('[data-nav]');

  /* ---------- Bite ---------- */
  const bite = $('[data-bite]');
  const biteCover = $('[data-bite-cover]');
  const biteHook = $('[data-bite-hook]');
  const biteSource = $('[data-bite-source]');
  const biteMeter = $('[data-bite-meter]');
  const crumbsCanvas = $('[data-crumbs]');
  let hookWords = [];
  if (biteHook) {
    biteHook.innerHTML = biteHook.textContent.trim().split(/\s+/).map((w) => `<span class="w">${w}</span>`).join(' ');
    hookWords = $$('.w', biteHook);
  }
  const BITES = [
    { at: 0.1, x: 0.8, y: 0.03 },
    { at: 0.2, x: 0.99, y: 0.12 },
    { at: 0.3, x: 1.01, y: 0.27 },
  ];
  const bitten = BITES.map(() => false);

  // Crumbs: a burst of paper flecks each time a bite lands
  const crumbs = [];
  const ctx = crumbsCanvas?.getContext('2d');
  function spawnCrumbs(b) {
    if (!ctx || reduceMotion) return;
    const cr = crumbsCanvas.getBoundingClientRect();
    const cv = biteCover.getBoundingClientRect();
    const x = cv.left - cr.left + b.x * cv.width;
    const y = cv.top - cr.top + b.y * cv.height;
    const colors = ['#e9e6dd', '#d8d4c9', '#bcb6a8', '#2a2623', '#c9a24a'];
    for (let i = 0; i < 26; i++) {
      const a = -Math.PI / 2 + (Math.random() - 0.2) * Math.PI * 1.1;
      const v = 2 + Math.random() * 6;
      crumbs.push({ x, y, vx: Math.cos(a) * v + 1.5, vy: Math.sin(a) * v, r: 1.5 + Math.random() * 3.5, rot: Math.random() * 6, vr: (Math.random() - 0.5) * 0.4, life: 1, c: colors[i % colors.length] });
    }
  }
  function drawCrumbs() {
    if (!ctx) return;
    const dpr = Math.min(devicePixelRatio, 2);
    const w = crumbsCanvas.clientWidth, h = crumbsCanvas.clientHeight;
    if (crumbsCanvas.width !== w * dpr) { crumbsCanvas.width = w * dpr; crumbsCanvas.height = h * dpr; }
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);
    for (let i = crumbs.length - 1; i >= 0; i--) {
      const p = crumbs[i];
      p.vy += 0.32; p.vx *= 0.985; p.x += p.vx; p.y += p.vy; p.rot += p.vr; p.life -= 0.012;
      if (p.life <= 0 || p.y > h) { crumbs.splice(i, 1); continue; }
      ctx.save();
      ctx.globalAlpha = Math.min(1, p.life * 1.5);
      ctx.translate(p.x, p.y); ctx.rotate(p.rot);
      ctx.fillStyle = p.c;
      ctx.fillRect(-p.r, -p.r * 0.7, p.r * 2, p.r * 1.4);
      ctx.restore();
    }
  }

  function updateBite(p) {
    const w = biteCover.offsetWidth;
    BITES.forEach((b, i) => {
      const t = range(p, b.at, b.at + 0.05);
      biteCover.style.setProperty(`--r${i + 1}`, `${(t > 0 ? backOut(t) : 0) * w * 0.21}px`);
      if (t > 0 && !bitten[i]) { bitten[i] = true; spawnCrumbs(b); }
      if (p < b.at - 0.02) bitten[i] = false;
    });
    const turn = easeOut(range(p, 0, 0.4));
    biteCover.style.setProperty('--ry', `${-22 + turn * 22}deg`);
    biteCover.style.setProperty('--s', `${1 - easeOut(range(p, 0.38, 0.6)) * 0.12}`);
    const words = range(p, 0.36, 0.86) * hookWords.length;
    hookWords.forEach((el, i) => el.style.setProperty('--o', 0.1 + 0.9 * clamp(words - i)));
    biteSource.style.setProperty('--o', range(p, 0.86, 0.92));
    biteMeter.style.transform = `scaleX(${p})`;
  }

  /* ---------- Solve ---------- */
  // Example problems; steps come from each book's "How to apply it" section in the app
  const PROBLEMS = [
    {
      problem: 'I keep putting off the big task',
      book: 'Eat That Frog!',
      why: 'Do your most important task first, before easier work takes over the day.',
      steps: [
        'Tonight, write tomorrow’s list and mark the one task with the biggest impact.',
        'Start your day with a distraction-free block on that task, before you check messages.',
        'If it feels daunting, define the next concrete step and work in short, timed chunks.',
      ],
      ask: 'What if the big task depends on other people?',
      answer: 'Tracy would have you split it. Find the part only you can do and make that tomorrow morning’s frog. Send your requests to others first thing, so their part moves while you work on yours.',
    },
    {
      problem: 'I can’t stop checking my phone',
      book: 'Deep Work',
      why: 'Focus is a rare, valuable skill, and you can train it like any other.',
      steps: [
        'Schedule protected focus blocks and decide in advance what each one is for.',
        'During a block, silence notifications and keep messaging closed.',
        'Practise boredom: wait in a line or take a walk without reaching for your phone.',
      ],
      ask: 'I need my phone for work, though.',
      answer: 'Newport’s point is to be deliberate, not to go offline. Pick set times to check messages, say three a day, and leave the phone in another room during focus blocks. Most things that feel urgent can wait two hours.',
    },
    {
      problem: 'I want to stop stressing about money',
      book: 'The Psychology of Money',
      why: 'Financial success is less about formulas and more about your behaviour.',
      steps: [
        'Write down what “enough” means for you, and check big decisions against it.',
        'Build a buffer, like an emergency fund, so a setback never forces a rushed choice.',
        'Pick an investing approach you can stick with when markets fall.',
      ],
      ask: 'My friends earn more and I feel behind.',
      answer: 'Housel would say comparison has no finish line. Define what a good life costs for you and measure progress against that, not against what other people appear to spend.',
    },
    {
      problem: 'I have a tough conversation coming up',
      book: 'Never Split the Difference',
      why: 'Negotiation lessons from a former FBI hostage negotiator, for any high-stakes talk.',
      steps: [
        'Label the other person’s emotions out loud: “It seems like you’re worried about…”',
        'Ask “what” and “how” questions instead of yes-or-no ones.',
        'Mirror their last few words to keep them talking.',
      ],
      ask: 'I need to ask my boss for a raise.',
      answer: 'Voss would start by naming what your boss is likely feeling: “It seems like budgets are tight this year.” Then ask, “How can we get my pay in line with what I now deliver?” It invites them to solve the problem with you.',
    },
    {
      problem: 'My new habits never stick',
      book: 'Atomic Habits',
      why: 'Small changes, repeated daily, add up to remarkable results.',
      steps: [
        'Make it obvious: put the cue where you’ll see it, like a book on your pillow.',
        'Shrink the habit until it takes two minutes, then show up every day.',
        'Think in identity: not “I want to read” but “I’m a reader.”',
      ],
      ask: 'I always quit after a week.',
      answer: 'Clear’s rule is never miss twice. One missed day is an accident; two is the start of a new habit. Keep the habit small enough that even on a bad day you can do the two-minute version.',
    },
  ].map((p) => ({ ...p, ...(BOOKS.find((b) => b.title === p.book) || {}) }));

  const solveCard = $('[data-solve-card]');
  const problemsEl = $('[data-problems]');
  let solveIndex = -1, solveTimers = [], solveAuto = null, solveTyping = null;
  function showProblem(i) {
    if (!solveCard || i === solveIndex) return;
    solveIndex = i;
    const p = PROBLEMS[i];
    $$('button', problemsEl).forEach((b, j) => b.setAttribute('aria-selected', String(j === i)));
    solveTimers.forEach(clearTimeout); solveTimers = [];
    clearInterval(solveTyping);
    $('[data-solve-q]').textContent = p.problem;
    $('[data-solve-img]').src = p.cover || '';
    $('[data-solve-title]').textContent = `${p.book}${p.author ? `, ${p.author}` : ''}`;
    $('[data-solve-why]').textContent = p.why;
    const steps = $('[data-solve-steps]');
    steps.replaceChildren(...p.steps.map((t) => { const li = document.createElement('li'); li.textContent = t; return li; }));
    $('[data-ask-q]').textContent = p.ask;
    const answer = $('[data-ask-a]');
    answer.textContent = '';
    const parts = [$('[data-solve-q]'), ...$$('[data-solve-part]', solveCard).slice(0, 2), ...steps.children, $('.solve-ask')];
    parts.forEach((el) => { el.classList.add('rv'); el.classList.remove('in'); });
    if (reduceMotion) { parts.forEach((el) => el.classList.add('in')); answer.textContent = p.answer; return; }
    parts.forEach((el, k) => solveTimers.push(setTimeout(() => el.classList.add('in'), 120 + k * 260)));
    // The follow-up answer types out once the steps are in
    solveTimers.push(setTimeout(() => {
      let n = 0;
      solveTyping = setInterval(() => {
        n = Math.min(p.answer.length, n + 3);
        answer.textContent = p.answer.slice(0, n);
        if (n < p.answer.length) answer.insertAdjacentHTML('beforeend', '<span class="caret"></span>');
        else clearInterval(solveTyping);
      }, 24);
    }, 120 + parts.length * 260 + 200));
  }
  if (problemsEl && solveCard) {
    PROBLEMS.forEach((p, i) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.setAttribute('role', 'tab');
      b.textContent = p.problem;
      b.addEventListener('click', () => { clearInterval(solveAuto); solveAuto = 'off'; showProblem(i); });
      problemsEl.append(b);
    });
    let started = false;
    new IntersectionObserver(([e]) => {
      if (e.isIntersecting && !started) { started = true; showProblem(0); }
      if (reduceMotion || solveAuto === 'off') return;
      if (e.isIntersecting && !solveAuto) solveAuto = setInterval(() => showProblem((solveIndex + 1) % PROBLEMS.length), 11000);
      else if (!e.isIntersecting && solveAuto) { clearInterval(solveAuto); solveAuto = null; }
    }, { threshold: 0.35 }).observe(solveCard);
  }

  /* ---------- Story ---------- */
  const story = $('[data-story]');
  const steps = $$('[data-step]');
  const screens = $$('[data-scr]');
  const dots = $$('.story-dots li');
  const deck = $('[data-deck]');
  const IDEAS = [
    '<b>Focus is a skill.</b> Distraction-free effort on demanding tasks helps you learn hard things faster and do better work.',
    '<b>It’s what the economy rewards:</b> mastering difficult skills quickly and producing results at a high level.',
    '<b>It’s getting rare.</b> Constant connectivity, quick replies and task switching crowd it out of the day.',
    '<b>It feels better, too.</b> Sustained attention and care for craft make work more meaningful.',
    '<b>Build routines, not willpower.</b> Time-block your focus periods and make deep work a regular part of the week.',
    '<b>Four rules:</b> work deeply, embrace boredom, quit social media you don’t need, and drain the shallows.',
  ];
  const cards = IDEAS.map((html, i) => {
    const c = document.createElement('div');
    c.className = 'idea-card';
    c.innerHTML = `<span>${html}</span><span class="n">${i + 1} / ${IDEAS.length}</span>`;
    deck?.append(c);
    return c;
  });
  const deckCount = $('[data-deck-count]');
  const keep = $('[data-keep]');
  const readerScr = $('[data-scr="1"]');
  const readerPage = $('[data-reader-page]');
  const readerProgress = $('[data-reader-progress]');
  const readerLeft = $('[data-reader-left]');
  const themeNames = $$('[data-theme-name]');
  const listenScr = $('[data-scr="2"]');
  const wave = $('[data-wave]');
  const listenAt = $('[data-listen-at]');
  const chatQ = $('[data-chat-q]');
  const chatA = $('[data-chat-a]');
  const ANSWER = 'Newport’s advice is to start small and protect it. Block one hour early in the day for a single demanding task, with email closed. Then batch the shallow work into two or three set times instead of answering messages as they arrive.';
  const STORY_HUES = [8, 32, 48, 352];
  const waveBars = [];
  if (wave) {
    for (let i = 0; i < 46; i++) {
      const bar = document.createElement('i');
      const h = 18 + Math.abs(Math.sin(i * 1.7) * 52 + Math.sin(i * 0.43) * 30);
      bar.style.setProperty('--h', `${Math.min(100, h)}%`);
      bar.style.setProperty('--dl', `${(i % 7) * -0.15}s`);
      wave.append(bar);
      waveBars.push(bar);
    }
  }
  let lastStep = -1;

  function updateStory(p) {
    const n = steps.length;
    const f = clamp(p, 0, 0.9999) * n;
    const idx = Math.floor(f);
    const lp = f - idx;
    if (idx !== lastStep) {
      steps.forEach((s, i) => {
        s.classList.toggle('is-active', i === idx);
        s.classList.toggle('is-before', i < idx);
        s.classList.toggle('is-after', i > idx);
      });
      screens.forEach((s, i) => {
        s.classList.toggle('is-active', i === idx);
        s.classList.toggle('is-past', i < idx);
      });
      story.style.setProperty('--story-h', STORY_HUES[idx]);
      $('.story-device .phone').style.setProperty('--rot', `${[-3, 2, -2, 3][idx]}deg`);
      lastStep = idx;
    }
    dots.forEach((d, i) => d.style.setProperty('--f', i < idx ? 1 : i === idx ? lp : 0));

    // Key ideas: cards fly off as you scroll
    const cardF = clamp(range(lp, 0.05, 0.9) * (cards.length - 1), 0, cards.length - 1);
    const current = Math.round(cardF);
    cards.forEach((c, i) => {
      const d = i - cardF;
      let tf, op = 1;
      if (d < -0.5) { tf = `translateX(-130%) rotate(-12deg)`; op = 0; }
      else if (d <= 0) { tf = `translateX(${d * 120}%) rotate(${d * 10}deg)`; }
      else { tf = `translateY(${Math.min(d, 2) * 9}px) scale(${1 - Math.min(d, 2) * 0.05})`; op = d > 2.5 ? 0 : 1; }
      c.style.transform = tf;
      c.style.opacity = op;
      c.style.zIndex = 100 - i;
    });
    if (deckCount) deckCount.textContent = current + 1;
    keep?.classList.toggle('is-kept', current >= 4);
    if (keep) keep.textContent = current >= 4 ? 'Kept' : 'Keep';

    // Reader: scrolls, and switches Paper → Sepia → Night
    const theme = lp < 0.36 ? 'paper' : lp < 0.7 ? 'sepia' : 'night';
    readerScr.classList.toggle('t-sepia', theme === 'sepia');
    readerScr.classList.toggle('t-night', theme === 'night');
    themeNames.forEach((t) => t.classList.toggle('on', t.dataset.themeName === theme));
    readerPage.style.transform = `translateY(${-lp * 26}%)`;
    readerProgress.style.transform = `scaleX(${0.12 + lp * 0.3})`;
    readerLeft.textContent = `${Math.round(12 - lp * 4)} min left`;

    // Listen
    const played = range(lp, 0.05, 0.95);
    waveBars.forEach((b, i) => b.classList.toggle('on', i / waveBars.length < played));
    const secs = Math.round(played * 860 * 0.4);
    listenAt.textContent = `${Math.floor(secs / 60)}:${String(secs % 60).padStart(2, '0')}`;
    listenScr.classList.toggle('is-playing', idx === 2 && !reduceMotion);

    // Chat: the question lands, then the answer types out
    chatQ.classList.toggle('is-hidden', lp < 0.06 && idx === 3);
    const chars = Math.floor(range(lp, 0.18, 0.85) * ANSWER.length);
    chatA.classList.toggle('is-hidden', lp < 0.12 && idx === 3);
    const typed = ANSWER.slice(0, chars);
    if (chatA.dataset.len !== String(chars)) {
      chatA.textContent = typed;
      if (chars < ANSWER.length) chatA.insertAdjacentHTML('beforeend', '<span class="caret"></span>');
      chatA.dataset.len = chars;
    }
  }

  /* ---------- Widget ---------- */
  const WIDGET = [
    { title: 'The Power of Habit', idea: 'You can change a habit by keeping the old cue and reward but changing the routine.' },
    { title: 'Emotional Intelligence', idea: 'Self-awareness is key to understanding your emotions and their impact on your decisions.' },
    { title: 'The Laws of Human Nature', idea: 'Social pressure pulls people toward conformity, so a sense of purpose and independent judgment helps preserve your individuality.' },
    { title: 'The Subtle Art of Not Giving a F*ck', idea: 'Choose values based on what you can influence and how you behave, rather than on status, approval or outcomes outside your control.' },
    { title: 'The Psychology of Money', idea: 'People make money decisions through the lens of their experiences, incentives and emotions, so behavior often matters more than technical knowledge.' },
  ].map((w) => ({ ...w, ...(BOOKS.find((b) => b.title === w.title) || {}) })).filter((w) => w.cover);

  const home = $('[data-home]');
  const widget = $('[data-widget]');
  const widgetImg = $('[data-widget-img]');
  const widgetIdea = $('[data-widget-idea]');
  const widgetBy = $('[data-widget-by]');
  const picker = $('[data-widget-picker]');
  let widgetIndex = -1;
  let widgetTimer = null;

  function showWidget(i, { instant = false } = {}) {
    if (i === widgetIndex || !WIDGET[i]) return;
    widgetIndex = i;
    const w = WIDGET[i];
    const apply = () => {
      widgetImg.src = w.cover;
      widgetImg.alt = `${w.title} cover`;
      widgetIdea.textContent = w.idea;
      widgetBy.textContent = `${w.title}, ${w.author}`;
      widget.classList.remove('swap');
    };
    const hue = w.hue ?? null;
    widget.classList.toggle('neutral', hue === null);
    if (hue !== null) home.style.setProperty('--h', hue);
    home.style.setProperty('--s', hue === null ? '6%' : '55%');
    $$('button', picker).forEach((b, j) => b.setAttribute('aria-selected', String(j === i)));
    if (instant) return apply();
    widget.classList.add('swap', 'flip');
    setTimeout(() => widget.classList.remove('flip'), 260);
    setTimeout(apply, 320);
  }
  if (picker && WIDGET.length) {
    WIDGET.forEach((w, i) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.setAttribute('role', 'tab');
      b.innerHTML = `<img alt="" src="${w.cover}"><span></span>`;
      b.lastChild.textContent = w.title.replace(/ of Not Giving a F\*ck/, '');
      b.addEventListener('click', () => { clearInterval(widgetTimer); widgetTimer = null; showWidget(i); });
      picker.append(b);
    });
    showWidget(0, { instant: true });
    if (!reduceMotion) {
      new IntersectionObserver(([e]) => {
        if (e.isIntersecting && widgetTimer === null && widgetIndex !== -2) {
          widgetTimer = setInterval(() => showWidget((widgetIndex + 1) % WIDGET.length), 3800);
        } else if (!e.isIntersecting && widgetTimer) { clearInterval(widgetTimer); widgetTimer = null; }
      }, { threshold: 0.4 }).observe(home);
    }
  }

  /* ---------- Shelves marquee ---------- */
  const rows = $$('[data-row]').map((row, r) => {
    const books = shuffled(BOOKS, 90 + r * 31).slice(0, 18);
    [...books, ...books].forEach((b) => row.append(coverEl(b, { lazy: false })));
    return { el: row, dir: r ? 1 : -1, x: r ? -600 : 0 };
  });

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
  const progressOf = (el) => {
    const r = el.getBoundingClientRect();
    return clamp(-r.top / (r.height - innerHeight));
  };
  const visible = (el) => { const r = el.getBoundingClientRect(); return r.bottom > 0 && r.top < innerHeight; };
  let lastY = scrollY, velocity = 0, lastT = performance.now();
  const shelfRows = $$('[data-shelf]').map((el, i) => ({ el, x: 0, speed: i ? 9 : 14 }));

  function frame(now) {
    const dt = Math.min(64, now - lastT) / 1000;
    lastT = now;
    const y = scrollY;
    velocity += ((y - lastY) / Math.max(dt, 0.001) - velocity) * 0.12;
    lastY = y;

    nav.classList.toggle('is-stuck', y > 40);

    if (hero && visible(hero) && !reduceMotion) {
      shelfRows.forEach((s) => {
        s.x -= s.speed * dt;
        const w = s.el.scrollWidth / 2;
        if (w > 0 && -s.x > w) s.x += w;
        s.el.style.transform = `translate3d(${s.x}px, 0, 0)`;
      });
    }
    if (bite && visible(bite)) updateBite(progressOf(bite));
    if (crumbs.length) drawCrumbs();
    if (story && visible(story)) updateStory(progressOf(story));

    rows.forEach((r) => {
      if (!visible(r.el)) return;
      const boost = reduceMotion ? 0 : clamp(Math.abs(velocity) / 18, 0, 60);
      r.x += r.dir * ((reduceMotion ? 0 : 30) + boost) * dt * (r.dir < 0 ? 1 : 1);
      const w = r.el.scrollWidth / 2;
      if (w > 0) { if (r.x < -w) r.x += w; if (r.x > 0) r.x -= w; }
      const skew = reduceMotion ? 0 : clamp(velocity / 300, -6, 6);
      r.el.style.transform = `translate3d(${r.x}px, 0, 0) skewX(${-skew * r.dir}deg)`;
    });

    requestAnimationFrame(frame);
  }
  if (story) updateStory(0);
  requestAnimationFrame(frame);
})();
