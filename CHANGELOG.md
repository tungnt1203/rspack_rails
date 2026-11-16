## [Unreleased]

## [0.17.0] - 2026-11-16

- Lazy compilation goes through Rails: under `rspack serve`, the client posts the modules to compile to `/rspack/_rspack/lazy/trigger` on the page's origin, and `RspackRails::DevServerProxy` forwards that POST (and only that one) to the dev server. It used to call `http://localhost:3036/` directly, a cross-origin request that only worked where the browser can reach that port. Only the HMR websocket still goes to the dev server directly
- `#/` imports for app code: `import { formatDate } from "#/lib/dates"` loads `app/javascript/lib/dates.{js,ts}`. `rspack:install` adds `"imports": { "#/*": "./app/javascript/*" }` to `package.json` (Node.js subpath imports, resolved by rspack with the usual extensions), and the `tsconfig.json` from `rspack:install:typescript` maps `#/*` in `paths`, since TypeScript does not add extensions to `imports` targets. Existing apps: re-run `rspack:install` (and `rspack:install:typescript`, or add the `paths` entry by hand)
- Hand edits to `config/rspack/rails.mjs` are no longer lost without a word. The file carries a checksum of its content, so rspack_rails tells an edit apart from a file written by another version: `rspack:doctor` warns about it, and `rspack:sync` (also run by `rspack:build`) saves the edited file to `tmp/rspack_rails/` and says so before replacing it. Files written before this version have no checksum and are replaced as before
- CI: the browser test clicks a button that runs a dynamic `import()` under `rspack serve` and checks it loads, with every lazy compilation request on the page's origin
- CI: a weekly workflow (`Rspack next`) runs the integration suite against the most recently published `@rspack/core` and `@rspack/dev-server`, prereleases included (`bin/rspack-next-version`), so Rspack 3 betas are tested before apps get them

## [0.16.0] - 2026-11-16

