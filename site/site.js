const reduced = matchMedia('(prefers-reduced-motion: reduce)');

// Copy a command to the clipboard; the status line says what happened.
document.querySelectorAll('[data-copy]').forEach((button) => {
  const source = document.getElementById(button.dataset.copy);
  const status = button.closest('[data-command]')?.querySelector('[role="status"]');
  button.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(source.dataset.text || source.textContent.trim());
      if (status) status.textContent = 'Copied. Paste it in a terminal.';
    } catch {
      const range = document.createRange();
      range.selectNodeContents(source);
      getSelection().removeAllRanges();
      getSelection().addRange(range);
      if (status) status.textContent = 'Selected. Press Ctrl+C or Cmd+C to copy.';
    }
  });
});

// The recording loops: it runs only on screen and while its step is shown,
// pauses on hover and focus, never under reduced motion, and the button holds it.
document.querySelectorAll('[data-loop]').forEach((el) => {
  const button = el.querySelector('[data-loop-toggle]');
  const state = { seen: false, hover: false, focus: false, shown: true, held: reduced.matches };
  const sync = () => {
    const run = state.seen && state.shown && !state.hover && !state.focus && !state.held;
    el.classList.toggle('is-running', run);
    el.querySelectorAll('video').forEach((v) => (run ? v.play().catch(() => {}) : v.pause()));
    button.textContent = state.held ? 'Play' : 'Pause';
  };
  el.hallmarkLoop = (shown) => { state.shown = shown; button.hidden = !shown; sync(); };
  button.addEventListener('click', () => { state.held = !state.held; sync(); });
  [['pointerenter', 'hover', true], ['pointerleave', 'hover', false], ['focusin', 'focus', true], ['focusout', 'focus', false]]
    .forEach(([type, key, value]) => el.addEventListener(type, () => { state[key] = value; sync(); }));
  new IntersectionObserver(([entry]) => { state.seen = entry.isIntersecting; sync(); }).observe(el);
});

// Tabs: arrow keys move between them; without script every panel shows.
document.querySelectorAll('[data-switch]').forEach((root) => {
  const tabs = [...root.querySelectorAll('[role="tab"]')];
  const select = (tab) => {
    tabs.forEach((t) => {
      const on = t === tab;
      t.setAttribute('aria-selected', String(on));
      t.tabIndex = on ? 0 : -1;
      document.getElementById(t.getAttribute('aria-controls')).hidden = !on;
    });
  };
  tabs.forEach((tab, i) => {
    tab.addEventListener('click', () => select(tab));
    tab.addEventListener('keydown', (e) => {
      const next = { ArrowRight: 1, ArrowLeft: -1 }[e.key];
      if (!next) return;
      const target = tabs[(i + next + tabs.length) % tabs.length];
      select(target);
      target.focus();
    });
  });
  select(tabs.find((t) => t.getAttribute('aria-selected') === 'true') || tabs[0]);
});

// Pinned: the step nearest the middle of the screen picks what the stage shows.
document.querySelectorAll('.pinned').forEach((root) => {
  const steps = [...root.querySelectorAll('[data-step]')];
  const media = [...root.querySelectorAll('[data-step-media]')];
  const loop = root.querySelector('[data-loop]');
  const show = (index) => {
    steps.forEach((s) => s.classList.toggle('is-active', s.dataset.step === index));
    media.forEach((m) => m.classList.toggle('is-active', m.dataset.stepMedia === index));
    loop?.hallmarkLoop?.(index === '0');
  };
  const io = new IntersectionObserver((entries) => {
    entries.forEach((e) => { if (e.isIntersecting) show(e.target.dataset.step); });
  }, { rootMargin: '-45% 0px -45% 0px' });
  steps.forEach((s) => io.observe(s));
  show('0');
});

// Mapping: each template question joined to the installer task it runs.
document.querySelectorAll('[data-mapping]').forEach((root) => {
  const svg = root.querySelector('[data-wires]');
  const NS = 'http://www.w3.org/2000/svg';
  const draw = () => {
    svg.replaceChildren();
    if (getComputedStyle(svg).display === 'none') return;
    const box = root.getBoundingClientRect();
    const pairs = [...root.querySelectorAll('[data-pair]')];
    pairs.forEach((from, i) => {
      const to = root.querySelector(`[data-pair-to="${from.dataset.pair}"]`);
      if (!to) return;
      const a = from.getBoundingClientRect();
      const b = to.getBoundingClientRect();
      const left = from.closest('figure').getBoundingClientRect().right - box.left;
      const right = to.closest('figure').getBoundingClientRect().left - box.left;
      const y1 = a.top + a.height / 2 - box.top, y2 = b.top + b.height / 2 - box.top;
      const lane = left + ((i + 1) * (right - left)) / (pairs.length + 1);
      const path = document.createElementNS(NS, 'path');
      path.setAttribute('d', `M${left} ${y1} H${lane} V${y2} H${right}`);
      svg.append(path);
      [[left, y1], [right, y2]].forEach(([cx, cy]) => {
        const dot = document.createElementNS(NS, 'circle');
        dot.setAttribute('cx', cx); dot.setAttribute('cy', cy); dot.setAttribute('r', 2.5);
        svg.append(dot);
      });
    });
  };
  new ResizeObserver(draw).observe(root);
  document.fonts?.ready.then(draw);
});

