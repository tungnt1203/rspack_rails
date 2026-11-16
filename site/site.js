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

// The recording loops: it runs only on screen, pauses on hover and focus,
// never under reduced motion, and the button holds it.
document.querySelectorAll('[data-loop]').forEach((el) => {
  const button = el.querySelector('[data-loop-toggle]');
  const state = { seen: false, hover: false, focus: false, held: matchMedia('(prefers-reduced-motion: reduce)').matches };
  const sync = () => {
    const run = state.seen && !state.hover && !state.focus && !state.held;
    el.classList.toggle('is-running', run);
    el.querySelectorAll('video').forEach((v) => (run ? v.play().catch(() => {}) : v.pause()));
    button.textContent = state.held ? 'Play' : 'Pause';
  };
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
