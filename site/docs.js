// The sections of this page, in the sidebar: the one being read is marked.
const links = new Map([...document.querySelectorAll('.rail__sub a')].map((a) => [a.hash.slice(1), a]));
if (links.size) {
  const io = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      if (!e.isIntersecting) return;
      links.forEach((a) => a.removeAttribute('aria-current'));
      links.get(e.target.id)?.setAttribute('aria-current', 'true');
    });
  }, { rootMargin: '0px 0px -70% 0px' });
  links.forEach((_, id) => { const h = document.getElementById(id); if (h) io.observe(h); });
}

// On a phone the page list starts closed.
const menu = document.querySelector('.rail__menu');
const narrow = matchMedia('(max-width: 60rem)');
if (menu) {
  menu.open = !narrow.matches;
  narrow.addEventListener('change', (e) => { menu.open = !e.matches; });
}

// Code blocks: a copy button, shown only where the clipboard works.
if (navigator.clipboard) {
  document.querySelectorAll('.code__copy').forEach((button) => {
    button.hidden = false;
    button.addEventListener('click', async () => {
      const text = button.parentElement.querySelector('code').textContent;
      try {
        await navigator.clipboard.writeText(text);
        button.textContent = 'Copied';
      } catch {
        button.textContent = 'Not copied';
      }
      setTimeout(() => { button.textContent = 'Copy'; }, 1600);
    });
  });
}

// Search: one request for the index, the first time it is wanted.
const dialog = document.querySelector('dialog.search');
const openers = document.querySelectorAll('[data-search]');
if (dialog && typeof dialog.showModal === 'function') {
  const input = dialog.querySelector('input');
  const list = dialog.querySelector('.search__results');
  const hint = dialog.querySelector('.search__hint');
  let index = null;
  let active = -1;

  const load = () => {
    index ||= fetch('search.json').then((r) => r.json()).catch(() => []);
    return index;
  };

  // Every word must appear. A word in the heading counts for more than one in the text.
  const score = (entry, words) => {
    const heading = entry.heading.toLowerCase();
    const body = entry.text.toLowerCase();
    let total = 0;
    for (const w of words) {
      const inHeading = heading.includes(w);
      if (!inHeading && !body.includes(w)) return 0;
      total += inHeading ? (heading.startsWith(w) ? 6 : 4) : 1;
    }
    return total;
  };

  const snippet = (entry, words) => {
    const at = words.map((w) => entry.text.toLowerCase().indexOf(w)).filter((n) => n >= 0).sort((a, b) => a - b)[0] ?? 0;
    const start = Math.max(0, at - 30);
    return (start ? '…' : '') + entry.text.slice(start, start + 120) + (entry.text.length > start + 120 ? '…' : '');
  };

  const select = (n) => {
    const items = [...list.children];
    active = items.length ? (n + items.length) % items.length : -1;
    items.forEach((li, i) => li.setAttribute('aria-selected', String(i === active)));
    input.setAttribute('aria-activedescendant', active >= 0 ? items[active].id : '');
    items[active]?.scrollIntoView({ block: 'nearest' });
  };

  const render = async () => {
    const query = input.value;
    const words = query.toLowerCase().split(/\s+/).filter(Boolean);
    list.replaceChildren();
    active = -1;
    if (!words.length) { hint.textContent = 'Type a word, a helper name or a task.'; input.setAttribute('aria-expanded', 'false'); return; }
    const all = await load();
    if (query !== input.value) return; // a newer keystroke is already rendering
    const hits = all
      .map((entry) => ({ entry, s: score(entry, words) }))
      .filter((h) => h.s > 0)
      .sort((a, b) => b.s - a.s)
      .slice(0, 8);
    hits.forEach(({ entry }, i) => {
      const li = document.createElement('li');
      li.id = `search-hit-${i}`;
      li.setAttribute('role', 'option');
      const a = document.createElement('a');
      a.href = `${entry.page}.html${entry.id ? `#${entry.id}` : ''}`;
      const title = document.createElement('b');
      title.textContent = entry.heading;
      const page = document.createElement('span');
      page.textContent = entry.id ? entry.pageTitle : 'Page';
      const text = document.createElement('small');
      text.textContent = snippet(entry, words);
      a.append(title, page, text);
      li.append(a);
      list.append(li);
    });
    input.setAttribute('aria-expanded', String(hits.length > 0));
    hint.textContent = hits.length ? `${hits.length} ${hits.length === 1 ? 'result' : 'results'}` : 'Nothing matches. Try one word, or the name of a helper.';
    select(0);
  };

  const open = () => { dialog.showModal(); input.focus(); input.select(); load(); };
  openers.forEach((b) => { b.hidden = false; b.addEventListener('click', open); });
  input.addEventListener('input', render);
  input.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowDown') { e.preventDefault(); select(active + 1); }
    if (e.key === 'ArrowUp') { e.preventDefault(); select(active - 1); }
    if (e.key === 'Enter' && active >= 0) { e.preventDefault(); list.children[active].querySelector('a').click(); }
  });
  list.addEventListener('click', (e) => { if (e.target.closest('a')) dialog.close(); });
  dialog.addEventListener('click', (e) => { if (e.target === dialog) dialog.close(); });
  document.addEventListener('keydown', (e) => {
    const typing = /^(INPUT|TEXTAREA|SELECT)$/.test(document.activeElement?.tagName) || document.activeElement?.isContentEditable;
    if ((e.key === '/' && !typing && !e.metaKey && !e.ctrlKey) || ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k')) {
      e.preventDefault();
      if (!dialog.open) open();
    }
  });
}
