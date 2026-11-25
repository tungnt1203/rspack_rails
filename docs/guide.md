# Usage

[Back to the README](../README.md)

- [View helpers](#view-helpers)
- [Entry points](#entry-points)
- [Importing app code](#importing-app-code)
- [CSS](#css)
- [Images and fonts](#images-and-fonts)
- [Web Workers](#web-workers)
- [Adding tools](#adding-tools)
- [What `rspack:install` changes](#what-rspackinstall-changes)

## View helpers

```erb
<%= rspack_javascript_tag "application", "data-turbo-track": "reload" %>
<%= rspack_stylesheet_tag "application" %>
```

`rspack_javascript_tag` adds `defer` by default. Both helpers take several entries (`rspack_javascript_tag "application", "admin"`) and the options of the tag: `defer` (on by default for scripts), `nonce: true` for the Content Security Policy nonce, `integrity: true`, `media`, `data`, and so on. Keep `rspack_stylesheet_tag` in `<head>`.

Each build writes `public/rspack/.rspack-manifest.json`, listing the fingerprinted scripts and stylesheets of each entry. The helpers link exactly those files, so an entry without CSS gets no stylesheet link, and one that is not built yet raises an error that says what to run. Rails serves the files under `/rspack/`, with `config.asset_host` in front when you set one. `rspack serve` writes its own `.rspack-dev-manifest.json`, which the helpers read while it runs, so a build alongside it (`bin/rails test` runs one) does not change what dev pages link.

## Entry points

Besides `app/javascript/application.js` (or `.ts`, `.jsx`, `.tsx`), every file in `app/javascript/entrypoints/` becomes its own bundle, named after the file. Stylesheets work too, with no JavaScript needed:

```
app/javascript/application.js           -> application-<hash>.js
app/javascript/entrypoints/admin.ts     -> admin-<hash>.js
app/javascript/entrypoints/checkout.js  -> checkout-<hash>.js (+ checkout-<hash>.css if it imports CSS)
app/javascript/entrypoints/print.scss   -> print-<hash>.css (no script)
```

```erb
<%# app/views/layouts/admin.html.erb %>
<%= rspack_javascript_tag "admin" %>
<%= rspack_stylesheet_tag "print", media: "print" %>
```

`admin.js` and `admin.css` side by side make one entry.

Several entries can share a page. Under `rspack serve` the helpers link one shared `runtime.js`, so hot updates reach every entry. A build makes each entry self-contained instead, so `<entry>.js` runs on its own. On a page with two entries, a module both of them import (Turbo, your Stimulus `application`, React) is then loaded and run twice, each entry with its own copy. To share one runtime in builds too, set it in `rspack.config.mjs` (it is `isDevServer ? { name: "runtime" } : false` there):

```js
optimization: { runtimeChunk: { name: "runtime" } },
```

The helpers then link `runtime.js` before the entries, once per page. Only load the entries through the helpers after this, since `<entry>.js` no longer runs without `runtime.js`.

Restart the dev server after adding a new entry point.

## Importing app code

Import files in `app/javascript` from anywhere with `#/`, the [subpath imports](https://nodejs.org/api/packages.html#subpath-imports) prefix that Rspack resolves from `package.json`:

```js
import { formatDate } from "#/lib/dates"        // app/javascript/lib/dates.js (or .ts)
import logo from "#/images/logo.svg"
```

`rspack:install` adds `"imports": { "#/*": "./app/javascript/*" }` to `package.json`. With TypeScript, add the same mapping to the `paths` of `tsconfig.json` so type checking and your editor follow it too. Bare imports such as `import "lib/dates"` keep working as they did with importmap.

## CSS

Import CSS from JavaScript, and Rspack extracts it to `public/rspack/<entry>-<hash>.css`:

```js
// app/javascript/application.js
import "./styles/application.css"
```

```erb
<%= rspack_stylesheet_tag "application" %>
```

- `*.module.css` files are compiled as CSS modules. Import their class names as a namespace (`import styles from` fails the build: a CSS module has no default export):

  ```js
  import * as styles from "./Button.module.css"

  button.className = styles.primary      // a scoped name ending in "Button_module_css-primary", a short hash in production
  button.classList.add(styles["is-active"])
  ```

- Under `rspack serve`, CSS changes apply without a page reload.

## Images and fonts

Import an image from JavaScript, or reference images and fonts from CSS with `url()`:

```css
body { background: url("./images/hero.png"); }
@font-face { font-family: Brand; src: url("./fonts/brand.woff2"); }
```

- Files under 8 KB are inlined as data URIs.
- Larger ones are written to `public/rspack` as `<name>-<hash>.<ext>`.
- Images that a view shows (`<img>`, an icon, an Open Graph image) go in `app/javascript/images/`; see below.
- A root-relative `url()` is left for Rails: Rspack neither bundles nor fingerprints it. `url("/icon.png")` is served from `public/icon.png` as written. Without Propshaft or Sprockets, `image_tag "logo.png"` does not look in `app/assets/images` either: import the image from JavaScript or CSS, or put it in `public/`.

### Images in views

Every file in `app/javascript/images/` is fingerprinted into `public/rspack` on each build and listed in the manifest, whether or not JavaScript imports it. Name it by its path in that directory:

```erb
<%= rspack_image_tag "logo.svg", alt: "Acme", class: "h-8" %>
<%= rspack_image_tag "icons/menu.svg", alt: "" %>
<link rel="icon" href="<%= rspack_asset_path "favicon.png" %>">
```

- `rspack_image_tag` takes the options of `tag.img`. `rspack_asset_path` returns the URL (`/rspack/logo-<hash>.svg`, with `config.asset_host` in front), for anything that is not an `<img>`.
- An image that is not there raises `RspackRails::Manifest::MissingAsset`, naming the images that are.
- Under `rspack serve` the images come from the dev server, so adding or editing one needs no build.
- An image that CSS or JavaScript also imports is emitted once, by Rspack, and listed under its file name; a small one that Rspack inlines as a data URI still gets its own file for views. So the directory can hold every image, whoever uses it.

## Web Workers

Create a worker from a `new URL()` next to `import.meta.url`, and Rspack bundles the worker file with its imports as a chunk of its own:

```ts
// app/javascript/controllers/report_controller.ts
const worker = new Worker(new URL("../workers/report.worker.ts", import.meta.url), { name: "report" })
worker.postMessage({ rows })
```

- The chunk is written as `<name>-<hash>.js` (`report-…` here, from the `name` option) and loaded from the same origin as the page: `/rspack/` under `rspack serve` and after a build.
- A worker can import app code and packages like any other module, so code shared with the page lives in one file.
- TypeScript checks a worker against the `DOM` library from `tsconfig.json`, where `postMessage` takes a target origin. Call it as `(self as unknown as Worker).postMessage(result)` inside the worker.

## Adding tools

`rspack.config.mjs` is yours, so each tool is a package and a few lines in it. [rspack.rs](https://rspack.rs) documents each in full. [Recipes](recipes.md) has more: environment values, aliases, Less, PostCSS, Vue, Svelte, Preact, jQuery globals and plugins.

### TypeScript

`.ts` and `.tsx` files compile out of the box with Rspack's built-in SWC loader. SWC strips types without checking them, so add a check to your scripts:

```bash
npm install --save-dev typescript
npx tsc --init   # then set "noEmit": true, and "paths" if you use aliases
```

```json
"scripts": { "typecheck": "tsc --noEmit" }
```

Set `"isolatedModules": true` in `tsconfig.json`: SWC compiles one file at a time, and this makes `tsc` report the code that needs more than that. `"paths"` aliases in `tsconfig.json` are honored by the build, so `"@/*": ["./app/javascript/*"]` makes `import "@/lib/api"` work in both TypeScript and Rspack. For type errors in the dev server overlay, add [`ts-checker-rspack-plugin`](https://github.com/rspack-contrib/ts-checker-rspack-plugin) to `plugins` under `rspack serve`.

### Stimulus

```bash
npm install @hotwired/stimulus
```

```js
// app/javascript/controllers/application.js
import { Application } from "@hotwired/stimulus"

export const application = Application.start()
```

```js
// app/javascript/controllers/index.js
// Registers every Stimulus controller under app/javascript/controllers:
// hello_controller.js -> "hello", admin/user_controller.js -> "admin--user".
// New controllers need no manual import, and under `rspack serve` an edited or
// added controller is swapped in the open page without a reload.
import { application } from "./application"

const controllers = () => import.meta.webpackContext(".", { recursive: true, regExp: /_controller\.[jt]s$/ })

// "./admin/user_controller.js" -> "admin--user"
const identifierFor = (key) =>
  key
    .replace(/^\.\//, "")
    .replace(/_controller\.[jt]s$/, "")
    .replaceAll("/", "--")
    .replaceAll("_", "-")

const registerAll = (context) => {
  for (const key of context.keys()) {
    const controller = context(key).default
    if (controller) application.register(identifierFor(key), controller)
  }
}

const context = controllers()
registerAll(context)

// Stimulus unloads an identifier before registering it again, so registering
// again swaps connected controllers in place.
if (import.meta.webpackHot) {
  import.meta.webpackHot.accept(context.id, () => registerAll(controllers()))
}
```

Import `./controllers` from your entry. `admin/user_card_controller.js` becomes `admin--user-card`. Under `rspack serve`, editing or adding a controller swaps it in the open page, so form input and other page state survive. [`rspack:migrate`](migrating.md) writes this `index.js` for an importmap app that had stimulus-rails.

### Sass

```bash
npm install --save-dev sass sass-loader
```

```js
// rspack.config.mjs, in module.rules
{
  test: /\.s[ac]ss$/,
  type: "css/auto", // *.module.scss files become CSS modules
  loader: "sass-loader",
  options: { sassOptions: { loadPaths: [path.resolve(root, "app/assets/stylesheets")] } }, // @use "variables"
},
```

Import `.scss` files from JavaScript, like CSS. `url()` inside a partial is resolved from the file that was imported from JavaScript.

### Tailwind CSS

```bash
npm install --save-dev tailwindcss @tailwindcss/webpack
```

```js
// rspack.config.mjs: the module.rules entry for CSS
{
  test: /\.css$/,
  type: "css/auto",
  use: [{ loader: "@tailwindcss/webpack", options: { base: root } }],
},
```

```css
/* app/javascript/application.css, imported from application.js */
@import "tailwindcss";

/* Tailwind skips what .gitignore lists, but a Docker build has no .gitignore:
   leave out what Rails and rspack write to, or the image's CSS grows unused classes. */
@source not "../../tmp";
@source not "../../log";
@source not "../../storage";
@source not "../../public/rspack";
```

Classes in views, helpers and JavaScript are picked up automatically. Under `rspack serve`, editing a view reloads the page with the new classes already built.

**Coming from `rails new --css tailwind`?** That app has tailwindcss-rails, which builds into `app/assets/builds` for Propshaft or Sprockets, and it works next to Rspack as it is. To let Rspack build the CSS instead, after the steps above:

- remove the `tailwindcss-rails` gem (`bundle remove tailwindcss-rails`), the `css:` line in `Procfile.dev`, and `app/assets/tailwind` with the old `app/assets/builds/tailwind.css`;
- put your `@theme` and `@plugin` lines from `app/assets/tailwind/application.css` into `app/javascript/application.css`;
- remove `stylesheet_link_tag "tailwind"` from the layout if it has one (Rails 7.2). Rails 8's `stylesheet_link_tag :app` can stay: it links what is left in `app/assets`.

`rspack_stylesheet_tag "application"`, which `rspack:install` adds next to the script tag, links the new CSS. CI runs this move on Rails 7.2 and 8.1.

### React

```bash
npm install react react-dom
npm install --save-dev @rspack/plugin-react-refresh react-refresh
```

```js
// rspack.config.mjs
import { ReactRefreshRspackPlugin } from "@rspack/plugin-react-refresh";

// in the swc-loader rule: jsc.transform.react
react: { runtime: "automatic", development: !isProduction, refresh: isDevServer },

// in plugins
isDevServer && new ReactRefreshRspackPlugin(),
```

Mount components from your entry however suits the app; a `data-` attribute on an element and `createRoot` is enough. A view helper for the element is a few lines in `app/helpers/application_helper.rb`:

```ruby
# <%= react_component "Hello", name: "World" %>, mounted by your own script from data-react-component
def react_component(name, props = {}, html: {}, **more_props)
  html = html.dup
  tag = html.delete(:tag) || :div
  data = (html.delete(:data) || {}).merge(react_component: name, react_props: props.merge(more_props).to_json)
  content_tag(tag, "", **html, data: data)
end
```

Set `"jsx": "react-jsx"` in `tsconfig.json` if you use TypeScript.

**React Compiler.** It memoizes components for you, so `useMemo` and `useCallback` are rarely needed. It is experimental and needs `@rspack/core` 2.1.0 or later. Turn it on in the same `jsc.transform` as `react`:

```js
jsc: { transform: { react: { runtime: "automatic", development: !isProduction, refresh: isDevServer }, reactCompiler: true } },
```

With React 17 or 18, use `reactCompiler: { target: "18" }` and install `react-compiler-runtime`. The swc-loader rule in the generated config matches `.ts`, `.jsx` and `.tsx`, so plain `.js` files are not compiled: write components in `.jsx`. [rspack.rs](https://rspack.rs/guide/integrations/react) lists the compiler's options, such as `compilationMode: "annotation"` to compile only functions you mark.

## What `rspack:install` changes

- Creates `rspack.config.mjs` and `app/javascript/application.js`. An existing `application.ts`, `.jsx` or `.tsx` is kept as the entry. The config is yours: rspack_rails never rewrites it.
- Adds `build`, `build:watch` and `dev` (`rspack serve`) scripts to `package.json`.
- Adds `rspack_javascript_tag "application"` and `rspack_stylesheet_tag "application"` to your layouts (ERB, Slim or Haml).
- Adds a `js:` process running the dev server to `Procfile.dev`, and sets up `bin/dev`.
- Makes the `Dockerfile` install Node.js and your node modules so Kamal deploys can precompile ([Deploying](production.md#deploying-docker-and-kamal)), and makes `bin/setup` install node modules.
- In a dev container, adds Node.js and forwards the dev server port ([Dev containers](production.md#dev-containers)).
- Installs `@rspack/cli`, `@rspack/core` and `@rspack/dev-server`.
- Adds `/public/rspack` to `.gitignore` and `.dockerignore`.

Running it again is safe: it leaves your entry, layouts and `Procfile.dev` alone when they are already set up, and asks before it replaces a different `rspack.config.mjs`.
