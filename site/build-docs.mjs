// Builds site/docs/*.html from the repo's docs/*.md, in the landing page's design.
//
//   cd site && npm install && node build-docs.mjs
//
// The Pages workflow runs it before uploading site/. The generated pages are not
// committed (site/docs/ is in .gitignore): docs/*.md stays the one source.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { Marked } from "marked";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const out = path.join(here, "docs");
const REPO = "https://github.com/tungnt1203/rspack_rails";

// Reading order. Any other docs/*.md is appended after these.
const ORDER = ["guide", "recipes", "configuration", "production", "migrating", "upgrading", "troubleshooting"];
const files = fs.readdirSync(path.join(root, "docs")).filter((f) => f.endsWith(".md")).map((f) => f.slice(0, -3));
const slugs = [...ORDER.filter((s) => files.includes(s)), ...files.filter((s) => !ORDER.includes(s)).sort()];

// How the sidebar and the index group the pages. A page not listed lands in "More".
const GROUPS = [
  ["Build with it", ["guide", "recipes"]],
  ["Configure and ship", ["configuration", "production"]],
  ["Move and fix", ["migrating", "upgrading", "troubleshooting"]],
];
const groupOf = (slug) => GROUPS.find(([, pages]) => pages.includes(slug))?.[0] ?? "More";
const groups = [...new Set([...GROUPS.map(([name]) => name), ...slugs.map(groupOf)])]
  .map((name) => [name, slugs.filter((s) => groupOf(s) === name)])
  .filter(([, pages]) => pages.length);

const escape = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const plain = (md) => md.replace(/`([^`]+)`/g, "$1").replace(/\[([^\]]+)\]\([^)]+\)/g, "$1").replace(/[*_]/g, "").trim();

// GitHub's heading anchors, so links like migrating.md#from-tailwindcss-rails keep working.
const slugger = () => {
  const seen = new Map();
  return (text) => {
    const base = text.toLowerCase().replace(/<[^>]+>/g, "").replace(/[^\p{L}\p{N}\s_-]/gu, "").trim().replace(/\s/g, "-");
    const n = seen.get(base) || 0;
    seen.set(base, n + 1);
    return n ? `${base}-${n}` : base;
  };
};

const rewrite = (href) => {
  if (/^(https?:|mailto:|#)/.test(href)) return href;
  const [file, hash] = href.split("#");
  const name = path.basename(file, ".md");
  if (file.endsWith(".md") && !file.includes("/") && slugs.includes(name)) return `${name}.html${hash ? `#${hash}` : ""}`;
  if (file === "../README.md") return `${REPO}#readme`;
  const target = path.posix.normalize(path.posix.join("docs", file));
  return `${REPO}/blob/main/${target}${hash ? `#${hash}` : ""}`;
};

// One search entry per h2 or h3: its heading and the text under it, cut at the next heading.
function sectionsOf(slug, pageTitle, html) {
  const text = (h) => h.replace(/<a class="anchor"[^>]*>.*?<\/a>/g, "").replace(/<button class="code__copy".*?<\/button>/g, "").replace(/<[^>]+>/g, " ")
    .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, "&")
    .replace(/\s+/g, " ").trim();
  const parts = html.split(/(<h[23] id="[^"]+">.*?<\/h[23]>)/s);
  const out = [{ page: slug, pageTitle, heading: pageTitle, id: "", text: text(parts[0]).slice(0, 400) }];
  for (let i = 1; i < parts.length; i += 2) {
    const id = parts[i].match(/id="([^"]+)"/)[1];
    out.push({ page: slug, pageTitle, heading: text(parts[i]), id, text: text(parts[i + 1] ?? "").slice(0, 400) });
  }
  return out;
}

