## [Unreleased]

## [1.0.5] - 2026-11-20

- Builds no longer print Rspack's "asset size limit" and "entrypoint size limit" warnings. They flag any entry over 244 KiB, which an app with React and Turbo passes from the start, so every `assets:precompile` (and every deploy) warned about something nobody had asked to budget. Set `config.performance` in `rspack.config.mjs` to warn or fail over a budget of your own (docs/production.md#bundle-analysis)

## [1.0.4] - 2026-11-20

- `rspack:install:tailwind` leaves `tmp`, `log`, `storage` and `app/assets/builds` out of Tailwind's class scan with `@source not` lines in `app/javascript/application.css`. Tailwind skips what `.gitignore` lists, but a Docker build has no `.gitignore` and does have bootsnap's cache in `tmp/`, so the production CSS in the image picked up unused classes (twice the size of a local build). `rspack:doctor` warns about a Tailwind stylesheet without them; run `bin/rails rspack:install:tailwind` again to add them

## [1.0.3] - 2026-11-20

Found by taking a new Rails 8.1 app from `rails new` with the template through `bin/dev`, tests, `assets:precompile` and a Docker image.

- `rspack serve` writes its manifest to `app/assets/builds/.rspack-dev-manifest.json`, which the view helpers read while it runs. A build alongside it, such as the one `bin/rails test` runs, used to replace the shared `.rspack-manifest.json`, so dev pages dropped `runtime.js` and ran no JavaScript at all until the next rebuild. Run `bin/rails rspack:sync` (or any `rspack:build`) to get the new `config/rspack/rails.mjs`; until then the helpers keep reading `.rspack-manifest.json`

## [1.0.2] - 2026-11-19

- The view helpers keep the last complete `.rspack-manifest.json` when they read it while rspack is rewriting it, and read it again on the next call. They used to fall back to the conventional file names until the next rebuild, which under `rspack serve` left `runtime.js` out and broke hot updates on that page
- `config/rspack/rails.mjs` treats `rspack dev`, `rspack server` and `rspack s` like `rspack serve`. They are aliases of the same dev server command, and Rspack's docs now use `rspack dev`, but they got the build config: no shared runtime or lazy compilation, and a clean of `app/assets/builds` on every rebuild
- A build with a shared runtime (`config.optimization.runtimeChunk` set in `rspack.config.mjs`) no longer deletes `runtime.js` along with the empty script of a stylesheet-only entry (`app/javascript/entrypoints/print.css`). The manifest still listed it, so pages linked a missing file
- Usage guide: a build makes each entry self-contained, so two entries on one page each run their own copy of the modules they share. How to share one runtime in builds too
- `rspack_stylesheet_tag` passes its `nonce` to the hot update script it adds for a stylesheet-only entry under `rspack serve`, so a Content Security Policy no longer blocks it

## [1.0.1] - 2026-11-19

