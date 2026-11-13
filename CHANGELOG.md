## [Unreleased]

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