function parse(slug) {
  let md = fs.readFileSync(path.join(root, "docs", `${slug}.md`), "utf8");
  const title = md.match(/^# (.+)$/m)?.[1].trim() ?? slug;
  md = md.replace(/^# .+\n/m, "");
  // The README link and the hand-written contents list: the site has a nav and a contents rail.
  md = md.replace(/^\[Back to the README\]\(\.\.\/README\.md\)\s*\n/m, "");
  md = md.replace(/^\s*((?:- \[[^\]]+\]\(#[^)]+\)\n)+)/, "");
  // The intro: the first paragraph before the first section, when the page has one.
  // It becomes the lead under the title, so it leaves the body.
  const intro = md.split(/^## /m)[0];
  const first = intro.trim().split(/\n\s*\n/)[0]?.trim() ?? "";
  const isParagraph = first && !/^(```|#|\||- |> )/.test(first);
  const description = isParagraph ? plain(first) : "";
  const leadHtml = isParagraph ? new Marked().parseInline(first) : "";
  if (isParagraph) md = md.replace(first, "");

  const slugify = slugger();
  const toc = [];
  const marked = new Marked({
    gfm: true,
    renderer: {
      heading(text, level, raw) {
        const id = slugify(raw);
        if (level === 2) toc.push({ id, text });
        return `<h${level} id="${id}">${text} <a class="anchor" href="#${id}" aria-label="Link to this section">#</a></h${level}>\n`;
      },
      link(href, title, text) {
        const url = rewrite(href);
        return `<a href="${escape(url)}"${title ? ` title="${escape(title)}"` : ""}>${text}</a>`;
      },
      code(code, info) {
        const lang = (info || "").split(/\s/)[0];
        const label = { erb: "ERB", js: "JavaScript", ts: "TypeScript", bash: "Shell", sh: "Shell", ruby: "Ruby", rb: "Ruby", css: "CSS", scss: "Sass", json: "JSON", yaml: "YAML", yml: "YAML", dockerfile: "Dockerfile", html: "HTML", text: "" }[lang] ?? lang;
        return `<figure class="code">${label ? `<figcaption><span>${escape(label)}</span></figcaption>` : ""}<button class="code__copy" type="button" hidden>Copy</button><pre tabindex="0"><code>${escape(code)}</code></pre></figure>\n`;
      },
      // Typographic quotes in prose; code spans and blocks have their own renderers.
      text(text) {
        return text
          .replace(/(^|[\s(\[])&quot;/g, "$1\u201c").replace(/&quot;/g, "\u201d")
          .replace(/(^|[\s(\[])&#39;/g, "$1\u2018").replace(/&#39;/g, "\u2019");
      },
      table(header, body) {
        return `<div class="table-scroll" tabindex="0"><table><thead>${header}</thead><tbody>${body}</tbody></table></div>\n`;
      },
    },
  });
  const html = marked.parse(md);
  return { slug, title, description, leadHtml, toc, html, sections: sectionsOf(slug, title, html) };
}

const docs = slugs.map(parse);

const nav = (current) => `
  <header class="bar">
    <div class="container bar__inner">
      <a class="wordmark" href="../" aria-label="rspack_rails, home"><img src="../media/rspack-mascot.svg" alt="" width="40" height="31">rspack_rails</a>
      <nav aria-label="Site">
        <ul class="bar__links">
          <li><button class="search-btn" type="button" data-search hidden>Search<kbd>/</kbd></button></li>
          <li><a href="./"${current ? ' aria-current="page"' : ""}>Docs</a></li>
          <li><a href="${REPO}/blob/main/CHANGELOG.md">Changelog</a></li>
          <li><a href="${REPO}">GitHub</a></li>
        </ul>
      </nav>
    </div>
  </header>`;

const footer = `
  <footer class="footer">
    <div class="container footer__inner">
      <img src="../media/rspack-mascot.svg" alt="" width="72" height="56" loading="lazy">
      <p>These pages are built from <a class="link" href="${REPO}/tree/main/docs">docs/</a> in the repository. Spot a mistake? <a class="link" href="${REPO}/issues/new">Open an issue</a>.</p>
      <ul>
        <li><a href="../">Home</a></li>
        <li><a href="${REPO}">GitHub</a></li>
        <li><a href="https://rubygems.org/gems/rspack_rails">RubyGems</a></li>
        <li><a href="https://github.com/tungnt1203/rspack_rails-demo">Demo app</a></li>
        <li><a href="${REPO}/blob/main/CHANGELOG.md">Changelog</a></li>
        <li><a href="${REPO}/blob/main/LICENSE.txt">MIT licence</a></li>
      </ul>
    </div>
  </footer>`;

const page = ({ title, description, body }) => `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escape(title)}</title>
  <meta name="description" content="${escape(description)}">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,600..800&family=Martian+Mono:wdth,wght@75..112.5,400..600&family=Open+Sans:wght@400;600;700&display=swap" rel="stylesheet">
  <link rel="icon" type="image/svg+xml" href="../media/rspack-mascot.svg">
  <link rel="stylesheet" href="../docs.css">
  <script>document.documentElement.classList.add('js');</script>
</head>
<body>
  <a class="skip" href="#main">Skip to the page</a>
${nav(true)}
${body}
${footer}
  <dialog class="search" aria-label="Search the docs">
    <form class="search__box" method="dialog">
      <label class="visually-hidden" for="search-q">Search the docs</label>
      <input id="search-q" type="search" autocomplete="off" placeholder="Search the docs" role="combobox" aria-expanded="false" aria-controls="search-results">
      <button class="search__close" aria-label="Close search">Esc</button>
    </form>
    <ul class="search__results" id="search-results" role="listbox" aria-label="Results"></ul>
    <p class="search__hint" role="status" aria-live="polite">Type a word, a helper name or a task.</p>
  </dialog>
  <script src="../docs.js" defer></script>
</body>
</html>
`;

const rail = (current) => `
        <nav class="rail" aria-label="Documentation">
          <details class="rail__menu" open>
            <summary>All pages</summary>
${groups.map(([name, pages]) => `            <div class="rail__group">
              <p class="rail__label">${escape(name)}</p>
              <ol>
${pages.map((slug) => docs.find((d) => d.slug === slug)).map((d) => `                <li><a href="${d.slug}.html"${d.slug === current ? ' aria-current="page"' : ""}>${escape(d.title)}</a>${d.slug === current && d.toc.length ? `
                  <ol class="rail__sub" aria-label="On this page">
${d.toc.map((t) => `                    <li><a href="#${t.id}">${t.text}</a></li>`).join("\n")}
                  </ol>
                ` : ""}</li>`).join("\n")}
              </ol>
            </div>`).join("\n")}
          </details>
        </nav>`;

fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(out, { recursive: true });

docs.forEach((doc, i) => {
  const prev = docs[i - 1], next = docs[i + 1];
  const body = `
  <main id="main" class="doc">
    <header class="doc__hero">
      <div class="container doc__grid">
        <span aria-hidden="true"></span>
        <div class="doc__head">
          <h1 id="doc-title">${escape(doc.title)}</h1>
          ${doc.leadHtml ? `<p class="lead">${doc.leadHtml}</p>` : ""}
          <a class="doc__source" href="${REPO}/blob/main/docs/${doc.slug}.md">Edit docs/${doc.slug}.md</a>
        </div>
      </div>
    </header>
    <div class="container doc__grid">
${rail(doc.slug)}
      <article class="prose" aria-labelledby="doc-title">
${doc.html}
        <nav class="pager" aria-label="Next and previous">
          ${prev ? `<a class="pager__link" href="${prev.slug}.html" rel="prev"><span>Previous</span>${escape(prev.title)}</a>` : "<span></span>"}
          ${next ? `<a class="pager__link pager__link--next" href="${next.slug}.html" rel="next"><span>Next</span>${escape(next.title)}</a>` : ""}
        </nav>
      </article>
    </div>
  </main>`;
  fs.writeFileSync(path.join(out, `${doc.slug}.html`), page({ title: `${doc.title} · rspack_rails docs`, description: doc.description, body }));
});

const index = `
  <main id="main" class="doc">
    <header class="doc__hero">
      <div class="container docs-index__head">
        <h1 id="docs-title">Documentation</h1>
        <p class="lead">Everything after <code>rails new</code>: the helpers, the config, production and upgrades.</p>
        <button class="search-big" type="button" data-search hidden>Search the docs<kbd>/</kbd></button>
      </div>
    </header>
    <section class="docs-index" aria-labelledby="docs-title">
      <div class="container docs-index__groups">
${groups.map(([name, pages]) => `        <div class="index__group">
          <h2>${escape(name)}</h2>
          <ol class="index">
${pages.map((slug) => docs.find((d) => d.slug === slug)).map((d) => `            <li class="index__item">
              <a class="index__title" href="${d.slug}.html">${escape(d.title)}</a>
              <p class="index__desc">${escape(d.description.replace(/:$/, ".") || "")}</p>
              <ul class="index__sections">
${d.toc.map((t) => `                <li><a href="${d.slug}.html#${t.id}">${t.text}</a></li>`).join("\n")}
              </ul>
            </li>`).join("\n")}
          </ol>
        </div>`).join("\n")}
      </div>
    </section>
  </main>`;
fs.writeFileSync(path.join(out, "index.html"), page({ title: "Documentation · rspack_rails", description: "The rspack_rails documentation: view helpers, entry points, configuration, production, migrating and upgrading.", body: index }));

fs.writeFileSync(path.join(out, "search.json"), JSON.stringify(docs.flatMap((d) => d.sections)));

console.log(`built ${docs.length + 1} pages into ${path.relative(root, out)}/: index, ${docs.map((d) => d.slug).join(", ")}`);
