// The contents rail marks the section being read; on a phone the page list starts closed.
const links = new Map([...document.querySelectorAll('.toc a')].map((a) => [a.hash.slice(1), a]));
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
const menu = document.querySelector('.rail__menu');
const narrow = matchMedia('(max-width: 60rem)');
if (menu) {
  menu.open = !narrow.matches;
  narrow.addEventListener('change', (e) => { menu.open = !e.matches; });
}
