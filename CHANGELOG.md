## [Unreleased]

## [0.10.2] - 2026-11-13

- Fix: `rspack:install` and `rspack:doctor` treated `stylesheet_link_tag :app` inside an ERB comment as a real tag, and the installer rewrote the comment. Only output tags (`<%=` in ERB, `=` in Slim/Haml) count now
- README links to [rspack_rails-demo](https://github.com/tungnt1203/rspack_rails-demo)

## [0.10.1] - 2026-11-13

- Fix: after a `rspack build` (which `rspack:build` runs before tests and `assets:precompile`), `rspack serve` reused the build's cached modules, compiled without HMR, so editing a Stimulus controller reloaded the page instead of hot-swapping it. `rspack serve`, development builds and production builds now keep separate persistent caches (`cache.name`)
- Fix: Rails 8's `stylesheet_link_tag :app` also linked rspack's `*.bundle.css` files, so a print entry applied on screen and an admin entry on every page. `rspack:install` replaces `:app` with `"application"` when that is the app's only stylesheet, and `rspack:doctor` warns otherwise
- CI: `bin/integration-migrate` starts `rspack serve` after a build and checks that hot updates are accepted
- Existing apps: re-run `bin/rails rspack:install` and accept the new `rspack.config.mjs`

## [0.10.0] - 2026-11-13

- Requires Ruby 3.2+ and Rails 7.2+, the versions CI runs (Ruby 3.1 and Rails 7.0/7.1 are end of life)
- Slim and Haml layouts: installers add `rspack_javascript_tag` / `rspack_stylesheet_tag` in the layout's syntax, and `rspack:migrate` removes `javascript_importmap_tags` from every layout
- `rspack:doctor` checks every layout in `app/views/layouts` (ERB, Slim, Haml), not only `application.html.erb`
- `rspack:clobber` (and `assets:clobber`) removes only rspack's output: entry scripts, `*.bundle.css`, `runtime.js`, source maps and `*.digested.*`. Files from other tools in `app/assets/builds` stay
- Fix: `npm run typecheck` failed on `import "./application.css"` with recent TypeScript releases, which turn on `noUncheckedSideEffectImports` by default. `rspack:install:typescript` adds `app/javascript/types/assets.d.ts` with types for stylesheets, images and fonts; existing apps can re-run it
- CI: an app with an `application.ts` entry and a Slim layout runs through every installer

## [0.9.1] - 2026-11-13

- Fix: `rspack:install` and `rspack:install:stimulus` created `app/javascript/application.js` in apps whose entry is `application.ts` (or `.jsx`, `.tsx`), which then shadowed it. All installers now use the same entry discovery as `rspack.config.mjs`
- Fix: re-running `rspack:install` on Sprockets added `//= link_tree ../builds` to `manifest.js` again
- `rspack:install:sass`, `:tailwind` and `:react` accept a `.jsx`/`.tsx` main entry
- Installer templates share their steps through `RspackRails::Installer`

## [0.9.0] - 2026-11-13

- Stylesheet entry points: `app/javascript/entrypoints/*.{css,scss,sass}` build `<name>.bundle.css` without a JavaScript file; `admin.js` and `admin.css` side by side make one entry. Under `rspack serve`, `rspack_stylesheet_tag` adds the entry's script so its changes hot-reload
- Fix: with two entries on one page (`rspack_javascript_tag "application", "admin"`), HMR stopped working after the first update, because each entry carried its own runtime. Under `rspack serve` entries now share `runtime.js`, which the helpers link once per page; normal builds stay self-contained and remove the dev server's `runtime.js`
- `rspack:doctor` knows `.jsx`/`.tsx` and stylesheet entry points
- Existing apps: re-run `bin/rails rspack:install` and accept the new `rspack.config.mjs`

## [0.8.0] - 2026-11-13

- `tsconfig.json` `paths` aliases resolve in rspack (`resolve.tsConfig`)
- `rspack:install:typescript` adds `ts-checker-rspack-plugin`: type errors show in the dev server overlay
- JS and CSS target the app's browserslist config, or Baseline "widely available" without one (was a fixed ES2022 for TypeScript/JSX)
- React Compiler through the built-in SWC loader with `RSPACK_REACT_COMPILER=true`
- Fix: the persistent cache ignored changes to `RSPACK_REACT_COMPILER`, `package.json`, `tsconfig.json` and `.browserslistrc`
- Existing apps: re-run `bin/rails rspack:install` and accept the new `rspack.config.mjs`; re-run `rspack:install:typescript` for the type checker

## [0.7.1] - 2026-11-13

- Fix: `new Worker(new URL("./worker.js", import.meta.url))` threw `SecurityError` under `rspack serve`, because the worker script came from `localhost:3036`, another origin than the page. Rails now proxies the dev server under `/rspack/` (`RspackRails::DevServerProxy`, active only while the dev server is enabled), so bundles, chunks, workers, images and hot updates are same-origin
- `rspack:doctor` warns when `rspack.config.mjs` predates the proxy
- Existing apps: re-run `bin/rails rspack:install` and accept the new `rspack.config.mjs`. Without it everything keeps working as in 0.7.0, except Web Workers under `rspack serve`

## [0.7.0] - 2026-11-13

- Fix: dynamic `import()` failed under `rspack serve` ("Problem communicating active modules to the server: HTTP 404"). Rspack 2's dev server compiles them lazily and its client called the Rails origin; it now calls the dev server. `RSPACK_LAZY_COMPILATION=false` turns lazy compilation off
- `rspack:install:sass`: Sass through `sass-loader` and `sass-embedded`, with `app/assets/stylesheets` as a load path. Moves an app off dartsass-rails
- `rspack:analyze`: production build into `tmp/rsdoctor` and a single-file Rsdoctor report, no server needed
- Existing apps: re-run `bin/rails rspack:install` and accept the new `rspack.config.mjs`

## [0.6.0] - 2026-11-13

- `rspack:install:react`: React with Fast Refresh under `rspack serve`, and `app/javascript/components/` autoloaded by path
- `react_component "Hello", name: "World"` helper; components mount and unmount with Turbo Drive, frames and streams
- `.jsx` and `.tsx` files (and entry points) compile with the built-in SWC loader
- SWC now targets ES2022 instead of ES5, so TypeScript output is smaller and closer to the source
- Existing apps: re-run `bin/rails rspack:install` and accept the new `rspack.config.mjs`

## [0.5.0] - 2026-11-13

- `rspack:install:tailwind`: Tailwind CSS v4 through `@tailwindcss/webpack`. Moves an app off tailwindcss-rails (its `application.css`, gem, `Procfile.dev` process and build output)
- `rspack.config.mjs` adds the Tailwind loader when `@tailwindcss/webpack` is in `package.json`, and ignores `log/`, `tmp/`, `public/`, `app/assets/builds/` and similar directories when watching
- Fix: `rspack:clobber` (and so `assets:clobber`) crashed with `ENOENT` when a lazy chunk was built, since 0.4.1
- Existing apps: re-run `bin/rails rspack:install` and accept the new `rspack.config.mjs`

## [0.4.1] - 2026-11-13

- Fix: importing an image or font, from JavaScript or CSS `url()`, no longer fails the build. Files under 8 KB are inlined, larger ones are emitted as `*.digested.<ext>` for Propshaft
- Production builds no longer ship source maps to `public/assets`; development uses the faster `cheap-module-source-map`. Override with `RSPACK_DEVTOOL`
- Persistent cache in `node_modules/.cache/rspack` speeds up rebuilds and dev server restarts
- Outside the dev server, `publicPath` is `"auto"`: chunks and images load next to their script (any assets prefix or `asset_host`), and Propshaft rewrites CSS `url()`s without warnings
- `rspack:build` sets `NODE_ENV` from `Rails.env`, so development and test builds are no longer minified
- `rspack:clobber` also removes emitted images and fonts
- Existing apps: re-run `bin/rails rspack:install` and accept the new `rspack.config.mjs`

## [0.4.0] - 2026-11-13

- `rspack:migrate`: moves an importmap-rails or jsbundling-rails (esbuild/webpack/rollup) app to rspack. Requires a clean git tree (or `FORCE=1`)
- `rspack.config.mjs` resolves bare imports from `app/javascript` (`resolve.modules`), so importmap-style `import "controllers/application"` keeps working
- `rspack:install:stimulus` also rewrites a bare `import "controllers"`
- Installers stop when a package install fails instead of carrying on

## [0.3.0] - 2026-11-13

- Multiple entry points: every `app/javascript/entrypoints/*.{js,ts}` becomes a bundle named after the file; `application.ts` works as the main entry
- `rspack:doctor` lists entry points and reports any that are not built
- Fix: the dev server no longer writes `*.hot-update.js` files into `app/assets/builds`
- Existing apps: re-run `bin/rails rspack:install` and accept the new `rspack.config.mjs`

## [0.2.0] - 2026-11-13

- CSS imported from JavaScript is extracted to `app/assets/builds/<entry>.bundle.css` and hot-reloaded under `rspack serve`; `*.module.css` are CSS modules
- **Changed:** `rspack_stylesheet_tag "application"` now links `application.bundle.css` (was `application.css`)
- TypeScript: `.ts` files and `*_controller.ts` Stimulus controllers compile with the built-in SWC loader
- `rspack:install:typescript` adds `tsconfig.json`, `typescript` and a `typecheck` script
- Dev server writes bundles to disk so `app/assets/builds` stays current
- `rspack:doctor` warns when `application.bundle.css` is built but not linked
- Existing apps: re-run `bin/rails rspack:install` (and `rspack:install:stimulus`) and accept the new `rspack.config.mjs` / `autoload.js`

## [0.1.0] - 2026-11-13

- `rspack:doctor`: checks Node.js against rspack's `engines`, packages, config, entry, build output, layout, Procfile.dev, Stimulus and the dev server
- `rspack:install:stimulus`: Stimulus with automatic controller registration and hot-swapping under `rspack serve`
- `rspack_javascript_tag` / `rspack_stylesheet_tag` helpers that load from `rspack serve` in development and fall back to the asset pipeline
- Dev server with hot module replacement (`npm run dev`), configured via `RSPACK_DEV_SERVER_*` env vars or `RspackRails.configure`
- Installer adds `@rspack/dev-server` and upgrades Phase 1 layouts and `Procfile.dev`
- Railtie with `rspack:install`, `rspack:build`, `rspack:dependencies` and `rspack:clobber` tasks
- Hook `rspack:build` into `assets:precompile` and test prepare tasks
- Package manager detection (bun, yarn, pnpm, npm)