- The view helpers read the manifest of the current `Rails.root`. A process that switches apps (tests, an engine's dummy app) kept reading the first app's `.rspack-manifest.json`
- `rspack:doctor` leaves out the build output check when the app has no entry points. It said "✓ Build output: app/assets/builds has" with nothing after it
- Internal: the doctor's checks move into groups under `lib/rspack_rails/doctor/`. Its output is unchanged, which golden reports in `spec/fixtures/doctor/` now hold it to

## [1.0.0] - 2026-11-19

The first stable release. Nothing changed in the gem since 1.0.0.rc2; the parts listed under [Stability](docs/upgrading.md#stability) now change only in a major release. Upgrading from before 0.18.0: go through 0.19 first and fix what `rspack:doctor` reports.

- README: a shorter front page (quick start, what you get, how it works). The full guide moves to `docs/` (usage, production, configuration, migrating, upgrading, troubleshooting)
- CONTRIBUTING.md: setting up, a map of the code, and which integration script to run for which change

## [1.0.0.rc2] - 2026-11-17

Found by migrating a real two-layout importmap + tailwindcss-rails app with rc1.

- `rspack:migrate` puts `rspack_javascript_tag "application"` where each layout or layout partial called `javascript_importmap_tags`. It used to remove the call from every layout and add the new tag only to the application layout, so an admin layout lost its JavaScript without a word. A call with arguments is removed with a note
- `rspack_stylesheet_tag "application"` goes next to every `rspack_javascript_tag "application"`, in each layout or `<head>` partial, not only in the application layout. A tag in a layout partial the layout renders (`render "layouts/head"`) counts as the layout's own, so it is not added twice
- `rspack:install:tailwind` moves the other CSS files in `app/assets/tailwind/` along with `application.css`, so its `@import "./fonts.css"` still resolves. The build used to fail with "Can't resolve"
- `stylesheet_link_tag :app` becomes the app's own stylesheets by name, in the order `:app` linked them (`stylesheet_link_tag "application", "driver"`), when the app has more than `application.css`. It used to stay, with a warning, linking rspack's bundles a second time
- `rspack:doctor` says "use" and "link" for several layouts in its stylesheet check too

## [1.0.0.rc1] - 2026-11-17

The first release candidate for 1.0. From 1.0, the parts listed under [Stability](docs/upgrading.md#stability) change only in a major release. Upgrading from before 0.18.0: go through 0.19 first and fix what `rspack:doctor` reports.

- Removed, deprecated in 0.18.0: `SKIP_RSPACK_BUILD` (use `RSPACK_SKIP_BUILD`), `FORCE` for `rspack:migrate` (use `RSPACK_FORCE`), and `RspackRails.config.dev_server_host=` and `dev_server_port=` (use `RSPACK_DEV_SERVER_HOST` and `RSPACK_DEV_SERVER_PORT`). The old variables are ignored; the setters raise `NoMethodError`
- A managed file without a checksum line (`config/rspack/rails.mjs` before 0.17.0, the Stimulus and React loaders before 0.18.0) counts as edited: it is saved to `tmp/rspack_rails/` before it is replaced. 0.18 and 0.19 recognized the released copies and replaced them without a backup
- `rspack.config.mjs` that does not build on `config/rspack/rails.mjs` (from before 0.13.0) is an error in `rspack:doctor`, and `rspack:install:react`, `:sass` and `:tailwind` refuse to run on it. They used to accept an older config that mentioned the feature's plugin. `rspack:install` still offers to replace it
- `template.rb` no longer passes `FORCE=1`

## [0.19.0] - 2026-11-17

- README: a "Stability" section says what 1.0 keeps stable (the Ruby API in `sig/rspack_rails.rbs`, `railsConfig`, rake tasks, environment variables, build output names, supported versions) and what may change in any release
- `RspackRails.deprecator` is internal and no longer listed in `sig/rspack_rails.rbs`
- Coming in 1.0: `SKIP_RSPACK_BUILD`, `FORCE`, `config.dev_server_host=` and `config.dev_server_port=` are removed. So is upgrading straight from before 0.18: the loaders copied by 0.17.0 and earlier and a standalone `rspack.config.mjs` from before 0.13.0 are no longer recognized. Upgrade to 0.19 first, run `bin/rails rspack:doctor`, and fix what it warns about

## [0.18.2] - 2026-11-17

- `rspack:doctor` says "use" for several layouts (`application.html.erb, admin.html.erb use rspack_javascript_tag`)
- `template.rb` prints one closing message. `rspack:install` and `rspack:migrate` used to print theirs ("Run bin/dev", "Review the changes") in the middle, before the extras were installed. `rspack:migrate` run by itself no longer prints the installer's message either

## [0.18.1] - 2026-11-17

- Each build deletes what earlier builds left in `app/assets/builds`: old chunks and a development build's source maps. Propshaft copied all of it to `public/assets`, so precompiling on a machine that had run development builds deployed the source maps too (Docker and Kamal builds were not affected: `.dockerignore` leaves `app/assets/builds` out). Only Rspack's own files are deleted, by the rule `rspack:clobber` uses, so other tools' output stays. A broken symlink in `app/assets/builds` makes the build fail: delete it

## [0.18.0] - 2026-11-17

- Upgrading: if you edited `app/javascript/controllers/autoload.js` or `app/javascript/components/mount.js`, move your changes to a file of your own first. The first `rspack:build` (also run by `assets:precompile`) replaces an edited copy, and on a build server its backup in `tmp/rspack_rails/` is lost with the server
- Files rspack_rails keeps up to date no longer count as hand-edited when Git checks them out with CRLF line endings (`core.autocrlf` on Windows). They used to be backed up and rewritten after every checkout
- CI runs the integration suite with Yarn 1 and bun (`PACKAGE_MANAGER=yarn bin/integration`, or `bun`), on Rails 8.1. The installer detects the package manager from the lockfile, so the script creates one before `rspack:install`

- `RSPACK_DEV_SERVER_PUBLIC_URL`: where the browser opens the HMR websocket, for a dev server it cannot reach at `RSPACK_DEV_SERVER_HOST:PORT` (GitHub Codespaces, a remote dev container, a TLS proxy). `https://` becomes `wss://`, and `/ws` is added when the URL has no path. Hot updates used to fail to connect there, as the websocket always pointed at `ws://localhost:3036/ws`
- CI: the browser test runs the dev server on `0.0.0.0` with a public URL of `127.0.0.1`, and checks the HMR websocket connects to it
- The Stimulus and React loaders (`app/javascript/controllers/autoload.js`, `app/javascript/components/mount.js`) are kept up to date like `config/rspack/rails.mjs`: `rspack:sync` and `rspack:build` rewrite them when the gem changes, and save hand edits to `tmp/rspack_rails/` first, also in apps whose `rspack.config.mjs` predates `config/rspack/rails.mjs`. They used to stay as their installer first copied them. Copies from 0.17.0 and earlier, which carry no checksum, are replaced without a backup when they match a released version. `rspack:doctor` reports a loader that is outdated or edited
- Deprecated, removed in 1.0: `RspackRails.config.dev_server_host=` and `dev_server_port=`. `rspack serve` never read them, so Rails looked for the dev server where none listened; set `RSPACK_DEV_SERVER_HOST` and `RSPACK_DEV_SERVER_PORT` instead. Deprecations go through `Rails.application.deprecators[:rspack_rails]`
- Renamed, the old names work with a deprecation warning until 1.0: `SKIP_RSPACK_BUILD` is now `RSPACK_SKIP_BUILD`, and `FORCE` (for `rspack:migrate`) is now `RSPACK_FORCE`. The `SKIP_RSPACK_BUILD` warning waits until the app is initialized, so the app's deprecation settings apply to it
- README: what of the rspack config is stable across releases (`railsConfig` and its callback's second argument). `sig/rspack_rails.rbs` lists only the public API

## [0.17.0] - 2026-11-16

- Lazy compilation goes through Rails: under `rspack serve`, the client posts the modules to compile to `/rspack/_rspack/lazy/trigger` on the page's origin, and `RspackRails::DevServerProxy` forwards that POST (and only that one) to the dev server. It used to call `http://localhost:3036/` directly, a cross-origin request that only worked where the browser can reach that port. Only the HMR websocket still goes to the dev server directly
- `#/` imports for app code: `import { formatDate } from "#/lib/dates"` loads `app/javascript/lib/dates.{js,ts}`. `rspack:install` adds `"imports": { "#/*": "./app/javascript/*" }` to `package.json` (Node.js subpath imports, resolved by rspack with the usual extensions), and the `tsconfig.json` from `rspack:install:typescript` maps `#/*` in `paths`, since TypeScript does not add extensions to `imports` targets. Existing apps: re-run `rspack:install` (and `rspack:install:typescript`, or add the `paths` entry by hand)
- Hand edits to `config/rspack/rails.mjs` are no longer lost without a word. The file carries a checksum of its content, so rspack_rails tells an edit apart from a file written by another version: `rspack:doctor` warns about it, and `rspack:sync` (also run by `rspack:build`) saves the edited file to `tmp/rspack_rails/` and says so before replacing it. Files written before this version have no checksum and are replaced as before
- Internal: `RspackRails::App` is the one place that reads an app's files (package.json, installed node modules, layouts, entry points). The doctor, the migration, the installers and `rspack:analyze` use it instead of their own copies, and the installers no longer depend on the current directory being the app's root
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
