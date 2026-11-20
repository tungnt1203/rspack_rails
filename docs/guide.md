# Usage

[Back to the README](../README.md)

- [View helpers](#view-helpers)
- [Entry points](#entry-points)
- [Importing app code](#importing-app-code)
- [Stimulus](#stimulus)
- [CSS](#css)
- [Tailwind CSS](#tailwind-css)
- [Sass](#sass)
- [React](#react)
- [TypeScript](#typescript)
- [Images and fonts](#images-and-fonts)
- [What `rspack:install` changes](#what-rspackinstall-changes)

## View helpers

```erb
<%= rspack_javascript_tag "application", "data-turbo-track": "reload" %>
<%= rspack_stylesheet_tag "application" %>
```

`rspack_javascript_tag` adds `defer` by default. Both helpers take several entries (`rspack_javascript_tag "application", "admin"`) and any option that `javascript_include_tag` or `stylesheet_link_tag` accepts. Keep `rspack_stylesheet_tag` in `<head>`.

Each build writes `app/assets/builds/.rspack-manifest.json`, listing the scripts and stylesheets of each entry. The helpers link exactly those files, so an entry without CSS gets no stylesheet link. Because the manifest is a dotfile, it never reaches `public/assets`. `rspack serve` writes its own `.rspack-dev-manifest.json`, which the helpers read while it runs, so a build alongside it (`bin/rails test` runs one) does not change what dev pages link.

## Entry points

Besides `app/javascript/application.js` (or `.ts`, `.jsx`, `.tsx`), every file in `app/javascript/entrypoints/` becomes its own bundle, named after the file. Stylesheets work too, with no JavaScript needed:

```
app/javascript/application.js           -> application.js
app/javascript/entrypoints/admin.ts     -> admin.js
app/javascript/entrypoints/checkout.js  -> checkout.js (+ checkout.bundle.css if it imports CSS)
app/javascript/entrypoints/print.scss   -> print.bundle.css (no print.js)
```

```erb
<%# app/views/layouts/admin.html.erb %>
<%= rspack_javascript_tag "admin" %>
<%= rspack_stylesheet_tag "print", media: "print" %>
```

`admin.js` and `admin.css` side by side make one entry.

Several entries can share a page. Under `rspack serve` the helpers link one shared `runtime.js`, so hot updates reach every entry. A build makes each entry self-contained instead, so `<entry>.js` runs on its own. On a page with two entries, a module both of them import (Turbo, your Stimulus `application`, React) is then loaded and run twice, each entry with its own copy. To share one runtime in builds too, add this to `rspack.config.mjs`:

```js
export default railsConfig((config) => {
  config.optimization.runtimeChunk = { name: "runtime" };
});
```

The helpers then link `runtime.js` before the entries, once per page. Only load the entries through the helpers after this, since `<entry>.js` no longer runs without `runtime.js`.

Restart the dev server after adding a new entry point.

## Importing app code

Import files in `app/javascript` from anywhere with `#/`, the [subpath imports](https://nodejs.org/api/packages.html#subpath-imports) prefix that Rspack resolves from `package.json`:

```js
import { formatDate } from "#/lib/dates"        // app/javascript/lib/dates.js (or .ts)
import logo from "#/images/logo.svg"
```

`rspack:install` adds `"imports": { "#/*": "./app/javascript/*" }` to `package.json`. `rspack:install:typescript` adds the same mapping to the `paths` of `tsconfig.json`, so type checking and your editor follow it too. Bare imports such as `import "lib/dates"` keep working as they did with importmap.

## Stimulus

```bash
bin/rails rspack:install:stimulus
```

This installs `@hotwired/stimulus` and adds `app/javascript/controllers/autoload.js`, imported from your entry. Every `*_controller.js` (or `.ts`) under `app/javascript/controllers` is registered automatically, with the usual naming: `admin/user_card_controller.js` becomes `admin--user-card`.

Under `rspack serve`, editing or adding a controller hot-swaps it in the open page, so form input and other page state survive.

**`autoload.js` belongs to rspack_rails,** like `config/rspack/rails.mjs`. `rspack:sync` and `rspack:build` rewrite it when the gem changes, and save any hand edits to `tmp/rspack_rails/` first. A copy without a checksum line, as 0.17.0 and earlier wrote it, counts as edited and is saved too. To register controllers your own way, copy it to a file of your own, import that instead and delete `autoload.js`.

If your entry imported `./controllers` (the stimulus-rails index), the installer switches it to `./controllers/autoload`. stimulus-rails may still rewrite `controllers/index.js` when you run `bin/rails generate stimulus`, but nothing imports that file any more.

## CSS

Import CSS from JavaScript, and Rspack extracts it to `app/assets/builds/<entry>.bundle.css`:

```js
// app/javascript/application.js
import "./styles/application.css"
```

```erb
<%= rspack_stylesheet_tag "application" %>
```

- `*.module.css` files are compiled as CSS modules.
- Under `rspack serve`, CSS changes apply without a page reload.
- The `.bundle` suffix keeps the output from clashing with `app/assets/stylesheets/application.css`.

## Tailwind CSS

```bash
bin/rails rspack:install:tailwind
```

This installs `tailwindcss` and `@tailwindcss/webpack`, creates `app/javascript/application.css` with `@import "tailwindcss";`, imports it from your entry and adds `rspack_stylesheet_tag "application"` to the layout.

Classes in your views, helpers and JavaScript are picked up automatically. Under `rspack serve`, editing a view reloads the page with the new classes already built, and CSS edits apply without a reload.

Coming from `tailwindcss-rails`? See [Migrating](migrating.md#from-tailwindcss-rails).

## Sass

```bash
bin/rails rspack:install:sass
```

This installs `sass-loader` and `sass-embedded` and creates `app/javascript/application.scss`, imported from your entry.

- Import any `.scss` or `.sass` file from JavaScript. `*.module.scss` files are CSS modules.
- `app/assets/stylesheets` is a load path, so `@use "variables"` finds `app/assets/stylesheets/_variables.scss`.
- Inside partials, `url()` is resolved from the file that was imported from JavaScript, not from the partial.

Coming from `dartsass-rails`? See [Migrating](migrating.md#from-dartsass-rails). On Sprockets, see [Sass files on Sprockets](troubleshooting.md#sass-files-on-sprockets-fail-with-a-missing-sassc-gem).

## React

```bash
bin/rails rspack:install:react
```

This installs `react`, `react-dom` and React Fast Refresh, and adds `app/javascript/components/` with a sample `Hello` component. Render any component from a view:

```erb
<%= react_component "Hello", name: "World" %>
<%= react_component "admin/Chart", { points: @points }, html: { class: "chart" } %>
```

- Components are found by path, with no registration step: `admin/Chart` is `app/javascript/components/admin/Chart.jsx` (or `.tsx`).
- They mount when their element enters the page and unmount when it leaves, so Turbo Drive, frames and streams work.
- Props are passed as JSON.
- Under `rspack serve`, edits apply through Fast Refresh and components keep their state.
- The loader, `app/javascript/components/mount.js`, is kept up to date by rspack_rails the same way as the [Stimulus autoloader](#stimulus).
- With TypeScript set up, the installer also sets `"jsx": "react-jsx"` in `tsconfig.json` and adds `@types/react`.

**React Compiler.** To memoize components automatically with the [React Compiler](https://react.dev/learn/react-compiler), set `RSPACK_REACT_COMPILER=true` (Rspack 2.1 or later). It runs in Rspack's built-in SWC, with no Babel. Set it for every build, including `assets:precompile` on deploy, so development and production behave the same.

## TypeScript

`.ts` and `.tsx` files compile out of the box with Rspack's built-in SWC loader, Stimulus controllers (`*_controller.ts`) included. SWC strips types without checking them. For type checking:

```bash
bin/rails rspack:install:typescript   # tsconfig.json, typescript, a "typecheck" script
npm run typecheck
```

- The installer adds `app/javascript/types/assets.d.ts`, so imports of stylesheets, images and fonts type-check (`import heroUrl from "./hero.png"` is a `string`).
- Type errors show in the dev server overlay while you work (`ts-checker-rspack-plugin`). Builds stay fast and leave checking to `typecheck`.
- `paths` aliases in `tsconfig.json` are honored, so `"@/*": ["./app/javascript/*"]` makes `import "@/lib/api"` work in both TypeScript and Rspack.

## Images and fonts

Import an image from JavaScript, or reference images and fonts from CSS with `url()`:

```css
body { background: url("./images/hero.png"); }
@font-face { font-family: Brand; src: url("./fonts/brand.woff2"); }
```

- Files under 8 KB are inlined as data URIs.
- Larger ones are written to `app/assets/builds` as `<name>-<hash>.digested.<ext>`, and Propshaft serves them without fingerprinting them a second time.
- A root-relative `url()` is left for Rails: Rspack neither bundles nor fingerprints it. Propshaft looks it up in `app/assets`, so `url("/logo.svg")` becomes the fingerprinted `app/assets/images/logo.svg`. A file that only exists in `public/`, such as `url("/icon.png")`, stays as written. Propshaft logs "Unable to resolve" for it, which is harmless.

## What `rspack:install` changes

- Creates `rspack.config.mjs` (your config, built on `config/rspack/rails.mjs`; see [Configuration](configuration.md)) and `app/javascript/application.js`. An existing `application.ts`, `.jsx` or `.tsx` is kept as the entry.
- Adds `build`, `build:watch` and `dev` (`rspack serve`) scripts to `package.json`.
- Adds `rspack_javascript_tag "application"` to your layouts (ERB, Slim or Haml), and replaces Rails 8's `stylesheet_link_tag :app`, which would also link Rspack's bundles.
- Adds a `js:` process running the dev server to `Procfile.dev`, and sets up `bin/dev`.
- Makes the `Dockerfile` install Node.js and your node modules so Kamal deploys can precompile ([Deploying](production.md#deploying-docker-and-kamal)), and makes `bin/setup` install node modules.
- In a dev container, adds Node.js and forwards the dev server port ([Dev containers](production.md#dev-containers)).
- Installs `@rspack/cli`, `@rspack/core` and `@rspack/dev-server`.

Running it again is safe: it leaves your config, entry, layouts and `Procfile.dev` alone when they are already set up.
