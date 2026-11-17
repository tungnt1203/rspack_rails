# Production

[Back to the README](../README.md)

- [Builds](#builds)
- [Subresource Integrity](#subresource-integrity)
- [Deploying (Docker and Kamal)](#deploying-docker-and-kamal)
- [Dev containers](#dev-containers)
- [Bundle analysis](#bundle-analysis)
- [Doctor](#doctor)

## Builds

`rspack:build` runs automatically before `assets:precompile`, `test:prepare`, `spec:prepare` and `db:test:prepare`. Set `RSPACK_SKIP_BUILD=1` to turn that off. It installs JavaScript dependencies first, then runs the `build` script with `NODE_ENV` set from `Rails.env`: `development` in development and test, `production` everywhere else.

- **Production mode.** When `RAILS_ENV` or `NODE_ENV` is `production`, the generated config minifies. Lazy-loaded chunks are named `*.digested.js`, so Propshaft serves them without fingerprinting them a second time.
- **Browser targets.** JavaScript and CSS are compiled for the browsers in your [browserslist](https://github.com/browserslist/browserslist) config (`.browserslistrc`, or `"browserslist"` in `package.json`). Without one, the target is Baseline "widely available", which matches Rails 8's `allow_browser versions: :modern`.
- **Source maps.** On in development (`cheap-module-source-map`), off in production, so your source never lands in `public/assets`. `RSPACK_DEVTOOL` picks another [devtool](https://rspack.rs/config/devtool), for example `hidden-source-map` to upload maps to an error tracker.
- **Clean output.** Each build deletes what earlier builds left in `app/assets/builds` (a development build's source maps, old chunks), so precompiling on a machine that ran development builds ships none of it. Files other tools write there are kept.
- **Lazy compilation.** Under `rspack serve`, dynamic `import()`s are compiled the first time the page asks for them, which keeps startup fast in large apps. The request goes to `/rspack/_rspack/lazy/trigger` on the page's own origin, which Rails proxies to the dev server.
- **Persistent cache.** Kept in `node_modules/.cache/rspack`. Editing `rspack.config.mjs`, `config/rspack/rails.mjs`, `package.json`, the lockfile, `tsconfig.json` or `.browserslistrc` starts a fresh cache. Delete the directory to clear it by hand.

## Subresource Integrity

Pass `integrity: true` to have the browser check each bundle against a hash, so a tampered file on a CDN does not run:

```erb
<%= rspack_javascript_tag "application", integrity: true %>
<%= rspack_stylesheet_tag "application", integrity: true %>
```

Propshaft computes no hashes until an algorithm is set (Sprockets always does):

```ruby
# config/initializers/assets.rb
Rails.application.config.assets.integrity_hash_algorithm = "sha384"
```

- The asset pipeline computes the hashes from the files it serves, so they hold after Propshaft rewrites `url()`s in the CSS.
- Like Rails' own helpers, the attribute is only added on HTTPS (and on localhost), and never for files from `rspack serve`.
- Only the files linked by the helpers are covered. Chunks that Rspack loads at runtime (dynamic `import()`, Web Workers) get no hash. Rspack's own `SubresourceIntegrityPlugin` would hash them at build time, before Propshaft rewrites CSS chunks, so the browser would block them.

## Deploying (Docker and Kamal)

`assets:precompile` runs `rspack:build`, so the image needs Node.js at build time. Rails only adds Node.js to the `Dockerfile` for apps created with a JavaScript bundler, so `rspack:install` adds it to the build stage:

- Node.js (the version you run locally, or `NODE_VERSION`), installed the same way Rails does for esbuild apps.
- `COPY package.json package-lock.json` and `npm ci` (or your package manager's frozen install) before the app is copied, so the layer is cached.
- `RUN rm -rf node_modules` after precompiling, so the final image ships the built assets and no Node.js or node modules.

`rspack:doctor` reports a `Dockerfile` that cannot run Rspack. CI builds and runs the image of a new app.

## Dev containers

In an app made with `rails new --devcontainer`, `rspack:install` adds the `ghcr.io/devcontainers/features/node` feature to `.devcontainer/devcontainer.json` and forwards port 3036 next to 3000. Pages come through Rails, but the browser opens the HMR websocket to the dev server directly. `bin/setup`, which the container runs on creation, installs node modules. Rebuild the container after installing.

When the browser cannot reach the dev server at `localhost:3036`, set `RSPACK_DEV_SERVER_PUBLIC_URL` to the dev server's URL as the browser sees it. `https://` becomes `wss://`, and `/ws` is added when the URL has no path. GitHub Codespaces, for example, serves each port on its own URL:

```bash
# Make port 3036 visible to the browser in Codespaces first
export RSPACK_DEV_SERVER_HOST=0.0.0.0
export RSPACK_DEV_SERVER_PUBLIC_URL="https://$CODESPACE_NAME-3036.$GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN"
bin/dev
```

The same goes for a dev server behind a TLS proxy. Only the websocket uses this URL; scripts and chunks still come through Rails. CI checks that the browser connects to the public URL while the dev server listens on `0.0.0.0`. Codespaces itself is not tested.

## Bundle analysis

```bash
bin/rails rspack:analyze
```

This runs a production build into `tmp/rsdoctor/build` (leaving `app/assets/builds` alone) and writes a single-file [Rsdoctor](https://rsdoctor.rs) report to `tmp/rsdoctor/rsdoctor-report.html`, with bundle and module sizes, duplicate packages and build timings. It installs `@rsdoctor/rspack-plugin` the first time.

## Doctor

`bin/rails rspack:doctor` checks the setup and prints a hint for anything missing:

```
✓ Node.js: v22.12.0 (rspack needs ^20.19.0 || >=22.12.0)
✓ @rspack/core: 2.3.2
✓ Layout: uses rspack_javascript_tag
! Dev server: not running at http://localhost:3036
    → Start it with bin/dev; until then pages use app/assets/builds

0 error(s), 1 warning(s).
```

The task exits with status 1 when there are errors, so it can run in CI.