- Subresource Integrity: `rspack_javascript_tag` and `rspack_stylesheet_tag` pass `integrity: true` to the asset pipeline, which hashes the files it serves (CSS after Propshaft's `url()` rewriting). Under `rspack serve` the option is dropped, as those files are not part of the pipeline. README: how to turn it on (`config.assets.integrity_hash_algorithm` for Propshaft), and why chunks loaded at runtime are not covered
- CI checks that each `integrity` attribute matches the file served from `public/assets`, on Propshaft and Sprockets

## [0.15.0] - 2026-11-16

- Installers pin Rspack's major version (`@rspack/core@^2`, also `@rspack/cli`, `@rspack/dev-server` and `@rspack/plugin-react-refresh`), so a new app does not pick up Rspack 3 on its own when it comes out. `config/rspack/rails.mjs` is written for Rspack 2 (top-level persistent `cache`, `lazyCompilation`)
- Fix: on Rspack 2.0, every TypeScript and JSX file failed with `unknown field 'reactCompiler'`: the option, added in Rspack 2.1, was always passed. It is now passed only with `RSPACK_REACT_COMPILER=true`, which needs Rspack 2.1+
- Fix: on Rspack 2.0, a stylesheet-only entry (`app/javascript/entrypoints/print.css`) also built an empty `print.js`, which the manifest listed and `rspack_stylesheet_tag` linked. Builds now drop it; under `rspack serve` it stays, as it carries hot updates
- `rspack:doctor` fails on Rspack 1 and warns about a newer major than the one rspack_rails is tested with
- CI also runs the integration suite against Rspack 2.0, the oldest version the `^2` range allows
- README: Rspack 2 in the requirements; troubleshooting for imports of names a module does not export, an error since Rspack 2

## [0.14.1] - 2026-11-16

- Fix: a root-relative `url()` in CSS, such as `url("/icon.png")` for a file in `public/` or `url("/logo.svg")` for one in `app/assets/images`, failed the build with `Module not found: Can't resolve '/icon.png'`. Rspack 2 resolves such paths from the root of the file system. They are now left for Rails: Propshaft fingerprints the ones it finds in `app/assets`, and the rest stay as written. Relative `url()`s are still bundled and fingerprinted by rspack

## [0.14.0] - 2026-11-16

- rspack writes `app/assets/builds/.rspack-manifest.json` (each entry's scripts and stylesheets, runtime first), on every build and after each rebuild under `rspack serve`. `rspack_javascript_tag` and `rspack_stylesheet_tag` link what it lists instead of guessing file names from `app/javascript`, so the helpers no longer scan entry points or check for `runtime.js` on disk
- `rspack_stylesheet_tag` links nothing for an entry that imports no CSS (it linked a missing `<entry>.bundle.css`, an error in production)
- A script already on the page (such as a second `rspack_javascript_tag` for the same entry) is linked once
- `rspack:clobber` removes the manifest

## [0.13.0] - 2026-11-16

- The rspack config is split in two. `config/rspack/rails.mjs` holds the defaults and belongs to the gem: `rspack:build` (before `assets:precompile` and tests) and the new `rspack:sync` rewrite it when the gem version changes. `rspack.config.mjs` is the app's own and passes a callback to `railsConfig()` to change anything. Upgrading no longer means overwriting `rspack.config.mjs` and merging your changes back by hand
- When `config/rspack/rails.mjs` is from another version than `Gemfile.lock`, rspack prints a warning (e.g. under `bin/dev` before the next `rspack:build`)
- `rspack:doctor` checks that `config/rspack/rails.mjs` exists and matches the gem, and warns about a standalone `rspack.config.mjs`
- Re-running `rspack:install` keeps a `rspack.config.mjs` that builds on `config/rspack/rails.mjs` without asking. `rspack:install:sass`, `:tailwind` and `:react` update `config/rspack/rails.mjs` instead of asking for a new config
- Existing apps: run `bin/rails rspack:install` once, answer "y" to replace `rspack.config.mjs` ("d" shows your changes), and move your changes into the `railsConfig` callback

## [0.12.0] - 2026-11-16

- Docker and Kamal: `rspack:install` makes the `Dockerfile` install Node.js and node modules (frozen install from the lockfile) in the build stage and remove them after `assets:precompile`. Rails only does this for apps created with a JavaScript bundler, so a `--skip-javascript` or importmap app failed to build its image with `npm install failed`
- Dev containers: `rspack:install` adds the Node.js feature to `.devcontainer/devcontainer.json` and forwards the dev server port for the HMR websocket
- `rspack:install` makes `bin/setup` install node modules (dev containers run it on creation)
- `rspack:doctor` checks the `Dockerfile` (error when it cannot run rspack) and the dev container
- CI: `bin/integration-docker` builds and runs the image of a new app made with `rails new --devcontainer -m template.rb`
- Existing apps: re-run `bin/rails rspack:install` to update the `Dockerfile`, `bin/setup` and dev container

## [0.11.0] - 2026-11-16

- Under `rspack serve`, editing a file in `app/views`, `app/helpers` or `app/components` reloads the page. Views are rendered by Rails, so a hot update could not change them: a new Tailwind class in a view was built but only showed after a manual reload (the README claimed otherwise). `RSPACK_VIEW_RELOAD=false` turns it off. JavaScript and CSS changes are still hot-swapped
- CI: `bin/integration-hmr` runs `rails server` and `rspack serve` and drives Chromium with Playwright: editing a Stimulus controller keeps its state, a new controller connects and CSS edits apply without a reload, and editing a view reloads the page with its new Tailwind class. It fails on 0.10.0 (stale-cache HMR bug) and on 0.10.2 (no view reload)
- `template.rb`: a new app in one command, `rails new myapp -m https://raw.githubusercontent.com/tungnt1203/rspack_rails/main/template.rb`. It asks for Stimulus, TypeScript, React, Tailwind and Sass (or reads `RSPACK_FEATURES`), migrates the default importmap setup and `--css tailwind`/`--css sass`, and builds once. CI runs it on Rails 7.2 and 8.1
- Existing apps: re-run `bin/rails rspack:install` and accept the new `rspack.config.mjs`

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