// The field: an ASCII ground on an 8 by 16 cell. Source files enter dense on
// the right and leave as hashed bundles; the left, under the words, stays quiet.
document.querySelectorAll('[data-field]').forEach((canvas) => {
  const ctx = canvas.getContext('2d');
  const css = getComputedStyle(document.documentElement);
  const tone = (name) => css.getPropertyValue(name).trim();
  const tints = ['--color-glyph-1', '--color-glyph-2', '--color-glyph-3', '--color-glyph-4', '--color-accent-deep'].map(tone);
  const ramp = ' .:-=+*#%@';
  const paper = tone('--color-paper');
  const words = ['app/javascript/application.ts', 'controllers/clock_controller.ts', 'components/Playground.tsx', 'application.css', 'ThemeSwatches.module.scss',
    'application.js', 'chartjs-f8307f4a.digested.js', 'application.bundle.css', 'runtime.js', 'hero-15691d33.digested.jpg'];
  const CW = 8, CH = 16;
  let cols = 0, rows = 0, dpr = 1, running = false, last = 0, t = 0, lanes = [];
  const pointer = { x: -1e4, y: -1e4 };

  const hash = (x, y) => { const s = Math.sin(x * 127.1 + y * 311.7) * 43758.5453; return s - Math.floor(s); };
  const noise = (x, y) => {
    const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
    const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
    const a = hash(xi, yi), b = hash(xi + 1, yi), c = hash(xi, yi + 1), d = hash(xi + 1, yi + 1);
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
  };

  const resize = () => {
    dpr = Math.min(devicePixelRatio || 1, 2);
    const { width, height } = canvas.getBoundingClientRect();
    canvas.width = Math.round(width * dpr); canvas.height = Math.round(height * dpr);
    cols = Math.ceil(width / CW); rows = Math.ceil(height / CH);
    lanes = Array.from({ length: Math.max(3, Math.floor(rows / 5)) }, (_, i) => ({
      row: Math.floor((i + 0.5) * rows / Math.max(3, Math.floor(rows / 5))),
      word: words[i % words.length], speed: 6 + (i % 3) * 3, offset: i * 37,
    }));
    frame(t);
  };

  const frame = (time) => {
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.font = `12px ${tone('--font-outlier')}`;
    ctx.textBaseline = 'top';
    const narrow = innerWidth < 960;
    const quietEnd = cols * (narrow ? 0 : 0.5);
    // On a phone the words fill the width: the field keeps to the band under them.
    const firstRow = narrow ? rows - 3 : 0;
    for (let y = firstRow; y < rows; y++) {
      for (let x = 0; x < cols; x++) {
        const ramp01 = Math.max(0, (x - quietEnd) / (cols - quietEnd));
        let n = (noise(x / 11 - time * 0.35, y / 5 + time * 0.05) * 0.7 + noise(x / 4.3 - time * 0.6, y / 2.1) * 0.3) * ramp01 * 1.4;
        const dx = x * CW - pointer.x, dy = y * CH - pointer.y;
        if (dx * dx + dy * dy < 9000) n += 0.25;
        if (n < 0.18) continue;
        const level = Math.min(ramp.length - 1, Math.floor(n * ramp.length));
        ctx.fillStyle = tints[Math.min(tints.length - 1, Math.floor(n * 3.6))];
        ctx.fillText(ramp[level], x * CW, y * CH);
      }
    }
    lanes.forEach((lane, i) => {
      const span = cols - quietEnd + lane.word.length;
      const head = (lane.offset + time * lane.speed) % span;
      const x = Math.floor(cols - head);
      if (x < quietEnd || lane.row < firstRow) return;
      const resolved = x < quietEnd + (cols - quietEnd) * 0.45;
      const word = resolved ? words[5 + (i % 5)] : words[i % 5];
      ctx.fillStyle = paper;
      ctx.fillRect(x * CW - CW, lane.row * CH, (word.length + 2) * CW, CH);
      ctx.fillStyle = tints[resolved ? 4 : 3];
      ctx.fillText(word, x * CW, lane.row * CH);
    });
  };

  const loop = (now) => {
    if (!running) return;
    if (now - last > 33) { t = now / 1000; frame(t); last = now; }
    requestAnimationFrame(loop);
  };
  const start = () => { if (!running && !reduced.matches) { running = true; requestAnimationFrame(loop); } };
  const stop = () => { running = false; };

  canvas.parentElement.addEventListener('pointermove', (e) => { const r = canvas.getBoundingClientRect(); pointer.x = e.clientX - r.left; pointer.y = e.clientY - r.top; });
  canvas.parentElement.addEventListener('pointerleave', () => { pointer.x = pointer.y = -1e4; });
  new ResizeObserver(resize).observe(canvas);
  new IntersectionObserver(([e]) => (e.isIntersecting ? start() : stop())).observe(canvas);
  reduced.addEventListener('change', () => (reduced.matches ? stop() : start()));
  document.fonts?.ready.then(() => frame(t));
});
