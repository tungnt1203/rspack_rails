## [Unreleased]

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
